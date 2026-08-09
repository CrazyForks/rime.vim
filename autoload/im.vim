function! s:vimrc_save() abort"{{{
  let s:save_completeopt = &completeopt
  let s:save_pumheight   = &pumheight
  let s:save_iminsert    = &iminsert
  let s:save_imsearch    = &imsearch
  let s:save_keymap      = &keymap
endfunction"}}}

function! s:vimrc_setup() abort"{{{
  set completeopt=menuone,noinsert
  let &pumheight = get(g:, 'im_pumheight', 9)
  " set keymap=
  " set iminsert=1
  " set imsearch=0
endfunction"}}}

function! s:vimrc_restore() abort"{{{
  let &completeopt = s:save_completeopt
  let &pumheight   = s:save_pumheight
  " let &keymap      = s:save_keymap
  " let &iminsert    = s:save_iminsert
  " let &imsearch    = s:save_imsearch
  let &keymap = s:save_keymap
  let &iminsert = s:save_iminsert
  let &imsearch = s:save_imsearch
endfunction"}}}

function! s:setup_im_autocmd() abort"{{{
  augroup im_augroup
    autocmd!
    autocmd InsertEnter * call im#on_insert_enter()
    autocmd InsertLeave * call im#on_insert_leave()
  augroup END
endfunction"}}}

function! s:clear_im_autocmd() abort"{{{
  augroup im_augroup
    autocmd!
  augroup END
endfunction"}}}

