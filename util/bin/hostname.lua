-- hostname --

local shell = require("shell")
local hostname = require("hostname")

local args, opts = shell.parse(...)

local show = #args == 0
local set = not show

if show then
  print(hostname.get())
else
  print(hostname.set(args[1]))
end
