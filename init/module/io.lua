-- `io` library --

do
  dofile("/lib/init/io.lua")

  function loadfile(file, mode, env)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
    checkArg(3, env, "table", "nil")
    mode = mode or "bt"
    env = env or _G
    local handle, err = io.open(file, "r")
    if not handle then
      return nil, err
    end
    local data = handle:read("*a")
    handle:close()
    return load(data, "="..file, mode, env)
  end
end
