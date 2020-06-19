-- init --

local addr, invoke = computer.getBootAddress(), component.invoke

local kernelPath = "/boot/kernel/loader"

local handle, err = invoke(addr, "open", kernelPath)
if not handle then
  error(err)
end

local t = ""
repeat
  local c = invoke(addr, "read", handle, math.huge)
  t = t .. (c or "")
until not c

invoke(addr, "close", handle)

local ok, err = load(t, "=" .. kernelPath, "bt", _G)
if not ok then
  kernel.logger.panic(err)
end

local ok, err = xpcall(ok, debug.traceback, flags)
if not ok and err then
  error(err)
end
