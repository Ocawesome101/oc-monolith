-- su --

local shell = require("shell")
local users = require("users")

local args, opts = shell.parse(...)

if #args == 0 or opts.help then
  print([[
usage: su USER
  ]])
  return 
end
