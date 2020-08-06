-- component API metatable allowing component.filesystem, and component.get --

do
  function component.get(addr)
    checkArg(1, addr, "string")
    for ca, ct in component.list() do
      if ca:sub(1, #addr) == addr then
        return ca, ct
      end
    end
    return nil, "no such compoennt"
  end

  function component.isAvailable(name)
    checkArg(1, name, "string")
    local ok, comp = pcall(function()return component[name] end)
    return ok
  end

  local mt = {
    __index = function(tbl, k)
      local addr = component.list(k, true)()
      if not addr then
        error("component of type '" .. k .. "' not found")
      end
      tbl[k] = component.proxy(addr)
      return tbl[k]
    end
  }

  setmetatable(component, mt)
end
