-- textbox element --

local base = require("monoui.object")

local _box = base(0,0,0,0)

local binit = _box.__init
function _box:__init(x, y, w, h)
  self.buffer = ""
  self.text = {text="", x=1, y=1}
  return binit(self, x, y, w, h)
end

-- TODO: proper Unicode support
function _box:key(c, k, m)
  if m then
    if c >= 32 and c <= 126 then
      self.buffer = self.buffer .. string.char(c)
    elseif c == 8 then
      self.buffer = self.buffer:sub(1, -2)
    elseif c == 13 then
      if self.submit then
        self.submit(self.buffer)
      end
    end
    self.text.text = self.buffer:sub(#self.buffer - self.size.w, 0)
  end
end

local lib = {}

function lib.new(...)
  return _box(...)
end

return lib
