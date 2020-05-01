-- false file streams --

local buffer = require("buffer")

local stream = {}

function stream.new(read, write, close)
  checkArg(1, read, "function")
  checkArg(2, write, "function")
  checkArg(3, close, "function")

  local new = {
    closed = false
  }

  function new:read(...)
    if self.closed then
      return nil, "cannot read from closed stream"
    end
    return read(...)
  end

  function new:write(...)
    if self.closed then
      return nil, "cannot write to closed stream"
    end
    return write(...)
  end

  function new:close()
    self.closed = true
    return close()
  end

  return new

  --local buf = buffer.new("rw", new)

  --buf:setvbuf("no")
  --return buf
end

function stream.dummy()
  local rbuf = ""
  local wbuf = ""

  local function rread(n)
    checkArg(1, n, "number", "nil")
    if n then
      while #rbuf < n do
        coroutine.yield()
      end
      local r = rbuf:sub(1, n)
      rbuf = rbuf:sub(n + 1)
      return r
    else
      while not rbuf:find("\n") do
        coroutine.yield()
      end
      n = rbuf:find("\n")
      local r = rbuf:sub(1, n)
      rbuf = rbuf:sub(n + 1)
      return r
    end
  end

  local function rwrite(s)
    checkArg(1, s, "string")
    wbuf = wbuf .. s
  end

  local function wread(n)
    checkArg(1, n, "number", "nil")
    if n then
      while #wbuf < n do
        coroutine.yield()
      end
      local r = wbuf:sub(1, n)
      wbuf = wbuf:sub(n + 1)
      return r
    else
      while not wbuf:find("\n") do
        coroutine.yield()
      end
      n = wbuf:find("\n")
      local r = wbuf:sub(1, n)
      wbuf = wbuf:sub(n + 1)
      return r
    end
  end

  local function wwrite(s)
    checkArg(1, s, "string")
    rbuf = rbuf .. s
  end

  return stream.new(rread, rwrite, function()end), stream.new(wread, wwrite, function()end)
end

return stream
