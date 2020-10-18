-- common editor functions --

local vt = require("vt")
local ed = {}
ed.buffers = {}
ed.buffer = {}

function ed.buffer:load(file)
  checkArg(1, file, "string")
  local handle, err = io.open(file, "r")
  if not handle then
    return nil, err
  end
  local lines = {}
  for line in handle:lines("l") do
    lines[#lines + 1] = line:gsub("\n", "") .. "\n"
  end
  handle:close()
  self.lines = lines
  return true
end

function ed.buffer:save(file)
  checkArg(1, file, "string", "nil")
  if not self.name or self.name == "" then
    checkArg(1, file, "string")
  end
  file = file or self.name
  local handle, err = io.open(file, "w")
  if not handle then
    return nil, err
  end
  for i, line in ipairs(self.lines) do
    handle:write(line)
  end
  handle:close()
  return true
end

local function drawline(y, n, l, L)
  l = l or ""
  n = (n and tostring(n)) or "\27[94m~"
  local nl = tostring(L):len()
  local out = string.format("\27[%d;1H\27[93m%"..nl.."s\27[37m %s", y, n, l)
  out = out .. (" "):rep((vt.getResolution()))
  io.write(out)
end

function ed.buffer:draw(num)
  local w, h = vt.getResolution()
  if num == false then num = false else num = true end
  local y = 1
  io.write("\27[9m\27[1H\27[K")
  for i=1+self.scroll.h, 1+self.scroll.h+h, 1 do
    local line = self.lines[i] or ""
    local n = drawline(y, (self.lines[i] and (num and i or "")) or nil, (self.highlighter or function(e)return e end)(line:sub(1, w + self.scroll.w)), #self.lines)
    y=y+1
    if y >= h - 1 then
      break
    end
  end
  io.write("\27[29m")
end

function ed.new(file)
  checkArg(1, file, "string", "nil")
  if file then
    -- try to prevent opening multiple buffers containing the same file
    for n, buf in pairs(ed.buffers) do
      if buf.name == file then
        return n
      end
    end
  end
  local new = setmetatable({
    name = file,
    lines = {""},
    scroll = {
      w = 0,
      h = 0
    }
  }, {__index=ed.buffer})
  if file then
    new:load(file)
  end
  local n = #ed.buffers + 1
  ed.buffers[n] = new
  return n
end

return ed
