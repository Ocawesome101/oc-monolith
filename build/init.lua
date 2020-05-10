-- init --

local flags = {
  init = "/sbin/init.lua",
  quiet = false
}

local addr, invoke = computer.getBootAddress(), component.invoke

local kernel = "/boot/kernel.lua"

local handle, err = invoke(addr, "open", kernel)
if not handle then
  error(err)
end

local t = ""
repeat
  local c = invoke(addr, "read", handle, math.huge)
  t = t .. (c or "")
until not c

invoke(addr, "close", handle)

local ok, err = load(t, "=" .. kernel, "bt", _G)
if not ok then
  error(err)
end

ok(flags)
