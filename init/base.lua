-- Monolith's init --

local _INITVERSION = "InitMe $[[git rev-parse --short HEAD]] (built $[[date +'%a %b %d %R:%S %Z %Y']] by $[[whoami]]@$[[hostname]])"
local kernel = kernel
local panic = kernel.logger.panic
local log = kernel.logger.log
local _log = function()end--component.sandbox.log

--[[local oerr = error
function _G.error(e, l)
  _log(debug.traceback(e, l))
  oerr(e, l)
end]]

log(_INITVERSION)

--#include "module/package.lua"
--#include "module/io.lua"
--#include "module/os.lua"
--#include "module/initd.lua"
--#include "module/initsvc.lua"

kernel.logger.setShown(false)

_G._BOOT = require("computer").uptime() - _START

while true do
  coroutine.yield()
end
