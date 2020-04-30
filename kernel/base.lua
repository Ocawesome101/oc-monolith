-- The core --

local _START = computer.uptime()

local flags = ...
flags.init = flags.init or "/sbin/init.lua"
flags.quiet = flags.quiet or false

local _KERNEL = "ComputOS"
local _KERNEL_REVISION = "$[[git rev-parse --short HEAD]]"
local _KERNEL_BUILDER = "$[[whoami]]@$[[hostname]]"
local _KERNEL_COMPILER = "luacomp $[[luacomp -v]]"

_G._OSVERSION = string.format("%s revision %s (%s, %s)", _KERNEL_NAME, _KERNEL_REVISION, _KERNEL_BUILDER, _KERNEL_COMPILER)

_G.kernel = {}

--#include "module/logger.lua"
--#include "module/component.lua"
--#include "module/initfs.lua"
--#include "module/users.lua"
--#include "module/module.lua"
--#include "module/filesystem.lua"
--#include "module/computer.lua"
--#include "module/sandbox.lua"
--#include "module/thread.lua"
--#include "module/loadfile.lua"

local ok, err = loadfile(flags.init, "bt", sandbox)
if not ok then
  kernel.logger.panic(err)
end

kernel.thread.spawn(ok, flags.init, kernel.logger.panic)
