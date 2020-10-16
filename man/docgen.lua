#!/usr/bin/env lua5.3
-- VT100-formatted man-page generator --

local args = {...}

print(table.concat({"[ \27[94mINFO\27[39m ] docgen", args[1], "->", args[2]}, " "))

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
  line = line:gsub("%%%%", "?") -- always the edge case :P
  line = line:gsub("%`", "#") -- and another one
  outh:write(line .. "\n")
end

print("\27[A\27[2K[ \27[92m OK \27[39m ] generated manpage")

inph:close()
outh:close()
