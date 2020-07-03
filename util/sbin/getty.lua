-- getty implementation --

local thread = require("thread")
local component = require("component")
local computer = require("computer")
local vt100 = require("vt100")
local readline = require("readline")
local stream = require("stream")
local config = require("config")

local cfg = config.load("/etc/getty.conf", {start = "/sbin/login.lua",cursorblink=true})
local login = cfg.start or "/sbin/login.lua"
local blink = cfg.cursorblink
config.save(cfg, "/etc/getty.conf")
if not require("runlevel").levels[require("runlevel").max()].multiuser then login = "/bin/sh.lua" package.loaded.users = setmetatable({
  user = function() return 'root' end,
  uid = function() return 0 end,
  login = function() error('system is in single-user mode') end,
  sudo = function() error('system is in single-user mode') end,
  shell = function() return '/bin/sh.lua' end
}, {__index = require("users")}) end

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
  write("\27[2J")
  return stream.new(read, write, close, {screen = screen, gpu = gpu})
end

local ttyn = 0
local cursors = {}

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
        cursors[p.pid] = nil
      end
      gpus[addr] = nil
    else
      if not (thread.info(p.pid)) then
        kernel.logger.log("restarting terminal on GPU " .. addr)
        io.input(cursors[p.pid])
        io.output(cursors[p.pid])
        local old = p.pid
        p.pid = thread.spawn(loadfile(login), login, error)
        screens[p.screen].pid = p.pid
        cursors[p.pid] = cursors[old]
        cursors[old] = nil
      end
    end
  end

  for addr, p in pairs(screens) do
    if not dinfo[addr] then
      if p.bound then
        thread.signal(p.bound, thread.signals.kill)
        gpus[p.gpu].bound = false
        cursors[p.pid] = nil
      end
      screens[addr] = nil
    else
      if not (thread.info(p.pid)) then
        kernel.logger.log("restarting terminal on screen " .. addr)
        io.input(cursors[p.pid])
        io.output(cursors[p.pid])
        local old = p.pid
        p.pid = thread.spawn(loadfile(login), login, error)
        screens[p.screen].pid = p.pid
        cursors[p.pid] = cursors[old]
        cursors[old] = nil
      end
    end
  end

  while true do
    local gpu, screen = nextGPU(), nextScreen()
    if gpu and screen then
      local ok, err = loadfile(login)
      if not ok then
        error(err)
      end
      local ios = makeStream(gpu, screen)
      ios.tty = true
      require("devfs").register("tty" .. ttyn, ios)
      io.input(ios)
      io.output(ios)
      local pid = thread.spawn(ok, login, error)
      cursors[pid] = ios
      gpus[gpu].bound = pid
      gpus[gpu].screen = screen
      screens[screen].bound = pid
      screens[screen].gpu = gpu
      ttyn = ttyn + 1
    else
      break
    end
  end
end

getty.scan()

local last_blink = computer.uptime()
while true do
  local sig, pid, res = coroutine.yield((blink and (last_blink + 0.5) - computer.uptime()) or math.huge)
  if sig == "thread_errored" then
    if res:sub(-1) ~= "\n" then res = res .. "\n" end
    io.write("\27[31m" .. res)
  end
  if sig == "component_added" or sig == "component_removed" then
    getty.scan()
  end
  if computer.uptime() - last_blink >= 0.5 then
    last_blink = computer.uptime()
    for _,s in pairs(cursors) do
      s:write("\27[255m")
    end
  end
end
