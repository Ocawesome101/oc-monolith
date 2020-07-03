-- term api implemented on top of vt100 --

local term = {}

term.write = io.write
term.read = require("readline").readline
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
term.getGlobalArea = function() return 1, 1, io.stdout.gpu.getResolution() end
function term.clear()
  io.write "\27[2J"
end
function term.isAvailable()
  return true
end
function term.gpu()
  return io.stdout.gpu
end
function term.keyboard()
  return require("component").invoke(io.stdout.screen, "getKeyboards")[1]
end
function term.screen()
  return io.stdout.screen
end
term.pull = require("event").pull

return term
