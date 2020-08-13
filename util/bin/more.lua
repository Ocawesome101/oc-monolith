-- more pager --

local shell = require("shell")

local args, opts = shell.parse(...)

if #args == 0 then
  shell.error("usage", "more FILE")
  return shell.codes.argument
end

local handle, err = io.open(args[1])
if not handle then
  shell.error("more", err)
  return shell.codes.failure
end

local w, h = io.output().gpu.getResolution()
local written = 0
repeat
  local line = handle:read("l")
  if line then
    written = written + math.max(1, math.ceil(#line / w))
    print(line)
  end
  if written >= h - 1 then
    io.write("-- More --")
    io.read(1)
    io.write("\n")
    written = 0
  end
until not line

handle:close()
