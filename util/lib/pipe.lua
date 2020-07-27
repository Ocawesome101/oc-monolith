-- pipes???? :O --

local pipe = {}

local thread = require("thread")

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
      table.concat(prog, " "),          --name
      handler                           --handler
    ))
  end
  io.input(orig_io.input)
  io.output(orig_io.output)
  return pids
end

package.delay(pipe, "/lib/full/pipe.lua")

return pipe
