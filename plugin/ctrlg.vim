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
let s:lang = exists("$LANG") ? tolower($LANG[:1]) : 'en'

if index(['it'], s:lang) < 0
  let s:lang = 'en'
endif
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
  let file = expand("%")
  let mod = !&modified? '' : printf('[%s] ', s:tr('Modified'))
  let lines = printf('%s / %s %s', line('.'), line('$'), s:tr('lines'))

  if !filereadable(file)
    let info = "        " . s:tr("Not a file.")
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

fun! s:tr(string)
  if s:lang == 'en'
    return a:string
  else
    return {
          \ 'Modified':    {'it': 'Modificato'        },
          \ 'lines':       {'it': 'righe'             },
          \ 'Not a file.': {'it': 'File inesistente.' },
          \}[a:string][s:lang]
  endif
endfun

"--------------------------------------------------------------------------{{{1

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: et sw=2 ts=2 sts=2 fdm=marker
