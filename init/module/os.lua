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
end
