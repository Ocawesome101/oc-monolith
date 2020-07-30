#!/usr/bin/lua5.3
-- HTML man-page generator --

local args = {...}

print(table.concat({"[ \27[94mINFO\27[39m ] genhtml", args[1], "->", args[2]}, " "))

local inp = args[1]
local out = args[2]

local inph = assert(io.open(inp, "r"))
local outh = assert(io.open(out, "w"))

local patterns = {
  {"%#(.-)[%?%&%^%~%@%*]", "<span style=\"color:#DDDD00;font-weight:bold;\">%1</span>"},
  {"%*(.-)[%?%&%^%~%#%@]", "<span style=\"color:#000000;font-weight:bold;\">%1</span>"},
  {"%~(.-)[%?%&%^%#%@%*]", "<span style=\"color:#FF0000;font-weight:bold;\">%1</span>"},
  {"%?(.-)[%&%^%~%#%@%*]", "<span style=\"color:#FF00FF;font-weight:bold;\">%1</span>"},
  {"%@(.-)[%?%&%^%~%#%*]", "<span style=\"color:#00FF00;font-weight:bold;\">%1</span>"},
  {"%^(.-)[%?%&%~%#%@%*]", "<span style=\"color:#00AAFF;font-weight:bold;\">%1</span>"},
  {"%&", "<span style=\"color:#000000;\"></span>"},
  {"[%?%&%^%~%#%@%*]", ""}
}

local data = ""
-- hacky solution for wrapping at 80 chars
local c80 = string.rep(".?", 80)
for line in inph:lines() do
  for chunk in line:gmatch(c80) do
    data = data .. chunk .. "\n"
  end
end
for _, pat in ipairs(patterns) do
  data = data:gsub(pat[1], pat[2])
end
data = data:gsub("%%", "?") -- always the edge case :P
data = data:gsub("%`", "#") -- and another one
outh:write("<html><title>" .. inp .. "</title><body><div style=\"width:80ch;\"><pre>" .. data .. "\n</pre></div></body></html>")

print("\27[A\27[2K[ \27[92m OK \27[39m ] generated manpage " .. args[1])

inph:close()
outh:close()
