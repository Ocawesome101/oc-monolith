-- `package` library --

do
  _G.package = {}

  local loaded = {
    ["_G"] = _G,
    os = os,
    math = math,
    string = string,
    table = table,
    component = component,
    computer = computer,
    unicode = unicode
  }

  _G.component, _G.computer, _G.unicode = nil, nil, nil

  package.loaded = loaded
  local fs = kernel.filesystem

  package.path = "/lib/?.lua;/lib/lib?.lua;/usr/lib/?.lua;/usr/lib/lib?.lua;/usr/compat/?.lua;/usr/compat/lib?.lua"

  local function libError(name, searched)
    local err = "module '%s' not found:\n\tno field package.loaded['%s']"
    err = err .. ("\n\tno file '%s'"):rep(#searched)
    error(string.format(err, name, name, table.unpack(searched)))
  end

  function package.searchpath(name, path, sep, rep)
    checkArg(1, name, "string")
    checkArg(2, path, "string")
    checkArg(3, sep, "string", "nil")
    checkArg(4, rep, "string", "nil")
    sep = "%" .. (sep or ".")
    rep = rep or "/"
    local searched = {}
    name = name:gsub(sep, rep)
    for search in path:gmatch("[^;]+") do
      search = search:gsub("%?", name)
      if fs.exists(search) then
        return search
      end
      searched[#searched + 1] = search
    end
    return nil, searched
  end

  function package.protect(tbl, name)
    return setmetatable(tbl, {
      __newindex = function() error((name or "lib") .. " is read-only") end,
      __metatable = {}
    })
  end

  function package.delay(lib, file)
    local mt = {
      __index = function(tbl, key)
        setmetatable(lib, nil)
        setmetatable(lib.internal or {}, nil)
        dofile(file)
        return tbl[key]
      end
    }
    if lib.internal then
      setmetatable(lib.internal, mt)
    end
    setmetatable(lib, mt)
  end

  function _G.dofile(file)
    checkArg(1, file, "string")
    file = fs.canonical(file)
    local ok, err = loadfile(file)
    if not ok then
      error(err)
    end
    local stat, ret = xpcall(ok, debug.traceback)
    if not stat and ret then
      error(ret)
    end
    return ret
  end

  function _G.require(lib, reload)
    checkArg(1, lib, "string")
    checkArg(2, reload, "boolean", "nil")
    if loaded[lib] and not reload then
      return loaded[lib]
    else
      local ok, searched = package.searchpath(lib, package.path, ".", "/")
      if not ok then
        libError(lib, searched)
      end
      local ok, err = dofile(ok)
      if not ok then
        error(string.format("failed loading module '%s':\n%s", lib, err))
      end
      loaded[lib] = ok
      return ok
    end
  end
end
package.loaded.filesystem = kernel.filesystem
package.loaded.thread = kernel.thread
package.loaded.signals = kernel.thread.signals
package.loaded.module = kernel.module
package.loaded.modules = kernel.modules
package.loaded.kinfo = kernel.info
package.loaded.runlevel = runlevel
package.loaded.syslog = {
  log = function(s,m)if not m then m, s = s, "OK"end log(s,m) end
}
package.loaded.users = setmetatable({}, {__index = function(_,k) _G.kernel = kernel package.loaded.users = require("users", true) _G.kernel = nil return package.loaded.users[k] end})
_G.kernel = nil
