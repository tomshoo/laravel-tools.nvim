" vim:set tabstop=2 shiftwidth=2:

function! s:expand_args(args) abort
  let l:string = a:args
  let l:string = substitute(l:string, '%\%(:.\)*', '\=expand(submatch(0))', 'g')
  let l:string = substitute(l:string, '\(<\%(cfile\|afile\|abuf\|amatch\|cexpr\|sfile\|slnum\|sflnum\|SID\|script\|stack\|cword\|cWORD\|client\)>\)', '\=expand(submatch(0))', 'g')

  return l:string
endfunction

function! artisan#command(args, mods, range, line1, line2, bang, ...) abort
  if a:0 && a:1 is# 'tinker' && ! a:bang && has('nvim')
    try
      if a:range
        call v:lua.require'laravel.tinker'.handle_range(0, a:line1, a:line2)
      else
        exe a:mods . ' split +enew'
        setl nobuflisted bufhidden=delete

        call v:lua.require'laravel.tinker'.handle()
      endif
    catch /^Vim\%((\S\+)\)\=:E5108:/
      bdelete
      throw v:exception
    endtry
  elseif a:0 && a:1 is# 'route:clist'
    if a:0 < 2
      call v:lua.require'laravel.routes'.setqflist()
    else
      call v:lua.require'laravel.routes'.setqflist(s:expand_args(a:2))
    endif
  elseif a:0 && a:1 is# 'route:cfind'
    if a:0 < 2
      echoerr "What should I find?"
      return
    endif

    call v:lua.require'laravel.routes'.getselect(s:expand_args(a:2))
  elseif a:0 && a:1 is# 'route:ctags'
    if a:0 < 2
      call v:lua.require'laravel.routes'.ctags()
    else
      call v:lua.require'laravel.routes'.ctags(a:2)
    endif
  else
    exe a:mods . ' split +enew'
    call artisan#execute(a:args, #{term: v:true, pty: v:true})
  endif
endfunction

function! artisan#execute(cmd, opts) abort
  let l:use_valet = executable('valet') && ! exists('g:laravel_tools_no_valet')
  let l:artisan = findfile('artisan', '.;')

  if l:artisan is# ''
    echoerr "Could not find artisan in path"
    return
  endif

  let l:islist =  type(a:cmd) == v:t_list
  let l:cmd = l:islist
          \ ? ['php', l:artisan] + a:cmd
          \ : printf('php %s %s', shellescape(fnamemodify(l:artisan, ':.')), a:cmd)

  if l:use_valet
    let l:cmd = l:islist ? (['valet'] + l:cmd) : ('valet ' . l:cmd)
  endif

  return jobstart(l:cmd, a:opts)
endfunction
