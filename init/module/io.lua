-- `io` library --

do
  log("InitMe: Initialing IO library")

  _G.io = {}
  package.loaded.io = io

  local buffer = require("buffer")
  local fs = require("filesystem")
  local thread = require("thread")
  local stream = require("stream")

  setmetatable(io, {__index = function(tbl, k)
    if k == "stdin" then
      return thread.stdin()
    elseif k == "stdout" or k == "stderr" then
      return thread.stdout()
    end
  end})

  function io.open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
    file = fs.canonical(file)
    mode = mode or "r"
    local handle, err = fs.open(file, mode)
    if not handle then
      return nil, err
    end
    return buffer.new(mode, handle)
  end

  function io.output(file)
    checkArg(1, file, "string", "table", "nil")
    if type(file) == "string" then
      file = io.open(file, "w")
    end
    return thread.stdout(file)
  end

  function io.input(file)
    checkArg(1, file, "string", "table", "nil")
    if type(file) == "string" then
      file = io.open(file, "r")
    end
    return thread.stdin(file)
  end

  function io.popen(file) -- ...ish
    checkArg(1, file, "string")
    local ok, err = loadfile(file)
    if not ok then
      return nil, err
    end
    local thdio, uio = stream.dummy()
    local pid
    function thdio:close()
      thread.signal(pid, thread.signals.kill)
      thdio = nil
      uio = nil
      return true
    end
    local pid = thread.spawn(ok, file, function(e)thdio:write(e)end, nil, thdio, thdio)
    return uio, pid
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
    local args = {...}
    local tp = ""
    for k, v in ipairs(args) do
      tp = tp .. tostring(v) .. "\n"
    end
    return io.write(tp)
  end
end
