-- umount --

local shell = require("shell")
local fs = require("filesystem")

local args, opts = shell.parse(...)

local vb = opts.v or opts.verbose or false

if #args == 0 then
  shell.error("umount", "usage: umount PATH")
  return shell.codes.argument
end

for i=1, #args, 1 do
  local cnc = fs.canonical(args[i])
  if not cnc or not fs.exists(cnc) or not fs.isDirectory(cnc) then
    shell.error(args[i], "no such directory")
    return shell.codes.failed
  end
  local ok, err = fs.umount(cnc)
  if not ok then
    shell.error("umount", err)
    return shell.codes.failed
  end
end
