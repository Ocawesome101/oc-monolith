--[[    
        The core of the Monolith kernel.
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

kernel._START = computer.uptime()

local flags = ... or {}
flags.init = flags.init or "/sbin/init.lua"
flags.quiet = flags.quiet or false
flags.runlevel = flags.runlevel or 3

local _KERNEL_NAME = "Monolith"
local _KERNEL_REVISION = "@[{os.date('%Y.%m.%d')}]"

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

if _VERSION ~= "Lua 5.3" then
  kernel.logger.panic("Lua 5.3 is not available but is required")
end

kernel.logger.log("CPU architecture is Lua 5.3")

do
  local pullSignal = computer.pullSignal
  function collectgarbage()
    local missed = {}
    for i=1,10,1 do
      local sig = table.pack(pullSignal(0))
      if sig.n > 0 then
        table.insert(missed, sig)
      end
    end
    for i=1,#missed,1 do
      computer.pushSignal(table.unpack(missed[i]))
    end
  end
end

kernel.logger.log("module/component")
--#include "module/component.lua"
kernel.logger.log("module/users")
--#include "module/users.lua"
kernel.logger.log("module/dkms")
--#include "module/dkms.lua"
kernel.logger.log("module/filesystem")
--#include "module/filesystem.lua"
kernel.logger.log("module/computer")
--#include "module/computer.lua"
kernel.logger.log("module/runlevel")
--#include "module/runlevel.lua"
kernel.logger.log("module/thread")
--#include "module/thread.lua"
kernel.logger.log("module/sandbox")
--#include "module/sandbox.lua"
kernel.logger.log("module/loadfile")
--#include "module/loadfile.lua"

kernel.logger.log("loading init from " .. flags.init)

local ok, err = loadfile(flags.init, "bt", sandbox)
if not ok then
  kernel.logger.panic(err)
end

kernel.thread.spawn(function()return ok(flags.runlevel or 3) end, "[init]", kernel.logger.panic)
kernel.runlevel.setrunlevel(1)
sandbox.kernel._FINISH = computer.uptime()
kernel.thread.start()
