# rime vim

A Chinese input method (Rime / ㄓ) solution for Vim and Neovim, based on the
[rime-ice](https://github.com/iDvelve/rime-ice) scheme.

## Table of Contents

- [Introduction](#introduction)
- [Quick Start](#quick-start)
  - [Requirements](#requirements)
  - [Installation](#installation)
  - [Building the backend](#building-the-backend)
- [Configuration](#configuration)
  - [Options](#options)
  - [Environment variables](#environment-variables)
- [Usage](#usage)
  - [Commands](#commands)
  - [Key mappings](#key-mappings)
- [Integration](#integration)
  - [Autocmd](#autocmd)
  - [Statusline](#statusline)
- [Advanced Topics](#advanced-topics)
  - [rime-ice configuration examples](#rime-ice-configuration-examples)
  - [Complementary plugins](#complementary-plugins)
- [Acknowledgments](#acknowledgments)
- [License](#license)

---

## Introduction

Rime (Zhongzhouyun) input method integration for Vim / Neovim, based on the
[rime-ice](https://github.com/iDvelve/rime-ice) dictionary, supporting both Vim
(>= 8.2.1978) and Neovim.

**Usage**: enter Insert mode and type pinyin directly; a candidate popup
appears. Use the number keys or `Up` / `Down` to select a candidate,
`Enter` / `Space` to commit, and `Esc` to cancel the current composition.

![demo](https://github.com/user-attachments/assets/20978d66-c198-426f-97f1-0ba7322cf656)
![demo2](https://github.com/user-attachments/assets/93d255dd-a9e4-4612-905a-bea1bf0a5501)

Key features:

- Supports full pinyin, double pinyin, nine-grid (T9) and other input schemes
- Toggle between simplified / traditional, half/full-width punctuation, and emoji
- Candidate popup / underline rendering; the statusline can show the current input state

---

## Quick Start

### Requirements

- Vim >= 8.2.1978 or Neovim
- librime (required to build the backend)
- Rime shared data directory (e.g. [rime-ice](https://github.com/iDvelve/rime-ice)) and a user data directory

### Installation

- **vim.pack**

```vim
vim.pack.add({
  "https://github.com/TSalmon3/rime.vim"
})
```

- **vim-plug**

```vim
Plug 'TSalmon3/rime.vim'
```

### Building the backend

The built `rime-query` executable must be findable (searched on `PATH` by
default; you can point at it via `g:im_rime_bin`), otherwise `:IMStart` will
fail.

> Replace the repo path `/path/to/rime.vim` in the commands below with your
> actual path.

#### macOS

```bash
cd /path/to/rime.vim/cpp
brew install librime
clang++ -std=c++17 -I./3rd -I/opt/homebrew/include -L/opt/homebrew/lib -lstdc++ -lrime -o build/rime-query rime-query.cc
```

Alternatively, use CMake (edit the librime include / lib paths in `CMakeLists.txt` if needed):

```bash
cd /path/to/rime.vim/cpp
cmake -S . -B build
cmake --build build
```

#### Linux

Compile librime manually, then point at its header include path and dynamic
library lib path separately:

```bash
cd /path/to/rime.vim/cpp
clang++ -std=c++17 -I./3rd -I/path/to/librime/include -L/path/to/librime/lib -lstdc++ -lrime -o build/rime-query rime-query.cc
```

#### Windows

1. Download a librime prebuilt release archive.
2. Provide librime's header include path and dynamic library lib path, then compile.
3. Copy `rime.dll` into the same directory as the executable.
4. Add the executable to `PATH`.

```bash
cd /path/to/rime.vim/cpp
clang++ -std=c++17 -I./3rd -I/path/to/librime/include -L/path/to/librime/lib -lstdc++ -lrime -o build/rime-query.exe rime-query.cc
```

After building, add the generated `rime-query` to `PATH`.

---

## Configuration

### Options

These are common `g:` variables; all are optional (defaults apply). Set them in
your vimrc **before** the plugin is loaded:

```vim
" rime-query executable path (must be on PATH)
let g:im_rime_bin                  = 'rime-query'
" User data directory ($RIME_USER_DATA_DIR)
let g:im_user_data_dir             = '/path/to/rime'
" Shared data directory ($RIME_SHARED_DATA_DIR)
let g:im_shared_data_dir           = '/usr/share/rime-data'
" Backend log path ($RIME_LOG)
let g:im_log_file                  = '~/.local/state/log/vim/rime.log'
" Candidate popup height
let g:im_pumheight                 = 9
" Set to 1 to disable underline rendering
let g:im_underline_disable         = 0
" Set to 1 to skip creating default key mappings
let g:im_no_default_mappings       = 0
" Toggle input method on/off
let g:im_toggle_key                = ';;'
" Toggle Chinese/English punctuation
let g:im_toggle_ascii_punct_key    = ';a'
" Toggle simplified/traditional
let g:im_toggle_traditional_key    = ';f'
" Toggle emoji
let g:im_toggle_emoji_key          = ';e'
" Statusline icon
let g:im_status_text               = 'ㄓ'
" Half-width punctuation status text
let g:im_status_half_text          = '半'
" Full-width punctuation status text
let g:im_status_full_text          = '全'
" Simplified status text
let g:im_status_simplified_text    = '简'
" Traditional status text
let g:im_status_traditional_text   = '繁'
" Initial punctuation state (1 = half-width)
let g:im_option_ascii_punct        = 0
" Initial simplified/traditional state (1 = traditional)
let g:im_option_traditional   = 0


" Use in the command line
function! IMCmdEdit()
    let cmdtype = getcmdtype()
    if cmdtype != ':' && cmdtype != '/'
        return ''
    endif

    call im#start()

    let cmdline = getcmdline()
    if cmdline ==# ''
        call feedkeys("\<c-c>q" . cmdtype . 'a', 'nt')
    else
        let charPos = strchars(strpart(cmdline, 0, getcmdpos() - 1))
        let moveRight = charPos > 0 ? charPos . 'l' : ''
        call feedkeys("\<c-c>q" . cmdtype . 'k0' . moveRight . 'a', 'nt')
    endif
    return ''
endfunction
cnoremap <silent><expr> ;; IMCmdEdit()


" Use in the terminal
function! PassToTerm(text)
  let @t = a:text
  if has('nvim')
    call feedkeys('"tpa', 'nt')
  else
    call feedkeys("a\<c-w>\"t", 'nt')
  endif
  redraw!
endfunction
command! -nargs=* PassToTerm :call PassToTerm(<q-args>)
tnoremap ;; <c-\><c-n><cmd>call im#start()<cr>q:a:PassToTerm<space>
```

Notes:

- `g:im_rime_bin` corresponds to the backend executable.
- `g:im_user_data_dir` / `g:im_shared_data_dir` / `g:im_log_file` map to the
  three environment variables below, and take **higher priority**.

### Environment variables

The plugin reads three environment variables for its data directories and log
path. Either of the following two approaches works:

#### Setting in Vim

Set them in your vimrc, before the plugin is loaded:

```vim
" RIME_LOG - backend log path
let $RIME_LOG = expand("~/.local/state/log/vim/rime.log")

" RIME_USER_DATA_DIR - user data directory
let $RIME_USER_DATA_DIR = "/path/to/rime"

" RIME_SHARED_DATA_DIR - shared data directory
let $RIME_SHARED_DATA_DIR = "/usr/share/rime-data"
```

#### Setting in the terminal

If you want these directories to apply to all programs, export them in your
shell config (e.g. `~/.zshrc`):

```sh
export RIME_LOG="$HOME/.local/state/log/vim/rime.log"
export RIME_USER_DATA_DIR="$HOME/.local/share/rime-ice"
export RIME_SHARED_DATA_DIR="/usr/share/rime-data"
```

> Note: setting `g:im_user_data_dir`, `g:im_shared_data_dir` or `g:im_log_file`
> in Vim overrides the corresponding environment variable.

---

## Usage

### Commands

| Command   | Description                                        |
| --------- | -------------------------------------------------- |
| `:IMStart` | Start the input method (and start the `rime-query` backend) |
| `:IMStop`  | Stop the input method                              |
| `:IMToggle`| Toggle the input method on/off                     |

### Key mappings

Default key mappings (disable by setting `g:im_no_default_mappings=1`, and
customize via the corresponding `g:im_*_key`):

| Key | Mode                                | Function              |
| --- | ----------------------------------- | --------------------- |
| `;;`| normal / insert / command / terminal | Toggle input method    |
| `;a`| normal / insert                      | Toggle punctuation     |
| `;f`| normal / insert                     | Toggle traditional     |
| `;e`| normal / insert                      | Toggle emoji           |

---

## Integration

### Autocmd

**`autocmd User RimeIMEnable {command}`**

Fired when the input method is enabled; useful for disabling completion from
other plugins.

**`autocmd User RimeIMDisable {command}`**

Fired when the input method is disabled; useful for re-enabling completion from
other plugins.

Example:

```vim
function! im_nvim#hooks#on_enable() abort
  if exists('*coc#config')
    call coc#config('suggest.autoTrigger', 'none')
  endif
  if exists(':Codeium')
    Codeium Disable
  endif
  if exists('g:blink_cmp_enabled')
    let g:blink_cmp_enabled = v:false
  endif
endfunction

function! im_nvim#hooks#on_disable() abort
  if exists('*coc#config')
    call coc#config('suggest.autoTrigger', 'always')
  endif
  if exists(':Codeium')
    Codeium Enable
  endif
  if exists('g:blink_cmp_enabled')
    let g:blink_cmp_enabled = v:true
  endif
endfunction

augroup IMGroup
  autocmd!
  autocmd User RimeIMEnable  call im_nvim#hooks#on_enable()
  autocmd User RimeIMDisable call im_nvim#hooks#on_disable()
augroup END
```

### Statusline

The simplest way is to add `%{IM_Status()}` to your `'statusline'` option. When
enabled it shows `[ㄓ]半|简` (icon / punctuation / simplified-traditional; the
text is customizable via the `g:im_status_*` variables); when disabled it
returns an empty string.

```vim
let statusline^=%{IM_Status()}
```

---

## Advanced Topics

### rime-ice configuration examples

**`default.custom.yaml`**

```yaml
patch:
  schema_list:
    # You can delete or comment out schemes you do not need; the corresponding
    # *.schema.yaml scheme files can also be deleted.
    # Except t9: it depends on rime_ice, so keep rime_ice.schema.yaml if you use T9.
    - schema: double_pinyin_flypy # 鹤 双拼
    - schema: rime_ice # 雾凇 pinyin (full)
    - schema: t9 # nine-grid (Cangjie input)
    - schema: double_pinyin # natural-code double pinyin
    - schema: double_pinyin_abc # Smart ABC double pinyin
    - schema: double_pinyin_mspy # Microsoft double pinyin
    - schema: double_pinyin_sogou # Sogou double pinyin
    - schema: double_pinyin_ziguang # Ziguang double pinyin

  # Menu
  menu:
    page_size: 5 # number of candidates
```

**`double_pinyin_flypy.custom.yaml`**

```yaml
patch:
  schema:
    dependencies:
      - melt_eng # English input, mounted onto the pinyin scheme as a secondary translator
      - radical_pinyin # radical (component) input, for reverse lookup and auxiliary codes

  # Word frequency {{{1
  "translator/enable_user_dict": true

  # Mixed spelling {{{1
  # Insert long-word-priority Lua into engine/filters
  # Double pinyin is not converted to full-pinyin codes
  translator/preedit_format: []

  engine/filters:
    - lua_filter@*corrector
    - reverse_lookup_filter@radical_reverse_lookup
    - lua_filter@*autocap_filter
    - lua_filter@*pin_cand_filter
    - lua_filter@*long_word_filter # boost long words
    - lua_filter@*reduce_english_filter
    - simplifier@emoji
    - simplifier@traditionalize
    - lua_filter@*search@radical_pinyin
    - uniquifier

  # Long-word priority: promote 10 words to the first position
  long_word_filter:
    count: 10
    idx: 1

  # Change xform to derive
  speller/algebra:
    # Fuzzy sounds
    - derive/^([zcs])h/$1/
    - derive/^([zcs])([^h])/$1h$2/
    - derive/ang$/an/
    - derive/an$/ang/
    - derive/eng$/en/
    - derive/en$/eng/
    - derive/in$/ing/
    - derive/ing$/in/
    - derive/ian$/iang/
    - derive/iang$/ian/
    - derive/uan$/uang/
    - derive/uang$/uan/
    - derive/ong$/on/
      ### v u conversion
      # The 雾凇 dictionary follows correct u v(ü) annotations; the two lines
      # below accept incorrect pinyin (e.g. qv, nue) to respond to qu, nve.
    - derive/^([nl])ve$/$1ue/
    - derive/^([jqxy])u/$1v/
      # Also convert in case other dictionaries are not annotated correctly.
    - derive/^([nl])ue$/$1ve/
    - derive/^([jqxy])v/$1u/

    # Double pinyin
    - derive/^([jqxy])u$/$1v/
    - derive/^([aoe])([ioun])$/$1$1$2/
    - derive/^([aoe])(ng)?$/$1$1$2/
    - derive/iu$/Ⓠ/
    - derive/(.)ei$/$1Ⓦ/
    - derive/uan$/Ⓡ/
    - derive/[uv]e$/Ⓣ/
    - derive/un$/Ⓨ/
    - derive/^sh/Ⓤ/
    - derive/^ch/Ⓘ/
    - derive/^zh/Ⓥ/
    - derive/uo$/Ⓞ/
    - derive/ie$/Ⓟ/
    - derive/(.)i?ong$/$1Ⓢ/
    - derive/ing$|uai$/Ⓚ/
    - derive/(.)ai$/$1Ⓓ/
    - derive/(.)en$/$1Ⓕ/
    - derive/(.)eng$/$1Ⓖ/
    - derive/[iu]ang$/Ⓛ/
    - derive/(.)ang$/$1Ⓗ/
    - derive/ian$/Ⓜ/
    - derive/(.)an$/$1Ⓙ/
    - derive/(.)ou$/$1Ⓩ/
    - derive/[iu]a$/Ⓧ/
    - derive/iao$/Ⓝ/
    - derive/(.)ao$/$1Ⓒ/
    - derive/ui$/Ⓥ/
    - derive/in$/Ⓑ/
    - xlit/ⓆⓌⓇⓉⓎⓊⒾⓄⓅⓈⒹⒻⒼⒽⒿⓀⓁⓏⓍⒸⓋⒷⓃⓂ/qwrtyuiopsdfghjklzxcvbnm/
```

### Complementary plugins

- [jieba.vim](https://github.com/kkew3/jieba.vim) - word-wise navigation of jieba in Vim/Nvim
- [pangu.vim](https://github.com/hotoo/pangu.vim) - Chinese typography auto-normalization in Vim
- [vim-easymotion-zh](https://github.com/zzhirong/vim-easymotion-zh) - Make EasyMotion recognize Chinese via Double Pinyin

---

## Acknowledgments

- [ZFVimIM](https://github.com/ZSaberLv0/ZFVimIM) - Vim input method by pure vim script (user words, dynamic word priority, cloud db files)
- [rime-ls](https://github.com/wlh320/rime-ls) - a language server that provides input method functionality using librime, so you can use Rime via LSP completion
- [rime.nvim](https://github.com/rimeinn/rime.nvim) - Rime for Neovim

## License

MIT
