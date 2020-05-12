-- automounting of filesystems --

local fs = require("filesystem")
local component = require("component")

local function isMounted(ad)
  for k, v in pairs(fs.mounts()) do
    if v == ad then return true end
  end
  return false
end

for addr, _ in component.list("filesystem") do
  if not isMounted(addr) then
    fs.mount(addr, "/mnt/" .. addr:sub(1,3))
  end
end

while true do
  local sig, addr, ct = coroutine.yield()
  if ct and ct == "filesystem" then
    if sig == "component_added" then
      fs.mount(addr, "/mnt/" .. addr:sub(1,3))
    elseif sig == "component_removed" then
      fs.umount("/mnt/" .. addr:sub(1,3))
    end
  end
end
