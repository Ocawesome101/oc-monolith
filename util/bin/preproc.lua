-- basic preprocessor --

local preproc = require("preproc")
local shell = require("shell")
local args, opts = shell.parse(...)

if #args < 2 then
  shell.error("Usage:")
  return shell.codes.argument
end

preproc(table.unpack(args))
