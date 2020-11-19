-- window class - provides a draggable, closable element --

local base = require("monoui.object")

local _window = base(0,0,0,0)

-- TODO TODO TODO: improve drag logic
function _window:drag(x, y)
  self.pos.x = x - (self.size.w // 2)
  self.pos.y = y - (self.size.h // 2)
end

local wk = _window.key
local keys = {
  lcontrol = 29,
  rcontrol = 157
}
function _window:key(c, k, m)
  self.ctrl = (k == keys.lcontrol or k == keys.rcontrol) and m
  if self.ctrl and string.char(c) == "w" and m then
    self.parent.children[self.childidx] = nil
    return
  end
  -- propagate to child elements
  wk(self, c, k, m)
end

local lib = {}

function lib.new(x, y, w, h)
  local new = _window(x, y, w, h)
  return new
end

return lib
