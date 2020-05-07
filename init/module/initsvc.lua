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
