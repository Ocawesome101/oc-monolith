--[[
        Monolith's init.
        Copyright (C) 2020 Ocawesome101

        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.

        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this program.  If not, see <https://www.gnu.org/licenses/>. ]]

local maxrunlevel = ...
local _INITVERSION = "InitMe 2020.10.22"
local _INITSTART = computer.uptime()
local kernel = kernel
local panic = kernel.logger.panic
local runlevel = kernel.runlevel

-- fancy-ish init logger - certainly fancier than the kernel --

local logger = {}
do
  local klog = kernel.logger
  local shown = true
  function logger.setShown(s)
    shown = s
  end

  local stats = {
    OK = 0x00FF00,
    INFO = 0x00AAFF,
    WAIT = 0xFFCC00,
    FAIL = 0xFF0000
  }
  if not klog.gpu then
    logger.log = klog.log
  else
    klog.y = klog.y + 1
    local w, h = klog.gpu.getResolution()
    local function pad(s)
      local p = (' '):rep((8 - #s) / 2)
      return p .. s .. p
    end
    local function log(status, msg)
      local padded = pad(status)
      klog.logwrite("[" .. padded .. "] " .. msg .. "\n")
      if not shown then return end
      klog.gpu.set(1, klog.y, "[")
      if stats[status] then
        klog.gpu.setForeground(stats[status])
      end
      klog.gpu.set(2, klog.y, padded)
      klog.gpu.setForeground(0xDDDDDD)
      klog.gpu.set(10, klog.y, "] " .. msg)
      if klog.y >= h then
        klog.gpu.copy(1,1,w,h,0,-1)
        klog.gpu.fill(1,h,w,1," ")
        klog.y = h
      else
        klog.y = klog.y + 1
      end
    end
    function logger.log(status, ...)
      local msg = table.concat({...}, " ")
      for line in msg:gmatch("[^\n]+") do
        log(status, line)
      end
    end
  end
end

local log = logger.log

log("INFO", "Starting " .. _INITVERSION)

log("OK", "module/package")

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

  local rs = rawset
  local blacklist = {}
  do
    function _G.rawset(tbl, k, v)
      checkArg(1, tbl, "table")
      if blacklist[tbl] then
        tbl[k] = v
      end
      return rs(tbl, k, v)
    end
  end

  function package.protect(tbl, name)
    local new = setmetatable(tbl, {
      __newindex = function() error((name or "lib") .. " is read-only") end,
      __metatable = {}
    })
    blacklist[new] = true
    return new
  end

  function package.delay(lib, file)
    local mt = {
      __index = function(tbl, key)
        setmetatable(lib, nil)
        setmetatable(lib.internal or {}, nil)
        dofile(file)
        log("INFO", "DELAYLOAD "..file..": "..tostring(key))
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

log("OK", "module/io")

-- `io` library --

do
  _G.io = {}
  package.loaded.io = io

  local buffer = require("buffer")
  local fs = require("filesystem")
  local thread = require("thread")

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
    if file == "-" then -- support opening stdio in a fashion similar to *nix
      return buffer.new(mode, ((mode == "r" or mode == "a") and io.stdin) or (mode == "w" and io.stdout))
    end
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
      thread.closeOnExit(file)
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
      thread.closeOnExit(file)
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
      thread.closeOnExit(file)
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
    if file and not (file == io.stdin or file == io.stdout or file == io.stderr)
                                                                            then
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

do
  function loadfile(file, mode, env)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
    checkArg(3, env, "table", "nil")
    mode = mode or "bt"
    env = env or _G
    local handle, err = io.open(file, "r")
    if not handle then
      return nil, err
    end
    local data = handle:read("*a")
    handle:close()
    return load(data, "="..file, mode, env)
  end
end

log("OK", "module/os")

-- os --

do
  local computer = computer or require("computer")
  local thread = thread or require("thread")

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
    checkArg(1, k, "string", "number", "nil")
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
    checkArg(1, k, "string", "number")
    checkArg(2, v, "string", "number", "nil")
    ; -- god dammit Lua
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

  function os.exit(code)
    checkArg(1, code, "string", "number", "nil")
    code = code or 0
    thread.signal(thread.current(), thread.signals.kill)
    if thread.info(thread.current()).parent then
      thread.ipc(thread.info(thread.current()).parent, "child_exited", thread.current())
    end
    coroutine.yield(0)
  end
end

log("OK", "module/component")

-- component API metatable allowing component.filesystem and things --
-- the kernel implements this but metatables aren't copied to the sandbox currently so we redo it here --

do
  local component = require("component")
  local overrides = {
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

log("OK", "module/scripts")

log("INFO", "Running scripts from /lib/init/scripts/...")

local files = kernel.filesystem.list("/lib/init/scripts/")
if files then
  table.sort(files)
  for k, v in ipairs(files) do
    log("WAIT", v)
    local full = kernel.filesystem.concat("/lib/init/scripts/", v)
    local ok, err = loadfile(full)
    if not ok then
      panic(err)
    end
    local s, r = xpcall(ok, debug.traceback)
    if not s and r then
      kernel.logger.y = kernel.logger.y - 1
      log("FAIL", v)
      panic(r)
    end
  end
end

runlevel.setrunlevel(2)
runlevel.setrunlevel(3)
log("OK", "module/initsvc")

-- `initsvc` lib. --

function runlevel.max()
  return maxrunlevel
end

if runlevel.levels[maxrunlevel].services then
  local config = require("config")
  local fs = require("filesystem")
  local thread = require("thread")
  local users = require("users")
  local services = "/lib/init/services/"

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
    local pid = thread.spawn(ok, "["..service.."]", handler or error)
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
      thread.kill(svc[service], 9)
    end
    svc[service] = nil
    return true
  end

  function initsvc.enable(service)
    checkArg(1, service, "string")
    if cfg[service] then
      return true
    end
    if fs.exists(services .. service .. ".lua") then
      cfg[service] = true
      config.save(cfg, "/etc/initsvc.cfg")
    else
      return nil, "service not found"
    end
    return true
  end

  function initsvc.disable(service)
    checkArg(1, service, "string")
    if cfg[service] then
      cfg[service] = nil
      config.save(cfg, "/etc/initsvc.cfg")
      return true
    else
      return nil, "not enabled"
    end
  end

  package.loaded.initsvc = initsvc

  if require("computer").freeMemory() < 16384 then
    log("WARN", "Low memory - collecting garbage")
    collectgarbage()
  end

  for sname in pairs(cfg) do
    log("WAIT", "Starting service " .. sname)
    local ok, err = initsvc.start(sname, panic)
    if not ok then
      panic(err)
    end
  end
end

log("WAIT", "Starting getty")
local ok, err = loadfile("/sbin/getty.lua")
if not ok then
  panic("GETTY load failed: " .. err)
end
require("thread").spawn(ok, "getty", error)


kernel.logger.setShown(false)
logger.setShown(false)

local _INITFINISH = package.loaded.computer.uptime()

package.loaded.times = {
  kernel_start  = kernel._START,
  kernel_finish = kernel._FINISH,
  init_start    = _INITSTART,
  init_finish   = _INITFINISH
}

while true do
  require("event").pull()
end
