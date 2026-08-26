local dump_var = "$tinkerGeneratedVariableDoNotUseOtherwiseEverythingBreaks_thisIsStrictlyForInternalUse"

local output_buffer = nil

local function is_not_dumped(line)
  return not vim.startswith(line, "echo")
      and not vim.startswith(line, "dump")
      and not vim.startswith(line, "var_dump")
      and not vim.startswith(line, "dd")
end

local function transform(statements)
  if #statements == 0 then
    error("statements cannot be empty")
  end

  local first = statements[1]
  local not_dumped = is_not_dumped(first)

  if not_dumped then
    statements[1] = dump_var .. " = " .. first
  end

  local last = statements[#statements]
  if not string.match(last, "%s*;%s*$") then
    statements[#statements] = last .. ";"
  end

  if not_dumped then
    table.insert(statements, "dump(" .. dump_var .. ");")
  end

  return statements
end

local function tinker_transform_treesitter(bufnr)
  local parser = vim.treesitter.get_parser(bufnr, "php")

  if parser == nil then
    return vim.api.nvim_buf_get_lines(bufnr, 1, -1, false)
  end

  local query = vim.treesitter.query.parse("php", "(program (expression_statement) @stmt .)")
  local tree  = parser:parse()[1]
  local root  = tree:root()


  --- @type TSNode?
  local last_node = vim.iter(query:iter_captures(root, bufnr, 0, -1))
      :filter(function(id, node) return node and query.captures[id] == "stmt" end)
      :map(function(_, node) return node end)
      :last()

  if last_node == nil then
    return vim.api.nvim_buf_get_lines(bufnr, 1, -1, false)
  end

  local rstart, cstart, rend, cend = last_node:range()
  local statements = vim.api.nvim_buf_get_text(bufnr, rstart, cstart, rend, cend, {})

  local lines = vim.api.nvim_buf_get_lines(bufnr, 1, rstart, true)

  return vim.list_extend(lines, transform(statements))
end

local function tinker_output_buffer(opts)
  if output_buffer == nil then
    output_buffer = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_var(output_buffer, "channel", vim.api.nvim_open_term(output_buffer, {}))
  end

  local found = vim.iter(vim.api.nvim_tabpage_list_wins(0)):any(function(win)
    return vim.api.nvim_win_get_buf(win) == output_buffer
  end)

  if not found then
    vim.api.nvim_open_win(output_buffer, false, { split = "below", height = (opts and opts.winheight) or 20 })
  end

  return output_buffer
end

local function tinker_initialize_repl(bufnr)
  local out         = vim.api.nvim_buf_get_var(tinker_output_buffer(), "channel")
  local transformed = tinker_transform_treesitter(bufnr)

  if not transformed then
    return nil
  end

  local text = table.concat(transformed, "\n")

  vim.api.nvim_set_option_value('busy', 1, { buf = bufnr })
  vim.api.nvim_chan_send(out, '\x1b[3J\x1b[2J\x1b[H')

  require('laravel').execute_artisan({ "tinker", "--execute", text }, {
    stdout_buffered = true,
    pty = true,
    on_stdout = function(_, data)
      vim.fn.chansend(out, data)
    end,
    on_exit = function()
      vim.api.nvim_set_option_value('busy', 0, { buf = bufnr })
      vim.fn.chansend(out, "")
    end
  })
end

local function tinker_handle()
  local tinker_file  = tostring(vim.fn.rand()) .. ".tinker.php"
  local input_buffer = vim.api.nvim_create_buf(false, false)
  local tinker_group = vim.api.nvim_create_augroup("plugins#tinker#repl", { clear = true })

  vim.api.nvim_buf_set_name(input_buffer, tinker_file)
  vim.api.nvim_win_set_buf(0, input_buffer)
  vim.api.nvim_set_option_value("filetype", "php", { buf = input_buffer })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = tinker_group,
    buffer = input_buffer,
    callback = function(args)
      tinker_initialize_repl(args.buf)
    end
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWinLeave" }, {
    group = tinker_group,
    buffer = input_buffer,
    callback = function()
      if output_buffer ~= nil and vim.api.nvim_buf_is_valid(output_buffer) then
        vim.api.nvim_buf_delete(output_buffer, { force = true })
        output_buffer = nil
      end

      vim.fs.rm(tinker_file, { force = true })
    end
  })
end

local function tinker_extract_imports(bufnr)
  local query  = vim.treesitter.query.parse("php", "(program (namespace_use_declaration) @import)")
  local parser = assert(vim.treesitter.get_parser(bufnr, "php"), "Failed to get parser for php")
  local tree   = parser:parse()[1]
  local root   = tree:root()

  return vim.iter(query:iter_captures(root, bufnr, 0, -1))
      :filter(function(id, node) return node and query.captures[id] == "import" end)
      :map(function(_, node) return vim.treesitter.get_node_text(node, 0) end)
      :totable()
end

local function tinker_handle_range(buf, line1, line2)
  local imports     = tinker_extract_imports(buf)
  local out_buffer  = tinker_output_buffer({ winheight = vim.o.cmdwinheight })
  local out_channel = vim.api.nvim_buf_get_var(out_buffer, "channel")

  local lines       = vim.api.nvim_buf_get_lines(buf, line1 - 1, line2, false)
  local text        = table.concat(vim.list_extend(imports, lines), "\n")

  vim.api.nvim_set_option_value('busy', 1, { buf = buf })

  require('laravel').execute_artisan({ 'tinker', '--execute', text }, {
    stdout_buffered = true,
    pty = true,
    on_stdout = function(_, data)
      vim.fn.chansend(out_channel, data)
    end,
    on_exit = function()
      vim.fn.chansend(out_channel, "")
      vim.api.nvim_set_option_value('busy', 0, { buf = buf })
    end
  })

  vim.api.nvim_create_autocmd("BufWinLeave", {
    group    = vim.api.nvim_create_augroup("plugins#tinker#range-repl", { clear = true }),
    buffer   = out_buffer,
    callback = function()
      output_buffer = nil
    end
  })
end

return {
  handle = tinker_handle,
  handle_range = tinker_handle_range,
}