function! s:redraw(ctx) abort"{{{
  let state = im#state#get()

  let lnum = line('.')
  let line = getline(lnum)

  let before = strpart(line, 0, state.boundary - 1)
  let after  = strpart(line, state.boundary - 1 + state.preedit_len)
  call setline(lnum, before . a:ctx.preedit . after)

  let state.preedit_len = strlen(a:ctx.preedit)
  let state.cursor_pos  = a:ctx.cursor_pos
  let state.sel_start   = a:ctx.sel_start
  let state.sel_end     = a:ctx.sel_end

  call cursor(lnum, state.boundary + state.cursor_pos)

  let state.candidate_count = len(a:ctx.candidates)
  let words = map(copy(a:ctx.candidates), 'v:val.word')
  let norm_preedit = substitute(a:ctx.preedit, '\s', '', 'g')
  let candidates_changed = (words !=# get(state, 'last_candidates', []))
        \ || (norm_preedit !=# get(state, 'last_preedit', ''))
  if !empty(a:ctx.candidates)
    let result = []
    let i = 1
    for item in a:ctx.candidates
      let comment = empty(item.comment) ? '' : ' ' . item.comment
      call add(result, {
            \ 'word'  : item.word,
            \ 'abbr'  : i . ' ' . item.word . comment,
            \ 'menu'  : '[' . a:ctx.preedit . ']',
            \ 'dup'   : 1,
            \ 'empty' : 1,
            \ })
      let i += 1
    endfor
    if candidates_changed
      call complete(state.boundary, result)
      let idx = a:ctx.highlighted_candidate_index
      if idx > 0
        call feedkeys(repeat("\<down>", idx), 'ni')
      endif
    else
      let delta = a:ctx.highlighted_candidate_index - get(state, 'last_hl', 0)
      if delta > 0
        call feedkeys(repeat("\<down>", delta), 'ni')
      elseif delta < 0
        call feedkeys(repeat("\<up>", -delta), 'ni')
      endif
    endif
  endif

  let state.last_candidates = words
  let state.last_preedit    = norm_preedit
  let state.last_hl         = a:ctx.highlighted_candidate_index

  call im#underline#render()
endfunction"}}}

function! im#type(char) abort"{{{
  let state = im#state#get()

  " if !im#state#composing()
  "   call s:begin_composition()
  " endif

  let ctx = im#rime#key(char2nr(a:char), 0)

  " librime reject 上屏
  if !ctx.accepted
    let committed = get(ctx, 'committed', '')
    if !empty(committed)
      let lnum = line('.')
      let line = getline(lnum)

      let before = strpart(line, 0, state.boundary - 1)
      let after = strpart(line, state.boundary - 1 + state.preedit_len)
      call setline(lnum, before . committed . after)

      call cursor(line('.'), state.boundary + strlen(committed))
      call im#underline#clean()
      call complete(col('.'), [])
    endif


    let lnum = line('.')
    let line = getline(lnum)
    let c    = col('.')
    call setline(lnum, strpart(line, 0, c - 1) . a:char . strpart(line, c - 1))
    call cursor(lnum, c + 1)

    call im#state#reset_input()
    return

  endif

  " 组词结束上屏
  let committed = get(ctx, 'committed', '')
  if !empty(committed) || !ctx.composing
    let lnum = line('.')
    let line = getline(lnum)

    let before = strpart(line, 0, state.boundary - 1)
    let after = strpart(line, state.boundary - 1 + state.preedit_len)
    call setline(lnum, before . committed . after)

    call cursor(line('.'), state.boundary + strlen(committed))
    call im#underline#clean()
    call im#state#reset_input()
    call complete(col('.'), [])
    return
    " composing waiting input
    call s:redraw(ctx)
  endif


endfunction"}}}

function! im#key(keycode, mask, ...) abort"{{{
  let state = im#state#get()
  let ctx = im#rime#key(a:keycode, a:mask)

  let fallback = a:0 ? a:1 : im#keymap#fallback(a:keycode, a:mask)

  " librime reject 上屏
  if !ctx.accepted
    let committed = get(ctx, 'committed', '')
    if !empty(committed)
      let lnum = line('.')
      let line = getline(lnum)

      let before = strpart(line, 0, state.boundary - 1)
      let after = strpart(line, state.boundary - 1 + state.preedit_len)
      call setline(lnum, before . committed . after)

      call cursor(line('.'), state.boundary + strlen(committed))
      call complete(col('.'), [])
    endif
    call im#underline#clean()
    call im#state#reset_input()
    call feedkeys(fallback, 'ni')
    return
  else
    " 组词结束上屏
    let committed = get(ctx, 'committed', '')
    if !empty(committed) || !ctx.composing
      let lnum = line('.')
      let line = getline(lnum)

      let before = strpart(line, 0, state.boundary - 1)
      let after = strpart(line, state.boundary - 1 + state.preedit_len)
      call setline(lnum, before . committed . after)

      call cursor(line('.'), state.boundary + strlen(committed))
      call im#underline#clean()
      call im#state#reset_input()
      call complete(col('.'), [])
      return
    endif
    " composing waiting input
    call s:redraw(ctx)
  endif

endfunction"}}}

function! im#cancel() abort"{{{
  if !im#state#composing()
    return
  endif
  call im#underline#clean()
  call im#rime#reset()
  call im#state#reset_input()
endfunction"}}}

function! im#enable() abort"{{{
  let state = im#state#get()
  if !state.started
    return
  endif
  call im#keymap#setup()
  set keymap=
  set iminsert=1
  set imsearch=0
  let state.boundary = -1
  let state.enabled = 1
endfunction"}}}

function! im#disable() abort"{{{
  let state = im#state#get()
  if !state.started
    return
  endif
  call im#cancel()
  " let &keymap = s:save_keymap
  " let &iminsert = s:save_iminsert
  " let &imsearch = s:save_imsearch
  call im#keymap#clear()
  let state.boundary = -1
  let state.enabled = 0
endfunction"}}}

function! im#start() abort"{{{
  let state = im#state#get()
  if state.started
    return
  endif
  let state.started = im#rime#start()
  if !state.started
    return
  endif

  call im#state#init()
  call s:setup_im_autocmd()
  call s:vimrc_save()
  call s:vimrc_setup()
  call im#enable()
  doautocmd User RimeIMEnable
  echo '[IM] on'
  redrawstatus
  return
endfunction"}}}

function! im#stop() abort"{{{
  let state = im#state#get()
  if !state.started
    return
  endif
  call s:clear_im_autocmd()
  call s:vimrc_restore()
  call im#disable()
  call im#rime#stop()
  let state.started = 0
  doautocmd User RimeIMDisable
  echo '[IM] off'
  redrawstatus
  return
endfunction"}}}

function! im#toggle() abort"{{{
  let state = im#state#get()
  if state.started
    call im#stop()
  else
    call im#start()
  endif
  return
endfunction"}}}

function! im#on_insert_enter() abort"{{{
  let state = im#state#get()
  if state.started && !state.enabled
    call im#enable()
  endif
endfunction"}}}

function! im#on_insert_leave() abort"{{{
  let state = im#state#get()
  if state.started && state.enabled
    call im#disable()
  endif
endfunction"}}}

function! im#status() abort"{{{
  let state = im#state#get()
  let icon = get(g:, 'im_status_text', 'ㄓ')
  let icon_half = get(g:, 'im_status_half_text', '半')
  let icon_full = get(g:, 'im_status_full_text', '全')
  let icon_simplified = get(g:, 'im_status_simplified_text', '简')
  let icon_traditional = get(g:, 'im_status_traditional_text', '繁')
  let punct = state.ascii_punct ? icon_half : icon_full
  let trad = state.traditional ? icon_traditional : icon_simplified
  return state.started ? "[" . icon . "]" . punct . '|' . trad  : ''
endfunction"}}}

