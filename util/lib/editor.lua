-- common editor functions --

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
  for line in handle:lines() do
    lines[#lines + 1] = line:gsub("\n", "") .. "\n"
  end
  handle:close()
  self.lines = lines
  return true
end

function ed.buffer:save(file)
  checkArg(1, file, "string", "nil")
  if not self.name or self.name = "" then
    checkArg(1, file, "string")
  end
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

local function drawline(y, n, l)
  if l then
    return io.write(string.format("\27[%d;1H\27[31m%4d\27[37m %s", y, n, l))
  else
    return io.write(string.format("\27[%d;1H\27[33m~   \27[37m"))
  end
end

function ed.buffer:draw()
  local w, h = ed.getScreenSize()
  local y = 1
  for i=1+self.scroll.h, 1+self.scroll.h+h, 1 do
    local line = self.lines[i] or nil
    local n = drawline(y, i, (self.highlighter or function(e)return e end)(line:sub(1, w + self.scroll.w)))
    y=y+n
    if y >= h then
      break
    end
  end
end

function ed.getScreenSize()
  io.write("\27[999;999H\27[6n")
  local resp = ""
  repeat
    local c = io.read(1)
    resp = resp .. c
  until c == "R"
  local h, w = resp:match("\27%[(%d+);(%d+)R")
  h, w = tonumber(h), tonumber(w)
  return w or 50, h or 16
end

function ed.new(file)
  checkArg(1, file, "string")
  local new = setmetatable({
    name = file,
    lines = {},
    x = 1,
    y = 1,
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
