" ========================================================================///
" Description: recently accessed files with fzf
" File:        mru.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     Mon 13 April 2020 21:43:21
" Modified:    Mon 13 April 2020 21:43:21
" ========================================================================///

" Some code has been taken from mru.vim by Yegappan Lakshmanan
" Copyright: Copyright (C) 2003-2018 Yegappan Lakshmanan

" GUARD {{{1
if v:version < 800
   finish
endif

if exists('g:loaded_mru')
   finish
endif
let g:loaded_mru = 1

let s:save_cpo = &cpo
set cpo&vim
" }}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Commands {{{1

" Autocommands to detect the most recently used files
augroup MRU_augroup
   autocmd!
   autocmd BufRead      * call s:add_file(expand('<abuf>'))
   autocmd BufWritePost * call s:add_file(expand('<abuf>'))
   autocmd VimLeavePre  * call s:save_list()
augroup END

" bang is used for fullscreen
command! -bang Mru      call s:mru_fzf(<bang>0)

" lock without bang, unlock with bang
command! -bang MruLock  call s:mru_lock(<bang>0)

" main mapping
nnoremap \fr        :Mru<cr>



" Initialization                    {{{1

function! s:init()
   if !exists('g:MRU_File')
      if has('nvim')
         let g:MRU_File = expand(stdpath('data')) . '/.vim_mru_files'
      elseif isdirectory(expand('~/.vim'))
         let g:MRU_File = expand('~/.vim') . '/.vim_mru_files'
      elseif exists('$HOME')
         let g:MRU_File = $HOME . '/.vim_mru_files'
      elseif has('win32')
         if $USERPROFILE != ''
            let g:MRU_File = $USERPROFILE . '\_vim_mru_files'
         else
            let g:MRU_File = $VIM . '/_vim_mru_files'
         endif
      endif
      let g:MRU_File=expand(g:MRU_File)
   endif

   " Files to exclude from the MRU list
   let g:MRU_Exclude_Files = get(g:, 'MRU_Exclude_Files', '')

   " Initialize files list
   if !exists('s:mru')
      let s:mru = []
      let s:mru_list_locked = 0
   endif
endfunction

call s:init()


" Add file                           {{{1

function! s:add_file(bnr)
   " MRU list is currently locked
   if s:mru_list_locked | return | endif

   " Get the full path to the filename
   let fname = fnamemodify(bufname(a:bnr + 0), ':p')
   if fname == '' | return | endif

   " Skip temporary buffers
   if !filereadable(fname) || getbufvar(a:bnr, '&buftype') != '' | return | endif

   " Do not add files matching the pattern
   if g:MRU_Exclude_Files != '' && fname =~# g:MRU_Exclude_Files | return | endif

   " Load the MRU file list
   if empty(s:mru)
      let s:mru = s:load_list()
   endif

   " Remove the new file name from the existing MRU list (if already present)
   call filter(s:mru, 'v:val !=# fname')

   " Add the new file list to the beginning of the updated old file list
   call insert(s:mru, fname, 0)

   " Trim the list
   while len(s:mru) > get(g:, 'MRU_Max_Entries', 50)
      call remove(s:mru, -1)
   endwhile
endfunction


" Save list on exit                  {{{1

function! s:save_list()
   if empty(s:mru) | return | endif
   let l = ['# MRU files list'] + s:mru
   call writefile(l, g:MRU_File)
endfunction


" Load list                          {{{1

function! s:load_list()
   let mru = []
   if filereadable(g:MRU_File)
      let mru = readfile(g:MRU_File)
      if mru[0] =~# '^#'
         " Remove the comment line
         call remove(mru, 0)
      endif
   endif
   return mru
endfunction


" Lock list                         {{{1

function! s:mru_lock(unlock)
   if a:unlock && s:mru_list_locked
      let s:mru_list_locked = 0
      echo '[MRU] unlocked'
   elseif !a:unlock && !s:mru_list_locked
      let s:mru_list_locked = 1
      echo '[MRU] locked'
   endif
endfunction


" Finder/fzf                        {{{1

function! s:mru_fzf(fullscreen)
   if !exists('g:MRU_File')
      " Variable not set for some reason
      call s:init()
   endif

   " get the valid files from viminfo only once
   if !exists('s:oldfiles')
      let s:oldfiles = filter(copy(v:oldfiles), 'filereadable(v:val)')
   endif

   " integrate files from viminfo, if not already in the list
   let mru = copy(s:mru)
   call extend(mru, filter(copy(s:oldfiles), 'index(mru, v:val) < 0'))

   if exists('g:loaded_finder') " use Finder
      call FileFinder(mru, 'Recent files')

   elseif exists('*fzf#complete') " use the fzf.vim plugin
      call fzf#vim#files('', fzf#vim#with_preview(
               \{'source': mru, 'down': '50%'}), a:fullscreen)
   else
      let dict = {'source': mru, 'sink': 'edit', 'options': [
               \   '--preview', 'cat {}', '--prompt', 'MRU >> ',
               \]}
      if !a:fullscreen | let dict.down = '~50%' | endif
      call fzf#run(fzf#wrap(dict))
   endif
endfunction


"}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Restore previous external compatibility options {{{1
let &cpo = s:save_cpo
unlet s:save_cpo

" vim: et sw=3 ts=3 sts=3 fdm=marker
