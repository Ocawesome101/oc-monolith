-- ComputOS init --

local _INITVERSION = "InitMe $[[git rev-parse --short HEAD]] (built $[[date +'%a %b %d %R:%S %Z %Y']] by $[[whoami]]@$[[hostname]])"
local panic = kernel.logger.panic
local log = kernel.logger.log

log(_INITVERSION)

--#include "module/package.lua"
--#include "module/io.lua"
--#include "module/initsvc.lua"

while true do
  coroutine.yield()
end
