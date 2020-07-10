--[[
        Monolith's init.
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

local maxrunlevel = ...
local _INITVERSION = "InitMe 2020.7.10"
local kernel = kernel
local panic = kernel.logger.panic
local runlevel = kernel.runlevel
--#include "module/logger.lua"
local log = logger.log

log("INFO", "Starting " .. _INITVERSION)

--#include "module/package.lua"
--#include "module/io.lua"
--#include "module/os.lua"
--#include "module/component.lua"
--#include "module/scripts.lua"
runlevel.setrunlevel(2)
runlevel.setrunlevel(3)
--#include "module/initsvc.lua"

kernel.logger.setShown(false)
logger.setShown(false)

_G._BOOT = require("computer").uptime() - _START

while true do
  coroutine.yield()
end
