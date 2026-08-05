#!/usr/bin/env python3
"""
rime-query 协议测试脚本。

用法:
    RIME_SHARED_DATA_DIR=... RIME_USER_DATA_DIR=... python3 test_rime_query.py [path/to/rime-query]

每个 test_xxx 函数是一个独立场景，按顺序跑完打印 PASS/FAIL 汇总。
故意不用 unittest —— 协议本身是"发一行 JSON、收一行 JSON"的强状态依赖
流程，写成顺序脚本更贴近真实交互，也更方便你照着某个 test_xxx 的写法
自己现改现测。
"""
import json
import subprocess
import sys
import time


class RimeQuery:
    def __init__(self, binary):
        self.proc = subprocess.Popen(
            [binary],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        self._id = 0

    def call(self, **req):
        self._id += 1
        req["id"] = self._id
        line = json.dumps(req, ensure_ascii=False)
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()
        out = self.proc.stdout.readline()
        if not out:
            err = self.proc.stderr.read()
            raise RuntimeError(f"进程无输出，可能已退出。stderr:\n{err}")
        resp = json.loads(out)
        assert resp["id"] == req["id"], f"id 错位: 发 {req['id']} 收 {resp['id']}"
        return resp

    def close(self):
        self.proc.stdin.close()
        self.proc.terminate()


def expect(cond, msg):
    if not cond:
        raise AssertionError(msg)


def test_ping(q):
    resp = q.call(type="ping")
    expect(resp["ok"], "ping 应该成功")


def test_basic_input_and_select(q):
    """最基础的场景：敲 n i，第一候选应该已经出现，选中后 preedit 清空。"""
    q.call(type="reset")
    r = q.call(type="input", key="n")
    expect(r["ok"], "input n 应该成功")
    expect(r["preedit"] == "n", f"preedit 应为 'n'，实际 {r['preedit']!r}")

    r = q.call(type="input", key="i")
    expect(r["preedit"] == "ni", f"preedit 应为 'ni'，实际 {r['preedit']!r}")
    expect(len(r["candidates"]) > 0, "ni 应该已经有候选")

    r = q.call(type="select", index=0)
    expect(r["committed"], "select 应该产生 committed 文本")
    expect(r["preedit"] == "", "选完之后 preedit 应该清空")
    expect(r["composing"] is False, "选完之后 composing 应为 false")


def test_backspace(q):
    """退格应该逐字符收缩 preedit，退到空之后 composing 变 false。"""
    q.call(type="reset")
    q.call(type="input", key="n")
    r = q.call(type="input", key="i")
    expect(r["preedit"] == "ni", "退格前 preedit 应为 ni")

    r = q.call(type="backspace")
    expect(r["preedit"] == "n", f"退一格后 preedit 应为 'n'，实际 {r['preedit']!r}")

    r = q.call(type="backspace")
    expect(r["preedit"] == "", "退空之后 preedit 应为空")
    expect(r["composing"] is False, "退空之后 composing 应为 false")


def test_cursor_pos_tracks_typing(q):
    """cursor_pos 应该随着敲字符线性增长，等于 preedit 的字节长度
    （因为这里没有移动过组合内部光标）。"""
    q.call(type="reset")
    r = None
    for ch in "nihao":
        r = q.call(type="input", key=ch)
        expect(
            r["cursor_pos"] == len(r["preedit"]),
            f"敲完 {ch!r} 后 cursor_pos={r['cursor_pos']} "
            f"应等于 preedit 长度 {len(r['preedit'])}（preedit={r['preedit']!r}）",
        )


def test_move_cursor(q):
    """在组合内部左右移动，cursor_pos 应该跟着变化，且不影响 preedit 内容。"""
    q.call(type="reset")
    q.call(type="input", key="n")
    r = q.call(type="input", key="i")
    preedit_before = r["preedit"]
    cursor_before = r["cursor_pos"]

    r = q.call(type="move_cursor", direction="left")
    expect(r["preedit"] == preedit_before, "左移不应该改变 preedit 内容")
    expect(
        r["cursor_pos"] < cursor_before,
        f"左移后 cursor_pos 应该变小，之前 {cursor_before}，之后 {r['cursor_pos']}",
    )

    r = q.call(type="move_cursor", direction="right")
    expect(r["cursor_pos"] == cursor_before, "右移一格应该回到原来的 cursor_pos")


def test_long_sentence_multi_segment(q):
    """长句多段组字的核心场景：敲一整串拼音，看 Rime 是否已经在
    preedit 里做了自动分段/整句猜测（这是判断"能不能支持长句"的
    关键指标——如果一路敲完 preedit 还是原样罗马字母，说明 schema
    没开长句联想，不是客户端的问题）。"""
    q.call(type="reset")
    r = None
    for ch in "nihaoshijie":
        r = q.call(type="input", key=ch)

    print(f"    [长句结果] preedit={r['preedit']!r}")
    print(f"    [长句结果] 候选[0..3]={[c for c in r['candidates'][:3]]}")
    # 不强行 assert 具体文本（依赖词库/schema），但至少要有候选，
    # 且 sel_end 不应该覆盖整个 preedit 之外的范围。
    expect(len(r["candidates"]) > 0, "长句应该至少产生候选")
    expect(0 <= r["sel_start"] <= r["sel_end"] <= len(r["preedit"]),
           f"sel_start/sel_end 应该落在 preedit 范围内，"
           f"实际 sel_start={r['sel_start']} sel_end={r['sel_end']} "
           f"preedit_len={len(r['preedit'])}")

    r = q.call(type="select", index=0)
    print(f"    [长句结果] 首次 select 后 committed={r['committed']!r} "
          f"剩余 preedit={r['preedit']!r} composing={r['composing']}")
    # 如果 composing 仍为 true，说明只确认了一个分段，客户端要接着
    # 用剩余 preedit 继续这次组合，而不是重新拼一遍剩余拼音。


def test_reset_clears_state(q):
    q.call(type="input", key="n")
    q.call(type="input", key="i")
    r = q.call(type="reset")
    expect(r["ok"], "reset 应该成功")
    r = q.call(type="input", key="h")
    expect(r["preedit"] == "h", f"reset 之后应该是全新组合，实际 preedit={r['preedit']!r}")


def main():
    binary = sys.argv[1] if len(sys.argv) > 1 else "./rime-query"
    q = RimeQuery(binary)
    time.sleep(0.3)  # 等 deployment 起来

    tests = [
        test_ping,
        test_basic_input_and_select,
        test_backspace,
        test_cursor_pos_tracks_typing,
        test_move_cursor,
        test_long_sentence_multi_segment,
        test_reset_clears_state,
    ]

    passed, failed = 0, 0
    for t in tests:
        name = t.__name__
        try:
            t(q)
            print(f"[PASS] {name}")
            passed += 1
        except Exception as e:
            print(f"[FAIL] {name}: {e}")
            failed += 1

    q.close()
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()



