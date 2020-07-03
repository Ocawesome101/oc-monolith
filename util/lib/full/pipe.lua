local pipe = require("pipe")

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
