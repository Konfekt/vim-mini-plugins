" ========================================================================///
" File:         ctrlg.vim
" Description:  replacement for built-in <C-G> mapping
" Version:      1.0
" Author:       Gianmaria Bajo <mg1979@git.gmail.com>
" License:      MIT
" Modified:     lun 11 novembre 2019 07:13:37
" ========================================================================///

" INIT {{{1
if exists('g:loaded_ctrlg')
  finish
endif
let g:loaded_ctrlg = 1

let s:save_cpo = &cpo
set cpo&vim

let s:win = has("win32") || has("win64") || has("win16")
"}}}

"------------------------------------------------------------------------------

if maparg('<c-g>', 'n') == ''
  nnoremap <silent> <c-g> :<c-u>call CtrlG(v:count)<cr>
endif

if maparg('g<c-g>', 'n') == ''
  nnoremap <silent> g<c-g> :<c-u>call GCtrlG()<cr>
endif

"------------------------------------------------------------------------------

fun! CtrlG(cnt)
  let buf = "Buf ".bufnr('')
  let all = a:cnt ? execute("normal! 1\<C-G>") : execute("normal! \<C-G>")
  let file = matchstr(all, '"\zs.*\ze"')

  " all things enclosed in square brackets
  let mod = substitute(matchstr(all, '\[.*\]'), '\]', '] ', 'g')
  if stridx(mod, file) == 0
    let file = ''
  endif
  let mod   = substitute(mod, '"', '', 'g')
  let mod   = substitute(mod, '\s\+', ' ', 'g')

  let all   = substitute(all, '.*]', '', 'g')
  let perc  = matchstr(all,  '--\zs.*\ze--')
  let lines = matchstr(all, '\%(.*"\)\?\zs.\{-}\ze--')

  " make arglist string more compact
  let args  = matchstr(all, '.*--\s\+\zs(.*)')
  if args =~ '\S'
    let args  = substitute(args, '\v\(.{-}(\(?\d+\)?).*(\d+)\)', '  [\1/\2]', '')
  endif
  " don't print args if current file is not in arglist, and not using count
  if args =~ '(' && !a:cnt
    let args = ''
  endif

  " add current line to lines count
  if v:version < 802 && lines =~ '\d'
    let lines = printf('%s /%s', line('.'), lines)
  endif

  " add output of ls -l {file}
  if !filereadable(expand('%')) || s:win
    let info = ''
  else
    let sh = shellescape(expand('%:p'))
    let info = join(split(system('ls -l '.sh.''))[:7])
  endif

  " we'll need to trim the line if too long, 6 is the length of separators
  let all = strwidth(buf) + 6
  if mod =~ '\S'   | let all += strwidth(mod) + 6   | endif
  if file =~ '\S'  | let all += strwidth(file) + 6  | endif
  if perc =~ '\S'  | let all += strwidth(perc) + 6  | endif
  if lines =~ '\S' | let all += strwidth(lines) + 6 | endif
  if args =~ '\S'  | let all += strwidth(args)  | endif

  " we don't trim it if called with count
  let max = &columns - all - 15
  let newln = 0
  if len(info) > max
    if !a:cnt
      let info = info[:max]."…"
    else
      let newln = 1
    endif
  endif

  if mod =~ '\S'
    echohl Constant   | echo mod
  endif
  echohl Special      | echon buf
  if file =~ '\S'
    echohl WarningMsg | echon "  >>  "
    echohl Directory  | echon file
  endif
  if args =~ '\S'
    echohl Constant   | echon args
  endif
  if perc =~ '\S'
    echohl WarningMsg | echon "  >>  "
    echohl Special    | echon perc
  endif
  if lines =~ '\S'
    echohl WarningMsg | echon "  >>  "
    echohl None       | echon lines
  endif
  if info =~ '\S'
    echohl Type
    if newln | echo info
    else     | echon '   ' info
    endif
    echohl None
  endif
endfun


fun! GCtrlG() abort
  let all = split(substitute(execute("normal! g\<C-G>"), '\n', '', ''), ';')
  call map(all, 'split(v:val)')
  let n = 0
  echo "\r"
  for list in all
    for string in list
      if str2nr(string) > 0
        echohl Number
      else
        echohl None
      endif
      echon string . ' '
    endfor
    let n += 1
    if n < len(all)
      echohl NonText
      echon " >>  "
    endif
  endfor
  echohl None
endfun


"--------------------------------------------------------------------------{{{1

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: et sw=2 ts=2 sts=2 fdm=marker
