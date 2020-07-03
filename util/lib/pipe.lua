-- pipes???? :O --

local pipe = {}

local thread = require("thread")

local streamA = {
  read = function(self, len)
    checkArg(1, len, "number")
    if self.closedA or self.closedB then
      error("broken pipe")
    end
    if len > 2048 then len = 2048 end
    local ret = self.bufA:sub(1, len)
    self.bufA = self.bufA:sub(len + 1)
    return ret
  end,
  write = function(self, data)
    checkArg(1, data, "string")
    if self.closedA or self.closedB then
      error("broken pipe")
    end
    self.bufB = self.bufB .. data
    return true
  end,
  close = function(self)
    self.closedA = true
  end
}

local streamB = {
  read = function(self, len)
    checkArg(1, len, "number")
    if self.closedA or self.closedB then
      error("broken pipe")
    end
    if len > 2048 then len = 2048 end
    local ret = self.bufB:sub(1, len)
    self.bufB = self.bufB:sub(len + 1)
    return ret
  end,
  write = function(self, data)
    checkArg(1, data, "string")
    if self.closedA or self.closedB then
      error("broken pipe")
    end
    self.bufA = self.bufA .. data
    return true
  end,
  close = function(self)
    self.closedB = true
  end
}

function pipe.new()
  tbl = { bufA = "", bufB = "" }
  return setmetatable(tbl, {__index = streamA}), setmetatable(tbl, {__index = streamB})
end

function pipe.popen(prog, mode, env)
  checkArg(1, prog, "string")
  checkArg(2, mode, "string", "nil")
  mode = mode or "rw"
  prog = require("text").split(prog, " ")
  prog[1] = "/bin/" .. prog[1] .. ".lua"
  local ok, err = loadfile(prog[1])
  if not ok then
    return nil, err
  end
  local input, output = pipe.new()
  local mode = {}
  for m in mode:gmatch(".") do mode[m] = true end
  local orig_io = {i = io.input(), o = io.output()}
  if mode.r then io.output(output) end
  if mode.w then io.input(input) end
  thread.spawn(function()return ok(table.unpack(prog,2))end, prog[1], nil, env)
  io.input(orig_io.i)
  io.output(orig_io.o)
  return input
end

local streamX = {
  read = function(self, len)
    checkArg(1, len, "number")
    if self.closed or self.whatIO.closed then
      error("broken pipe")
    end
    if self.what then
      return self.whatIO:read(len)
    end
    while #self.buf[self.i] < len and not self.buf[self.i]:find("\0") do
      coroutine.yield()
    end
    local ret = self.buf[self.i]:sub(1, len)
    self.buf[self.i] = self.buf[self.i]:sub(len + 1)
    return ret
  end,
  write = function(self, data)
    checkArg(1, data, "string")
    if self.closed or self.whatIO.closed then
      error("broken pipe")
    end
    if self.what then
      self.buf[self.i] = self.buf[self.i] .. data
    end
    return self.whatIO:write(data)
  end,
  close = function(self)
    self.closed = true
  end
}

-- e.g. A | B | C | ... | Z
function pipe.chain(progs)
  checkArg(1, progs, "table")
  local buffers = {}
  local last
  local pids = {}
  local orig_io = { input = io.input(), output = io.output() }
  for i=1, #progs, 1 do
    buffers[i] = ""
    local new = setmetatable({
      buf = buffers,
      i = i,
      whatIO = i % 2 == 0 and last or orig_io.input,
      what = i % 2 == 0
    }, {
      __index = streamX
    })
    local prog = (type(progs[i]) == "string" and require("text").split(progs[i], " ")) or progs[i]
    if #prog == 0 then return nil, "invalid program length " .. #prog .. " for " .. type(progs[i]) .. " entry " .. i end
    local ok, err = loadfile(prog[1])
    if not ok then return nil, err end
    local function handler(...)
      orig_io.output:write("\27[31m", ..., "\27[37m")
    end
    io.input ((i > 1 and last) or orig_io.input)
    io.output((i < #progs and new) or orig_io.output)
    table.insert(pids, thread.spawn(
      function()
        return ok(
          table.unpack(prog, 2, #prog)
        )
      end,
      prog[1],                          --name
      handler                           --handler
    ))
  end
  io.input(orig_io.input)
  io.output(orig_io.output)
  return pids
end

return pipe
