-- very heavily inspired by the default *nix Bourne shell --

dofile("/etc/profile.lua")

local shell = require("shell")
local sh = require("sh")

os.setenv("PWD", os.getenv("HOME"))
os.setenv("PS1", os.getenv("PS1") or "\\w\\$ ")

sh.execute(".shrc")

while true do
  io.write(sh.prompt(os.getenv("PS1")))
  local cmd = io.read():gsub("\n", "")
  if cmd ~= "" then
    (function()shell.execute(cmd)end)()
  end
end
