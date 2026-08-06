#ifdef _WIN32
#define _CRT_SECURE_NO_WARNINGS
#endif

#include <cstdlib>
#include <csignal>
#include <string>
#include <vector>
#include <iostream>
#include <filesystem>

#include <rime_api.h>
#include "3rd/json.hpp"
#include "3rd/spdlog/spdlog.h"
#include "3rd/spdlog/sinks/basic_file_sink.h"
#include "3rd/spdlog/sinks/null_sink.h"

using json = nlohmann::json;

static void log_init() {// {{{
  std::string log_path;
  bool to_file = false;
  const char *env_log = getenv("RIME_LOG");
  if (env_log && *env_log) {
    log_path = env_log;
    to_file = true;
  } else {
#ifdef _WIN32
    const char *local = getenv("LOCALAPPDATA");
    if (local && *local) {
      log_path = std::string(local) + "\\rime-query\\rime.log";
      to_file = true;
    }
#else
    const char *xdg = getenv("XDG_STATE_HOME");
    if (xdg && *xdg) {
      log_path = std::string(xdg) + "/rime-query/rime.log";
      to_file = true;
    } else {
      const char *home = getenv("HOME");
      if (home) {
        log_path = std::string(home) + "/.local/state/rime-query/rime.log";
        to_file = true;
      }
    }
#endif
  }

  std::shared_ptr<spdlog::logger> logger;
  if (to_file) {
    std::filesystem::create_directories(std::filesystem::path(log_path).parent_path());
    logger = spdlog::basic_logger_mt("rime", log_path);
  } else {
    logger = spdlog::null_logger_mt("rime");
  }
  spdlog::set_default_logger(logger);
  spdlog::set_level(spdlog::level::debug);
  spdlog::set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%l] %v");
  spdlog::flush_on(spdlog::level::debug);
}// }}}

static RimeSessionId g_session = 0;
static volatile std::sig_atomic_t g_should_exit = 0;

static void on_signal(int) {
    g_should_exit = 1;
}

static void rime_init(const char *shared_dir, const char *user_dir) {// {{{
    RIME_STRUCT(RimeTraits, traits);
    traits.shared_data_dir        = shared_dir;
    traits.user_data_dir          = user_dir;
    traits.app_name               = "rime.vim-query";
    traits.distribution_name      = "Rime";
    traits.distribution_code_name = "rime-query";
    traits.distribution_version   = "0.2.0";
    traits.min_log_level          = 3;

    RimeApi *api = rime_get_api();
    api->setup(&traits);
    api->initialize(&traits);

    if (api->start_maintenance(false)) {
        spdlog::info("deployment started, waiting for it to finish...");
        api->join_maintenance_thread();
        spdlog::info("deployment finished");
    }
}// }}}

static RimeSessionId get_session() {// {{{
    RimeApi *api = rime_get_api();
    if (!g_session || !api->find_session(g_session)) {
        g_session = api->create_session();
        spdlog::info("created new session: {}", (long long)g_session);
    }
    return g_session;
}// }}}

static std::string fetch_commit() {// {{{
    RimeApi *api = rime_get_api();
    RimeSessionId sid = get_session();

    RIME_STRUCT(RimeCommit, commit);
    std::string committed;
    if (sid && api->get_commit(sid, &commit)) {
        if (commit.text) committed = commit.text;
        api->free_commit(&commit);
    }
    return committed;
}// }}}

static void fill_context(json &resp) {// {{{
    RimeApi *api = rime_get_api();
    RimeSessionId sid = get_session();

    RIME_STRUCT(RimeContext, ctx);
    if (!sid || !api->get_context(sid, &ctx)) {
        resp["candidates"] = json::array();
        resp["comments"]   = json::array();
        resp["preedit"]    = "";
        resp["cursor_pos"] = 0;
        resp["sel_start"]  = 0;
        resp["sel_end"]    = 0;
        resp["page_no"]    = 0;
        resp["highlighted_candidate_index"] = 0;
        resp["has_more"]   = false;
        resp["composing"]  = false;
        return;
    }

    std::vector<std::string> candidates;
    std::vector<std::string> comments;
    for (int i = 0; i < ctx.menu.num_candidates; ++i) {
        candidates.push_back(ctx.menu.candidates[i].text ? ctx.menu.candidates[i].text : "");
        comments.push_back(ctx.menu.candidates[i].comment ? ctx.menu.candidates[i].comment : "");
    }

    std::string preedit = ctx.composition.preedit ? ctx.composition.preedit : "";

    resp["candidates"] = candidates;
    resp["comments"]   = comments;
    resp["preedit"]    = preedit;

    resp["cursor_pos"] = ctx.composition.cursor_pos;
    resp["sel_start"]  = ctx.composition.sel_start;
    resp["sel_end"]    = ctx.composition.sel_end;
    resp["page_no"]    = ctx.menu.page_no;
    resp["highlighted_candidate_index"] = ctx.menu.highlighted_candidate_index;
    resp["has_more"]   = !ctx.menu.is_last_page;
    resp["composing"]  = !preedit.empty();

    api->free_context(&ctx);
}// }}}

