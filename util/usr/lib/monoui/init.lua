-- monoui core --

local obj = require("monoui.object")
local component = require("component")
local lib = {}

local base = obj()

function base:__init(gpu, screen)
  checkArg(1, gpu, "string")
  checkArg(2, screen, "string")
  self.gpu = component.proxy(gpu)
  self.gpu.bind(screen)
  local w, h = self.gpu.maxResolution()
  self.gpu.setResolution(w, h)
  self.size = {w=w,h=h}
  self.children = {}
  return self
end

function base:render()
  self.gpu.fill(1, 1, self.size.w, self.size.h, " ")
  for i=1, #self.children, 1 do
    self.children[i]:render(self.gpu, 0, 0)
  end
end

function lib.init(...)
  return base(...)
end

return lib
