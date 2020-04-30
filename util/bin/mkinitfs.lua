-- rebuild the initramfs --

-- ComputOS' initramfs has a similar format to OpenBootLoader's BROFS, differing only in that its file table is twice as large, allowing for 64 files, and that file start is in bytes rather than sectors.

local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local ser = require("serialization").serialize
local shell = require("shell")

local args, opts = shell.parse(...)

if not (string.unpack and string.pack) then
  error("Lua 5.3 is required")
end

local root = opts.root or "/"
local boot = opts.boot or computer.getBootAddress()
local tmp = opts.tmp or computer.tmpAddress()

print("mkinitfs: using '" .. root .. "' as generator root dir")
print("mkinitfs: using '" .. boot .. "' as boot drive")
print("mkinitfs: using '" .. tmp  .. "' as /tmp")

local ft = {}

local lunused = 2049

local function add(name, size)
  print("mkinitfs: adding file " .. name .. " with size " .. size)
  ft[#ft + 1] = {
    name = name,
    start = lunused,
    size = size
  }
  lunused = lunused + size
end

local function mkft()
  print("mkinitfs: generating file table")
  local t = ""
  for i=1, #ft, 1 do
    t = t .. string.pack("<c24I4I4", ft[i].name, ft[i].start, ft[i].size)
  end
  return string.pack("<c2048", t)
end

local files = {}

local function mkfs()
  print("mkinitfs: generating image")
  local rst = mkft()
  for i=1, #ft, 1 do
    print("mkinitfs: adding file " .. ft[i].name .. " at " .. #rst + 1 .. " (should be " .. ft[i].start .. ")")
    rst = rst .. string.pack("<c" .. #files[ft[i].name], files[ft[i].name])
  end
  return rst
end

print("mkinitfs: generating fstab")

local fstab = [[{
  {
    address = "]]..boot..[[",
    path = "/"
  },
  {
    address = "]]..tmp..[[",
    path = "/tmp"
  }
}]]

local ifsd = fs.concat(root, "/lib/initfs/")

for file in fs.list(ifsd) do
  local handle = io.open(fs.concat(ifsd, file), "r")
  local data = handle:read("*a")
  handle:close()
  files[file] = data
  add(file, #data)
end

if not files.fstab then
  files.fstab = fstab
  add("fstab", #fstab)
end

local bin = mkfs()

print("mkinitfs: saving to initramfs.bin")

local file, err = io.open(fs.concat(root, "initramfs.bin"), "w")
if not file then
  error("failed opening initramfs.bin for writing: " .. err)
end

file:write(bin)

file:close()

return 0
