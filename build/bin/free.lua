-- free --

local shell = require("shell")
local computer = require("computer")

local args, opts = shell.parse(...)

local total, free, used

total = computer.totalMemory()
free = computer.freeMemory()
used = total - free

local function round(n)
  return (n / 1024) - (n / 1024) % 0.1
end

if opts.h then
  total = round(total) .. "k"
  free = round(free) .. "k"
  used = round(used) .. "k"
end

print(string.format("Total: %s\nUsed:  %s\nFree:  %s", total, used, free))
