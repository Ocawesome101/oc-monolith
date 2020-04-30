-- rebuild the initramfs --

local args = {...}

local opts = {}

if not (string.unpack and string.pack) then
  error("Lua 5.3 is required")
end

for i=1, #args, 1 do
  if args[i]:sub(1,1) == "--" then
    opts[args[i]:sub(3)] = table.remove(args, i + 1)
  end
end

local root = opts.root or "/"

print("mkinitramfs: using '" .. root .. "' as root dir")
