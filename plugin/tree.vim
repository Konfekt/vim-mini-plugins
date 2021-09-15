" ========================================================================///
" Description: Simple directory explorer, 'tree' executable needed
" File:        tree.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Modified:    dom 01 agosto 2021 10:49:25
" ========================================================================///
"                    _                             _
"                   | |_ _ __ ___  ___      __   _(_)_ __ ___
"                   | __| '__/ _ \/ _ \     \ \ / / | '_ ` _ \
"                   | |_| | |  __/  __/  _   \ V /| | | | | | |
"                    \__|_|  \___|\___| (_)   \_/ |_|_| |_| |_|


" GUARD {{{
if exists('g:loaded_tree')
  finish
endif
let g:loaded_tree = 1

let s:save_cpo = &cpo
set cpo&vim
"}}}


command! -nargs=* -complete=dir Tree  call tree#show('<mods>' == '' ? 'enew' : '<mods> new', <q-args>)
command! -nargs=* -complete=dir PTree call tree#show('project', <q-args>)

nnoremap <Plug>(Tree)         :<c-u>Tree <C-r>=v:count?'-L '.v:count:''<cr><cr>
nnoremap <Plug>(Tree-Vsplit)  :<c-u>vert Tree <C-r>=v:count?'-L '.v:count:''<cr><cr>
nnoremap <Plug>(Tree-Split)   :<c-u>bel Tree <C-r>=v:count?'-L '.v:count:''<cr><cr>
nnoremap <Plug>(Tree-Project) :<c-u>PTree <C-r>=v:count?'-L '.v:count:''<cr><cr>


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

  let is_project = a:cmd == 'project'

  if is_project
    let was_open = s:is_tree_project_open()
    call s:close_tree_project()
    if was_open
      return
    endif
  endif

  " running the command from a Tree buffer, reuse it
  if exists('b:Tree')
    %d _
    call extend(b:Tree, args)
    call b:Tree.fill()
    return
  endif

  let curfile = buflisted(bufnr(''))  ? bufnr('') : 0
  let altfile = buflisted(bufnr('#')) ? bufnr('#') : 0

  exe 'silent' (is_project ? 'topleft vnew | 50wincmd |' :  a:cmd)
  setlocal buftype=nofile noswapfile nobuflisted ft=treeview bufhidden=wipe

  " id is used for conflicting Tree buffer names
  autocmd BufUnload <buffer> let s:id -= 1
  let s:id += 1

  autocmd ShellCmdPost <buffer> call b:Tree.refresh()

  let b:Tree = copy(s:Tree)
  call extend(b:Tree, args)
  let b:Tree.id = s:id
  let b:Tree.cmd = a:cmd
  let b:Tree.history = copy(s:History)
  let b:Tree.history.dirs = [b:Tree.dir]
  let b:Tree.curfile = curfile
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

let s:Tree = {'dirs_only': 0, 'hidden': 0, 'current': '.', 'has_preview': 0}


