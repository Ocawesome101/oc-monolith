-- devfs --

local uuid = require("uuid")
local fs = require("filesystem")
local text = require("text")
local component = require("component")

local devfs = {internal = {}}

local vfs = {
  isDirectory = true,
  children = {
    ["random"] = {
      isDirectory = false,
      read = function(_,n) if n > 2048 then n = 2048 end local s = "" for i=1, n, 1 do s = s .. string.char(math.random(0, 255)) end return s end,
      write = roerr
    },
    ["zero"] = {
      isDirectory = false,
      read = function(_,n) if n > 2048 then n = 2048 end return string.rep("\0", n) end,
      write = roerr
    },
    ["null"] = {
      isDirectory = false,
      read = function()return "" end,
      write = function()end
    },
    ["stdin"] = {
      isDirectory = false,
      read = function(_,...)return io.stdin:read(...) end,
      write = roerr
    },
    ["stdout"] = {
      isDirectory = false,
      read = function()error("stdout is write-only")end,
      write = function(_,...)return io.stdout:write(...) end
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

function devfs.internal.find(f)
  if f == "/" then return vfs end
  local segs = text.split(f, "/", true)
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

function fsc.getLabel()
  return "devfs"
end

function fsc.exists(file)
  checkArg(1, file, "string")
  if file == "/" or file == "" then return true end
  local ok, err = find(file)
  return ok
end

devfs.internal.fsc = fsc

package.delay(fsc, "/lib/full/devfs.lua")

fs.mount(fsc, "/dev")

local seen = {}
local generic = require("devfs.adapters.generic")
local function getadapter(ctype)
  local ok, ret = pcall(require, "devfs.adapters." .. ctype)
  if ok and ret then return ret, false else return generic, true end
end
function devfs.addComponent(addr)
  checkArg(1, addr, "string")
  local t = component.type(addr)
  local adapter, isgeneric = getadapter(t)
  local inst = adapter.instance(addr)
  seen[t] = seen[t] or 0
  local n = adapter.name or t
  if not isgeneric then vfs.children[n..seen[t]] = (inst.isDirectory and inst) or {read = inst.read, write = inst.write, isDirectory = false} end
  vfs.children.components.children[addr:sub(1,3)] = (inst.isDirectory and inst) or {read = inst.read, write = inst.write, isDirectory = false, nodename = n..seen[t]}
  seen[t] = seen[t]+1
  return true
end

function devfs.register(name, stream)
  checkArg(1, name, "string")
  checkArg(2, stream, "table")
  vfs.children[name] = {
    isDirectory = false,
    read = function(_,...)return stream:read(...) end,
    write = function(_,...)return stream:write(...)end,
  }
  return true
end

function devfs.unregister(name)
  checkArg(1, name, "string")
  vfs.children[name] = nil
  return true
end

function devfs.removeComponent(addr)
  checkArg(1, addr, "string")
  local c = vfs.children.component.children
  if c[addr:sub(1,3)] then
    vfs.children[c[addr:sub(1,3)].nodename] = nil
    c[addr] = nil
  end
end

return devfs
