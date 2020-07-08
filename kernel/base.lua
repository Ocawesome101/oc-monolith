-- The core --

_G._START = computer.uptime()

local flags = ... or {}
flags.init = flags.init or "/sbin/init.lua"
flags.quiet = flags.quiet or false

local _KERNEL_NAME = "Monolith"
local _KERNEL_REVISION = "2020.7.7"

_G._OSVERSION = string.format("%s version %s", _KERNEL_NAME, _KERNEL_REVISION)

kernel.logger.log("Starting " .. _OSVERSION)

kernel.info = {
  name          = _KERNEL_NAME,
  version       = _KERNEL_REVISION
}

if computer.setArchitecture then
  kernel.logger.log("Set architecture to Lua 5.3")
  computer.setArchitecture("Lua 5.3")
end

--#include "module/component.lua"
--#include "module/users.lua"
--#include "module/module.lua"
--#include "module/filesystem.lua"
--#include "module/computer.lua"
--#include "module/runlevel.lua"
--#include "module/thread.lua"
--#include "module/sandbox.lua"
--#include "module/loadfile.lua"

kernel.logger.log("loading init from " .. flags.init)

local ok, err = loadfile(flags.init, "bt", sandbox)
if not ok then
  kernel.logger.panic(err)
end

kernel.thread.spawn(function()return ok(flags.runlevel or 3) end, flags.init, kernel.logger.panic)
kernel.runlevel.setrunlevel(1)
kernel.thread.start()
