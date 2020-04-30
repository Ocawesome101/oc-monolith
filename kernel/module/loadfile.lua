-- basic loadfile function --

local function loadfile(file, mode, env)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  checkArg(3, env, "table", "nil")
  mode = mode or "bt"
  env = env or sandbox
  local handle, err = kernel.filesystem.open(file, "r")
  if not handle then
    return nil, err
  end
  local data = handle:read("*a")
  handle:close()
  return load(data, "=" .. file, mode, env)
end

sandbox.loadfile = loadfile
