-- Monolith's init --

local maxrunlevel = ...
local _INITVERSION = "InitMe $[[git rev-parse --short HEAD]] (built $[[date +'%a %b %d %R:%S %Z %Y']] by $[[whoami]]@$[[hostname]])"
local kernel = kernel
local panic = kernel.logger.panic
local log = kernel.logger.log
local runlevel = kernel.runlevel
local _log = function()end--component.sandbox.log

log(_INITVERSION)

--#include "module/package.lua"
--#include "module/io.lua"
--#include "module/os.lua"
--#include "module/component.lua"
---#include "module/initd.lua"
runlevel.setrunlevel(2)
runlevel.setrunlevel(3)
--#include "module/initsvc.lua"

kernel.logger.setShown(false)

_G._BOOT = require("computer").uptime() - _START

while true do
  coroutine.yield()
end
