let s:kShiftMask = 1
let s:kCtrlMask = 4

let s:keys = {
      \ 'bs'      : [0xff08, 0,            "\<bs>"],
      \ 's-bs'    : [0xff08, s:kShiftMask, "\<bs>"],
      \ 'left'    : [0xff51, 0,            "\<left>"],
      \ 'right'   : [0xff53, 0,            "\<right>"],
      \ 'up'      : [0xff52, 0,            "\<up>"],
      \ 'down'    : [0xff54, 0,            "\<down>"],
      \ 'home'    : [0xff50, 0,            "\<home>"],
      \ 'end'     : [0xff57, 0,            "\<end>"],
      \ 'tab'     : [0xff09, 0,            "\<tab>"],
      \ 's-tab'   : [0xff09, s:kShiftMask, "\<s-tab>"],
      \ 'pagedown': [0xff56, 0,            "\<pagedown>"],
      \ 'pageup'  : [0xff55, 0,            "\<pageup>"],
      \ 'return'  : [0xff0d, 0,            "\<cr>"],
      \ 'space'   : [0x0020, 0,            "\<space>"],
      \ 'c-u'     : [0x75,   s:kCtrlMask,  "\<c-u>"],
      \ 'c-f'     : [0x66,   s:kCtrlMask,  "\<c-f>"],
      \ 'c-b'     : [0x62,   s:kCtrlMask,  "\<c-b>"],
      \ }

" key -> 回放字符串 反查表，由 s:keys 生成，
" 键为 "code:mask"（如 "65293:0"、"65289:1"）。
let s:keysym = {}
for [key, entry] in items(s:keys)
  let s:keysym[entry[0] . ':' . entry[1]] = entry[2]
endfor

function! im#keymap#fallback(keycode, mask) abort"{{{
  let literal = get(s:keysym, a:keycode . ':' . a:mask, '')
  if literal !=# ''
    return literal
  endif
  if a:mask == s:kCtrlMask && nr2char(a:keycode) =~# '^[a-z]$'
    return '\<c-' . nr2char(a:keycode) . '>'
  endif
  return a:keycode >= 0x20 ? nr2char(a:keycode) : ''
endfunction"}}}

let s:mapped_keys = {
      \ 'letters': split('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', '\zs'),
      \ 'symbols' : ['`','-','+','=','!','$','@','#','%','&','^','*','_','(',')','[',']','{','}','<','>','\','/','~',';',':',',','.','?',"'",'"'],
      \ 'numbers': ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
      \ 'specials': ['<bs>', '<s-bs>', '<left>', '<right>', '<up>', '<down>','<c-a>', '<c-e>', '<space>', '<cr>',
      \ '<tab>', '<s-tab>', '<c-w>', '<c-u>', '<c-n>', '<c-p>', '<pagedown>', '<pageup>', '<c-f>', '<c-b>']
      \ }

function! im#keymap#setup() abort"{{{
  for key in s:mapped_keys.letters
    execute 'lnoremap <expr> ' . key . ' im#keymap#char(' . string(key) . ')'
  endfor

  for key in s:mapped_keys.symbols
    execute 'lnoremap <expr> ' . key . ' im#keymap#char(' . string(key) . ')'
  endfor

  for key in s:mapped_keys.numbers
    execute 'lnoremap <expr> ' . key . ' im#keymap#char(' . string(key) . ')'
  endfor

  lnoremap <expr> <bs>       im#keymap#special('bs')
  lnoremap <expr> <s-bs>     im#keymap#special('s-bs')
  lnoremap <expr> <c-u>      im#keymap#special('c-u')
  lnoremap <expr> <c-w>      im#keymap#special('s-bs')
  lnoremap <expr> <left>     im#keymap#special('left')
  lnoremap <expr> <right>    im#keymap#special('right')
  lnoremap <expr> <up>       im#keymap#special('up')
  lnoremap <expr> <down>     im#keymap#special('down')
  lnoremap <expr> <c-n>      im#keymap#special('up')
  lnoremap <expr> <c-p>      im#keymap#special('down')
  lnoremap <expr> <c-a>      im#keymap#special('home')
  lnoremap <expr> <c-e>      im#keymap#special('end')
  lnoremap <expr> <space>    im#keymap#special('space')
  lnoremap <expr> <cr>       im#keymap#special('return')
  lnoremap <expr> <tab>      im#keymap#special('tab')
  lnoremap <expr> <s-tab>    im#keymap#special('s-tab')
  lnoremap <expr> <pagedown> im#keymap#special('pagedown')
  lnoremap <expr> <pageup>   im#keymap#special('pageup')
  lnoremap <expr> <c-f>      im#keymap#special('c-f')
  lnoremap <expr> <c-b>      im#keymap#special('c-b')

  doautocmd User RimeKeymapSetup
endfunction"}}}

function! im#keymap#clear() abort"{{{
  for key in s:mapped_keys.letters + s:mapped_keys.numbers +
        \ s:mapped_keys.symbols + s:mapped_keys.specials
    silent! execute 'lunmap ' . key
  endfor
  doautocmd User RimeKeymapClear
endfunction"}}}

function! s:begin_composition() abort"{{{
  let state = im#state#get()
  let state.boundary    = col('.')
  let state.preedit_len = 0
  let state.cursor_pos  = 0
  let state.sel_start   = 0
  let state.sel_end     = 0
endfunction"}}}

function! im#keymap#char(char) abort"{{{
  if !im#state#composing()
    call s:begin_composition()
  endif
  return "\<Cmd>call im#key(" . char2nr(a:char) . ", 0)\<CR>"
endfunction"}}}

function! im#keymap#special(name) abort"{{{
  let [code, mask, literal] = s:keys[a:name]
  if !im#state#composing()
    return literal
  endif
  return "\<Cmd>call im#key(" . code . ", " . mask . ")\<CR>"
endfunction"}}}
