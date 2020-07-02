-- su --

local shell = require("shell")
local users = require("users")

local args, opts = shell.parse(...)

if #args == 0 or opts.help then
  print([[
usage: su [--shell=<shell>] USER
  ]])
  return 
end

local shell = opts.shell or os.getenv("SHELL") or "/bin/sh.lua"

users.sudo(function() shell.execute(shell) end)
