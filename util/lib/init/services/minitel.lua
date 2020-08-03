-- minitel daemon largely copied from the OpenOS one --

local component = require("component")
local computer = require("computer")
local hostname = computer.address():sub(1,8)
local config = require("config")
local modems = {}
local cfg = {
  debug = false,
  port = 4096,
  retry = 10,
  retrycount = 3,
  route = true,
  sroutes = {},
  rctime = 15,
  pcime = 30
}
local rcache = setmetatable({}, {__index = cfg.sroutes})
local pqueue = {}
local pcache = {}
local listeners = {}
local timers = {}

--[[local function dprint(...)
  if cfg.debug then
    print(...)
  end
end]]

local function saveconfig()
  return config.save(cfg, "/etc/minitel.cfg")
end

local function loadconfig()
  local ncfg = config.load("/etc/minitel.cfg")
  if ncfg then
    for k, v in pairs(ncfg) do
      cfg[k] = v
    end
  else
    saveconfig()
  end
end

loadconfig()
for addr, _ in component.list("modem") do
  modems[#modems + 1] = component.proxy(addr)
end
for _, modem in ipairs(modems) do
  modem.open(cfg.port)
end

local function genPacketID()
  local npid = ""
  for i=1, 16, 1 do
    npid = npid .. string.char(math.random(32, 126))
  end
  return npid
end

local function sendPacket(pid, ptype, dest, sender, vport, data, repeating)
  if rcache[dest] then
    if component.type(rcache[dest].comp) == "modem" then
      component.invoke(rcache[dest].comp, "sent", rcache[dest].remote, cfg.port, pid, ptype, dest, sender, vport, data)
    end
  else
    for _, modem in pairs(modems) do
      if modem.address ~= repeating or (v.isWireless()) then
        modem.broadcast(cfg.port, pid, ptype, dest, sender, vport, data)
      end
    end
  end
end

local function pruneCache()
  for k, v in pairs(rcache) do
    if v.age < computer.uptime() then
      rcache[k] = nil
    end
  end
  for k, v in pairs(pcache) do
    if v < computer.uptime() then
      pcache[k] = nil
    end
  end
end

local function checkPCache(pid)
  for k, v in pairs(pcache) do
    if k == pid then return true end
  end
  return false
end

local function processPacket(_, receiving, from, pport, _, pid, ptype, dest, sender, vport, data)
  pruneCache()
  if pport == cfg.port or pport == 0 then
    if checkPCache(pid) then return end
    if dest == hostname then
      if ptype == 1 then
        sendPacket(genPacketID(), 2, sender, hostname, vport, pid)
      end
      if ptype == 2 then
        pqueue[data] = nil
        computer.pushSignal("net_ack", data)
      end
      if ptype ~= 2 then
        computer.pushSignal("net_msg", sender, vport, data)
      end
    elseif dest:sub(1,1) == "~" then -- apparently this is what broadcasts start with
      computer.pushSignal("net_broadcast", sender, vport, data)
    elseif cfg.route then
      sendPacket(pid, ptype, dest, sender, vport, data, receiving)
    end
    if not rcache[sender] then
      rcache[sender] = {comp = receiving, addr = from, age = computer.uptime() + cfg.rctime}
    end
    if not pcache[pid] then
      pcache[pid] = computer.uptime() + cfg.pctime
    end
  end
end

local function queuePacket(_, ptype, to, vport, data, npid)
  npid = npid or genPacketID()
  if to == hostname or to == "localhost" then
    computer.pushSignal("net_msg", to, vport, data)
    computer.pushSignal("net_ack", npid)
    return
  end
  pqueue[npid] = {ptype = ptype, to = to, vport = vport, data = data, z1 = 0, z2 = 0}
end

local function packetPusher()
  for k, v in pairs(pqueue) do
    if v.z1 < computer.uptime() then
      sendPacket(k, v.ptype. v.to, hostname, v.vport, v.data)
      if v.ptype ~= 1 or v.z2 == cfg.retrycount then
        pqueue[k] = nil
      else
        pqueue[k].z1 = computer.uptime() + cfg.retry
        pqueue[k].z2 = pqueue[k].z2 + 1
      end
    end
  end
end

-- this section is primarily where the differences are
while true do
  local sig = {coroutine.yield()}
  if sig[1] == "modem_message" then
    processPacket(table.unpack(sig))
  elseif sig[1] == "net_send" then
    queuePacket(table.unpack(sig))
  elseif sig[1] == "shutdown" then -- oh no, we're shutting down!
    os.exit(0)
  elseif sig[1] == "ipc" then -- config request
    if sig[3] == "minitel_config" then
      local rq1, rq2, rq3, rq4 = sig[4] or nil, sig[5] or nil, sig[6] or nil, sig[7] or nil
      if rq1 == "set" and rq2 and rq3 then
        if type(cfg[rq2]) == "string" then
          cfg[rq2] = rq3
        elseif type(cfg[rq2]) == "number" then
          cfg[rq2] = tonumber(rq3)
        elseif type(cfg[rq2]) == "boolean" then
          if rq3:sub(1,1):lower() == "t" then
            cfg[k] = true
          else
            cfg[k] = false
          end
        end
      elseif rq1 == "set_route" and rq2 and rq3 and rq4 then
        cfg.sroutes[rq2] = {laddr = rq3, raddr = rq3, z1 = rq4}
      elseif rq1 == "del_route" and rq2 then
        cfg.sroutes[rq2] = nil
      end
      saveconfig()
    end
  end
  packetPusher()
end
