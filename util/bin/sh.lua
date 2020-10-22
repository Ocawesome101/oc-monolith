-- very heavily inspired by the default *nix Bourne shell --

assert(xpcall(function()
local shell = require("shell")
local sh = require("sh")
local readline = require("readline")
local thread = require("thread")

-- suppress interrupts

sh.execute("/etc/profile")
local exit = false
local oexit = rawget(shell, "exit") -- avoid loading the full shell lib for memory reasons
function shell.exit()
  shell.exit = oexit
  exit = true
  return true
end

if not require("filesystem").exists(os.getenv("HOME")) then
  shell.error("warning", "home directory does not exist")
  os.setenv("HOME", "/")
end

os.setenv("PWD", os.getenv("PWD") or os.getenv("HOME") or "/")
os.setenv("PATH", os.getenv("PATH") or "/bin:/sbin")
os.setenv("SHLVL", (os.getenv("SHLVL") or "0") + 1)
os.setenv("PS1", os.getenv("PS1") or "\\s-\\v$ ")
local ok, err = pcall(sh.execute, ".shrc")
if not ok then print("\27[31m.shrc: " .. err .. "\27[37m") end

local handle, err = io.open("/etc/motd.txt")
if handle then
  io.write((handle:read("a")))
  handle:close()
end

local history = {}

local function onInterrupt()
  io.write("^C")
end

thread.handleSignal(thread.signals.interrupt, onInterrupt)
while not exit do
  io.write("\27[0m"..sh.prompt(os.getenv("PS1")))
  local cmd = readline({history = history, notrail = true})
  if cmd ~= "" then
    local ok, err = shell.execute(cmd)
    if not ok and err then
      shell.error("sh", err)
    end
  end
end
end,
debug.traceback))
