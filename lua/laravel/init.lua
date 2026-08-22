local M = {}

---@param valet boolean
---@param artisan string
---@param command string[]
---@return string[]
local function artisan_command_list(valet, artisan, command)
  local cmdlist = vim.list_extend({ 'php', artisan }, command)

  if valet then
    cmdlist = vim.list_extend({ 'valet' }, cmdlist)
  end

  return cmdlist
end

---@param valet boolean
---@param artisan string
---@param command string
---@return string
local function artisan_command_string(valet, artisan, command)
  local cmdstring = string.format('php %q ', artisan) .. command

  if valet then
    cmdstring = 'valet ' .. cmdstring
  end

  return cmdstring
end

---Execute an artisan command
---@param command string[]|string
---@param job_opts table options to forward to vim.fn.jobstart
---@return integer
function M.execute_artisan(command, job_opts)
  local use_valet = vim.fn.exists('g:laravel_tools_no_valet') == 0 and vim.fn.executable('valet') == 1
  local artisan   = vim.fs.find('artisan', { upward = true, limit = 1 })

  if #artisan == 0 then
    error('Could not find artisan in path')
  end

  ---@type string|string[]
  local artisan_command = {}

  if (type(command) == 'string') then
    artisan_command = artisan_command_string(use_valet, vim.fn.fnamemodify(artisan[1], ':.'), command)
  else
    artisan_command = artisan_command_list(use_valet, vim.fn.fnamemodify(artisan[1], ':.'), command)
  end

  return vim.fn.jobstart(artisan_command, job_opts)
end

return M
