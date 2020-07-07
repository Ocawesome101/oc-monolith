-- fancy-ish init bootlogger - certainly fancier than the kernel --

local logger = {}
do
  local klog = kernel.logger.log
  local stats = {
    ok = 0x00FF00,
    wait = 0xFFCC00,
    err = 0xFF0000
  }
  function logger.log(status, ...)
    
  end
  function logger.up()
  end
end
