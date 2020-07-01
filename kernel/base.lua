-- The core --

_G._START = computer.uptime()

local flags = ... or {}
flags.init = flags.init or "/sbin/init.lua"
flags.quiet = flags.quiet or false

local _KERNEL_NAME = "Monolith"
local _KERNEL_REVISION = "$[[git rev-parse --short HEAD]]"
local _KERNEL_BUILDER = "$[[whoami]]@$[[hostname]]"
local _KERNEL_COMPILER = "luacomp $[[luacomp -v]]"

_G._OSVERSION = string.format("%s revision %s (%s, %s)", _KERNEL_NAME, _KERNEL_REVISION, _KERNEL_BUILDER, _KERNEL_COMPILER)

kernel.logger.log("Starting " .. _OSVERSION)

kernel.info = {
  name          = _KERNEL_NAME,
  revision      = _KERNEL_REVISION,
  builder       = _KERNEL_BUILDER,
  compiler      = _KERNEL_COMPILER
}

if computer.setArchitecture then
  kernel.logger.log("Set architecture to Lua 5.3")
  computer.setArchitecture("Lua 5.3")
end

-- --#include "module/logger.lua"
--#include "module/component.lua"
-- --#include "module/initfs.lua"
--#include "module/users.lua"
--#include "module/module.lua"
--#include "module/filesystem.lua"
--#include "module/computer.lua"
--#include "module/runlevel.lua"
--#include "module/process.lua"
--#include "module/sandbox.lua"
--#include "module/loadfile.lua"

kernel.logger.log("loading init from " .. flags.init)

local ok, err = loadfile(flags.init, "bt", sandbox)
if not ok then
  kernel.logger.panic(err)
end

kernel.process.spawn(function()return ok(flags.runlevel or 3) end, flags.init, {default = kernel.logger.panic})
kernel.runlevel.setrunlevel(1)
kernel.process.start()
