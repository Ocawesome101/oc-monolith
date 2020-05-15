-- devfs --

local uuid = require("uuid")
local fs = require("filesystem")
local text = require("text")
local component = require("component")

local devfs = {}

local roerr = setmetatable({"makeDirectory", "remove", "rename", "setLabel"}, {__index = function(tbl,k) for k,v in pairs(tbl) do tbl[v] = k end if tbl[k] then return tbl[k] end end, __call = function()error("filesystem is read-only")end})

local vfs = {
  isDirectory = true,
  children = {
    ["random"] = {
      isDirectory = false,
      read = function(n) if n > 2048 then n = 2048 end local s = "" for i=1, n, 1 do s = s .. string.char(math.random(0, 255)) end return s end,
      write = roerr
    },
    ["zero"] = {
      isDirectory = false,
      read = function(n) if n > 2048 then n = 2048 end return string.rep("\0", n) end,
      write = roerr
    },
    ["null"] = {
      isDirectory = false,
      read = function()return "" end,
      write = function()end
    },
    ["stdin"] = {
      isDirectory = false,
      read = function(...)return io.stdin:read(...) end,
      write = roerr
    },
    ["stdout"] = {
      isDirectory = false,
      read = function()error("stdout is write-only")end,
      write = function(...)return io.stdout:write(...) end
    },
    ["components"] = {
      isDirectory = true,
      children = {}
    }
  }
}

local fsc = {
  address = uuid.new(),
  type = "filesystem",
  isReadOnly = function()return true end
}
local mt = {
  __index = function(tbl,k)
    if roerr[k] then roerr() else error("attempt to index field '" .. k .. "' (a nil value)") end
  end
}
setmetatable(fsc, mt)

local open = {}

local function find(f)
  if f == "/" then return vfs end
  local segs = text.split(f, "/")
  local cur = vfs
  for _, seg in ipairs(segs) do
    if cur.isDirectory and cur.children[seg] then
      cur = cur.children[seg]
      if _ == #segs then return cur end
    else
      break
    end
  end
  return nil, f
end

function fsc.lastModified()
  return 0
end

function fsc.getLabel()
  return "devfs"
end

function fsc.open(file, mode)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  local ok, err = find(file)
  if not ok then
    return nil, err
  end
  local n = #open + 1
  open[n] = ok
  return n
end

function fsc.read(n, a)
  checkArg(1, n, "number")
  checkArg(2, a, "number")
  if not open[n] then
    return nil, "bad file descriptor"
  end
  return open[n].read(a)
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
  return open[n].read(a)
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
  if not ok then return nil, err end
  return true
end

function fsc.list(path)
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

fs.mount(fsc, "/dev")

local seen = {}
function devfs.addComponent(addr)
  checkArg(1, addr, "string")
  local t = component.type(addr)
  local adapter = require("devfs.adapters." .. t)
  local inst = adapter.instance(addr)
  seen[t] = seen[t] or 0
  vfs.children[t..seen[t]] = {read = inst.read, write = inst.write, isDirectory = false}
  vfs.children.components.children[addr] = {read = inst.read, write = inst.write, isDirectory = false, nodename = t..seen[t]}
  seen[t] = seen[t]+1
  return true
end

function devfs.removeComponent(addr)
  checkArg(1, addr, "string")
  local c = vfs.children.component.children
  if c[addr] then
    vfs.children[c[addr].nodename] = nil
    c[addr] = nil
  end
end

return devfs
