local M = {}

local route_list_script = [[
use Illuminate\Support\Facades\Artisan;

error_reporting(0);

$name = %s;

Artisan::call('route:list', array('--json' => true, '--name' => $name));
$routes = json_decode(Artisan::output());
$qfixitems = array();

foreach($routes as $route) {
  if ($route->path !== null) {
    preg_match('/(.*):(\d+)/', $route->path, $matches);
    $file = $matches[1];
    $lnum = $matches[1];
  } else {
    $fragments = explode('@', $route->action, 2);
    if (! isset($fragments[1])) {
      $fragments[1] = '__invoke';
    }

    try {
      $m = new \ReflectionMethod($fragments[0], $fragments[1]);
      $file = $m->getFileName();
      $lnum = $m->getStartLine();
    } catch (\ReflectionException $e) {
      continue;
    }
  }

  $text = $route->method . ' ' . $route->uri;

  if ($route->name) {
    $text = $text . sprintf(' (%%s)', $route->name);
  }

  if (isset($route->middleware) && count($route->middleware)) {
    $middlewares = array_map('class_basename', $route->middleware);
    $text = $text . sprintf(' middlewares: [%%s]', implode(', ', $middlewares));
  }

  $qfixitems[] = array_merge(compact('lnum', 'text'), array(
    'filename' => $file,
    'user_data' => $route,
  ));
}

echo json_encode($qfixitems);
]]

---Returns a list of routes
---@param name string? optional name to filter by
---@return vim.quickfix.entry[]
function M.list(name)
  local script = route_list_script:format(name ~= nil and string.format('%q', name) or 'null')
  local json   = ''
  local items  = {}

  local pid    = require('laravel').execute_artisan({ 'tinker', '--execute', script }, {
    stdout_buffered = false,
    on_stdout = function(_, out)
      json = json .. table.concat(out, '')
    end,
    on_exit = function()
      local ok, decoded = pcall(vim.json.decode, json)

      if ok then
        items = decoded
      else
        error(decoded)
      end
    end
  })

  vim.fn.jobwait({ pid })

  return items
end

---Set get routes from laravel and set the quickfix list
---@return nil
function M.setqflist()
  vim.fn.setqflist({}, ' ', { title = 'Routes (all)', items = M.list() })
  vim.cmd.cwin()
end

---Get a list of routes matching the given name
---@param name string
---@return nil
function M.getselect(name)
  local routes = M.list(name)

  if #routes == 0 then return end
  if #routes == 1 then
    vim.cmd(string.format("edit +%d %s", routes[1].lnum, routes[1].filename))
    return
  end

  vim.ui.select(
    M.list(name),
    {
      ---@param item vim.quickfix.entry
      format_item = function(item)
        return string.format("%s\n\t%s\n\t%s: %d\n", item.text, item.user_data.action,
          vim.fn.fnamemodify(item.filename, ':.'), item.lnum)
      end,

      ---@param item vim.quickfix.entry
      preview_item = function(item)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.fn.readfile(item.filename))

        vim.echoe(tostring(buf))

        return { buf = buf, pos = { item.lnum, 0 } }
      end,

      prompt = "Where to go?"
    },
    ---@param item vim.quickfix.entry?
    function(item)
      if item == nil then return end
      vim.cmd(string.format("edit +%d %s", item.lnum, item.filename))
    end)
end

return M
