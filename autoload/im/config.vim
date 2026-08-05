function! im#config#init() abort
  let g:im_rime_bin = get(g:, 'im_rime_bin', 'rime-query')
  let $RIME_LOG = expand(get(g:, 'im_log_file', '~/.local/state/log/vim/rime.log'))

  if has('mac')
    call s:apply('~/dotfiles/rime/rime-ice-vim', '/Library/Input Methods/Squirrel.app/Contents/SharedSupport')
  elseif !empty($WSL_DISTRO_NAME) && has('linux')
    call s:apply('~/.local/share/rime-ice', '/usr/share/rime-data')
  elseif has('win32') || has('win64')
    call s:apply('~/AppData/Roaming/Rime', 'D:/Application/weasel-0.17.4/data')
  endif
  " Other platforms: leave $RIME_USER_DATA_DIR / $RIME_SHARED_DATA_DIR
  " untouched, i.e. whatever the user/environment already set.

  let g:im_underline_disable = get(g:, 'im_underline_disable', 0)
  call im#state#init()
endfunction

function! s:apply(default_user_dir, default_shared_dir) abort
  let $RIME_USER_DATA_DIR   = expand(get(g:, 'im_user_data_dir', a:default_user_dir))
  let $RIME_SHARED_DATA_DIR = get(g:, 'im_shared_data_dir', a:default_shared_dir)
endfunction



