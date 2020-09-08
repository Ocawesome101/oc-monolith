#!/usr/bin/env lua
-- HTML man-page generator --

local args = {...}

print(table.concat({"[ \27[94mINFO\27[39m ] genhtml", args[1], "->", args[2]}, " "))

local inp = args[1]
local out = args[2]

local inph = assert(io.open(inp, "r"))
local outh = assert(io.open(out, "w"))

local patterns = {
  {"%#", "<span style=\"color:#DDDD00;font-weight:bold;\">"},
  {"%*", "<span style=\"color:#FFFFFF;font-weight:bold;\">"},
  {"%~", "<span style=\"color:#FF0000;font-weight:bold;\">"},
  {"%?", "<span style=\"color:#FF00FF;font-weight:bold;\">"},
  {"%@", "<span style=\"color:#00FF00;font-weight:bold;\">"},
  {"%^", "<span style=\"color:#00AAFF;font-weight:bold;\">"},
  {"%&", "<span style=\"color:#FFFFFF;font-weight:normal;\">"},
  {"[%?%&%^%~%#%@%*]", ""},
  {"\n", "<br>"},
  {"  ", "&nbsp;&nbsp;"}
}

local data = inph:read("a")
for _, pat in ipairs(patterns) do
  data = data:gsub(pat[1], pat[2])
end
data = data:gsub("%%", "?") -- always the edge case :P
data = data:gsub("%`", "#") -- and another one
outh:write("<html><title>" .. inp .. "</title><body style=\"font-family:Courier;background-color:#000;color:#FFF;\">" .. data .. "\n</body></html>")

print("\27[A\27[2K[ \27[92m OK \27[39m ] generated manpage " .. args[1])

inph:close()
outh:close()
