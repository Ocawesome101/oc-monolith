-- very heavily inspired by the default *nix Bourne shell --

dofile("/etc/profile.lua")

local shell = require("shell")
local sh = require("sh")
local log = require("component").sandbox.log
log("shell started")

os.setenv("PWD", os.getenv("HOME"))
os.setenv("PS1", os.getenv("PS1") or "\\w\\$ ")
log("PWD: " .. tostring(os.getenv("PWD")))
log("PS1: " .. os.getenv("PS1"))

log("running shrc")
sh.execute(".shrc")

log("i/o stdio: " .. tostring(io.input()) .. ", " .. tostring(io.output()))
log("have", io.output().write)
log("shell main loop")
--print("start shell loop")
while true do
--  print("SHELL LOOP")
  io.write(sh.prompt(os.getenv("PS1")))
--  print("READ")
  local cmd = io.read():gsub("\n", "")
  if cmd ~= "" then
    (function()shell.execute(cmd)end)()
  end
end
