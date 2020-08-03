-- getty implementation --

local thread = require("thread")
local component = require("component")
local computer = require("computer")
package.loaded.times.getty_start = computer.uptime()
local vt100 = require("vt100")
local readline = require("readline")
local stream = require("stream")
local config = require("config")

local cfg = config.load("/etc/getty.conf", {start = "/sbin/login.lua"})
local login = cfg.login or "/sbin/login.lua"
local login_name = cfg.login_name or "login"
cfg.login_name = login_name
cfg.login = login
config.save(cfg, "/etc/getty.conf")
if not require("runlevel").levels[require("runlevel").max()].multiuser then
  login = "/bin/sh.lua"
  local users = require("users")
  users.getname(0)
  os.setenv("UID", 0)
  os.setenv("USER", "root")
end

local getty = {}

local gpus, screens, dinfo = {}, {}, {}

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
    coroutine.yield(0)
    local gpu, screen = nextGPU(), nextScreen()
    if gpu and screen then
      local ok, err = loadfile(login)
      if not ok then
        error(err)
      end
      local ios = makeStream(gpu, screen)
      ios.tty = true
      io.input(ios)
      io.output(ios)
      local pid = thread.spawn(ok, login_name or login, error)
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

package.loaded.times.getty_finish = computer.uptime()

while true do
  local sig, pid, res = coroutine.yield()
  if sig == "component_added" or sig == "component_removed" then
    getty.scan()
  end
end
