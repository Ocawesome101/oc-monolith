#!/usr/bin/env lua5.3
-- VT100-formatted man-page generator --

local args = {...}

print=function()end
print(table.concat({"[ \27[94mINFO\27[39m ] docgen", args[1], "->", args[2]}, " "))

local inp = args[1]
local out = args[2]

local inph = assert(io.open(inp, "r"))
local outh = assert(io.open(out, "w"))

local sep = {
  [' '] = true,
  ['*'] = true,
  ['+'] = true,
  ['='] = true,
  ['-'] = true
}
while true do
  local line = inph:read("l")
  if line == "." or not line then break end
  -- split 'line' into wrapped lines of up to 50 chars each
  do
    local ol = ""
    local ln = ""
    local wd = ""
    for char in line:gmatch(".") do
      wd = wd .. char
      if #ln + #wd > 50 then
        ol = ol .. ln .. "\n" .. wd
        ln = ""
        wd = ""
      elseif sep[char] then
        ln = ln .. wd
        wd = ""
      end
    end
    if #wd > 0 then
      ln = ln .. wd
    end
    if #ln > 0 then
      ol = ol .. ln
    end
    line = ol
  end
  line = line:gsub("%&", "\27[37m")
  line = line:gsub("%*", "\27[97m")
  line = line:gsub("%~", "\27[91m")
  line = line:gsub("%#", "\27[93m")
  line = line:gsub("%?", "\27[95m")
  line = line:gsub("%@", "\27[92m")
  line = line:gsub("%^", "\27[94m")
  line = line:gsub("%%%%", "?") -- always the edge case :P
  line = line:gsub("%`", "#") -- and another one
  line = line:gsub("o/o", "%%") -- aaaaand another
  outh:write(line .. "\n")
end

print("\27[A\27[2K[ \27[92m OK \27[39m ] generated manpage " .. args[1])

inph:close()
outh:close()
