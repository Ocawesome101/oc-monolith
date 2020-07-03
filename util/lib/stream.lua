-- false file streams --

local buffer = require("buffer")

local stream = {}

function stream.new(read, write, close, fields)
  checkArg(1, read, "function")
  checkArg(2, write, "function")
  checkArg(3, close, "function")
  checkArg(4, fields, "table", "nil")

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

  if fields then
    for k, v in pairs(fields) do
      new[k] = v
    end
  end
  new.stream = new

  return new

  --local buf = buffer.new("rw", new)

  --buf:setvbuf("no")
  --return buf
end

return stream
