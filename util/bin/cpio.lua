-- cpio --
--[[ Copyright (C) 2020 Ocawesome101

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details. ]]

local shell = require("shell")
local cpio = require("cpio")

local args, opts = shell.parse(...)

local usage = [[cpio utility copyright (c) 2020 Ocawesome101 under the GNU GPLv3.
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
