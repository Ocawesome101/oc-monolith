-- terminal emulation for MonoUI

local window = require("monoui.window")
local vterm = require("monoui.vterm")
local thread = require("thread")

local win = window.new(2, 2, 50, 16)
local tbo = vterm.new(1, 1)

win:addChild(tbo)

local i, o, e = io.input(), io.output(), io.error()
io.input(tbo)
io.output(tbo)
io.error(tbo)

local function err(e)
  tbo:write("shell crashed: " .. tostring(e))
end

thread.spawn(function()dofile("/bin/sh.lua")end, "mvt-sh", err)

io.input(i)
io.output(o)
io.error(e)

return win
