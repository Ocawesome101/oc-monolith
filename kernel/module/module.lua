-- kernel modules-ish --

do
  kernel.logger.log("dkms: initializing dynamic kernel module service")
  local m = {}
  local l = {}
  kernel.modules = l
  setmetatable(kernel, {__index = l})

  function m.load(mod)
    checkArg(1, mod, "string")
    if kernel.users.uid() ~= 0 then
      return nil, "permission denied"
    end
    kernel.logger.log("dkms: loading module: " .. mod)
    local handle, err = kernel.filesystem.open("/lib/modules/" .. mod .. ".lua", "r")
    if not handle then
      return nil, err
    end
    local read = handle:read("*a")
    handle:close()
    local ok, err = load(read, "=" .. mod, "bt", _G)
    if not ok then
      return nil, err
    end
    l[mod] = ok()
    return true
  end

  function m.unload(mod)
    checkArg(1, mod, "string")
    if kernel.users.uid() ~= 0 then
      return nil, "permission denied"
    end
    kernel.logger.log("dkms: unloading module: " .. mod)
    l[mod] = nil
    return true
  end

  kernel.module = m

  kernel.logger.log("dkms: done")
end
