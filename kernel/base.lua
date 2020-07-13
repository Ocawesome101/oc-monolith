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

local _KERNEL_NAME = "Monolith"
local _KERNEL_REVISION = "2020.7.10"

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

function collectgarbage()
  local missed = {}
  for i=1,10,1 do
    local sig = table.pack(computer.pullSignal(0))
    if sig.n > 0 then
      table.insert(missed, sig)
    end
  end
  for i=#missed,1,-1 do
    computer.pushSignal(table.unpack(missed[i]))
  end
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
sandbox.kernel._FINISH = computer.uptime()
kernel.thread.start()
