-- component API metatable allowing component.filesystem and things --
-- the kernel implements this but metatables aren't copied to the sandbox currently so we redo it here --

do
  log("WAIT", "Set up components")
  local component = require("component")
  local overrides = {
    gpu = function()return io.stdout.gpu end
  }
  local mt = {
    __index = function(tbl, k)
      if overrides[k] then
        return overrides[k]()
      end
      local addr = component.list(k, true)()
      if not addr then
        error("component of type '" .. k .. "' not found")
      end
      tbl[k] = component.proxy(addr)
      return tbl[k]
    end
  }

  setmetatable(component, mt)
  kernel.logger.y = kernel.logger.y - 1
  log("OK", "Set up components")
end
