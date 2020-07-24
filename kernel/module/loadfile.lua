-- basic loadfile function --

kernel.logger.log("initializing loadfile")

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
  local data = ""
  repeat
    local chunk = handle:read(math.huge)
    data = data .. (chunk or "")
  until not chunk
  handle:close()
  if data:sub(1,1) == "#" then -- crude shebang detection
    data = "--" .. data
  end
  return load(data, "=" .. file, mode, env)
end

sandbox.loadfile = loadfile

kernel.logger.log("loadfile done")
