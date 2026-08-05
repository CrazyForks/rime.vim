highlight Preedit gui=underline cterm=underline
highlight default link IMActiveSegment CompletionPrefix

function! im#underline#render() abort"{{{
  if exists('g:im_underline_disable') && g:im_underline_disable
    return
  endif
  call im#underline#render_match()
endfunction"}}}

function! im#underline#clean() abort"{{{
  if exists('g:im_underline_disable') && g:im_underline_disable
    return
  endif
  call im#underline#clean_match()
endfunction"}}}

function! im#underline#render_match() abort"{{{
  let state = im#state#get()

  if state.match_id != 0
    call matchdelete(state.match_id)
    let state.match_id = 0
  endif

  if state.boundary < 0 || state.preedit_len <= 0
    return
  endif

  let lnum = line('.')
  let match_id = matchaddpos('Preedit',
        \ [[lnum, state.boundary, state.preedit_len]])
  if state.match_id != 0
    call matchdelete(state.match_id)
  endif
  let state.match_id = match_id

endfunction"}}}

function! im#underline#render_extmark() abort"{{{
  let state = im#state#get()

  if state.mark_id != 0
    call nvim_buf_del_extmark(0, state.ns_id, state.mark_id)
    let state.mark_id = 0
  endif

  if state.boundary < 0 || state.preedit_len <= 0
    return
  endif

  let lnum = line('.') - 1
  let opts = {
        \ 'end_col'  : state.boundary - 1 + state.preedit_len,
        \ 'hl_group' : 'CompletionPrefix',
        \ }
  let state.mark_id = nvim_buf_set_extmark(0, state.ns_id, lnum, state.boundary - 1, opts)

  if state.sel_end > state.sel_start
    call nvim_buf_set_extmark(0, state.ns_id, lnum, state.boundary - 1 + state.sel_start, {
          \ 'end_col'  : state.boundary - 1 + state.sel_end,
          \ 'hl_group' : 'IMActiveSegment',
          \ })
  endif
endfunction"}}}

function! im#underline#clean_match() abort"{{{
  let state = im#state#get()
  if state.match_id != 0
    call matchdelete(state.match_id)
    let state.match_id = 0
  endif
endfunction"}}}

function! im#underline#clean_extmark() abort"{{{
  let state = im#state#get()
  if state.mark_id != 0
    call nvim_buf_del_extmark(0, state.ns_id, state.mark_id)
    let state.mark_id = 0
  endif
  call nvim_buf_clear_namespace(0, state.ns_id, 0, -1)
endfunction"}}}


