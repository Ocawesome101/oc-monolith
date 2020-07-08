-- Monolith's init --

local maxrunlevel = ...
local _INITVERSION = "InitMe 2020.7.7"
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
