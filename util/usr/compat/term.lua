-- term api implemented on top of vt100 --

local term = {}

term.write = io.write
term.read = require("readline").readline
function term.setCursor(x,y)
  io.write(string.format("\27[%d;%dH", y, x))
end
function term.clear()
  io.write "\27[2J"
end

return term
