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

local uiBase = monoui.init(gpu, screen)

local win = window.new(1, 1, 20, 10)
local lab = label.new(7, 1, "LOG IN", 0)
win:addChild(lab)
uiBase:addChild(win)
local win2 = window.new(10, 10, 20, 10)
win2:bg(0xFF0000)
uiBase:addChild(win2)

uiBase:mainLoop()
