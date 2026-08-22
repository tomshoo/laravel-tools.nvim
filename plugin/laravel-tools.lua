vim.api.nvim_create_user_command('Artisan', function(args)
  local buf   = vim.api.nvim_create_buf(false, true)
  local cname = args.fargs[1]

  if cname == 'tinker' and #args.fargs == 1 then
    vim.cmd(args.mods .. " split")
    vim.api.nvim_win_set_buf(0, buf)

    local ok, err = pcall(require('laravel.tinker').handle)

    if not ok then
      vim.cmd.bdelete()

      ---@diagnostic disable-next-line
      vim.notify_once(err, vim.log.levels.ERROR)
    end
  elseif cname == 'route:clist' and #args.fargs <= 2 then
    require('laravel.routes').setqflist(args.fargs[2])
  else
    vim.cmd(args.mods .. " split")
    vim.api.nvim_win_set_buf(0, buf)

    require('laravel').execute_artisan(args.args, { term = true, pty = true })
  end
end, { nargs = '+' })


if vim.fn.exists('g:laravel_tools_no_plugin_maps') == 0 then
  vim.keymap.set('n', '<leader>lrr', '<cmd>exe "Artisan route:clist " . expand("<cfile>")<cr>', {
    desc   = "Find route at cursor",
    silent = true,
  })
end
