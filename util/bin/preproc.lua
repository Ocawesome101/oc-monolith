-- basic preprocessor --

local preproc = require("preproc", true)
local shell = require("shell")
local args, opts = shell.parse(...)

if #args < 2 then
  shell.error("Usage", "preproc FILE DEST")
  return shell.codes.argument
end

preproc(table.unpack(args))
