-- set up the devfs --

local devfs = require("devfs")
local component = require("component")

for addr, ctype in component.list() do
  -- attempts to guess component type and autoload an adapter for it
  pcall(devfs.addComponent, addr)
end

while true do
  local sig, addr, ctype = coroutine.yield()
  if sig == "component_added" then
    pcall(devfs.addComponent, addr)
  elseif sig == "component_removed" then
    pcall(devfs.removeComponent, addr)
  end
end
