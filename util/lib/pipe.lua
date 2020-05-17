-- pipes! --

local stream = require("stream")
local uuid = require("uuid")

local pipe = {}

local dummy = {In = {}, Out = {}}

function dummy.In:write(data)
  checkArg(1, data, "string")
  if not self.availOut then
    error("broken pipe")
  end
  self.bufferOut = self.bufferOut .. data
  return true
end

function dummy.In:read(n)
  checkArg(1, n, "number", "nil")
  if not self.availIn then
    error("broken pipe")
  end
  while (n and #self.bufferIn < n) do
    coroutine.yield()
    if not self.availIn then
      error("broken pipe")
    end
  end
  local ret = self.bufferIn:sub(1, n)
  self.bufferIn = self.bufferIn:sub(n + 1)
  return ret
end

function dummy.In:close()
  self.availIn = false
end

function dummy.Out:write(data)
  checkArg(1, data, "string")
  if not self.availIn then
    error("broken pipe")
  end
  self.bufferIn = self.bufferIn .. data
end

function dummy.Out:read(n)
  checkArg(1, n, "number", "nil")
  if not self.availOut then
    error("broken pipe")
  end
  while (n and #self.bufferOut < n) do
    coroutine.yield()
    if not self.availOut then
      error("broken pipe")
    end
  end
  local ret = self.bufferOut:sub(1, n)
  self.bufferOut = self.bufferOut:sub(n + 1)
  return ret
end

function dummy.Out:close()
  self.availOut = false
end

function pipe.create()
  local tmp = {
    bufferIn = "",
    bufferOut = "",
    availIn = true,
    availOut = true
  }
  local new = {
    input = setmetatable(tmp, {__index = dummy.In}),
    output = setmetatable(tmp, {__index = dummy.Out})
  }
  return new
end

return pipe
