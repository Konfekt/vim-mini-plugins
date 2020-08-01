" ========================================================================///
" Description: Simple directory explorer, 'tree' executable needed
" File:        tree.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Modified:    ven 18 ottobre 2019 11:59:15
" ========================================================================///
"                    _                             _
"                   | |_ _ __ ___  ___      __   _(_)_ __ ___
"                   | __| '__/ _ \/ _ \     \ \ / / | '_ ` _ \
"                   | |_| | |  __/  __/  _   \ V /| | | | | | |
"                    \__|_|  \___|\___| (_)   \_/ |_|_| |_| |_|


" Limitations:
"
" - the path cannot be given between switches, either before or after
" - an unquoted path cannot contain spaces, use quotes in this cases


if exists('g:loaded_tree')
  finish
endif
let g:loaded_tree = 1

" Preserve external compatibility options, then enable full vim compatibility
let s:save_cpo = &cpo
set cpo&vim


command! -nargs=* -complete=dir Tree call tree#show('enew', <q-args>)
command! -nargs=* -complete=dir VTree call tree#show('vnew', <q-args>)
command! -nargs=* -complete=dir STree call tree#show('new', <q-args>)
command! -nargs=* -complete=dir PTree call tree#show('project', <q-args>)

if get(g:, 'tree_mappings', 1)
  nnoremap -+ :Tree<cr>
  nnoremap -V :VTree<cr>
  nnoremap -S :STree<cr>
  nnoremap -P :PTree<cr>
endif


"------------------------------------------------------------------------------
" Function: tree#show
"
" Entry point for the Tree commands.
"
" @param cmd: defines the command to open the window
" @param args: command line args as typed by the user
"------------------------------------------------------------------------------
""
fun! tree#show(cmd, args) abort
  " Create or reuse buffer for Tree command.
  if !executable('tree')
    echo "tree executable not found"
    return
  endif

  let args = s:parse_args(a:args)
  if empty(args)
    echo '[Tree] invalid arguments'
    return
  endif

  " ensure dirname has no trailing slash
  if args.dir[-1:] =~ '[\/]'
    let args.dir = args.dir[:-2]
  endif

  " running the command from a Tree buffer, reuse it
  if exists('b:Tree')
    %d _
    call extend(b:Tree, args)
    return b:Tree.fill()
  endif

  " store alt file if calling Tree from an unlisted buffer
  if !buflisted(bufnr('')) && buflisted(bufnr('#'))
    let altfile = bufnr('#')
  else
    let altfile = 0
  endif

  let is_explorer = index(['netrw', 'dirvish'], &ft) >= 0
  let is_project = a:cmd == 'project'
  exe 'silent' (is_project ? 'aboveleft vnew | 50wincmd |' :  a:cmd)
  setlocal buftype=nofile noswapfile nobuflisted ft=treeview
  if is_explorer
    setlocal bufhidden=wipe
  else
    setlocal bufhidden=hide
  endif

  let b:Tree = copy(s:Tree)
  call extend(b:Tree, args)
  let b:Tree.cmd = a:cmd
  let b:Tree.history = copy(s:History)
  let b:Tree.history.dirs = [b:Tree.dir]
  let b:Tree.altfile = altfile
  let b:Tree.is_project = is_project

  " fill buffer with command output and assign buffer mappings
  call b:Tree.fill()
  call s:maps()
  echo "press <F1> for help"
endfun



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tree class
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:Tree = {'dirs_only': 0, 'hidden': 0, 'current': '.'}


fun! s:Tree.fill() abort
  " Fill buffer with command output.
  exe "r! tree -F " b:Tree.options . ' ' . shellescape(b:Tree.dir)

  " set statusline
  let name = getline('.')
  keepjumps normal! k"_2ddgg"_dd
  let bufname = '[Tree] -F ' . b:Tree.options . ' ' . s:fnameescape(b:Tree.dir)
  exe 'silent! keepalt file' bufname
  call setline('.', substitute(getline('.'), '^'.getcwd(), '.', ''))
  call setline('.', substitute(getline('.'), '^'.$HOME, '~', ''))
  let &l:statusline = "%#WildMenu# ".name
  setlocal noma
  call self.syntax()
  call self.cleanup()
  redraw!
endfun


