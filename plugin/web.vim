" ========================================================================///
" Description: a handful of commands for the web
" Author:      Gianmaria Bajo ( mg1979@git.gmail.com )
" File:        web.vim
" License:     MIT
" Created:     mer 09 ottobre 2019 18:44:18
" Modified:    mer 09 ottobre 2019 18:44:18
" ========================================================================///

if exists('g:loaded_web')
  finish
endif
let g:loaded_web = 1

" Preserve external compatibility options, then enable full vim compatibility...
let s:save_cpo = &cpo
set cpo&vim

"--------------------------------------------------------------

" Url:            open url in default browser
" Google:         search a string or visual selection on Google
" StackOverFlow:  ,, ,, ,, ,,  on StackOverflow
" Translate:      translate a string or visual selection with Google

command! -nargs=1        Url           call s:open_url(<q-args>)
command! -range -nargs=? Google        call s:websearch('google',<line1>,<line2>,<q-args>)
command! -range -nargs=? StackOverFlow call s:websearch('stofl',<line1>,<line2>,<q-args>)
command! -range -nargs=? Translate     call s:websearch('translate',<line1>,<line2>,<q-args>)

if get(g:, 'web_mappings', 1)
  nnoremap gou :Url <C-R>=expand('<cWORD>')<CR>
  nnoremap gog :Google <C-R>=expand('<cword>')<CR>
  nnoremap gos :StackOverFlow <C-R>=expand('<cword>')<CR>
  xnoremap gou y:Url <C-r>=escape(@", '\')<cr>
  xnoremap gog y:Google <C-r>=escape(@", '\')<cr>
  xnoremap gos y:StackOverFlow <C-r>=escape(@", '\')<cr>
endif

if get(g:, 'web_plugs', 0)
  nnoremap <Plug>(WebUrl)           :Url <C-R>=expand('<cWORD>')<CR>
  nnoremap <Plug>(WebGoogle)        :Google <C-R>=expand('<cword>')<CR>
  nnoremap <Plug>(WebStackOverFlow) :StackOverFlow <C-R>=expand('<cword>')<CR>
  xnoremap <Plug>(WebUrl)           y:Url <C-r>=escape(@", '\')<cr>
  xnoremap <Plug>(WebGoogle)        y:Google <C-r>=escape(@", '\')<cr>
  xnoremap <Plug>(WebStackOverFlow) y:StackOverFlow <C-r>=escape(@", '\')<cr>
endif

"--------------------------------------------------------------

fun! s:open_url(url)
  "
  " Open an url in the default browser
  "
  if has('win16') || has('win32') || has('win64')
    silent! call system('start cmd /cstart /b '.a:url)
  elseif has('mac') || has('macunix') || has('gui_macvim')
    silent! call system('open "'.a:url.'"')
  else
    silent! call system('xdg-open '.a:url)
  endif
  redraw!
endfun

"--------------------------------------------------------------

fun! s:websearch(site, l1, l2, string)
  "
  " Search a string wtih a web search engine
  "
  if a:l1 != a:l2
    echoerr 'Multiline not allowed'
    return
  elseif empty(a:string)
    silent normal! `<v`>y
    let s = substitute(@", "\<NL>", '\r', 'g')
  else
    let s = a:string
  endif
  let s = substitute(s, ' ', '+', 'g')
  let s = substitute(s, '"', '%22', 'g')

  let url = {
        \'google': 'https://www.google.com/search?q=%s',
        \'stofl': 'https://stackoverflow.com/search?q=%s',
        \'translate': 'http://translate.google.com/\#auto/it/%s',
        \}[a:site]
  call s:open_url(printf(url, s))
endfun


" Restore previous external compatibility options
let &cpo = s:save_cpo
unlet s:save_cpo

" vim: et sw=2 ts=2 sts=2
