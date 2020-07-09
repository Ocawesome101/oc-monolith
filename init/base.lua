--[[ Monolith's init.

Copyright 2020 Ocawesome101

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. ]]--

local maxrunlevel = ...
local _INITVERSION = "InitMe 2020.7.9"
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