fun! s:Tree.syntax() abort
  " Add syntax highlighting.
  syn clear
  if !get(g:, 'tree_syntax_highlighting', 1)
    return
  endif
  if b:Tree.options =~ 'd'
    syn match TreeDirectory '\%>1l[[:alnum:]]\+'
  else
    syn match TreeDirectory '[[:alnum:]]\+.*/$' contains=TreeClassify,TreeLink
  endif
  syn match TreeExecutable '[[:alnum:]]\+.*\*$' contains=TreeClassify,TreeLink
  syn match TreeClassify    '[/*=>|]$' contained
  syn match TreeLink       '\->.*'
  hi! link TreeDirectory Directory
  hi! link TreeExecutable Title
  hi! link TreeClassify Function
  hi! link TreeLink Special
endfun


fun! s:Tree.action_on_line(with_tree, cmd) abort
  " Perform an action on the item at current line.
  if line('.') == 1 && a:with_tree
    return
  endif

  normal! 0
  if line('.') > 1 && getline('.') !~ '\w'
    echo "[Tree] Invalid line"
    return
  endif

  let item = s:item_at_line()

  "add to history and descend into directory with Tree
  if a:with_tree
    if isdirectory(item)
      let self.dir = item
      call self.history.add(self.dir)
      call self.refresh()
    else
      " not possible to descend into a file...
      echo "[Tree] Not a directory"
    endif

  " open directory or file
  elseif isdirectory(item) || filereadable(item)
    call self.open(a:cmd, item)

  " something went wrong
  else
    echo "[Tree] Invalid item"
  endif
endfun


fun! s:Tree.open(cmd, item)
  " Open a directory or file.
  if self.is_project && a:cmd == 'edit' && len(tabpagebuflist()) > 1
    wincmd l
    exe 'edit' s:fnameescape(a:item)
    wincmd p
  else
    exe a:cmd s:fnameescape(a:item)
  endif
endfun


fun! s:Tree.item_in_quotes() abort
  " Item at line, in quotes.
  return has('win32') ? '"' . s:item_at_line() . '"'
        \             : '"' . escape(s:item_at_line(), '"') . '"'
endfun


fun! s:Tree.go_up()
  " Go to the parent directory.
  let self.dir = fnamemodify(self.dir, ':p:h:h')
  call self.history.add(self.dir)
  call self.refresh()
endfun


fun! s:Tree.move(cnt, up, move_by_root, type) abort
  " Go to closest item above or below.
  let pos = getcurpos()
  let [ skip_files, skip_dirs ] = [ a:type == 1, a:type == -1 ]
  while ( a:up ? line('.') > 1 : line('.') != line("$") )
    for n in range(a:cnt)
      exe 'normal!' (a:up ? 'k0' : 'j0')
    endfor
    call search(s:item_pat, 'W', line('.'))
    if a:move_by_root && virtcol('.') > 5
      continue
    endif
    let item = s:item_at_line()
    if (!skip_dirs && isdirectory(item)) || (!skip_files && filereadable(item))
      return
    endif
  endwhile
  call setpos('.', pos)
endfun


fun! s:Tree.quit() abort
  " Close the Tree buffer.
  let altfile = b:Tree.altfile

  if self.cmd == 'enew' && (buflisted(bufnr('#')) || altfile)
    buffer #
  elseif self.cmd == 'enew'
    " there could be no other buffers
    try | bnext | catch | quit | endtry
  else
    quit
  endif
  if altfile && bufexists(altfile)
    let @# = bufname(altfile)
  endif
  call self.cleanup()
endfun


fun! s:Tree.toggle_option(opt, ...) abort
  " Toggle Tree command parameter.
  let pat  = ' \-'.a:opt.' '

  if b:Tree.options =~ pat
    let b:Tree.options = substitute(b:Tree.options, pat, '', '')
    let state = '-'
  elseif b:Tree.options =~ a:opt
    let b:Tree.options = substitute(b:Tree.options, a:opt, '', '')
    let state = '-'
  else
    let b:Tree.options .= ' -'.a:opt.' '
    let state = '+'
  endif

  call self.refresh()
  if a:0
    echo '[Tree]' state a:1
  endif
endfun


fun! s:Tree.depth(change)
  " Set the tree depth (-L option).
  if match(self.options, 'L \d\+') >= 0
    let depth = str2nr(matchstr(self.options, 'L \zs\d\+'))
  else
    let depth = get(g:, 'tree_default_depth', 2)
  endif

  " apply change
  let depth += a:change

  " remove the old depth
  if match(self.options, '\s*\-L \d\+') >= 0
    let self.options = substitute(self.options, '\s*\-L \d\+', '', 'g')
  else
    let self.options = substitute(self.options, 'L \d\+', '', 'g')
  endif

  " apply the new depth, if non-zero
  if depth
    let space = self.options =~ ' $' ? ' ' : ''
    let self.options .= space . '-L ' . depth
  endif
  call self.refresh()
