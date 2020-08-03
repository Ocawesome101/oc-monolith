-- `initsvc` lib. --

function runlevel.max()
  return maxrunlevel
end

if runlevel.levels[maxrunlevel].services then
  log("WAIT", "Initializing initsvc")

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
    if fs.exists(services .. script .. ".lua") then
      cfg[script] = true
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
    kernel.logger.y = kernel.logger.y - 1
    log("OK", "Started service " .. sname .. "   ")
  end
  coroutine.yield(0)
  log("OK", "Initialized initsvc")
end

log("WAIT", "Starting getty")
local ok, err = loadfile("/sbin/getty.lua")
if not ok then
  panic("GETTY load failed: " .. err)
end
kernel.logger.y = kernel.logger.y - 1
require("thread").spawn(ok, "getty", error)
log("OK", "Started getty    ")
