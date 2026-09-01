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
    $lnum = $matches[2];
  } else {
    $fragments = explode('@', $route->action, 2);
    if (! isset($fragments[1])) {
      $fragments[1] = '__invoke';
    }

    try {
      $m = new \ReflectionMethod($fragments[0], $fragments[1]);
      $file = $m->getFileName();
      $lnum = $m->getStartLine();

      $route->class_name  = class_basename($fragments[0]);
      $route->method_name = $fragments[1];
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

  local pid    = vim.call('artisan#execute', { 'tinker', '--execute', script }, {
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
    routes,
    {
      ---@param item vim.quickfix.entry
      format_item = function(item)
        return string.format("%s\t%s\n\t\t%s:%d\n", item.user_data.name, item.user_data.action,
          vim.fn.fnamemodify(item.filename, ':.'), item.lnum)
      end,

      ---@param item vim.quickfix.entry
      preview_item = function(item)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.fn.readfile(item.filename))

        return { buf = buf, pos = { item.lnum, 0 } }
      end,

      prompt = "Select route:"
    },
    ---@param item vim.quickfix.entry?
    function(item)
      if item == nil then return end
      vim.cmd(string.format("edit +%d %s", item.lnum, item.filename))
    end)
end

---Generates a tag file for laravel routes
---@param tagspath string? optional filepath to write to
function M.ctags(tagspath)
  ---@type string[]
  local tags = vim.iter(M.list())
      :filter(function(item)
        return item.user_data.name ~= vim.NIL
      end)
      :map(function(r)
        if r.user_data.class_name == nil or r.user_data.method_name == nil then
          return string.format("%s\t%s\t%d\n", r.user_data.name, r.filename, r.lnum)
        end

        return string.format("%s\t%s\t%d;/public function %s/;\"\tclass:%s\n", r.user_data.name,
          vim.fn.fnamemodify(r.filename, ':.'), r.lnum, r.user_data.method_name, r.user_data.class_name)
      end)
      :totable()

  table.sort(tags, function(a, b)
    return a:upper() < b:upper()
  end)

  tags = vim.list_extend({ "!_TAG_FILE_SORTED\t1\n" }, tags)

  local fulltagpath = vim.fn.fnamemodify(tagspath
    or vim.g.laravel_tools_route_tags_file
    or vim.fs.joinpath(vim.fn.getcwd(), 'tags'), ':p')

  local tagsdir = vim.fn.fnamemodify(fulltagpath, ':h')

  if vim.fn.isdirectory(tagsdir) == 0 then
    vim.fn.mkdir(tagsdir, 'p')
  end

  local tagsfile = io.open(fulltagpath, 'w+')

  if tagsfile == nil then
    error(string.format("Could not open %s", fulltagpath))
  end

  tagsfile:write(table.unpack(tags))
  tagsfile:close()
end

return M
