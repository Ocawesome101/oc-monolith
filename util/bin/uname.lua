-- uname --

local shell = require("shell")
local computer = require("computer")
local kinfo = require("kinfo")
local dinfo = computer.getDeviceInfo()

local args, opts = shell.parse(...)

local kna = opts.s or opts.a or not (opts.n or opts.r or opts.m or opts.p or opts.p or opts.i or opts.o) or false
local nna = opts.n or opts.a or false
local rev = opts.r or opts.a or false
local mch = opts.m or opts.a or false
local prc = opts.p or opts.a or false
local hwp = opts.i or opts.a or false
local ops = opts.o or opts.a or false

local out = ""

if kna then
  out = out .. kinfo.name .. " "
end

if nna then
  out = out .. (os.getenv("HOSTNAME") or "localhost") .. " "
end

if rev then
  out = out .. kinfo.version .. " "
end

if mch then
  out = out .. "Blocker "
end

if prc then
  out = out .. "oc" .. _VERSION:match("(%d%.%d+)"):gsub("%.", "") .. " "
end

if hwp then
  out = out .. _VERSION .. " "
end

if ops then
  out = out .. kinfo.name
end

print(out)
