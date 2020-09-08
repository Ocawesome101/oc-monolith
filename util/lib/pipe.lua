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

-- e.g. A | B | C | ... | Z
function pipe.chain(progs)
  checkArg(1, progs, "table")
  local last
  local pids = {}
  local orig_io = { input = io.input(), output = io.output(), stderr = io.stderr }
  for i=1, #progs, 1 do
    local bnew = setmetatable({
      buf = ""
    }, {
      __index = streamX
    })
    local new = buffer.new("w", bnew)
    new:setvbuf("no")
    local prog = (type(progs[i]) == "string" and require("text").tokenize(progs[i])) or progs[i]
    if #prog == 0 then return nil, "invalid program length " .. #prog .. " for " .. type(progs[i]) .. " entry " .. i end
    local ok, err = loadfile(prog[1])
    if not ok then return nil, err end
    local function handler(...)
      orig_io.stderr:write(table.concat(table.pack("\27[31m", ..., "\27[37m\n")))
    end
    local l, n = last, new
    table.insert(pids, thread.spawn(
      function()
        --print("A", i, l, n, orig_io.input, orig_io.output, "B")
        io.input ((i > 1 and l) or orig_io.input)
        io.output((i < #progs and n) or orig_io.output)
        local eh, x = xpcall(ok,
          debug.traceback,
          table.unpack(prog, 2, #prog)
        )
        if n then n:close() end
        --[[if eh and x and x ~= 0 and type(x) == "number" then
          require("shell").error(prog[1]:match(".+/(.-)%.lua"), require("shell").errors[x])
        end]]
        if not eh and x then
          handler(x)
        end
      end,
      table.concat(prog, " "),          --name
      handler                           --handler
    ))
    last = buffer.new("r", bnew)
    last:setvbuf("no")
  end
  io.input(orig_io.input)
  io.output(orig_io.output)
  return pids
end

package.delay(pipe, "/lib/full/pipe.lua")

return pipe
