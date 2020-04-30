-- kernel modules-ish --

do
  kernel.logger.log("initializing kernel module service")
  local m = {}
  local l = {}
  setmetatable(kernel, {__index = l})

  function m.load(mod)
    checkArg(1, mod, "string")
    if kernel.users.uid() ~= 0 then
      return nil, "permission denied"
    end
    local ok, err = ifs.read(mod)
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
    l[mod] = nil
    return true
  end

  kernel.module = m
end
