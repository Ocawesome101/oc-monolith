#!/usr/bin/lua5.3
-- VT100-formatted man-page generator --

print(...)
local args = {...}

local inp = args[1]
local out = args[2]

local inph = assert(io.open(inp, "r"))
local outh = assert(io.open(out, "w"))

while true do
  local line = inph:read("l")
  if line == "." or not line then break end
--  line = line:gsub(" ", "\27[37m ") -- horribly inefficient, made (re)rendering really slow
  line = line:gsub("%&", "\27[37m")
  line = line:gsub("%*", "\27[97m")
  line = line:gsub("%~", "\27[91m")
  line = line:gsub("%#", "\27[93m")
  line = line:gsub("%?", "\27[95m")
  line = line:gsub("%@", "\27[92m")
  line = line:gsub("%^", "\27[94m")
  line = line:gsub("%%", "?") -- always the edge case :P
  outh:write(line .. "\n")
end

inph:close()
outh:close()
