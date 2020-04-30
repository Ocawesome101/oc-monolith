-- read-only driver for the initramfs --

local ifs = {}

do
  kernel.logger.log("loading initramfs.bin")
  local fs = component.proxy(computer.getBootAddress())
  local iramfs = fs.open("/initramfs.bin", "r")
  if not iramfs then
    kernel.logger.panic("initramfs not found")
  end
  local filetable = fs.read(iramfs, 2048)
  
  local files = {}
  for i=1, 2048, 32 do
    local name, start, size = string.unpack("<c24I4I4", filetable:sub(i, i + 31))
    if name == "\0" then
      break
    end
    name = name:gsub("\0", "")
    files[name] = {
      start= start,
      size = size
    }
  end

  function ifs.read(file)
    if files[file] then
      kernel.logger.log("reading " .. file .. " from initramfs")
      local nptr = fs.seek(iramfs, "set", files[file].start)
      if not nptr then
        kernel.logger.panic("invalid initramfs entry: " .. file)
      end
      local data = fs.read(iramfs, files[file].size)
      return data
    end
    kernel.logger.panic("no such file: " .. file)
  end

  function ifs.close()
    return fs.close(iramfs)
  end
end
