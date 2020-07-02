-- os --

do
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
    --checkArg(1, k, "string", "number")
    --checkArg(2, v, "string", "number", "nil")
    (kernel.thread or require("thread")).info().data.env[k] = v
  end
end
