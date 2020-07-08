-- os --

do
  log("INFO", "Finalizing 'os' API")

  local computer = computer or require("computer")

  function os.sleep(t)
    checkArg(1, t, "number", "nil")
    t = t or 0
    local m = computer.uptime() + t
    repeat
      coroutine.yield(m - computer.uptime())
    until computer.uptime() >= m
    return true
  end

  -- we define os.getenv and os.setenv here now, rather than in kernel/module/thread
  function os.getenv(k)
    checkArg(1, k, "string", "number")
    if k then
      return assert((kernel.thread or require("thread")).info()).data.env[k] or nil
    else -- return a copy of the env
      local e = {}
      for k, v in pairs((kernel.thread or require("thread")).info().data.env) do
        e[k] = v
      end
      return e
    end
  end

  function os.setenv(k,v)
    checkArg(1, k, "string", "number")
    checkArg(2, v, "string", "number", "nil")
    ; -- god dammit Lua
    (kernel.thread or require("thread")).info().data.env[k] = v
  end

  local filesystem = require("filesystem")

  os.remove = filesystem.remove
  os.rename = filesystem.rename

  os.execute = function(command)
    local shell = require("shell")
    if not command then
      return type(shell) == "table"
    end
    return shell.execute(command)
  end

  function os.tmpname()
    local path = os.getenv("TMPDIR") or "/tmp"
    if filesystem.exists(path) then
      for _ = 1, 10 do
        local name = filesystem.concat(path, tostring(math.random(1, 0x7FFFFFFF)))
        if not filesystem.exists(name) then
          return name
        end
      end
    end
  end

  kernel.logger.y = kernel.logger.y - 1
  log("OK", "Finalized 'os' API ")
end