endfun


fun! s:Tree.refresh()
  " Refresh Tree buffer.
  let pos = getcurpos()
  setlocal ma
  %d _
  call self.fill()
  silent! call cursor(pos[1:2])
endfun


fun! s:Tree.cleanup() abort
  " Clean up previous Tree buffers.
  for bn in range(1, bufnr('$'))
    if !buflisted(bn) && bn != bufnr('') && bufname(bn) =~ '\V\^[Tree] -F'
      exe bn.'bw'
    endif
  endfor
endfun


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Directory history class
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:History = {'index': 0}


fun! s:History.add(dir) abort
  " Add current directory to the browsable history.
  let self.dirs = self.dirs[:self.index] + [a:dir]
  let self.index = len(self.dirs) - 1
endfun


fun! s:History.go(back) abort
  " Move through the directory history.
  let prev = self.index
  let max = len(self.dirs) - 1
  if a:back
    let self.index = max([0, self.index-1])
  else
    let self.index = min([max, self.index+1])
  endif
  if self.index == prev
    echo "Limit reached"
  else
    let b:Tree.dir = self.dirs[self.index]
    call b:Tree.refresh()
    redraw
    echo "History:" (self.index+1) . '/' . (max+1)
  endif
endfun



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:char_under_cursor = { -> matchstr(getline('.'), '\%' . col('.') . 'c.') }
let s:item_pat = has('win32') ? '\w' : '.*─ \zs.'


fun! s:maps() abort
  " Assign buffer mappings.
  nnoremap <silent><buffer><nowait> q       :call b:Tree.quit()<cr>
  nnoremap <silent><buffer><nowait> j       :<C-u>call b:Tree.move(v:count1, 0, 0, 0)<cr>
  nnoremap <silent><buffer><nowait> k       :<C-u>call b:Tree.move(v:count1, 1, 0, 0)<cr>

  nnoremap <silent><buffer><nowait> J       :<C-u>call b:Tree.move(v:count1, 0, 1, 1)<cr>
  nnoremap <silent><buffer><nowait> K       :<C-u>call b:Tree.move(v:count1, 1, 1, 1)<cr>
  nnoremap <silent><buffer><nowait> d       :<C-u>call b:Tree.move(v:count1, 0, 0, 1)<cr>
  nnoremap <silent><buffer><nowait> f       :<C-u>call b:Tree.move(v:count1, 0, 0, -1)<cr>
  nnoremap <silent><buffer><nowait> D       :<C-u>call b:Tree.move(v:count1, 1, 0, 1)<cr>
  nnoremap <silent><buffer><nowait> F       :<C-u>call b:Tree.move(v:count1, 1, 0, -1)<cr>

  nnoremap <silent><buffer><nowait> <CR>    :<C-u>call b:Tree.action_on_line(0, 'edit')<cr>
  nnoremap <silent><buffer><nowait> v       :<C-u>call b:Tree.action_on_line(0, 'vsplit')<cr>
  nnoremap <silent><buffer><nowait> s       :<C-u>call b:Tree.action_on_line(0, 'split')<cr>
  nnoremap <silent><buffer><nowait> t       :<C-u>call b:Tree.action_on_line(0, 'tabedit')<cr>

  nnoremap <silent><buffer><nowait> <F1>    :call <sid>help()<cr>
  nnoremap <silent><buffer><nowait> <F2>    :call b:Tree.history.go(1)<cr>
  nnoremap <silent><buffer><nowait> <F3>    :call b:Tree.history.go(0)<cr>

  nnoremap <silent><buffer><nowait> -       :call b:Tree.go_up()<cr>
  nnoremap <silent><buffer><nowait> o       :call b:Tree.action_on_line(1, '')<cr>
  nnoremap         <buffer><nowait> .       :! <C-r>=b:Tree.item_in_quotes()<cr><Home><Right>
  nnoremap <silent><buffer><nowait> gh      :call b:Tree.toggle_option('a', 'hidden elements')<cr>
  nnoremap <silent><buffer><nowait> gd      :call b:Tree.toggle_option('d', 'directories only')<cr>
  nnoremap <silent><buffer><nowait> gr      :call b:Tree.refresh()<cr>
  nnoremap <silent><buffer><nowait> g+      :<c-u>call b:Tree.depth(v:count1)<cr>
  nnoremap <silent><buffer><nowait> g-      :<c-u>call b:Tree.depth(v:count1 * -1)<cr>
