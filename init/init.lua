-- ComputOS init --

local _INITVERSION = "InitMe 986f02c (built Thu Apr 30 12:09:01 EDT 2020 by ocawesome101@manjaro-pbp)"
local panic = kernel.logger.panic
local log = kernel.logger.log

log(_INITVERSION)


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
    local err = "mofule '%s' not found:\n\tno field package.loaded['%s']"
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
    for search in path:gmatch("[^;]+") do
      search = search:gsub(sep, rep):gsub("%?", name)
      if fs.exists(search) then
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
    if loaded[lib] and not reload then
      return loaded[lib]
    else
      local ok, searched = package.searchpath(name, path, sep, rep)
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
package.loaded.users = require("users")
package.loaded.thread = kernel.thread
package.loaded.signals = kernel.thread.signals
package.loaded.module = kernel.module
_G.kernel = nil


-- `io` library --

do
  log("InitMe: Initialing IO library")

  _G.io = {}
  package.loaded.io = io

  local buffer = require("buffer")
  local fs = require("filesystem")
  local thread = require("thread")
  local stream = require("stream")

  setmetatable(io, {__index = function(tbl, k)
    if k == "stdin" then
      return thread.stdin()
    elseif k == "stdout" or k == "stderr" then
      return thread.stdout()
    end
  end})

  function io.open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
    file = fs.canonical(file)
    mode = mode or "r"
    local handle, err = fs.open(file, mode)
    if not handle then
      return nil, err
    end
    return buffer.new(mode, handle)
  end

  function io.output(file)
    checkArg(1, file, "string", "table", "nil")
    if type(file) == "string" then
      file = io.open(file, "w")
    end
    return thread.stdout(file)
  end

  function io.input(file)
    checkArg(1, file, "string", "table", "nil")
    if type(file) == "string" then
      file = io.open(file, "r")
    end
    return thread.stdin(file)
  end

  function io.popen(file) -- ...ish
    checkArg(1, file, "string")
    local ok, err = loadfile(file)
    if not ok then
      return nil, err
    end
    local thdio, uio = stream.dummy()
    local pid
    function thdio:close()
      thread.signal(pid, thread.signals.kill)
      thdio = nil
      uio = nil
      return true
    end
    local pid = thread.spawn(ok, file, function(e)thdio:write(e)end, nil, thdio, thdio)
    return uio, pid
  end

  function io.lines(file, ...)
    checkArg(1, file, "string", "table", "nil")
    if file then
      local err
      if type(file) == "string" then
        file, err = io.open(file)
      end
      if not file then return nil, err end
      return file:lines()
    end
    return io.input():lines()
  end

  function io.close(file)
    checkArg(1, file, "table", "nil")
    if file then
      return file:close()
    end
    return nil, "cannot close standard file"
  end

  function io.flush(file)
    checkArg(1, file, "table", "nil")
    file = file or io.output()
    return file:flush()
  end

  function io.type(file)
    checkArg(1, file, "table")
    if file.closed then
      return "closed file"
    elseif (file.read or file.write) and file.close then
      return "file"
    end
    return nil
  end

  function io.read(...)
    return io.input():read(...)
  end

  function io.write(...)
    return io.output():write(...)
  end
end


-- `initsvc` lib --

do
  log("InitMe: Initializing initsvc")

  local config = require("comfig")
  local fs = require("filesystem")
  local thread = require("thread")
  local scripts = "/lib/scripts/"
  local services = "/lib/services/"
  local default = {
    getty = "service"
  }

  local cfg = config.load("/etc/initsvc.cfg")

  local initsvc = {}
  local svc = {}

  function initsvc.start(service)
    checkArg(1, service, "string")
    if svc[service] and thread.info(svc[service]) then
      return nil, "service is already running"
    end
    local ok, err = loadfile(services .. service .. ".lua")
    if not ok then
      return nil, err
    end
    local pid = thread.spawn(ok, service, function()initsvc.start(service)end)
    svc[service] = pid
    return true
  end

  function initsvc.stop(service)
    checkArg(1, service, "string")
    if not svc[service] then
      return nil, "service is not running"
    end
    thread.signal(svc[service], thread.signals.kill)
    svc[service] = nil
    return true
  end

  function initsvc.enable(script, isService)
    checkArg(1, script, "string")
    checkArg(2, isService, "boolean", "nil")
    local s = (isService and "service") or "script"
    if cfg[script] then
      return true
    end
    if isService then
      if fs.exists(services .. script .. ".lua") then
        cfg[script] = s
        config.save(cfg, "/etc/initsvc.cfg")
      else
        return nil, "service not found"
      end
    else
      if fs.exists(scripts .. script .. ".lua") then
        cfg[script] = s
        config.save(cfg, "/etc/initsvc.cfg")
      else
        return nil, "script not found"
      end
    end
  end

  function initsvc.disable(script)
    checkArg(1, script, "string")
    if cfg[script] then
      cfg[script] = nil
      config.save(cfg, "/etc/initsvc.cfg")
      return true
    else
      return nil, "not enabled"
    end
  end

  package.loaded.initsvc = initsvc

  for sname, stype in pairs(cfg) do
    if stype == "script" then
      local path = scripts .. sname .. ".lua"
      local ok, err = dofile(path)
      if not ok then
        panic(err)
      end
    elseif stype == "service" then
      local ok, err = initsvc.start(sname)
      if not ok then
        panic(err)
      end
    end
  end
end


while true do
  coroutine.yield()
end
