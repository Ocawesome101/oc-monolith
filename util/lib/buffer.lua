-- Thank you, Payonel, for your buffer library --

local computer = require("computer")
local unicode = require("unicode")

local buffer = {}
local metatable = {
  __index = buffer,
  __metatable = "file"
}

function buffer.new(mode, stream)
  local result = {
    closed = false,
    tty = false,
    mode = {},
    stream = stream,
    bufferRead = "",
    bufferWrite = "",
    bufferSize = math.max(512, math.min(8 * 1024, computer.freeMemory() / 8)),
    bufferMode = "full",
    readTimeout = math.huge,
  }
  mode = mode or "r"
  for i = 1, unicode.len(mode) do
    result.mode[unicode.sub(mode, i, i)] = true
  end
  -- when stream closes, result should close first
  -- when result closes, stream should close after
  -- when stream closes, it is removed from the proc
  stream.close = setmetatable({close = stream.close,parent = result},{__call = buffer.close})
  return setmetatable(result, metatable)
end

function buffer:close()
  -- self is either the buffer, or the stream.close callable
  local meta = getmetatable(self)
  if meta == metatable.__metatable then
    return self.stream:close()
  end
  local parent = self.parent

  if parent.mode.w or parent.mode.a then
    parent:flush()
  end
  parent.closed = true
  return self.close(parent.stream)
end

function buffer:flush()
  if #self.bufferWrite > 0 then
    local tmp = self.bufferWrite
    self.bufferWrite = ""
    local result, reason = self.stream:write(tmp)
    if not result then
      return nil, reason or "bad file descriptor"
    end
  end

  return self
end

function buffer:lines(...)
  local args = table.pack(...)
  return function()
    local result = table.pack(self:read(table.unpack(args, 1, args.n)))
    if not result[1] and result[2] then
      error(result[2])
    end
    return table.unpack(result, 1, result.n)
  end
end

local function readChunk(self)
  if computer.uptime() > self.timeout then
    error("timeout")
  end
  local result, reason = self.stream:read(math.max(1,self.bufferSize))
  if result then
    self.bufferRead = self.bufferRead .. result
    return self
  else -- error or eof
    return result, reason
  end
end

