" ========================================================================///
" File:         noinchlsearch.vim
" Description:  disable the new live hlsearch feature
" Version:      1.0
" Author:       Gianmaria Bajo <mg1979@git.gmail.com>
" License:      vim license
" Created:      lun 04 novembre 2019 00:19:18
" Modified:     lun 04 novembre 2019 00:19:18
" ========================================================================///

" patch 8.0.1238 made it so, that while searching with / or ?, all matches are
" highlighted with hlsearch, not only the one with 'incsearch'
" this plugin can revert this change, but since I find this feature useful at
" least in the : command line, it is configurable in this sense

if !has('patch-8.0.1238') || exists('g:loaded_noinchlsearch')
  finish
endif
let g:loaded_noinchlsearch = 1

let s:save_cpo = &cpo
set cpo&vim

" Plug to toggle hlsearch while in the command line
cnoremap <Plug>CmdlineHlsearch <c-r>=execute('set hls!')<cr>

" Map it to <c-s> by default, unless mapped
if empty(mapcheck('<c-s>', 'c')) && !hasmapto('<Plug>CmdlineHlsearch')
  cmap <c-s> <Plug>CmdlineHlsearch
endif

" : command line is allowed, to disable it too, change to '/,\?,:'
let s:pat = get(g:, 'noinchlsearch_cmdlines', '/,\?')

" Autocommands that disable hlsearch inside the command line
augroup noinchlsearch
  au!
  exe 'autocmd CmdlineEnter' s:pat 'call s:enter()'
  exe 'autocmd CmdlineLeave' s:pat 'call s:leave()'
augroup END

" When entering the command line, disable hlsearch if it was enabled
fun! s:enter()
  let s:oldhls = &hlsearch
  if &hlsearch
    set nohlsearch
  endif
endfun

" When exiting the command line, reenable hlsearch if it was disabled
fun! s:leave()
  if s:oldhls
    set hlsearch
  endif
endfun

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: et sw=2 ts=2 sts=2
