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

let s:win  = has("win32") || has("win64") || has("win16")
"}}}

"------------------------------------------------------------------------------

if maparg('<c-g>', 'n') == ''
  nnoremap <silent> <c-g> :<c-u>call CtrlG()<cr>
endif

"------------------------------------------------------------------------------

fun! CtrlG()
  " percentage
  let l = str2float(line('.').".0") / line("$") * 100
  let perc = string(float2nr(l)) . "%"

  let buf = "Buf ".bufnr('')
  let file = expand("%") == '' ? s:tr('unnamed') : expand('%')
  let mod = !&modified? '' : printf('[%s] ', s:tr('modified'))
  let lines = printf('%s / %s %s', line('.'), line('$'), s:tr('lines'))

  if !filereadable(file)
    let info = "        " . s:tr("nofile")
    let warn = 1
  else
    let info = s:win ? '' : substitute(system('ls -l "'.file.'"'), '\('.file.'\)\?\n', '', '')
    let info = "        " . info
    let warn = 0
  endif

  let all = strwidth(buf.file.perc.mod.lines) + 18 "18 is 6x3 separators
  let max = &columns - all - 20
  if len(info) > max
    let info = info[:max]."…"
  endif

  echohl Constant   | echo mod
  echohl Special    | echon buf
  echohl WarningMsg | echon "  >>  "
  echohl Directory  | echon file
  echohl WarningMsg | echon "  >>  "
  echohl Special    | echon perc
  echohl WarningMsg | echon "  >>  "
  echohl None       | echon lines
  if warn
    echohl WarningMsg
  else
    echohl Type
  endif
  echon info
  echohl None
endfun


let s:langs = {
      \ 'en': ['Modified',   'lines', 'Not a file.', '[No Name]'],
      \ 'it': ['Modificato', 'righe', 'File inesistente', '[Senza nome]']
      \}

let s:tr_dict = {
      \ 'modified': 0,
      \ 'lines': 1,
      \ 'nofile': 2,
      \ 'unnamed': 3
      \}

fun! s:tr(string)
  try
    if exists('g:ctrlg_lang')
      return g:ctrlg_lang[s:tr_dict[a:string]]
    endif
    let lang = exists("$LANG") ? tolower($LANG[:1]) : 'en'
    if !has_key(s:langs, lang)
      let lang = 'en'
    endif
    return s:langs[lang][s:tr_dict[a:string]]
  catch
    return s:langs['en'][s:tr_dict[a:string]]
  endtry
endfun

"--------------------------------------------------------------------------{{{1

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: et sw=2 ts=2 sts=2 fdm=marker
