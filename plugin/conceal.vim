" ========================================================================///
" Description: conceal some text with regex
" Author:      Gianmaria Bajo <mg1979.git@gmail.com>
" License:     Vim License
" Modified:    ven 23 agosto 2019 11:14:25
" ========================================================================///

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
  "
  hi Invisible guibg=NONE guifg=bg
  let w:conceal_patterns = get(w:, 'conceal_patterns', {})
  let w:conceal_patterns.Invisible = get(w:conceal_patterns, 'Invisible', copy(s:Hi))
  let w:conceal_patterns.Invisible.hi = 'Invisible'
  call w:conceal_patterns.Invisible.start(a:reset, a:pattern)
endfun


let s:Hi = { 'match': 0, 'patterns' : [], 'hi': '' }


fun! s:Hi.start(reset, pattern) abort
  " Conceal or unconceal a regex pattern.
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


fun! s:Hi.reset(all, pattern)
  " Remove one or all concealed patterns.
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


fun! s:Hi.apply()
  " Add the conceal match.
  call self.clear()
  if !empty(self.patterns)
    let self.match = matchadd(self.hi, join(self.patterns, '\|'))
  endif
endfun


fun! s:Hi.clear()
  " Clear old match if present.
  if self.match
    call matchdelete(self.match)
    let self.match = 0
  endif
endfun


fun! s:Hi.print(...)
  " Print current patterns.
  if a:0 | echo a:1 | return | endif
  echo 'Current patterns:' string(self.patterns)
endfun

" vim: et sw=2 ts=2 sts=2 fdm=indent fdn=1
