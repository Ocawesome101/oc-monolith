-- element base --

local class = require("class")

local _obj = class()

function _obj:__init(x, y, w, h)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, w, "number")
  checkArg(4, h, "number")
  self.size = {w=w, h=h}
  self.pos  = {x=x, y=y}
  self.children = {}
end

function _obj:addChild(chl)
  self.children[#self.children + 1] = chl
  chl.parent = self
  return self
end

function _obj:render(gpu)
  checkArg(1, gpu, "table")
  gpu.fill(self.pos.x, self.pos.y, self.size.w, self.size.h, " ")
  if self.text then
    gpu.set(self.text.x + self.pos.x, self.text.y + self.pos.y, self.text.text)
  end
  for i=1, #self.children, 1 do
    self.children[i]:render(gpu)
  end
  return self
end

function _obj:parent()
  return self.parent
end

return _obj
