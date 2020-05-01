-- getty implementation --

local thread = require("thread")
local component = require("component")
local computer = require("computer")
local vt100 = require("vt100")
local stream = require("stream")

local getty = {}

local gpus, screens, dinfo = {}, {}, {}

local function nextGPU(res)
  local match = {}
  for k, v in pairs(gpus) do
    if not v.bound then
      match[v.res] = match[v.res] or k
    end
  end

  return match[res] or match[8000] or match[800] or match[200]
end

local function nextScreen(res)
  local match = {}
  for k, v in pairs(screens) do
    if not v.bound then
      match[v.res] = match[v.res] or k
    end
  end

  return match[res] or match[8000] or match[800] or match[200]
end

function getty.scan()
  dinfo = computer.getDeviceInfo()
  for addr, _ in component.list("gpu") do
    gpus[addr] = gpus[addr] or {bound = false, res = tonumber(dinfo[addr].capacity)}
  end

  for addr, _ in component.list("screen") do
    screens[addr] = screens[addr] or {bound = false, res = tonumber(dinfo[addr].capacity)}
  end

  for addr, p in pairs(gpus) do
    if not dinfo[addr] then
      if p.bound then
        thread.signal(p.bound, thread.signals.kill)
      end
      gpus[addr] = nil
    end
  end

  for addr, p in pairs(screens) do
    if not dinfo[addr] then
      if p.bound then
        thread.signal(p.bound, thread.signals.kill)
      end
      screens[addr] = nil
    end
  end

  local gpu, screen = nextGPU(), nextScreen()
  if gpu and screen then
    local sr, sw, sc = vt100.session(gpu, screen)
    local ios = stream.new(sr, sw, sc)
    local ok, err = loadfile("/sbin/login.lua")
    if not ok then
      error(err)
    end
    local pid = thread.spawn(ok, "/sbin/login.lua", nil, nil, ios, ios)
    gpus[gpu].bound = pid
    screens[screen].bound = pid
  end
end

while true do
  coroutine.yield()
  getty.scan()
end
