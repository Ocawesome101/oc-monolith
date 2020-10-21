-- term api implemented on top of vt100 --

local component = require("component")
local vt = require("vt")
local term = {}

term.write = io.write
term.read = require("readline")
function term.setCursor(x,y)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  io.write(string.format("\27[%d;%dH", y, x))
end
function term.getCursor()
  io.write("\27[6n")
  local resp = ""
  repeat
    local c = io.read(1)
    resp = resp .. c
  until c == "R"
  local x, y = resp:match("%[(%d)+;(%d+)R")
  print(resp)
  return tonumber(x) or 1, tonumber(y) or 1
end
term.setCursorBlink = function() end
term.getGlobalArea = function() return 1, 1, vt.getResolution() end
function term.clear()
  io.write "\27[2J"
end
function term.isAvailable()
  return true
end
-- TODO: abstract these things on top of vt100
function term.gpu()
  return component.gpu
end
function term.keyboard()
  return component.keyboard
end
function term.screen()
  return component.screen
end
term.pull = require("event").pull

return term
