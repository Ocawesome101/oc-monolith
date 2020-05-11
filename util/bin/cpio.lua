-- cpio --

local shell = require("shell")
local cpio = require("cpio")

local args, opts = shell.parse(...)

local usage = [[cpio utility (C) 2020 Ocawesome101 under the MIT license.
usage:
  cpio -a | --archive SOURCE DEST
  cpio -x | --extract SOURCE DEST
]]

local halp = opts.h or opts.help or false
local arcv = opts.a or opts.archive or false
local extr = opts.x or opts.extract or false

if #args < 2 or halp then
  print(usage)
  return shell.codes.failure
end

if arcv then
  shell.error("cpio", "archival not implemented")
  return shell.codes.failure
end

if extr then
  return cpio.extract(args[1], args[2])
end
