" ========================================================================///
" Description: conceal some text with regex
" Author:      Gianmaria Bajo <mg1979.git@gmail.com>
" License:     Vim License
" Modified:    ven 23 agosto 2019 11:14:25
" ========================================================================///

" GUARD {{{1
if exists('g:loaded_conceal')
  finish
endif
let g:loaded_conceal = 1
"}}}

" Conceal: hide a pattern, BANG clears specific patterns, all if none given.
command! -nargs=? -bang Conceal call conceal#pattern(<bang>0, <q-args>)

""=============================================================================
" Function: conceal#pattern
" Entry point for the Conceal command.
" @param reset: unconceal all or a single pattern.
" @param pattern: pattern to (un)conceal.
""=============================================================================
""
fun! conceal#pattern(reset, pattern)
  "{{{1
  hi Invisible guibg=NONE guifg=bg
  let w:conceal_patterns = get(w:, 'conceal_patterns', {})
  let w:conceal_patterns.Invisible = get(w:conceal_patterns, 'Invisible', copy(s:Hi))
  let w:conceal_patterns.Invisible.hi = 'Invisible'
  call w:conceal_patterns.Invisible.start(a:reset, a:pattern)
endfun
"}}}


let s:Hi = { 'match': 0, 'patterns' : [], 'hi': '' }


""
" Conceal or unconceal a regex pattern.
""
fun! s:Hi.start(reset, pattern) abort
  "{{{
  if a:reset
    return self.reset(!strlen(a:pattern), a:pattern)
  elseif !strlen(a:pattern)
    return self.print('Pattern needed')
  else
    call add(self.patterns, a:pattern)
    call self.apply()
    call self.print()
  endif
endfun
"}}}


""
" Remove one or all concealed patterns.
""
fun! s:Hi.reset(all, pattern)
  "{{{
  if empty(self.patterns)
    echo 'No patterns'
    return
  elseif a:all
    let self.patterns = []
    return self.clear()
  elseif index(self.patterns, a:pattern) < 0
    return self.print('No such a pattern')
  endif
  call remove(self.patterns, index(self.patterns, a:pattern))
  call self.apply()
  call self.print()
endfun
"}}}


""
" Add the conceal match.
""
fun! s:Hi.apply()
  "{{{
  call self.clear()
  if !empty(self.patterns)
    let self.match = matchadd(self.hi, join(self.patterns, '\|'))
  endif
endfun
"}}}


""
" Clear old match if present.
""
fun! s:Hi.clear()
  "{{{
  if self.match
    call matchdelete(self.match)
    let self.match = 0
  endif
endfun
"}}}


""
" Print current patterns.
""
fun! s:Hi.print(...)
  "{{{
  if a:0 | echo a:1 | return | endif
  echo 'Current patterns:' string(self.patterns)
endfun
"}}}

" vim: et sw=2 ts=2 sts=2 fdm=marker
