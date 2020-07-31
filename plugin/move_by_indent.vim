" ========================================================================///
" File:        move_by_indent.vim
" Description: move by lines with same/less/greater indentation
" Version:     1.0
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" Credits:     https://vim.fandom.com/wiki/Move_to_next/previous_line_with_same_indentation
" License:     MIT
" Created:     lun 04 novembre 2019 23:43:35
" Modified:    gio 30 luglio 2020 23:15:46
" ========================================================================///

if exists('g:loaded_move_by_indent')
  finish
endif
let g:loaded_move_by_indent = 1

let s:save_cpo = &cpo
set cpo&vim

"--------------------------------------------------------------

if get(g:, 'move_by_indent_plugs', 0)
  " move by same indent
  nnoremap <silent> <Plug>(MoveBySameIndentBwd) :call <sid>move_by_indent(0,0)<CR>
  nnoremap <silent> <Plug>(MoveBySameIndentFwd) :call <sid>move_by_indent(1,0)<CR>
  xnoremap <silent> <Plug>(MoveBySameIndentBwd) <esc>:call <sid>move_by_indent(0,0)<CR>m>gv
  xnoremap <silent> <Plug>(MoveBySameIndentFwd) <esc>:call <sid>move_by_indent(1,0)<CR>m>gv

  " move back/forward to deeper indent
  nnoremap <silent> <Plug>(MoveByDeeperIndentBwd) :call <sid>move_by_indent(0,v:count1)<CR>
  nnoremap <silent> <Plug>(MoveByDeeperIndentFwd) :call <sid>move_by_indent(1,v:count1)<CR>
  xnoremap <silent> <Plug>(MoveByDeeperIndentBwd) <esc>:call <sid>move_by_indent(0,1)<CR>m>gv
  xnoremap <silent> <Plug>(MoveByDeeperIndentFwd) <esc>:call <sid>move_by_indent(1,1)<CR>m>gv

  " move back/forward to lesser indent
  nnoremap <silent> <Plug>(MoveByLesserIndentBwd) :call <sid>move_by_indent(0,v:count1*-1)<CR>
  nnoremap <silent> <Plug>(MoveByLesserIndentFwd) :call <sid>move_by_indent(1,v:count1*-1)<CR>
  xnoremap <silent> <Plug>(MoveByLesserIndentBwd) <esc>:call <sid>move_by_indent(0,-1)<CR>m>gv
  xnoremap <silent> <Plug>(MoveByLesserIndentFwd) <esc>:call <sid>move_by_indent(1,-1)<CR>m>gv
endif

if get(g:, 'move_by_indent_mappings', 1)
  " move by same indent
  nnoremap <silent> [< :call <sid>move_by_indent(0,0)<CR>
  nnoremap <silent> ]< :call <sid>move_by_indent(1,0)<CR>
  xnoremap <silent> [< <esc>:call <sid>move_by_indent(0,0)<CR>m>gv
  xnoremap <silent> ]< <esc>:call <sid>move_by_indent(1,0)<CR>m>gv

  " move back to lesser indent
  nnoremap <silent> [> :call <sid>move_by_indent(0,v:count1*-1)<CR>
  xnoremap <silent> [> <esc>:call <sid>move_by_indent(0,-1)<CR>m>gv

  " move forward to deeper indent
  nnoremap <silent> ]> :call <sid>move_by_indent(1,v:count1)<CR>
  xnoremap <silent> ]> <esc>:call <sid>move_by_indent(1,1)<CR>m>gv

  " move back/forward to deeper indent
  nnoremap <silent> [; :call <sid>move_by_indent(0,v:count1)<CR>
  nnoremap <silent> ]; :call <sid>move_by_indent(1,v:count1)<CR>
  xnoremap <silent> [; <esc>:call <sid>move_by_indent(0,1)<CR>m>gv
  xnoremap <silent> ]; <esc>:call <sid>move_by_indent(1,1)<CR>m>gv

  " move back/forward to lesser indent
  nnoremap <silent> [, :call <sid>move_by_indent(0,v:count1*-1)<CR>
  nnoremap <silent> ], :call <sid>move_by_indent(1,v:count1*-1)<CR>
  xnoremap <silent> [, <esc>:call <sid>move_by_indent(0,-1)<CR>m>gv
  xnoremap <silent> ], <esc>:call <sid>move_by_indent(1,-1)<CR>m>gv
endif

"--------------------------------------------------------------

fun! s:move_by_indent(forward, difference)
  "
  " Move by indentation level.
  "
  let indent = matchstr(getline('.'), '^\s*')
  let [ line, opts ] = a:forward ? [ '\%>', 'e' ] : [ '\%<', 'be' ]
  let line .= line('.') . 'l'
  if !a:difference
    let [met_different, met_empty, success] = [0, 0, 0]
    let [I, pos] = [indent(line('.')), getcurpos()]
    while ( a:forward ? line('.') < line('$') : line('.') > 1 )
      exe ( a:forward ? '+' : '-' )
      if getline('.') == ''
        let met_empty = 1
      elseif (met_different || met_empty) && I == indent(line('.'))
        let success = 1
        break
      elseif I != indent(line('.'))
        let met_different = 1
      endif
    endwhile
    if !success
      call setpos('.', pos)
    else
      normal! zv
    endif
  elseif a:difference > 0
    return search('^' . indent . line . '\s\+\S', opts)
  elseif (strlen(indent) - 1) > 0
    let indent = '\s\{,' . (strlen(indent) - 1) . '}'
    return search('^' . indent . line . '\S', opts)
  endif
endfun

"--------------------------------------------------------------

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: et sw=2 ts=2 sts=2 tags=tags
