-- fancy-ish init bootlogger - certainly fancier than the kernel --

local logger = {}
do
  local klog = kernel.logger
  local shown = true
  function logger.setShown(s)
    shown = s
  end

  local stats = {
    OK = 0x00FF00,
    WAIT = 0xFFCC00,
    FAIL = 0xFF0000
  }
  if not klog.gpu then
    logger.log = klog.log
  else
    klog.y = klog.y + 1
    local w, h = klog.gpu.getResolution()
    local function pad(s)
      local p = (' '):rep((8 - #s) / 2)
      return p .. s .. p
    end
    local function log(status, msg)
      local padded = pad(status)
      klog.logwrite("[" .. padded .. "] " .. msg .. "\n")
      if not shown then return end
      klog.gpu.set(1, klog.y, "[")
      if stats[status] then
        klog.gpu.setForeground(stats[status])
      end
      klog.gpu.set(2, klog.y, padded)
      klog.gpu.setForeground(0xDDDDDD)
      klog.gpu.set(10, klog.y, "] " .. msg)
      if klog.y > h then
        klog.gpu.copy(1,1,w,h,0,-1)
        klog.gpu.fill(1,h,w,1," ")
        klog.y = h
      else
        klog.y = klog.y + 1
      end
    end
    function logger.log(status, ...)
      local msg = table.concat({...}, " ")
      for line in msg:gmatch("[^\n]+") do
        log(status, line)
      end
    end
  end
end

logger.log("OK", "Initialized init logger")
