-- Monolith's init --

local maxrunlevel = ...
local _INITVERSION = "InitMe 369c2b2 (built Sun Jul 05 16:32:01 EDT 2020 by ocawesome101@manjaro-pbp)"
local kernel = kernel
local panic = kernel.logger.panic
local log = kernel.logger.log
local runlevel = kernel.runlevel
local _log = function()end--component.sandbox.log

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
    unicode = unicode,
    runlevel = runlevel
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
log("InitMe: setting up libraries")
package.loaded.filesystem = kernel.filesystem
package.loaded.thread = kernel.thread
package.loaded.signals = kernel.thread.signals
package.loaded.module = kernel.module
package.loaded.modules = kernel.modules
package.loaded.kinfo = kernel.info
package.loaded.syslog = {
  log = kernel.logger.log
}
package.loaded.users = setmetatable({}, {__index = function(_,k) _G.kernel = kernel package.loaded.users = require("users", true) _G.kernel = nil return package.loaded.users[k] end})
_G.kernel = nil


-- `io` library --

do
  log("InitMe: Initializing IO library")

  _G.io = {}
  package.loaded.io = io

  local buffer = require("buffer")
  local fs = require("filesystem")
  local thread = require("thread")
  local stream = require("stream")

  setmetatable(io, {__index = function(tbl, k)
    if k == "stdin" then
      return thread.info().data.io[0]
    elseif k == "stdout" then
      return thread.info().data.io[1]
    elseif k == "stderr" then
      return thread.info().data.io[2] or thread.info().data.io[1]
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

  function io.popen(...)
    return require("pipe").popen(...)
  end

  function io.output(file)
    checkArg(1, file, "string", "table", "nil")
    if type(file) == "string" then
      file = io.open(file, "w")
    end
    if file then
      thread.info().data.io[1] = file
    end
    return thread.info().data.io[1]
  end

  function io.input(file)
    checkArg(1, file, "string", "table", "nil")
    if type(file) == "string" then
      file = io.open(file, "r")
    end
    if file then
      thread.info().data.io[0] = file
    end
    return thread.info().data.io[0]
  end

  function io.error(file)
    checkArg(1, file, "string", "table", "nil")
    if type(file) == "string" then
      file = io.open(file, "r")
    end
    if file then
      thread.info().data.io[2] = file
    end
    return thread.info().data.io[2] or thread.info().data.io[1]
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
    return io.output():write(table.concat({...}))
  end

  function _G.print(...)
    local args = table.pack(...)
    local tp = ""
    local n = args.n
    for i=1, n, 1 do
      local k, v = i, args[i]
      tp = tp .. tostring(v) .. (k < n and "\t" or "")
    end
    return io.stdout:write(tp .. "\n")
  end
end


-- os --

do
  local computer = computer or require("computer")

  function os.sleep(t)
    checkArg(1, t, "number", "nil")
    t = t or 0
    local m = computer.uptime() + t
    repeat
      coroutine.yield(m - computer.uptime())
    until computer.uptime() >= m
    return true
  end

  -- we define os.getenv and os.setenv here now, rather than in kernel/module/thread
  function os.getenv(k)
    if k then
      return assert((kernel.thread or require("thread")).info()).data.env[k] or nil
    else -- return a copy of the env
      local e = {}
      for k, v in pairs((kernel.thread or require("thread")).info().data.env) do
        e[k] = v
      end
      return e
    end
  end

  function os.setenv(k,v)
    --checkArg(1, k, "string", "number")
    --checkArg(2, v, "string", "number", "nil")
    (kernel.thread or require("thread")).info().data.env[k] = v
  end

  local filesystem = require("filesystem")

  os.remove = filesystem.remove
  os.rename = filesystem.rename

  os.execute = function(command)
    local shell = require("shell")
    if not command then
      return type(shell) == "table"
    end
    return shell.execute(command)
  end

  function os.tmpname()
    local path = os.getenv("TMPDIR") or "/tmp"
    if filesystem.exists(path) then
      for _ = 1, 10 do
        local name = filesystem.concat(path, tostring(math.random(1, 0x7FFFFFFF)))
        if not filesystem.exists(name) then
          return name
        end
      end
    end
  end
end


-- component API metatable allowing component.filesystem and things --
-- the kernel implements this but metatables aren't copied to the sandbox currently so we redo it here --

do
  local component = require("component")
  local overrides = {
    gpu = function()return io.stdout.gpu end
  }
  local mt = {
    __index = function(tbl, k)
      if overrides[k] then
        return overrides[k]()
      end
      local addr = component.list(k, true)()
      if not addr then
        error("component of type '" .. k .. "' not found")
      end
      tbl[k] = component.proxy(addr)
      return tbl[k]
    end
  }

  setmetatable(component, mt)
end


log("Running scripts out of /lib/init/....")

local files = kernel.filesystem.list("/lib/init/")
if files then
  table.sort(files)
  for k, v in ipairs(files) do
    log(v)
    local full = kernel.filesystem.concat("/lib/init", v)
    local ok, err = loadfile(full)
    if not ok then
      panic(err)
    end
  end
end

runlevel.setrunlevel(2)
runlevel.setrunlevel(3)

-- `initsvc` lib. --

function runlevel.max()
  return maxrunlevel
end
if runlevel.levels[maxrunlevel].services then
  log("InitMe: Initializing initsvc")

  local config = require("config")
  local fs = require("filesystem")
  local thread = require("thread")
  local users = require("users")
  local scripts = "/lib/scripts/"
  local services = "/lib/services/"

  local cfg = config.load("/etc/initsvc.cfg")

  local initsvc = {}
  local svc = {}

  function initsvc.start(service, handler)
    checkArg(1, service, "string")
    if users.uid() ~= 0 then
      return nil, "only root can do that"
    end
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
    local pid = thread.spawn(ok, service, handler or error)
    thread.orphan(pid)
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
    if users.uid() ~= 0 then
      return nil, "only root can do that"
    end
    if type(svc[service]) == "table" then
      pcall(svc[service].stop)
    else
      thread.kill(svc[service])
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
    return true
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
  coroutine.yield(0)
end

local ok, err = loadfile("/sbin/getty.lua")
if not ok then
  panic("GETTY load failed: " .. err)
end
--log("starting getty")
require("thread").spawn(ok, "/sbin/getty.lua", error)


kernel.logger.setShown(false)

_G._BOOT = require("computer").uptime() - _START

while true do
  coroutine.yield()
end
