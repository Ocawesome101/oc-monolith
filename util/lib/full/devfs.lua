local devfs = require("devfs")

local fsc = devfs.internal.fsc
local find = devfs.internal.find

function fsc.lastModified()
  return 0
end

function fsc.open(file, mode)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  local ok, err = find(file)
  if not ok then
    return nil, err
  end
  local n = #open + 1
  open[n] = {thing = ok}
  return n
end

function fsc.read(n, a)
  checkArg(1, n, "number")
  checkArg(2, a, "number")
  if not open[n] then
    return nil, "bad file descriptor"
  end
  return open[n].thing.read(open[n], a)
end

function fsc.seek()
  return 0
end

function fsc.write(n, d)
  checkArg(1, n, "number")
  checkArg(2, d, "string", "number", "boolean")
  if not open[n] then
    return nil, "bad file descriptor"
  end
  return open[n].thing.write(open[n], a)
end

function fsc.close(n)
  checkArg(1, n, "number")
  if not open[n] then
    return nil, "bad file descriptor"
  end
  open[n] = nil
end

function fsc.spaceTotal()
  return math.huge
end

function fsc.size()
  return 0
end

function fsc.isDirectory(file)
  checkArg(1, file, "string")
  local ok, err = find(file)
  if not ok then return nil, err end
  return ok.isDirectory or false
end

function fsc.exists(file)
  checkArg(1, file, "string")
  if file == "/" or file == "" then return true end
  local ok, err = find(file)
  return ok
end

function fsc.list(file)
  checkArg(1, file, "string")
  local ok, err = find(file)
  if not ok then return nil, err end
  local l = {}
  for k, v in pairs(ok.children) do
    if v.isDirectory then k = k .. "/" end
    l[#l + 1] = k
  end
  return l
end

function fsc.spaceUsed()
  return 0
end 
