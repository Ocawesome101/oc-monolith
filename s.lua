#!/usr/bin/env lua5.3

local args = {...}
local fil = args[1]
local old = args[2]
local new = args[3]

io.open(fil,"w"):write((io.open(fil,"r"):read("a"):gsub(old,new)))
