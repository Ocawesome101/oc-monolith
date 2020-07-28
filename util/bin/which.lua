-- which --

local shell = require("shell")

local args, opts = shell.parse(...)

if #args == 0 then
  shell.error("Usage", "which COMMAND")
  return shell.codes.argument
end

print(shell.resolve(args[1], "lua"))