endfun


fun! s:help()
  " Tree buffer shortcuts.
  echo "Tree buffer shortcuts"
  echo repeat('-', 50)
  echo "q         quit"
  echo "j         move to item below"
  echo "k         move to item above"
  echo "J         move up by root subdirs"
  echo "K         move down by root subdirs"
  echo "d         move to next directory"
  echo "f         move to next file"
  echo "D         move to previous directory"
  echo "F         move to previous file"
  echo "-         go to parent directory"
  echo "o         descend into directory"
  echo "<CR>      open directory/file"
  echo "s         open directory/file in a horizontal split"
  echo "v         open directory/file in a vertical split"
  echo "t         open directory/file in a new tab"
  echo ".         populate command line with path"
  echo "gd        toggle -d switch (directories only)"
  echo "gh        toggle -h switch (hidden elements)"
  echo "gr        refresh"
  echo "g+        increase depth (-L switch)"
  echo "g-        decrease depth ,,"
  echo "<F1>      this help"
  echo "<F2>      history backward"
  echo "<F3>      history forward"
  call getchar()
  redraw
endfun


fun! s:default_opts()
  " Default command switches.
  let depth = get(g:, 'tree_default_depth', 2)
  let depth = depth ? '-L ' . depth : ''
  return get(g:, 'tree_default_options', depth)
endfun


fun! s:parse_args(args) abort
  " Return parsed arguments, or an empty dict if invalid.
  if a:args == ''
    return {'options': s:default_opts(), 'dir': '.'}
  endif

  " remove leading spaces if any
  let args = substitute(a:args, '^\s*', '', '')

  " path is double quoted
  if matchstr(args, '\(["'']\).*\1') != ''
    let dir = expand(matchstr(args, '\(["'']\).*\1')[1:-2])
    let opts = substitute(args, '\(["'']\).*\1', '', 'g')
    if empty(opts)
      let opts = s:default_opts()
    endif
    return isdirectory(dir) ? {'options': opts, 'dir': dir} : {}
  endif

  " no switches
  if args !~ '^\-\| \-'
    return isdirectory(args) ? {'options': s:default_opts(), 'dir': args} : {}
  endif

  let opts = split(args)
  let dir = '.'
  let attempt = ''

  " switches come last
  if opts[0] !~ '^\-'
    while opts[0] !~ '^\-'
      let attempt .= remove(opts, 0)
      " remove trailing slash and spaces
      let attempt = substitute(expand(attempt), '\s*/\?$', '', '')
      if isdirectory(attempt)
        let dir = attempt
        break
      endif
    endwhile
    return isdirectory(dir) ? {'options': join(opts), 'dir': dir} : {}
  endif

  let opts = split(args)
  let dir = '.'
  let attempt = ''

  " unescaped path, or no path
  while len(opts)
    let attempt = remove(opts, -1) . ' ' . attempt
    " remove trailing slash and spaces
    let attempt = substitute(expand(attempt), '\s*/\?$', '', '')
    if isdirectory(attempt)
      let dir = attempt
      break
    endif
  endwhile
  return isdirectory(dir) ? {'options': join(opts), 'dir': dir} : {}
endfun


fun! s:item_at_line(...) abort
  " Get full path of directory/file under cursor (or at line a:1).
  let line = a:0 ? a:1 : line('.')
  if line == 1
    return fnamemodify(getline('.'), ':p')
  endif

  " get item and its column
  let icol = match(getline(line), '\w')
  let item = getline(line)[icol:]

  " go up, and when an item at a lower level is found, it's a parent
  " in this case update the item name, prepending the parent's name
  while line > 2
    let line -= 1
    let L = getline(line)
    if match(L, '\w') < icol
      let icol = match(L, '\w')
      let item = L[icol:] . '/' . item
    endif
  endwhile

  " handle symlinks
  if item =~ ' \-> '
    let item = matchstr(item, '.*\ze \->')
  endif

  " double slashes could be present with -F option
  let item = substitute(item, '//', '/', 'g')

  " remove classification markers
  let item = substitute(item, '[/*]$', '', '')

  " prepend the base dir to the found item
  return b:Tree.dir . '/' . item
endfun


fun! s:fnameescape(item) abort
  " Escape directory name and remove trailing slashes.
  return substitute(fnameescape(a:item), '/$', '', '')
endfun


" Restore previous external compatibility options
let &cpo = s:save_cpo
unlet s:save_cpo

" vim: et sw=2 ts=2 sts=2 fdm=indent fdn=1 tags=tags
