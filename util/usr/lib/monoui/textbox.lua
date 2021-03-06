-- textbox element --

local base = require("monoui.object")

local _box = base(0,0,0,0)

local binit = _box.__init
function _box:__init(x, y, w, h, hide)
  self.hide = hide
  self.buffer = ""
  self.text = {text="", x=0, y=0}
  self.col = {fg = 0xFFFFFF, bg = 0x000000}
  self.submittable = true
  return binit(self, x, y, w, h)
end

-- TODO: proper Unicode support
function _box:key(c, k, m)
  if m and self.submittable then
    if c >= 32 and c <= 126 then
      self.buffer = self.buffer .. string.char(c)
    elseif c == 8 then
      self.buffer = self.buffer:sub(1, -2)
    elseif c == 13 then
      if self.submit then
        self.submit(self.buffer)
      end
      self.submittable = false
    end
    if self.hide then
      self.text.text = ("*"):rep(math.min(#self.buffer, self.size.w))
    else
      self.text.text = self.buffer:sub(1, self.size.w, 0)
    end
  end
end

local lib = {}

function lib.new(...)
  return _box(...)
end

return lib
