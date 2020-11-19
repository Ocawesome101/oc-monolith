--[[                                                                                               
        The core of MonoUI.
        Copyright (C) 2020 Ocawesome101

        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.

        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this program.  If not, see <https://www.gnu.org/licenses/>. ]]

local obj = require("monoui.object")
local component = require("component")
local lib = {}

local base = obj(0,0,0,0)

function base:__init(gpu, screen)
  checkArg(1, gpu, "string")
  checkArg(2, screen, "string")
  self.gpu = component.proxy(gpu)
  self.gpu.bind(screen)
  local w, h = self.gpu.maxResolution()
  self.gpu.setResolution(w, h)
  self.size = {w=w,h=h}
  self.col  = {fg=0xFFFFFF, bg=0x000000}
  self.children = {}
  return self
end

function base:render()
  self.gpu.setForeground(self.col.fg)
  self.gpu.setBackground(self.col.bg)
  self.gpu.fill(1, 1, self.size.w, self.size.h, " ")
  for i=1, #self.children, 1 do
    self.children[i]:render(self.gpu, 0, 0)
  end
end

function base:findChild(x, y)
  for i=1, #self.children, 1 do
    local c = self.children[i]
    if x >= c.pos.x and x <= c.pos.x + c.size.w and
       y >= c.pos.y and y <= c.pos.y + c.size.h then
      return c
    end
  end
end

-- main loop function - spawns a thread dealing with the provided UI base.
function base:mainLoop()
  local screen = self.gpu.getScreen()
  local keyboards = {}
  for _, k in pairs(component.invoke(screen, "getKeyboards")) do
    keyboards[k] = true
  end
  local focused = self
  local drag = false
  self:render()
  while true do
    local sig, addr, p1, p2, p3 = coroutine.yield()
    if addr == screen or keyboards[addr] then
      if sig == "touch" then
        local c = self:findChild(p1, p2)
        if c then
          focused = c
        end
      elseif sig == "drag" then
        drag = true
        self.gpu.set(p1, p2, "-")
      elseif sig == "drop" then
        if drag then
          focused:drag(p1, p2)
        else
          focused:click(p1, p2, p3)
        end
        drag = false
        self:render()
        focused = self
      elseif sig == "key_down" or sig == "key_up" then
        focused:key(p1, p2, sig == "key_up")
      end
    end
  end
end

function lib.init(...)
  return base(...)
end

return lib
