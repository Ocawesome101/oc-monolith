-- mkdir is usually one of the last commands I implement. This time it's the 4th or 5th. --

local shell = require("shell")
local fs = require("filesystem")

local args, opts = shell.parse(...)

local NO = opts.p or false

if #args == 0 then
  return shell.codes.argument
end

for i=1, #args, 1 do
  local makeme = fs.canonical(args[i])
  local parent = fs.path(makeme)
  if NO then
    if fs.exists(makeme) then
      shell.error("mkdir", string.format("cannot create directory '%s': file exists", args[i]))
      return 1
    end
    if not fs.exists(parent) then
      shell.error("mkdir", string.format("cannot create directory '%s': no such file or directory", args[i]))
      return 1
    end
  end
  fs.makeDirectory(makeme)
end

return 0
