" vim:set tabstop=2 shiftwidth=2:

function! s:expand_args(args) abort
  let l:string = a:args
  let l:string = substitute(l:string, '%\%(:.\)*', '\=expand(submatch(0))', 'g')
  let l:string = substitute(l:string, '\(<\%(cfile\|afile\|abuf\|amatch\|cexpr\|sfile\|slnum\|sflnum\|SID\|script\|stack\|cword\|cWORD\|client\)>\)', '\=expand(submatch(0))', 'g')

  return l:string
endfunction

function! artisan#command(args, mods, range, line1, line2, ...) abort
  if a:0 && a:1 is# 'tinker'
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
    if a:0 > 1
      call v:lua.require'laravel.routes'.setqflist(s:expand_args(a:2))
    else
      call v:lua.require'laravel.routes'.setqflist()
    endif
  else
    exe a:mods . ' split' | call v:lua.require'laravel'.execute_artisan(a:args, #{term: v:true, pty: v:true})
  endif
endfunction