fun! s:Tree.fill() abort
  " Fill buffer with command output.
  exe 'r! tree' self.all_args() fnameescape(self.dir)
  let name = getline('.')
  keepjumps normal! k"_2ddgg"_dd
  call setline('.', substitute(getline('.'), '^\V'.escape(getcwd(), '\'), '.', ''))
  call setline('.', substitute(getline('.'), '^\V'.escape($HOME, '\'), '~', ''))
  let &l:statusline = "%#WildMenu# ".name
  call self.setbufname()
  call self.syntax()
  call self.close_preview()
  if has('win32')
    silent! %s/|--/├──/
    silent! %s/`--/╰──/
    silent! %s/^|/│/
  endif
  setlocal noma
  1
  redraw!
endfun


fun! s:Tree.switches()
  " Switches managed by the plugin (-F, -L, -d, -a).
  let sw = ['-F', '-L', self.depth]
  let sw += self.hidden ? ['-a'] : []
  let sw += self.dirs_only ? ['-d'] : []
  return join(sw)
endfun


fun! s:Tree.all_args()
  " All arguments, including managed switches, user switches and path.
  return trim(printf('%s %s', self.switches(), self.args))
endfun


fun! s:Tree.syntax() abort
  " Add syntax highlighting.
  syn clear
  if !get(g:, 'tree_syntax_highlighting', 1)
    return
  endif
  if b:Tree.dirs_only
    syn match TreeDirectory '\%>1l[[:alnum:]]\+'
  else
    syn match TreeDirectory '[[:alnum:]]\+.*/$' contains=TreeClassify,TreeLink
  endif
  syn match TreeExecutable '[[:alnum:]]\+.*\*$' contains=TreeClassify,TreeLink
  syn match TreeClassify    '[/*=>|]$' contained
  syn match TreeLink       '\->.*'
  syn match TreeRoot       '\%1l.*'
  hi def link TreeRoot Special
  hi def link TreeDirectory Directory
  hi def link TreeExecutable Title
  hi def link TreeClassify Function
  hi def link TreeLink Special
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

  let item = self.item_at_line()

  "add to history and descend into directory with Tree
  if a:with_tree
    if isdirectory(item)
      let self.dir = item
      call self.history.add(self.dir)
      call self.redraw()
    else
      " not possible to descend into a file...
      echo "[Tree] Not a directory"
    endif

  " preview file
  elseif a:cmd == 'preview'
    call self.preview(item)

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
    call s:open_file('edit', a:item, self.curfile, self.altfile)
    wincmd p
    call search(s:item_pat, 'W', line('.'))
  else
    exe s:open_file(a:cmd, a:item, self.curfile, self.altfile)
  endif
endfun


fun! s:Tree.preview(item)
  " Open file preview.
  if !filereadable(a:item)
    echo "[Tree] Invalid item"
    return
  endif
  let self.has_preview = v:true
  let setheight = (&lines / 2) . 'wincmd _'
  if self.is_project
    wincmd l
    exe 'pedit' s:fnameescape(a:item)
    exe setheight
    wincmd t
  else
    exe 'pedit' s:fnameescape(a:item)
    exe setheight
    exe 'wincmd' (&splitbelow ? 'k' : 'j')
  endif
endfun


fun! s:Tree.item_at_line(...) abort
  " Get full path of directory/file under cursor (or at line a:1).
  let line = a:0 ? a:1 : line('.')
  if line == 1
    return fnamemodify(getline('.'), ':p')
  endif

  " get item and its column
  let icol = match(getline(line), s:item_pat)
  let item = matchstr(getline(line), s:item_pat)

  " go up, and when an item at a lower level is found, it's a parent
  " in this case update the item name, prepending the parent's name
  while line > 2
    let line -= 1
    let L = getline(line)
    if match(L, '\w') < icol
      let icol = match(L, s:item_pat)
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


fun! s:Tree.item_in_quotes() abort
  " Item at line, in quotes.
  return has('win32') ? '"' . self.item_at_line() . '"'
        \             : '"' . escape(self.item_at_line(), '"') . '"'
endfun


fun! s:Tree.go_up()
  " Go to the parent directory.
  let self.dir = fnamemodify(self.dir, ':p:h:h')
  call self.history.add(self.dir)
  call self.redraw()
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
    let item = self.item_at_line()
    if (!skip_dirs && isdirectory(item)) || (!skip_files && filereadable(item))
      return
    endif
  endwhile
  call setpos('.', pos)
endfun


fun! s:Tree.quit() abort
  " Close the Tree buffer or the preview window.
  if self.close_preview()
    return
  endif

  if self.cmd == 'enew'
    if self.curfile
      exe 'buffer' self.curfile
      if self.altfile
        let @# = bufname(self.altfile)
      endif
    elseif self.altfile
      exe 'buffer' self.altfile
    else
      " there could be no other buffers
      try | bnext | catch | quit | endtry
    endif
  else
    quit
  endif
endfun


fun! s:Tree.toggle_hidden() abort
  " Toggle visibility of hidden elements.
  let self.hidden = !self.hidden
  call self.refresh()
  let state = self.hidden ? 'enabled' : 'disabled'
  echo '[tree] visibility of hidden files' state
endfun


fun! s:Tree.toggle_files() abort
  " Toggle visibility of regular files.
  let self.dirs_only = !self.dirs_only
  call self.refresh()
  let state = self.dirs_only ? 'disabled' : 'enabled'
  echo '[Tree] visibility of regular files' state
endfun


fun! s:Tree.change_depth(change)
  " Set the tree depth (-L option).
  let self.depth = max([1, self.depth + a:change])
  call self.refresh()
endfun


fun! s:Tree.refresh()
  " Refresh the Tree buffer.
  set lz
  let pos = getcurpos()
  setlocal ma
  %d _
  call self.fill()
  silent! call cursor(pos[1:2])
  set nolz
endfun


fun! s:Tree.redraw()
  " Redraw the Tree buffer.
  set lz
  setlocal ma
  %d _
  call self.fill()
  set nolz
endfun


fun! s:Tree.setbufname()
  " Set Tree buffer name.
  let dir = self.dir == '.' ? '.' : fnamemodify(self.dir, ':~:.')
  let name = 'Tree ' . self.all_args() . ' ' . dir
  if self.id > 1
    let name = self.id . ': ' . name
  endif
  exe 'silent! keepalt file' fnameescape(name)
endfun


fun! s:Tree.close_preview() abort
  " Close preview window, return true if there was one.
  if self.has_preview
    silent! pclose
    let self.has_preview = v:false
    return v:true
  endif
  return v:false
endfun


fun! s:Tree.line_info() abort
  let f = self.item_at_line()
  if isdirectory(f)
    let s = systemlist('ls -ldh ' . f)[0]
  else
    let s = systemlist('ls -lh ' . f)[0]
  endif
  echohl Special
  echo s[:9]
  echohl None
  echon s[10:]
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
    call b:Tree.redraw()
    echo "History:" (self.index+1) . '/' . (max+1)
  endif
endfun



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:id = 0
let s:char_under_cursor = { -> matchstr(getline('.'), '\%' . col('.') . 'c.') }
let s:tree_winvar = { w -> getbufvar(winbufnr(w), 'Tree', v:null) }
let s:item_pat = '.*─ \zs.*'


fun! s:parse_args(args) abort
  " Return parsed arguments, or an empty dict if invalid.
  if a:args == ''
    return s:default_opts()
  endif

  " ensure one leading and ending space
  let args = ' ' . a:args . ' '

  " find depth
  let depth = matchstr(args, ' -L \d\+ ')
  if depth == ''
    let depth = 2
  else
    let depth = str2nr(matchstr(depth, '\d\+'))
  endif

  " find other switches
  let dirs_only = args =~ ' -d '
  let hidden = args =~ ' -a '

  " remove managed switches
  let args = substitute(args, '\C -[LFad] \d\?', ' ', 'g')

  " find directory by removing all other switches
  let dir = trim(substitute(args, ' -\a ', ' ', 'g'))
  let args = substitute(args, '\V' . escape(dir, '\'), '', '')

  " remove quotes and escaped spaces
  if dir =~ '^".*"$' || dir =~ "'^.*$'"
    let dir = dir[1:-2]
  else
    let dir = substitute(dir, '\ ', ' ', 'g')
  endif

  let dir = dir !~ '\S' ? '.' : fnamemodify(expand(dir), ':p')

  " ensure directory exists, remove trailing slash
  if !isdirectory(dir)
    return {}
  elseif dir[-1:] =~ '[\/]'
    let dir = dir[:-2]
  endif

  return {'args': trim(args), 'dir': dir, 'depth': depth,
        \ 'hidden': hidden, 'dirs_only': dirs_only}
endfun


fun! s:is_tree_project_open()
  " Check if Tree is open in project-drawer mode.
  for w in range(1, winnr('$'))
    let tree = s:tree_winvar(w)
    if tree isnot v:null
      return tree.is_project
    endif
  endfor
  return v:false
endfun


fun! s:close_tree_buffers()
  " Close all open Tree buffers.
  for w in range(1, winnr('$'))
    let tree = s:tree_winvar(w)
    if tree isnot v:null
      exe w . 'wincmd w'
      call tree.quit()
    endif
  endfor
endfun


fun! s:close_tree_project()
  " Close project-drawer window and return to previous one.
  let cur = bufnr()
  call s:close_tree_buffers()
  for w in range(1, winnr('$'))
    if winbufnr(w) == cur
      exe w . 'wincmd w'
      return
    endif
  endfor
endfun


fun! s:maps() abort
  " Assign buffer mappings.
  nnoremap <silent><buffer><nowait> q       :call b:Tree.quit()<cr>
  nnoremap <silent><buffer><nowait> j       :<C-u>call b:Tree.move(v:count1, 0, 0, 0)<cr>
  nnoremap <silent><buffer><nowait> k       :<C-u>call b:Tree.move(v:count1, 1, 0, 0)<cr>

  nnoremap <silent><buffer><nowait> J       :<C-u>call b:Tree.move(v:count1, 0, 1, 1)<cr>
  nnoremap <silent><buffer><nowait> K       :<C-u>call b:Tree.move(v:count1, 1, 1, 1)<cr>
  nnoremap <silent><buffer><nowait> L       :<C-u>call b:Tree.move(v:count1, 0, 0, 1)<cr>
  nnoremap <silent><buffer><nowait> l       :<C-u>call b:Tree.move(v:count1, 0, 0, -1)<cr>
  nnoremap <silent><buffer><nowait> H       :<C-u>call b:Tree.move(v:count1, 1, 0, 1)<cr>
  nnoremap <silent><buffer><nowait> h       :<C-u>call b:Tree.move(v:count1, 1, 0, -1)<cr>

  nnoremap <silent><buffer><nowait> o       :<C-u>call b:Tree.action_on_line(0, 'edit')<cr>
  nnoremap <silent><buffer><nowait> <CR>    :<C-u>call b:Tree.action_on_line(0, 'edit')<cr>
  nnoremap <silent><buffer><nowait> p       :<C-u>call b:Tree.action_on_line(0, 'preview')<cr>
  nnoremap <silent><buffer><nowait> v       :<C-u>call b:Tree.action_on_line(0, 'vsplit')<cr>
  nnoremap <silent><buffer><nowait> s       :<C-u>call b:Tree.action_on_line(0, 'split')<cr>
  nnoremap <silent><buffer><nowait> t       :<C-u>call b:Tree.action_on_line(0, 'tabedit')<cr>

  nnoremap <silent><buffer><nowait> <F1>    :call <sid>help()<cr>
  nnoremap <silent><buffer><nowait> <F2>    :call b:Tree.history.go(1)<cr>
  nnoremap <silent><buffer><nowait> <F3>    :call b:Tree.history.go(0)<cr>

  nnoremap         <buffer><nowait> <C-j>   :<C-u>call b:Tree.line_info()<CR>
  nnoremap <silent><buffer><nowait> -       :call b:Tree.go_up()<cr>
  nnoremap <silent><buffer><nowait> d       :call b:Tree.action_on_line(1, '')<cr>
  nnoremap         <buffer><nowait> .       :! <C-r>=b:Tree.item_in_quotes()<cr><Home><Right>
  nnoremap         <buffer><nowait> y       :let @" = <C-r>=b:Tree.item_in_quotes()<cr><cr>:echo 'Item copied to @"'<cr>
  nnoremap <silent><buffer><nowait> gh      :call b:Tree.toggle_hidden()<cr>
  nnoremap <silent><buffer><nowait> gd      :call b:Tree.toggle_files()<cr>
  nnoremap <silent><buffer><nowait> gr      :call b:Tree.refresh()<cr>
  nnoremap <silent><buffer><nowait> g+      :<c-u>call b:Tree.change_depth(v:count1)<cr>
  nnoremap <silent><buffer><nowait> g-      :<c-u>call b:Tree.change_depth(v:count1 * -1)<cr>
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
  echo "h         move to previous file"
  echo "H         move to previous directory"
  echo "l         move to next file"
  echo "L         move to next directory"
  echo "-         go to parent directory"
  echo "d         descend into directory"
  echo "o/<CR>    open directory/file"
  echo "p         preview file"
  echo "s         open directory/file in a horizontal split"
  echo "v         open directory/file in a vertical split"
  echo "t         open directory/file in a new tab"
  echo ".         populate command line with path"
  echo "<C-j>     ls -l {item at line}"
  echo "y         copy path to register \""
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
  " Default command arguments.
  return {'args': get(g:, 'tree_default_options', ''),
        \ 'dir': '.',
        \ 'depth': get(g:, 'tree_default_depth', 2),
        \ 'hidden': v:false,
        \ 'dirs_only': v:false}
endfun


fun! s:fnameescape(item) abort
  " Escape directory name and remove trailing slashes.
  return substitute(fnameescape(a:item), '/$', '', '')
endfun


fun! s:open_file(cmd, name, alt1, alt2)
  " Open a file and set the alternate buffer.
  exe a:cmd s:fnameescape(a:name)
  if a:alt1
    let @# = bufname(a:alt1)
  elseif a:alt2
    let @# = bufname(a:alt2)
  endif
endfun


" Restore previous external compatibility options {{{
let &cpo = s:save_cpo
unlet s:save_cpo
"}}}

" vim: et sw=2 ts=2 sts=2 fdm=expr tags=tags
