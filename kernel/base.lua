-- The core --

local flags = ...
flags.init = flags.init or "/sbin/init.lua"
flags.quiet = flags.quiet or false

local _KERNEL = "ComputOS"
local _KERNEL_REVISION = "$[[git rev-parse --short HEAD]]"
local _KERNEL_BUILDER = "$[[whoami]]@$[[hostname]]"
local _KERNEL_COMPILER = "luacomp $[[luacomp -v]]"

_G._OSVERSION = string.format("%s version %s")

----#include "module/logger.lua"
----#include "module/initfs.lua"
----#include "module/drivers.lua"
----#include "module/sandbox.lua"
----#include "module/scheduler.lua"
----#include "module/loadfile.lua"

local ok, err = loadfile()
