-- pipes???? :O --

local pipe = {}

local thread = require("thread")
local buffer = require("buffer")

local streamX = {
  read = function(self, len)
    checkArg(1, len, "number", "nil")
    if self.closed and #self.buf == 0 then
      return nil
    end
    while not len and not self.buf:find("\n") and not self.closed do
      coroutine.yield()
    end
    len = len or self.buf:find("\n") or #self.buf
    local ret = self.buf:sub(1, len)
    self.buf = self.buf:sub(len + 1)
    if ret == "" then ret = nil end
    return ret
  end,
  write = function(self, data)
    checkArg(1, data, "string")
    if self.closed then
      return nil, "broken pipe"
    end
    self.buf = self.buf .. data
    return true
  end,
  close = function(self)
    self.closed = true
  end
}

function pipe.create()
  local bnew = setmetatable({
    buf = ""
  }, {
    __index = streamX
  })
  local new = buffer.new("w", bnew)
  new:setvbuf("no")
  return new
end

package.delay(pipe, "/lib/full/pipe.lua")

return pipe
