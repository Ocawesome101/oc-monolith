-- more pager --

local shell = require("shell")
local vt = require("libvt")

local args, opts = shell.parse(...)

if #args == 0 then
  shell.error("usage", "more FILE")
  return shell.codes.argument
end

local handle, err = io.open(args[1], "r")
if not handle then
  shell.error("more", err)
  return shell.codes.failure
end

local w, h = vt.getResolution()
local written = 0
repeat
  local line = handle:read("l")
  if line then
    written = written + math.max(1, math.ceil(#line / w))
    print(line)
  end
  if written >= h then
    io.write("-- More --")
    io.read(1)
    io.write("\27[G\27[2K")
    written = 0
  end
until not line

handle:close()
