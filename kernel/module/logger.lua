-- bootlogger --

kernel.logger = {}
kernel.logger.log = function()end

do
  local y, w, h = 0
  local gpu = component.list("gpu")()
  local screen = component.list("screen")()
  if gpu and screen then
    gpu = component.proxy(gpu)
    gpu.bind(screen)
    w, h = gpu.maxResolution()
    gpu.setResolution(w, h)
    gpu.fill(1, 1, w, h, " ")
    function kernel.logger.log(msg)
      msg = string.format("[%3.3f] %s", computer.uptime() - _START, tostring(msg))
      if y == h then
        gpu.copy(1, 2, w, h, 0, -1)
        gpu.fill(1, h, w, 1, " ")
      else
        y = y + 1
      end
      gpu.set(1, y, msg)
    end
  end
end

kernel.logger.log(_OSVERSION)

function kernel.logger.panic(reason)
  reason = tostring(reason)
  kernel.logger.log("==== Crash ".. os.date() .." ====")
  local trace = debug.traceback(reason):gsub("\t", "  ")
  for line in trace:gmatch("[^\n]+") do
    kernel.logger.log(line)
  end
  kernel.logger.log("=========== End trace ===========")
  while true do computer.pullSignal(1) computer.beep(200, 1) end
end
