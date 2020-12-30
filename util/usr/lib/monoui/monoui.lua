--[[                                                                                               
        MonoUI login
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

-- these are passed by MDM
local gpu, screen = ...

local users = require("users")
local monoui = require("monoui")
local window = require("monoui.window")
local label = require("monoui.label")
local textbox = require("monoui.textbox")

local uiBase = monoui.init(gpu, screen)

local win = window.new(1, 1, 20, 10)
local lab = label.new(7, 1, "Log In", 0)
local errLabel = label.new(1, 2, "Invalid Credentials", 0xFF0000)
local unb = textbox.new(3, 3, 14, 1)
local pwb = textbox.new(3, 5, 14, 1, true)
unb:fg(0xFFFFFF):bg(0x000000)
pwb:fg(0xFFFFFF):bg(0x000000)
win:addChild(lab)
win:addChild(unb)

function unb.submit()
  win:addChild(pwb)
end

local added = false
function pwb.submit()
  local ok, err = users.login(unb.buffer, pwb.buffer)
  if not ok then
    win.children[pwb.childidx] = nil
    if not added then
      added = true
      win:addChild(errLabel)
    end
    pwb.parent = nil
    pwb.childidx = nil
    pwb.submittable = true
    unb.submittable = true
  else
    -- create desktop
    uiBase:bg(0x00AAFF).children = {}
    local w, h = uiBase:getResolution()
    local bar = window.new(1, h - 3, w, 1):fg(0xFFFFFF):bg(0x222222)
    uiBase:addChild(bar)
  end
end

uiBase:addChild(win)

uiBase:mainLoop()