static json handle_request(const json &req) {// {{{
    json resp;
    resp["id"] = req.value("id", 0);

    std::string type = req.value("type", "");
    RimeApi *api = rime_get_api();

    // --- ping ---
    if (type == "ping") {
        resp["ok"] = true;
        return resp;
    }

    if (type == "key") {
      if (!req.contains("keycode")) {
        resp["ok"]    = false;
        resp["error"] = "key requires 'keycode'";
        return resp;
      }
      int keycode = req.value("keycode", 0);
      int mask    = req.value("mask", 0);

      RimeSessionId sid = get_session();
      Bool accepted = api->process_key(sid, keycode, mask);

      resp["ok"]        = true;
      resp["accepted"]  = (bool)accepted;
      resp["committed"] = fetch_commit();
      fill_context(resp);
      return resp;
    }

    if (type == "select") {
        int index = req.value("index", 0);
        RimeSessionId sid = get_session();
        api->select_candidate_on_current_page(sid, index);

        resp["ok"]        = true;
        resp["committed"] = fetch_commit();
        fill_context(resp);
        return resp;
    }

    if (type == "reset") {
        RimeSessionId sid = get_session();
        if (sid) api->clear_composition(sid);
        resp["ok"] = true;
        return resp;
    }

    // --- toggle_option ---
    if (type == "toggle_option") {
        std::string option = req.value("option", "");
        if (option.empty()) {
            resp["ok"]    = false;
            resp["error"] = "option is required";
            return resp;
        }
        RimeSessionId sid = get_session();
        if (!sid) {
            resp["ok"]    = false;
            resp["error"] = "no active session";
            return resp;
        }
        Bool current   = api->get_option(sid, option.c_str());
        Bool new_value = current ? False : True;
        api->set_option(sid, option.c_str(), new_value);

        resp["ok"]     = true;
        resp["option"] = option;
        resp["value"]  = (bool)new_value;
        return resp;
    }

    if (type == "set_option") {
        std::string option = req.value("option", "");
        if (option.empty()) {
            resp["ok"]    = false;
            resp["error"] = "option is required";
            return resp;
        }
        RimeSessionId sid = get_session();
        if (!sid) {
            resp["ok"]    = false;
            resp["error"] = "no active session";
            return resp;
        }
        Bool value = req.value("value", false) ? True : False;
        api->set_option(sid, option.c_str(), value);

        resp["ok"]     = true;
        resp["option"] = option;
        resp["value"]  = (bool)value;
        return resp;
    }

    if (type == "get_option") {
        std::string option = req.value("option", "");
        if (option.empty()) {
            resp["ok"]    = false;
            resp["error"] = "option is required";
            return resp;
        }
        RimeSessionId sid = get_session();
        if (!sid) {
            resp["ok"]    = false;
            resp["error"] = "no active session";
            return resp;
        }
        Bool current = api->get_option(sid, option.c_str());

        resp["ok"]     = true;
        resp["option"] = option;
        resp["value"]  = (bool)current;
        return resp;
    }

    resp["ok"]    = false;
    resp["error"] = "unknown type: " + type;
    return resp;
}// }}}

int main() {// {{{
    log_init();

    std::signal(SIGINT,  on_signal);
    std::signal(SIGTERM, on_signal);

    const char *shared_dir = getenv("RIME_SHARED_DATA_DIR");
    const char *user_dir   = getenv("RIME_USER_DATA_DIR");

    if (!shared_dir || !user_dir) {
      spdlog::info("Check env $RIME_SHARED_DATA_DIR and $RIME_USER_DATA_DIR!!!");
      return 1;
    }

    rime_init(shared_dir, user_dir);

    spdlog::info("RIME_LOG: {}", getenv("RIME_LOG") ? getenv("RIME_LOG") : "(none)");
    spdlog::info("RIME_SHARED_DATA_DIR: {}", shared_dir);
    spdlog::info("RIME_USER_DATA_DIR: {}", user_dir);

    std::string line;
    while (!g_should_exit && std::getline(std::cin, line)) {
        if (line.empty()) continue;

        try {
            json req  = json::parse(line);
            spdlog::debug(">> {}", line);
            json resp = handle_request(req);
            std::cout << resp.dump() << "\n";
            spdlog::debug("<< {}", resp.dump());
            std::cout.flush();
        } catch (const json::exception &e) {
            json err;
            err["id"]    = 0;
            err["ok"]    = false;
            err["error"] = std::string("JSON parse error: ") + e.what();
            std::cout << err.dump() << "\n";
            std::cout.flush();
        }
    }

    RimeApi *api = rime_get_api();
    if (g_session) api->destroy_session(g_session);
    api->finalize();

    return 0;
}// }}}
