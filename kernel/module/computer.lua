-- computer.shutdown stuff --

do
  local shutdown = computer.shutdown
  local closeAll = kernel.filesystem.closeAll
  kernel.filesystem.closeAll = nil
  function computer.shutdown(reboot)
    checkArg(1, reboot, "boolean")
    local running = kernel.thread.threads()
    for i=1, #running, 1 do
      kernel.thread.signal(running[i], kernel.thread.signals.term)
    end
    coroutine.yield()
    for i=1, #running, 1 do
      kernel.thread.signal(running[i], kernel.thread.signals.kill)
    end
    coroutine.yield()
    closeAll()
    shutdown(reboot)
  end
end
