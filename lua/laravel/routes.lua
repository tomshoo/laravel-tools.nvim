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
    'data' => $route,
  ));
}

echo json_encode($qfixitems);
]]

---Returns a list of routes
---@param name string? optional name to filter by
---@return vim.quickfix.entry
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
---@param name string?
---@return nil
function M.setqflist(name)
  vim.fn.setqflist({}, ' ', { title = string.format('Routes (%s)', name or 'all'), items = M.list(name) })
  vim.cmd.cwin()
end

return M
