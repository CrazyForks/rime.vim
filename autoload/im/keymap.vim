let s:keysym = {
      \ 'bs'       : 0xff08,
      \ 'left'     : 0xff51,
      \ 'right'    : 0xff53,
      \ 'home'     : 0xff50,
      \ 'end'      : 0xff57,
      \ 'tab'      : 0xff09,
      \ 'pagedown' : 0xff56,
      \ 'pageup'   : 0xff55,
      \ 'return'   : 0xff0d,
      \ 'space'   : 0x0020,
      \ 'escape' : 0xff1b
      \ }

let s:kShiftMask = 1
let s:kCtrlMask = 4

let s:mapped_keys = {
      \ 'letters': split('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', '\zs'),
      \ 'symbols' : ['`','-','+','=','!','$','@','#','%','&','^','*','_','(',')','[',']','{','}','<','>','\','/','~',';',':',',','.','?',"'",'"'],
      \ 'numbers': ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
      \ 'specials': ['<bs>', '<s-bs>', '<left>', '<right>', '<c-a>', '<c-e>', '<space>', '<cr>',
      \ '<tab>', '<s-tab>', '<c-w>', '<c-u>', '<pagedown>', '<pageup>']
      \ }

function! im#keymap#setup() abort"{{{
  for key in s:mapped_keys.letters
    execute 'lnoremap <expr> ' . key . ' im#keymap#letter(' . string(key) . ')'
  endfor

  for key in s:mapped_keys.symbols
    execute 'lnoremap <expr> ' . key . ' im#keymap#symbol(' . string(key) . ')'
  endfor

  for i in range(len(s:mapped_keys.numbers))
    let key = s:mapped_keys.numbers[i]
    execute 'lnoremap <expr> ' . key . ' im#keymap#digit(' . string(key) . ')'
  endfor

  lnoremap <expr> <bs>    im#keymap#backspace()
  lnoremap <expr> <s-bs>  im#keymap#shift_backspace()
  lnoremap <expr> <c-u>   im#keymap#ctrl_u()
  lnoremap <expr> <c-w>   im#keymap#shift_backspace()
  lnoremap <expr> <left>  im#keymap#move('left')
  lnoremap <expr> <right> im#keymap#move('right')
  lnoremap <expr> <c-a>   im#keymap#move('home')
  lnoremap <expr> <c-e>   im#keymap#move('end')
  lnoremap <expr> <space> im#keymap#space()
  lnoremap <expr> <cr>    im#keymap#return()
  lnoremap <expr> <tab>   im#keymap#tab()
  lnoremap <expr> <s-tab> im#keymap#shift_tab()

  lnoremap <expr> <pagedown> im#keymap#pagedown()
  lnoremap <expr> <pageup>  im#keymap#pageup()
endfunction"}}}

function! im#keymap#clear() abort"{{{
  for key in s:mapped_keys.letters + s:mapped_keys.numbers +
        \ s:mapped_keys.symbols + s:mapped_keys.specials
    silent! execute 'lunmap ' . key
  endfor
endfunction"}}}

function! s:begin_composition() abort"{{{
  let state = im#state#get()
  let state.boundary    = col('.')
  let state.preedit_len = 0
  let state.cursor_pos  = 0
  let state.sel_start   = 0
  let state.sel_end     = 0
endfunction"}}}

function! im#keymap#letter(char) abort"{{{
  if !im#state#composing()
    call s:begin_composition()
  endif
  return "\<Cmd>call im#key(" . char2nr(a:char) . ", 0, " . string(a:char) . ")\<CR>"
endfunction"}}}

function! im#keymap#symbol(char) abort"{{{
  if !im#state#composing()
    call s:begin_composition()
  endif
  return "\<Cmd>call im#key(" . char2nr(a:char) . ", 0, " . string(a:char) . ")\<CR>"
endfunction"}}}

function! im#keymap#digit(char) abort"{{{
  if !im#state#composing()
    call s:begin_composition()
  endif
  return "\<Cmd>call im#key(" . char2nr(a:char) . ", 0, " . string(a:char) . ")\<CR>"
endfunction"}}}

function! im#keymap#backspace() abort"{{{
  if !im#state#composing()
    return "\<bs>"
  endif
  return "\<Cmd>call im#key(" . s:keysym.bs . ", 0, \"\\<bs>\")\<CR>"
endfunction"}}}

function! im#keymap#shift_backspace() abort"{{{
  if !im#state#composing()
    return "\<bs>"
  endif
  return "\<Cmd>call im#key(" . s:keysym.bs . ", " . s:kShiftMask . ", \"\\<bs>\")\<CR>"
endfunction"}}}

function! im#keymap#move(direction) abort"{{{
  let move_fallback = {
        \ 'left'  : "\<left>",
        \ 'right' : "\<right>",
        \ 'home'  : "\<home>",
        \ 'end'   : "\<end>",
        \ }
  if !im#state#composing()
    return move_fallback[a:direction]
  endif
  return "\<Cmd>call im#key(" . s:keysym[a:direction] . ", 0, " . string(move_fallback[a:direction]) . ")\<CR>"
endfunction"}}}

function! im#keymap#space() abort"{{{
  if !im#state#composing()
    return "\<space>"
  endif
  return "\<Cmd>call im#key(" . s:keysym.space . ", 0, \"\\<space>\")\<CR>"
endfunction"}}}

function! im#keymap#return() abort"{{{
  if !im#state#composing()
    return "\<cr>"
  endif
  return "\<Cmd>call im#key(" . s:keysym.return . ", 0, \"\\<cr>\")\<CR>"
endfunction"}}}

function! im#keymap#tab() abort"{{{
  if !im#state#composing()
    return "\<tab>"
  endif
  return "\<Cmd>call im#key(" . s:keysym.tab . ", 0, \"\\<tab>\")\<CR>"
endfunction"}}}

function! im#keymap#shift_tab() abort"{{{
  if !im#state#composing()
    return "\<s-tab>"
  endif
  return "\<Cmd>call im#key(" . s:keysym.tab . ", " . s:kShiftMask . ", \"\\<s-tab>\")\<CR>"
endfunction"}}}

function! im#keymap#pagedown() abort"{{{
  if !im#state#composing()
    return "\<tab>"
  endif
  return "\<Cmd>call im#key(" . s:keysym.pagedown . ", 0, \"\\<pagedown>\")\<CR>"
endfunction"}}}

function! im#keymap#pageup() abort"{{{
  if !im#state#composing()
    return "\<tab>"
  endif
  return "\<Cmd>call im#key(" . s:keysym.pageup . ", 0, \"\\<pageup>\")\<CR>"
endfunction"}}}

function! im#keymap#ctrl_u() abort"{{{
  if !im#state#composing()
    return "\<c-u>"
  endif
  return "\<Cmd>call im#key(" . s:keysym.escape . ", 0, \"\\<c-u>\")\<CR>"
endfunction"}}}
