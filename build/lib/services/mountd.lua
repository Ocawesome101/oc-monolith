-- automounting of filesystems --

local fs = require("filesystem")
local component = require("component")

for addr, _ in component.list("filesystem") do
  fs.mount(addr, "/mnt/" .. addr:sub(1,3))
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
