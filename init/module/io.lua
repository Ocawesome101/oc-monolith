-- `io` library --

do
  _G.io = {}
  package.loaded.io = io

  local buffer = require("buffer")
  local fs = require("filesystem")
  local thread = require("thread")

  setmetatable(io, {__index = function(tbl, k)
    if k == "stdin" then
      return thread.info().data.io[0]
    elseif k == "stdout" then
      return thread.info().data.io[1]
    elseif k == "stderr" then
      return thread.info().data.io[2] or thread.info().data.io[1]
    end
  end})

  function io.open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
    if file == "-" then -- support opening stdio in a fashion similar to *nix
      return buffer.new(mode, ((mode == "r" or mode == "a") and io.stdin) or (mode == "w" and io.stdout))
    end
    file = fs.canonical(file)
    mode = mode or "r"
    local handle, err = fs.open(file, mode)
    if not handle then
      return nil, err
    end
    return buffer.new(mode, handle)
  end

  function io.popen(...)
    return require("pipe").popen(...)
  end

  function io.output(file)
    checkArg(1, file, "string", "table", "nil")
    if type(file) == "string" then
      file = io.open(file, "w")
    end
    if file then
      thread.info().data.io[1] = file
    end
    return thread.info().data.io[1]
  end

  function io.input(file)
    checkArg(1, file, "string", "table", "nil")
    if type(file) == "string" then
      file = io.open(file, "r")
    end
    if file then
      thread.info().data.io[0] = file
    end
    return thread.info().data.io[0]
  end

  function io.error(file)
    checkArg(1, file, "string", "table", "nil")
    if type(file) == "string" then
      file = io.open(file, "r")
    end
    if file then
      thread.info().data.io[2] = file
    end
    return thread.info().data.io[2] or thread.info().data.io[1]
  end

  function io.lines(file, ...)
    checkArg(1, file, "string", "table", "nil")
    if file then
      local err
      if type(file) == "string" then
        file, err = io.open(file)
      end
      if not file then return nil, err end
      return file:lines()
    end
    return io.input():lines()
  end

  function io.close(file)
    checkArg(1, file, "table", "nil")
    if file then
      return file:close()
    end
    return nil, "cannot close standard file"
  end

  function io.flush(file)
    checkArg(1, file, "table", "nil")
    file = file or io.output()
    return file:flush()
  end

  function io.type(file)
    checkArg(1, file, "table")
    if file.closed then
      return "closed file"
    elseif (file.read or file.write) and file.close then
      return "file"
    end
    return nil
  end

  function io.read(...)
    return io.input():read(...)
  end

  function io.write(...)
    return io.output():write(...)
  end

  function _G.print(...)
    local args = table.pack(...)
    local tp = ""
    local n = args.n
    for i=1, n, 1 do
      local k, v = i, args[i]
      tp = tp .. tostring(v) .. (k < n and "\t" or "")
    end
    return io.stdout:write(tp .. "\n")
  end
end

do
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
