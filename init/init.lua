-- Monolith's init --

local _INITVERSION = "InitMe 82f6c72 (built Thu May 14 21:08:28 EDT 2020 by ocawesome101@windowsisbad)"
local panic = kernel.logger.panic
local log = kernel.logger.log
local _log = function()end--component.sandbox.log

--[[local oerr = error
function _G.error(e, l)
  _log(debug.traceback(e, l))
  oerr(e, l)
end]]

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
      return os.getenv("STDIN")
    elseif k == "stdout" or k == "stderr" then
      return os.getenv("STDOUT")
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
    if file then
      os.setenv("OUTPUT", file)
    end
    return os.getenv("OUTPUT")
  end

  function io.input(file)
    checkArg(1, file, "string", "table", "nil")
    if type(file) == "string" then
      file = io.open(file, "r")
    end
    if file then
      os.setenv("INPUT", file)
    end
    return os.getenv("INPUT")
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

  function _G.print(...)
    local args = {...}
    local tp = ""
    for k, v in ipairs(args) do
      tp = tp .. tostring(v) .. "\n"
    end
    return io.stdout:write(tp)
  end
end


-- `initsvc` lib. --

do
  log("InitMe: Initializing initsvc")

  local config = require("config")
  local fs = require("filesystem")
  local thread = require("thread")
  local scripts = "/lib/scripts/"
  local services = "/lib/services/"

  local cfg = config.load("/etc/initsvc.cfg")

  local initsvc = {}
  local svc = {}

  function initsvc.start(service, handler)
    checkArg(1, service, "string")
    if svc[service] and thread.info(svc[service]) then
      return nil, "service is already running"
    end
    local senv = setmetatable({}, {__index=_G})
    local ok, err = loadfile(services .. service .. ".lua", nil, senv)
    if not ok then
      return nil, err
    end
    --[[pcall(ok) -- this isn't actually supported, heh
    if senv.start then -- OpenOS-y service
      osvc[service] = senv
      thread.spawn(senv.start, service, handler or print)
    end]]
    local pid = thread.spawn(ok, service, handler or panic)
    svc[service] = pid
    return true
  end

  function initsvc.list()
    local l = {}
    for _, file in ipairs(fs.list(services)) do
      local e = {}
      file = file:gsub("%.lua$", "")
      if svc[file] then
        e.running = true
      else
        e.running = false
      end
      e.name = file
      l[#l + 1] = e
    end
    return l
  end

  function initsvc.stop(service)
    checkArg(1, service, "string")
    if not svc[service] then
      return nil, "service is not running"
    end
    if type(svc[service]) == "table" then
      pcall(svc[service].stop)
    else
      thread.signal(svc[service], thread.signals.kill)
    end
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
    log("running " .. stype .. " " .. sname)
    if stype == "script" then
      local path = scripts .. sname .. ".lua"
      local ok, err = dofile(path)
      if not ok and err then
        panic(err)
      end
    elseif stype == "service" then
      local ok, err = initsvc.start(sname, panic)
      if not ok then
        panic(err)
      end
    end
  end
  --require("computer").pushSignal("init")
  coroutine.yield(0)
end

local ok, err = loadfile("/sbin/getty.lua")
if not ok then
  panic(err)
end
require("thread").spawn(ok, "/sbin/getty.lua", panic)


--[[do
  local component = require("component")
  local computer  = require("computer")
  for a, t in component.list() do
    computer.pushSignal("component_added", a, t)
  end
end]]

_G._BOOT = require("computer").uptime() - _START

while true do
  coroutine.yield()
end
