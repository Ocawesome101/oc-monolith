-- getty implementation --

local thread = require("thread")
local component = require("component")
local computer = require("computer")
local vt100 = require("vt100")
local readline = require("readline")
local stream = require("stream")
local config = require("config")

local cfg = config.load("/etc/getty.conf", {start = "/sbin/login.lua"})
local login = cfg.start or "/sbin/login.lua"

local getty = {}

local gpus, screens, dinfo = {}, {}, {}
local streams = {}

local function nextGPU(res)
  local match = {}
  for k, v in pairs(gpus) do
    if not v.bound then
      match[v.res] = match[v.res] or k
    end
  end

  return match[res] or match[8000] or match[2000] or match[800]
end

local function nextScreen(res)
  local match = {}
  for k, v in pairs(screens) do
    if not v.bound then
      match[v.res] = match[v.res] or k
    end
  end

  return match[res] or match[8000] or match[2000] or match[800]
end

-- register gpu/screen as an IO stream
local function makeStream(gpu, screen)
  local gpu = component.proxy(gpu)
  gpu.bind(screen)
  readline.addscreen(screen, gpu) -- register with readline so it listens for stuff
  local write = vt100.emu(gpu)
  local read = readline.readline
  local close = function()end
  --component.sandbox.log("create IO stream", read, write, close)
  write("\27[2J")
  return stream.new(read, write, close, {screen = screen, gpu = gpu})
end

function getty.scan()
  dinfo = computer.getDeviceInfo()
  for addr, _ in component.list("gpu") do
    gpus[addr] = gpus[addr] or {bound = false, res = tonumber(dinfo[addr].capacity) or 8000}
  end

  for addr, _ in component.list("screen") do
    screens[addr] = screens[addr] or {bound = false, res = tonumber(dinfo[addr].capacity or 8000)}
  end

  for addr, p in pairs(gpus) do
    if not dinfo[addr] then
      if p.bound then
        thread.signal(p.bound, thread.signals.kill)
        screens[p.screen].bound = false
      end
      gpus[addr] = nil
    end
  end

  for addr, p in pairs(screens) do
    if not dinfo[addr] then
      if p.bound then
        thread.signal(p.bound, thread.signals.kill)
        gpus[p.gpu].bound = false
      end
      screens[addr] = nil
    end
  end

  while true do
    local gpu, screen = nextGPU(), nextScreen()
--    logger.log(gpu, screen)
    if gpu and screen then
      --local sr, sw, sc = vt100.session(gpu, screen)
      local ios = makeStream(gpu, screen)--stream.new(sr, sw, sc)]]
      local ok, err = loadfile(login)
      if not ok then
        error(err)
      end
      local pid = thread.spawn(ok, login, nil, nil, ios, ios)
      gpus[gpu].bound = pid
      gpus[gpu].screen = screen
      screens[screen].bound = pid
      screens[screen].gpu = gpu
    else
      break
    end
  end
end

getty.scan()

while true do
  local sig, pid, res = coroutine.yield()
  if sig == "thread_errored" then
    io.stderr:write(pid .. ": " .. res)
  end
  if sig == "component_added" or sig == "component_removed" then
    getty.scan()
  end
end
