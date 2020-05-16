-- mount --

local shell = require("shell")
local fs = require("filesystem")
local component = require("component")
local get = component.get
local text = require("text")

local args, opts = shell.parse(...)

local ro = ((opts.r and opts.o and not opts.w) or opts.ro) and not opts.rw or false
local rw = (opts.r and opts.w) or opts.rw or true

if #args < 2 then
  local mounts = fs.mounts()
  for k, v in pairs(mounts) do
    local ro = (fs.get(k).isReadOnly() and "ro") or "rw"
    print(string.format("%s on %s (%s) \"%s\"", v:sub(1,8), k, ro, (fs.get(k).getLabel()) or ""))
  end
  return
else
  local addr = get(args[1])
  if not addr or component.type(addr) ~= "filesystem" then
    shell.error(args[1], "no such filesystem")
  end
  local path = fs.canonical(args[2])
  local ok, err = fs.mount(addr, path, (ro and not rw))
  if not ok then
    shell.error("mount", err)
    return shell.codes.failure
  end
end
