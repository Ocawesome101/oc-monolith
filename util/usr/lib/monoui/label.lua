-- labels - text, possibly clickable --

local base = require("monoui.object")

local _obj = base(0,0,0,0)

local lib = {}

function lib.new(x, y, text, fg, bg)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, text, "string")
  checkArg(4, fg, "number")
  checkArg(5, bg, "number", "nil")
  local new = _obj(x, y, 0, 0)
  new:fg(fg)
  new:bg(bg)
  new.text = {x = 0, y = 0, text = text}
  return new
end

return lib
