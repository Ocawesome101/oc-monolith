-- memory-hungry faux-tmpfs lib --

local uuid = require("uuid")
local computer = require("computer")

local m = {}

local d = {}

local function split(s)
  s = s or"/"
  local r = {}
  for seg in s:gmatch("[^\\/]+") do
    if seg == ".." then
      table.remove(r, #r)
    else
      table.insert(r, seg)
    end
  end
  return r
end

function d:find(_, file)
  local s = split(file)
  local cur = self.nodes
  for i=1, #s, 1 do
    local S = s[i]
    if cur.children[S] then
      if i == #s then
        return cur.children[S], cur, S
      end
      cur = cur.children[S]
    end
  end
  if file == "/" or file == "" then return self.nodes end
  return nil, "no such file or directory"
end

function d:checkRO()
  if self.isRO then error("filesystem is read-only") end
end

function d:remove(file)
  checkArg(1, file, "string")
  self:checkRO()
  local node, parent, s = self:find(file)
  if not node then
    return nil, parent
  end
  parent[s] = nil
  return true
end

function d:makeDirectory(dir)
  checkArg(1, dir, "string")
  self:checkRO()
  local s = split(dir)
  local node, err = self:find("/" .. table.concat(s, "/", 1, #s - 1))
  if not node then
    return nil, err
  end
  if not node.isDirectory then
    return nil, "file is not a directory"
  end
  node[s[#s]] = { isDirectory = true, children = {} }
end

function d:open(file, mode)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  if not self:exists(file) and (mode == "w" or mode == "wb") then -- hack away
    self:makeDirectory(file)
    local node = self:find(file)
    node.isDirectory = false
    node.children = nil
    node.data = ""
  end
  local node, err = self:find(file)
  if not node then
    return nil, err
  end
  if mode:match("[wa]") then
    self:checkRO()
  end
  local n = #self.handles + 1
  self.handles[n] = {node = node, ptr = 1, mode = {}}
  for char in mode:gmatch(".") do
    self.handles[n].mode[char] = true
  end
  return n
end

function d:lastModified()
  return 0
end

function d:spaceTotal()
  return computer.totalMemory()
end

function d:write(h, d)
  checkArg(1, h, "number")
  checkArg(2, d, "string")
  if not self.handles[h] then
    return nil, "bad file descriptor"
  end
  self:checkRO()
  self.handles[h].node.data = self.handles[h].node.data:sub(1, self.handles[h].ptr) .. d .. self.handles[h].node.data:sub(self.handles[h].ptr + 1)
  self.handles[h].ptr = self.handles[h].ptr + #d
  return true
end

function d:setLabel(l)
  checkArg(1, l, "string")
  self.label = l:sub(1,36)
  return self.label
end

function d:close(h)
  checkArg(1, h, "number")
  if not self.handles[h] then
    return nil, "bad file descriptor"
  end
  self.handles[h] = nil
end

function d:rename(file1, file2)
  return nil, "cannot move files like that"
end

function d:list(dir)
  checkArg(1, dir, "string")
  local node, err = self:find(dir)
  if not node then
    return nil, err
  end
  local l = {}
  for k, v in pairs(node.children) do
    local n = k
    if v.isDirectory then n = n .. "/" end
    l[#l + 1] = n
  end
  return l
end

function d:getLabel()
  return self.label or nil
end

function d:seek(h, w, o)
  checkArg(1, h, "number")
  checkArg(2, w, "string", "nil")
  checkArg(3, o, "number", "nil")
  w = w or "cur"
  o = o or 0
  if not self.handles[h] then
    return nil, "bad file descriptor"
  end
  local handle = self.handles[h]
  if w == "set" then
    handle.ptr = o
  elseif w == "cur" then
    handle.ptr = handle.ptr + o
  elseif w == "end" then
    handle.ptr = #handle.node.data + o
  end
  return handle.ptr
end

function d:size(file)
  checkArg(1, file, "string")
  local node, err = self:find(file)
  if not node then
    return nil, err
  end
  if node.isDirectory then
    return 4096
  end
  return #node.data
end

function d:isDirectory(file)
  checkArg(1, file, "string")
  local node, err = self:find(file)
  if not node then
    return nil, err
  end
  return node.isDirectory
end

function d:read(h, a)
  checkArg(1, h, "number")
  checkArg(2, a, "string")
  if not self.handles[h] then
    return nil, "bad file descriptor"
  end
  if a > 2048 then a = 2048 end
  local handle = self.handles[h]
  if handle.ptr >= #handle.node.data then return nil end
  local ret = handle.data:sub(handle.ptr + a)
  handle.ptr = handle.ptr + a
  if handle.ptr > #handle.node.data then handle.ptr = #handle.node.data end
  return ret
end

function d:spaceUsed()
  return computer.totalMemory() - computer.freeMemory()
end

function d:isReadOnly()
  return self.isRO == true
end

function d:exists(file)
  checkArg(1, file, "string")
  local node, err = self:find(file)
  if node then
    return true
  end
  return false
end

local fmt = {
  __metatable = {},
  __index = function(tbl, k)
    if d[k] then
      return function(_, ...)
        return d[k](tbl, ...)
      end
    end
  end
}

function m.new(label, ro)
  checkArg(1, label, "string", "nil")
  checkArg(2, ro, "boolean", "nil")
  local nfs = {
    label = label or "",
    type = "filesystem",
    address = uuid.new(),
    isRO = ro,
    handles = {},
    nodes = {isDirectory = true, children = {}}
  }
  return setmetatable(nfs, fmt)
end

return m
