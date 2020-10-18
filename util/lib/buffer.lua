-- smol buffer library --

local buffer = {}
local computer = require("computer")

function buffer.new(mode, stream)
  local new = {
    tty = false,
    mode = {},
    rbuf = "",
    wbuf = "",
    stream = stream,
    closed = false,
    bufsize = math.max(512, math.min(8 * 1024, computer.freeMemory() / 8))
  }
  for c in mode:gmatch(".") do
    new.mode[c] = true
  end
  local ts = tostring(new):gsub("table", "FILE")
  return setmetatable(new, {
    __index = buffer,
    __tostring = function()
      return ts
    end,
    __metatable = {}
  })
end

-- this might be inefficient but it's still much better than raw file handles!
function buffer:read_byte()
  if self.bufsize == 0 then
    return self.stream:read(1)
  end
  if #self.rbuf <= 0 then
    self.rbuf = self.stream:read(self.bufsize) or ""
  end
  local read = self.rbuf:sub(1,1)
  --require("component").sandbox.log(self.bufsize, read, self.rbuf, #self.rbuf)
  self.rbuf = self.rbuf:sub(2)
  return read
end

function buffer:write_byte(byte)
  checkArg(1, byte, "string")
  byte = byte:sub(1,1)
  if #self.wbuf >= self.bufsize then
    self.stream:write(self.wbuf)
    self.wbuf = ""
  end
  self.wbuf = self.wbuf .. byte
end

function buffer:read(fmt)
  checkArg(1, fmt, "string", "number", "nil")
  fmt = fmt or "l"
  if type(fmt) == "number" then
    local ret = ""
    if self.bufsize == 0 then
      ret = self.stream:read(fmt)
    else
      for i=1, fmt, 1 do
        ret = ret .. (self:read_byte() or "")
      end
    end
    return ret, self
  else
    fmt = fmt:gsub("%*", "")
    fmt = fmt:sub(1,1)
    -- TODO: support more formats
    if fmt == "l" or fmt == "L" then
      local ret = ""
      repeat
        local byte = self:read_byte()
        if byte == "\n" then
          ret = ret .. (fmt == "L" and byte or "")
        else
          ret = ret .. (byte or "")
        end
      until byte == "\n" or #byte == 0 or not byte
      return ret, self
    elseif fmt == "a" then
      local ret, rf = "", function()return self:read_byte()end
      if self.bufsize == 0 then
        rf = function()return self.stream:read(math.huge)end
      end
      repeat
        local chunk = rf()
        ret = ret .. (chunk or "")
      until #chunk == 0 or not chunk
      return ret, self
    else
      error("bad argument #1 to 'read' (invalid format)")
    end
  end
end

function buffer:lines(fmt)
  return function()
    local result = table.pack(self:read(fmt))
    return table.unpack(result, 1, result.n)
  end
end

function buffer:write(...)
  local args = table.pack(...)
  for i=1, args.n, 1 do
    args[i] = tostring(args[i])
  end
  local write = table.concat(args)
  if self.bufsize == 0 then
    self.stream:write(write)
  else
    for byte in write:gmatch(".") do
      self:write_byte(byte)
    end
  end
  return self
end

function buffer:seek(whence, offset)
  checkArg(1, whence, "string", "nil")
  checkArg(2, offset, "number", "nil")
  if whence then
    self:flush()
    return self.stream:seek(whence, offset)
  end
  if self.mode.r then
    return self.stream:seek() + #self.rbuf
  elseif self.mode.w or self.mode.a then
    return self.stream:seek() + #self.wbuf
  end
  return 0, self
end

function buffer:flush()
  if self.mode.w then
    self.stream:write(self.wbuf)
  end
  return true, self
end

function buffer:setvbuf(mode)
  if mode == "no" then
    self.bufsize = 0
  else
    self.bufsize = 512
  end
end

function buffer:close()
  self:flush()
  self.closed = true
  return true
end

return buffer
