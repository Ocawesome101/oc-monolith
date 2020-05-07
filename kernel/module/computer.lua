-- computer.shutdown stuff --

do
  --local log = component.sandbox.log
  local shutdown = computer.shutdown
  local closeAll = kernel.filesystem.closeAll
  kernel.filesystem.closeAll = nil
  function computer.shutdown(reboot)
    checkArg(1, reboot, "boolean", "nil")
    local running = kernel.thread.threads()
    computer.pushSignal("shutdown")
    --log("shutdown")
    coroutine.yield()
    for i=1, #running, 1 do
      kernel.thread.signal(running[i], kernel.thread.signals.term)
    end
    coroutine.yield()
    --log("close all file handles")
    closeAll()
    -- clear all GPUs
    --log("clear all the screens")
    for addr, _ in component.list("gpu") do
      local w, h = component.invoke(addr, "getResolution")
      component.invoke(addr, "fill", 1, 1, w, h, " ")
    end
    --log("shut down")
    shutdown(reboot)
  end
end
