command! -range=0 -nargs=+ Artisan call artisan#command(<q-args>, <q-mods>, <range>, <line1>, <line2>, <f-args>)

noremap <silent> <Plug>(route-handler-under-cursor) <cmd>Artisan route:cfind <cfile><cr>
noremap <silent> <Plug>(eval-under-cursor)          :Artisan tinker<cr>
