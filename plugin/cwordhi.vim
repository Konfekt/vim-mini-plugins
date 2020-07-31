" ========================================================================///
" File:        cwordhi.vim
" Description: highlight other occurrences of current word
" Version:     0.0.1
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     mer 20 novembre 2019 07:20:10
" Modified:    ven 31 gennaio 2020 14:40:16
" ========================================================================///

" GUARD {{{1
if exists('g:loaded_cwordhi')
  finish
endif
let g:loaded_cwordhi = 1

let s:save_cpo = &cpo
set cpo&vim
" }}}

let g:cwordhi_enabled = get(g:, 'cwordhi_enabled', 0)

command! CwordHiToggle call <sid>cword_toggle()

fun! s:cword_toggle()
  " Toggle word highlight {{{1
  if g:cwordhi_enabled
    call s:cword_off()
  else
    call s:cword_on()
  endif
endfun "}}}

fun! s:cword_on()
  " Enable word highlight {{{1
  let g:cwordhi_enabled = 1
  augroup cwordhi
    au!
    au WinLeave     * call s:cword_clear()
    au InsertEnter  * call s:cword_clear()
    au InsertLeave  * call s:cword_hi()
    au CursorMoved  * call s:cword_hi()
  augroup END
  doautocmd CursorMoved
endfun "}}}

fun! s:cword_off()
  " Disable word highlight {{{1
  let g:cwordhi_enabled = 0
  call s:cword_clear()
  autocmd! cwordhi
  augroup! cwordhi
endfun "}}}

fun! s:cword_hi()
  " Reapply word highlight {{{1
  call s:cword_clear()
  if mode() != 'n'
    return
  endif
  let word = escape(expand('<cword>'), '\')
  if word =~ '\k' && matchstr(getline('.'), '\%' . col('.') . 'c.') =~ '\k'
    let c = col('.') . 'c\C\<' . word . '\>'
    let l = line('.') . 'l\C\<' . word . '\>'
    let w = max([0, col('.') - strlen(expand('<cword>'))])
    let h = get(g:, 'cwordhi', 'VisualNOS')
    let w:illuminated_words_below = matchadd(h, '\V\%>' . l)
    let w:illuminated_words_above = matchadd(h, '\V\%<' . l)
    let w:illuminated_words_right = matchadd(h, '\V\%>' . c)
    let w:illuminated_words_left  = matchadd(h, '\V\%<' . w . 'c\C\<' . word . '\>')
  endif
endfun "}}}

fun! s:cword_clear()
  " Clear word highlight {{{1
  silent! call matchdelete(w:illuminated_words_above)
  silent! call matchdelete(w:illuminated_words_below)
  silent! call matchdelete(w:illuminated_words_right)
  silent! call matchdelete(w:illuminated_words_left)
endfun "}}}

" FINISH {{{1
let &cpo = s:save_cpo
unlet s:save_cpo

" vim: et sw=2 ts=2 sts=2 fdm=marker
" }}}