function buffer:readLine(chop, timeout)
  self.timeout = timeout or (computer.uptime() + self.readTimeout)
  local start = 1
  while true do
    local buf = self.bufferRead
    local i = buf:find("[\r\n]", start)
    local c = i and buf:sub(i,i)
    local is_cr = c == "\r"
    if i and (not is_cr or i < #buf) then
      local n = buf:sub(i+1,i+1)
      if is_cr and n == "\n" then
        c = c .. n
      end
      local result = buf:sub(1, i - 1) .. (chop and "" or c)
      self.bufferRead = buf:sub(i + #c)
      return result
    else
      start = #self.bufferRead - (is_cr and 1 or 0)
      local result, reason = readChunk(self)
      if not result then
        if reason then
          return result, reason
        else -- eof
          result = #self.bufferRead > 0 and self.bufferRead or nil
          self.bufferRead = ""
          return result
        end
      end
    end
  end
end

function buffer:read(...)
  if not self.mode.r then
    return nil, "read mode was not enabled for this stream"
  end

  if self.mode.w or self.mode.a then
    self:flush()
  end

  if select("#", ...) == 0 then
    return self:readLine(true)
  end
  return self:formatted_read(readChunk, ...)
end

function buffer:setvbuf(mode, size)
  mode = mode or self.bufferMode
  size = size or self.bufferSize

  assert(mode == "no" or mode == "full" or mode == "line",
    "bad argument #1 (no, full or line expected, got " .. tostring(mode) .. ")")
  assert(mode == "no" or type(size) == "number",
    "bad argument #2 (number expected, got " .. type(size) .. ")")

  self.bufferMode = mode
  self.bufferSize = size

  return self.bufferMode, self.bufferSize
end

function buffer:write(...)
  if self.closed then
    return nil, "bad file descriptor"
  end
  if not self.mode.w and not self.mode.a then
    return nil, "write mode was not enabled for this stream"
  end
  local args = table.pack(...)
  for i = 1, args.n do
    if type(args[i]) == "number" then
      args[i] = tostring(args[i])
    end
    checkArg(i, args[i], "string")
  end

  for i = 1, args.n do
    local arg = args[i]
    local result, reason

    if self.bufferMode == "no" then
      result, reason = self.stream:write(arg)
    else
      result, reason = self:buffered_write(arg)
    end

    if not result then
      return nil, reason
    end
  end

  return self
end

-- Instead of package.delay I've just copied /lib/core/full_buffer.lua here. Or, well, all except the top 2 lines.

function buffer:getTimeout()
  return self.readTimeout
end

function buffer:setTimeout(value)
  self.readTimeout = tonumber(value)
end

function buffer:seek(whence, offset)
  whence = tostring(whence or "cur")
  assert(whence == "set" or whence == "cur" or whence == "end",
    "bad argument #1 (set, cur or end expected, got " .. whence .. ")")
  offset = offset or 0
  checkArg(2, offset, "number")
  assert(math.floor(offset) == offset, "bad argument #2 (not an integer)")

  if self.mode.w or self.mode.a then
    self:flush()
  elseif whence == "cur" then
    offset = offset - #self.bufferRead
  end
  local result, reason = self.stream:seek(whence, offset)
  if result then
    self.bufferRead = ""
    return result
  else
    return nil, reason
  end
end

function buffer:buffered_write(arg)
  local result, reason
  if self.bufferMode == "full" then
    if self.bufferSize - #self.bufferWrite < #arg then
      result, reason = self:flush()
      if not result then
        return nil, reason
      end
    end
    if #arg > self.bufferSize then
      result, reason = self.stream:write(arg)
    else
      self.bufferWrite = self.bufferWrite .. arg
      result = self
    end
  else--if self.bufferMode == "line" then
    local l
    repeat
      local idx = arg:find("\n", (l or 0) + 1, true)
      if idx then
        l = idx
      end
    until not idx
    if l or #arg > self.bufferSize then
      result, reason = self:flush()
      if not result then
        return nil, reason
      end
    end
    if l then
      result, reason = self.stream:write(arg:sub(1, l))
      if not result then
        return nil, reason
      end
      arg = arg:sub(l + 1)
    end
    if #arg > self.bufferSize then
      result, reason = self.stream:write(arg)
    else
      self.bufferWrite = self.bufferWrite .. arg
      result = self
    end
  end
  return result, reason
end

----------------------------------------------------------------------------------------------

function buffer:readNumber(readChunk)
  local len, sub
  if self.mode.b then
    len = rawlen
    sub = string.sub
  else
    len = unicode.len
    sub = unicode.sub
  end

  local number_text = ""
  local white_done

  local function peek()
    if len(self.bufferRead) == 0 then
      local result, reason = readChunk(self)
      if not result then
        return result, reason
      end
    end
    return sub(self.bufferRead, 1, 1)
  end

  local function pop()
    local n = sub(self.bufferRead, 1, 1)
    self.bufferRead = sub(self.bufferRead, 2)
    return n
  end

  while true do
    local peeked = peek()
    if not peeked then
      break
    end

    if peeked:match("[%s]") then
      if white_done then
        break
      end
      pop()
    else
      white_done = true
      if not tonumber(number_text .. peeked .. "0") then
        break
      end
      number_text = number_text .. pop() -- add pop to number_text
    end
  end

  return tonumber(number_text)
end

function buffer:readBytesOrChars(readChunk, n)
  n = math.max(n, 0)
  local len, sub
  if self.mode.b then
    len = rawlen
    sub = string.sub
  else
    len = unicode.len
    sub = unicode.sub
  end
  local data = ""
  while len(data) ~= n do
    if len(self.bufferRead) == 0 then
      local result, reason = readChunk(self)
      if not result then
        if reason then
          return result, reason
        else -- eof
          return #data > 0 and data or nil
        end
      end
    end
    local left = n - len(data)
    data = data .. sub(self.bufferRead, 1, left)
    self.bufferRead = sub(self.bufferRead, left + 1)
  end
  return data
end

function buffer:readAll(readChunk)
  repeat
    local result, reason = readChunk(self)
    if not result and reason then
      return result, reason
    end
  until not result -- eof
  local result = self.bufferRead
  self.bufferRead = ""
  return result
end

function buffer:formatted_read(readChunk, ...)
  self.timeout = require("computer").uptime() + self.readTimeout
  local function read(n, format)
    if type(format) == "number" then
      return self:readBytesOrChars(readChunk, format)
    else
      local first_char_index = 1
      if type(format) ~= "string" then
        error("bad argument #" .. n .. " (invalid option)")
      elseif unicode.sub(format, 1, 1) == "*"  then
        first_char_index = 2
      end
      format = unicode.sub(format, first_char_index, first_char_index)
      if format == "n" then
        return self:readNumber(readChunk)
      elseif format == "l" then
        return self:readLine(true, self.timeout)
      elseif format == "L" then
        return self:readLine(false, self.timeout)
      elseif format == "a" then
        return self:readAll(readChunk)
      else
        error("bad argument #" .. n .. " (invalid format)")
      end
    end
  end

  local results = {}
  local formats = table.pack(...)
  for i = 1, formats.n do
    local result, reason = read(i, formats[i])
    if result then
      results[i] = result
    elseif reason then
      return nil, reason
    end
  end
  return table.unpack(results, 1, formats.n)
end

function buffer:size()
  local len = self.mode.b and rawlen or unicode.len
  local size = len(self.bufferRead)
  if self.stream.size then
    size = size + self.stream:size()
  end
  return size
end

return buffer
