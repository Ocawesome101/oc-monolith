-- button object --

local base = require("monoui.object")
local label = require("monoui.label")

local _button = base(0,0,0,0)

-- the user should define this
function _button:click()
end

local lib = {}

function lib.new(x, y, w, h, bg, text, fg)
  checkArg(4, bg, "number")
  checkArg(5, text, "string", "nil")
  checkArg(6, fg, "number", "nil")
  local new = _button(x, y, w, h)
  if text then
    local label = label.new(1, h // 2, text, fg, bg)
    new:addChild(label)
  end
  new:bg(bg):fg(fg)
  return new
end

return lib
