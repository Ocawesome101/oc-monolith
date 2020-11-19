-- element base --

local class = require("class")

local _obj = class()

-- class initiator function.
-- arguments:
--   x:number - X position
--   y:number - Y position
--   w:number - width
--   h:number - height
function _obj:__init(x, y, w, h)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, w, "number")
  checkArg(4, h, "number")
  self.size = {w=w, h=h}
  self.pos  = {x=x, y=y}
  self.col  = {fg=0x000000, bg=0xFFFFFF}
  self.children = {}
end

-- add a child to the object.  the provided object's parent will be set to the
--   object on which this method is called.
-- arguments:
--   chl:{child} - child object
function _obj:addChild(chl)
  local n = #self.children + 1
  self.children[n] = chl
  chl.childidx = n
  chl.parent = self
  return self
end

-- set colors
function _obj:fg(f)
  checkArg(1, f, "number", "nil")
  if f then
    self.col.fg = f
    return self
  end
  return self.col.fg
end

function _obj:bg(b)
  checkArg(1, b, "number", "nil")
  if b then
    self.col.bg = b
    return self
  end
  return self.col.bg
end

-- render the object and all its children in a recursive-descent order.
-- for perfoamance reasons, this function is by default only called on the base
-- object when the user releases a mouse button.  I may change this in the
-- future, but for now it should be good enough for a UI similar to the Amiga or
-- the original Macintosh.
-- arguments:
--   gpu:table - proxy to the GPU that should be used to render
--   x:number  - base X coordinate (parent's base X + parent's X position)
--   y:number  - base Y coordinate (parent's base Y + parent's Y position)
function _obj:render(gpu, x, y)
  checkArg(1, gpu, "table")
  gpu.setForeground(self.col.fg)
  gpu.setBackground(self.col.bg)
  gpu.fill(self.pos.x + x, self.pos.y + y, self.size.w, self.size.h, " ")
  if self.text then
    gpu.set(self.text.x + self.pos.x + x, self.text.y + self.pos.y + y,
                                                                 self.text.text)
  end
  for i=1, #self.children, 1 do
    self.children[i]:render(gpu, self.pos.x + x, self.pos.y + y)
  end
  return self
end

-- returns the object's parent.  'nuff said.
function _obj:parent()
  return self.parent
end

-- called when the object is dragged.
-- arguments:
--   x:number - X coordinate
--   y:number - Y coordinate
function _obj:drag(x,y)
end

-- called when the object is clicked.
-- arguments:
--   x:number - X coordinate - relative to the object!
--   y:number - Y coordinate - relative to the object!
--   b:number - mouse button
--   m:boolean - mouse pressed or released?
--
function _obj:click(x,y,bm)
  for i=1, #self.children, 1 do
    local c = self.children[i]
    if x >= c.pos.x and x <= c.pos.x + c.size.w and
       y >= c.pos.y and y <= c.pos.y + c.size.h then
      c:click(x - c.pos.x, y - c.pos.y, b, m)
    end
  end
end

-- called when a key is pressed.
-- arguments:
--   c:number - character code
--   k:number - key code
--   m:boolean - pressed or released?
function _obj:key(c,k,m)
  -- default behavior: propagate to children
  for i=1, #self.children, 1 do
    self.children[i]:key(c,k,m)
  end
end

return _obj
