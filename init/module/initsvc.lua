-- `initsvc` lib --

do
  log("InitMe: Initializing initsvc")

  local config = require("config")
  local fs = require("filesystem")
  local thread = require("thread")
  local scripts = "/lib/scripts/"
  local services = "/lib/services/"
  local default = {
    getty = "service"
  }

  local cfg = config.load("/etc/initsvc.cfg", default)

  local initsvc = {}
  local svc = {}

  function initsvc.start(service, handler)
    checkArg(1, service, "string")
    if svc[service] and thread.info(svc[service]) then
      return nil, "service is already running"
    end
    local ok, err = loadfile(services .. service .. ".lua")
    if not ok then
      return nil, err
    end
    local pid = thread.spawn(ok, service, handler or function()initsvc.start(service)end)
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
    log("running " .. stype .. " " .. sname)
    if stype == "script" then
      local path = scripts .. sname .. ".lua"
      local ok, err = dofile(path)
      if not ok then
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
