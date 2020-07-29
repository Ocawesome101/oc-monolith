#!/usr/bin/lua5.3
-- HTML man-page generator --

local args = {...}

print(table.concat({"[ \27[94mINFO\27[39m ] genhtml", args[1], "->", args[2]}, " "))

local inp = args[1]
local out = args[2]

local inph = assert(io.open(inp, "r"))
local outh = assert(io.open(out, "w"))

local patterns = {
  {"%*(.-)%&", "<span style=\"font-weight:bold;\">%1</span>"},
  {"&~(.-)%&", "<span style=\"color:0xFF0000;\">%1</span>"},
  {"%#(.-)%&", "<span style=\"color:0xFFFF00;\">%1</span>"},
  {"%?(.-)%&", "<span style=\"color:0xFF00FF;\">%1</span>"},
  {"%@(.-)%&", "<span style=\"color:0x00FF00;\">%1</span>"},
  {"%^(.-)%&", "<span style=\"color:0x00AAFF;\"></span>"},
  {"%?%&%^%~%#%@", ""}
}

local line = inph:read("a")
for _, pat in ipairs(patterns) do
  line = line:gsub(pat[1], pat[2])
end
line = line:gsub("%%", "?") -- always the edge case :P
line = line:gsub("%`", "#") -- and another one
outh:write("<html><title>" .. inp .. "</title><body><div style=\"width:80ch;\"><pre>" .. line .. "\n</pre></div></body></html>")

print("\27[A\27[2K[ \27[92m OK \27[39m ] generated manpage " .. args[1])

inph:close()
outh:close()
