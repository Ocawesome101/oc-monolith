-- shutdown --

local shell = require("shell")
local computer = require("computer")

local args, opts = shell.parse(...)

local pwr = opts.poweroff or opts.P or opts.h or false
local rbt = opts.reboot or opts.r or false
local msg = opts.k or false
local hlt = opts.halt or opts.H or false -- uses computer.crash()

computer.pushSignal("shutdown")
coroutine.yield()

if (pwr or rbt or hlt) and not msg then
  computer.shutdown(rbt)
end

return shell.codes.argument
