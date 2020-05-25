-- very heavily inspired by the default *nix Bourne shell --

-- reload shell and sh, else things break badly for unknown reasons
local shell = require("shell")
local sh = require("sh")
local readline = require("readline").readline
local thread = require("thread")

dofile("/etc/profile.lua")
local exit = false
local oexit = shell.exit
function shell.exit()
  shell.exit = oexit
  exit = true
  return true
end

if not require("filesystem").exists(os.getenv("HOME")) then
  shell.error("warning", "home directory does not exist")
  os.setenv("HOME", "/")
end

os.setenv("PWD", os.getenv("HOME"))
os.setenv("PS1", os.getenv("PS1") or "\\w\\$ ")
local ok, err = pcall(sh.execute, ".shrc")

local handle, err = io.open("/etc/motd.txt")
if handle then
  io.write(handle:read("*a"))
  handle:close()
end

local history = {}
while not exit do
  local cmd = readline({prompt = "\27[0m" .. sh.prompt(os.getenv("PS1")), history = history, notrail = true})
  if cmd ~= "" then
    local ok, err = xpcall(shell.execute, debug.traceback, cmd)
    --thread.spawn(function()ok, err = xpcall(shell.execute, debug.traceback, cmd)end, cmd, function(e)shell.error(cmd, e) end)
    --coroutine.yield()
    if not ok and err then
      shell.error("sh", err)
    end
  end
end
