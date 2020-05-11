-- very heavily inspired by the default *nix Bourne shell --

-- reload shell and sh, else things break badly for unknown reasons
local shell = require("shell", true)
local sh = require("sh", true)

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
sh.execute(".shrc")

local hist = {}
while not exit do
  io.write("\27[0m" .. sh.prompt(os.getenv("PS1")))
  local cmd = io.read():gsub("\n", "")
  if cmd ~= "" then
    if cmd == "\27[A" then
      -- stub
    elseif cmd == "\27[B" then
      -- stub
    elseif cmd == "\27[C" or cmd == "\27[D" then
      -- stub
    else
      table.insert(hist, cmd)
      if #hist > 16 then
        table.remove(hist, 1)
      end
      pcall(function()shell.execute(cmd)end)
    end
  end
end
