-- df --

local fs = require("filesystem")
local text = require("text")

local mounts = fs.mounts()

print("Filesystem    Used    Available  Use%  Mounted on")

for k,v in pairs(mounts) do
  local px = fs.get(k)
  local label = px.getLabel() or v:sub(1,8)
  label = label:sub(1,12)
  local used = px.spaceUsed() / 1024
  local total = px.spaceTotal() / 1024
  local free = (total - used)
  local usep = string.format("%3d%%", (((used / total) * 100) + 0.5) // 1)
  used = string.format("%4.1fK", used)
  free = string.format("%4.1fK", free)
  print(string.format("%s  %s  %s  %s  %s", text.padRight(label, 12), text.padRight(used, 6), text.padRight(free, 9), text.padRight(usep, 4), k))
end
