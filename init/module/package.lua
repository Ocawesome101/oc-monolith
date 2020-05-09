-- `package` library --

do
  log("InitMe: Initializing package library")

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

  package.path = "/lib/?.lua;/lib/lib?.lua;/usr/lib/?.lua;/usr/lib/lib?.lua"

  local function libError(name, searched)
    local err = "module '%s' not found:\n\tno field package.loaded['%s']"
    err = err .. ("\n\tno file '%s'"):rep(#searched)
    _log(string.format(err, name, name, table.unpack(searched)))
    error(string.format(err, name, name, table.unpack(searched)))
  end

  function package.searchpath(name, path, sep, rep)
    checkArg(1, name, "string")
    checkArg(2, path, "string")
    checkArg(3, sep, "string", "nil")
    checkArg(4, rep, "string", "nil")
    _log("search", path, name)
    sep = "%" .. (sep or ".")
    rep = rep or "/"
    local searched = {}
    name = name:gsub(sep, rep)
    for search in path:gmatch("[^;]+") do
      search = search:gsub("%?", name)
      if fs.exists(search) then
        _log("found", search)
        return search
      end
      searched[#searched + 1] = search
    end
    return nil, searched
  end

  function _G.dofile(file)
    checkArg(1, file, "string")
    file = fs.canonical(file)
    local ok, err = loadfile(file)
    if not ok then
      return nil, err
    end
    local stat, ret = xpcall(ok, debug.traceback)
    if not stat and ret then
      return nil, ret
    end
    return ret
  end

  function _G.require(lib, reload)
    checkArg(1, lib, "string")
    checkArg(2, reload, "boolean", "nil")
    _log("require", lib, "reload:", reload)
    if loaded[lib] and not reload then
      _log("returning cached")
      return loaded[lib]
    else
      _log("searching")
      local ok, searched = package.searchpath(lib, package.path, ".", "/")
      if not ok then
        libError(lib, searched)
      end
      local ok, err = dofile(ok)
      if not ok then
        _log(string.format("failed loading module '%s':\n%s", lib, err))
        error(string.format("failed loading module '%s':\n%s", lib, err))
      end
      _log("succeeded - returning", lib)
      loaded[lib] = ok
      return ok
    end
  end
end

package.loaded.filesystem = kernel.filesystem
package.loaded.users = require("users")
package.loaded.thread = kernel.thread
package.loaded.signals = kernel.thread.signals
package.loaded.module = kernel.module
package.loaded.modules = kernel.modules
package.loaded.kinfo = kernel.info
_G.kernel = nil
