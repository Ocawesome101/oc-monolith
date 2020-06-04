local shell = require("shell")
local fs = require("filesystem")
local thread = require("thread")

shell.builtins = {
  [":"] = function() return 0 end,
  source = function(path)
    checkArg(1, path, "string")
    return shell.execute(path)
  end,
  echo = function(...) print(table.concat({...}, " ")) end,
  cd = function(dir)
    local path = dir or os.getenv("HOME") or "/"
    if path:sub(1,1) ~= "/" then
      if path:sub(1,1) == "~" then
        path = fs.concat((os.getenv("HOME") or "/"), path:sub(2))
      else
        path = fs.concat(os.getenv("PWD") or "/", path)
      end
    end
    if not fs.exists(path) then
      shell.error("cd", string.format("%s: no such file or directory", dir))
      return 1
    end
    os.setenv("_", os.getenv("PWD"))
    os.setenv("PWD", path)
    return 0
  end,
  exit = function()
    shell.exit()
  end,
  pwd = function()
    print(os.getenv("PWD"))
  end,
  read = function(var)
    os.setenv(var, io.read())
  end,
  ps = function(mode)
    local thd = thread.threads()
    if not mode then
      print("PID    | PARENT | OWNER    | NAME")
    elseif mode == "a" then
      print("PID    | PARENT | OWNER    | START    | TIME     | NAME")
    else
      shell.error("pid", "invalid argument")
      return shell.codes.argument
    end
    for i=1, #thd, 1 do
      local info, err = thread.info(thd[i])
      if not info then
        shell.error("ps", err or "no thread " .. thd[i])
      else
        if not mode then
          print(string.format("%6d | %6d | %8s | %s", thd[i], info.parent or 0, info.owner, info.name))
        elseif mode == "a" then
          print(string.format("%6d | %6d | %8s | %8s | %8s | %s", thd[i], info.parent or 0, info.owner, require("time").formatTime(info.started, "s", true), require("time").formatTime(info.uptime, "s", true), info.name))
        end
      end
    end
  end,
  kill = function(sig, pid, ...)
    pid = tonumber(pid) or tonumber(sig)
    if not pid then
      shell.error("usage", "kill [-<signal>] <pid>")
      return shell.codes.argument
    end
    if sig:sub(1,1) == "-" then
      if sig == "-SIGKILL" then
        sig = thread.signals.kill
      elseif sig == "-SIGINT" then
        sig = thread.signals.interrupt
      elseif sig == "-USR1" then
        sig = thread.signals.usr1
      elseif sig == "-USR2" then
        sig = thread.signals.usr2
      elseif sig == "-SIGQUIT" then
        sig = thread.signals.quit
      elseif sig == "-SIGTERM" then
        sig = thread.signals.term
      elseif sig == "-SIGSTOP" then
        sig = thread.signals.stop
      elseif sig == "-SIGCONT" then
        sig = thread.signals.continue
      else
        shell.error("kill", "signal must be one of: SIGINT, SIGQUIT, SIGCONT, SIGSTOP, SIGTERM, USR1, USR2, SIGKILL")
        return shell.codes.argument
      end
    else
      sig = thread.signals.kill
    end
    local ok, err = thread.signal(pid, sig)
    if not ok then
      shell.error("kill", err)
      return shell.codes.failure
    end
  end,
  set = function(...)
    local ts = {...}
    if #ts == 0 or ts[1] == "-p" then
      for k, v in pairs(os.getenv()) do
        print(string.format("%s = %s", k, tostring(v):gsub("\27", "\\27")))
      end
    else
      for k, v in pairs(ts) do
        local vr, vl = v:match("(.+)=(.+)")
        os.setenv(vr, vl)
      end
    end
  end,
  alias = function(var, cmd)
    if var and cmd then
      shell.setAlias(var, cmd)
    elseif var then
      print(string.format("alias %s=%s", var, aliases[var] or "nil"))
    else
      for a, c in pairs(aliases) do
        print(string.format("alias %s=%s", a, c))
      end
    end
  end,
  sleep = function(t)
    os.sleep(tonumber(t))
  end,
  test = function(...) -- taken from JackMacWindows' CASH shell
    local args = {...}
    if #args < 1 then
      shell.error("test", "unary operator expected")
      return 2
    end
    local function n(v) return v end
    if args[1] == "!" then
      table.remove(args, 1)
      n = function(v) return not v end
    end
    local a = args[1]
    local b = args[2]
    if a:sub(1,1) == "-" then
      if args[2] == nil then return n(true)
       elseif a == "-d" then return n(fs.exists(fs.canonical(b)) and fs.isDirectory(fs.canonical(b)))
       elseif a == "-e" then return n(fs.exists(fs.canonical(b)))
       elseif a == "-f" then return n(fs.exists(fs.canonical(b)) and not fs.isDirectory(fs.canonical(b)))
       elseif a == "-n" then return n(#b > 0)
       elseif a == "-s" then return n(fs.size(fs.canonical(b)) > 0)
       elseif a == "-w" then return n(not fs.isReadOnly(fs.canonical(b)))
       elseif a == "-x" then return n(true)
       elseif a == "-z" then return n(#b == 0)
       else return n(false) end
    elseif args[3] and b:sub(1,1) == "-" then
      local c = tonumber(args[3])
      local A = tonumber(a)
      if b == "-eq" then     return n(A == c)
      elseif b == "-ne" then return n(A ~= c)
      elseif b == "-lt" then return n(A < c)
      elseif b == "-gt" then return n(A > c)
      elseif b == "-le" then return n(A <= c)
      elseif b == "-ge" then return n(A >= c)
      else return n(false) end
    elseif b == "=" then return n(a == args[3])
    elseif b == "!-" then return n(a ~= args[3])
    else
      shell.error("test", "unary operator expected")
      return 2
    end
  end,
  ["true"] = function() return 0 end,
  ["false"] = function() return 1 end,
  unalias = function(...)
    for k, v in ipairs({...}) do
      shell.unsetAlias(v)
    end
  end,
  unset = function(...)
    for k, v in ipairs({...}) do
      os.setenv(v, nil)
    end
  end,
  cat = function(...)
    local args = {...}
    if #args == 0 then
      local data = io.read()
      print(data)
      return 0
    else
      for k, v in ipairs(args) do
        local file, err = io.open(v, "r")
        if file then
          repeat
            local chunk = file:read(2048)
            io.write(chunk or "")
          until not chunk
          file:close()
        else
          shell.error("cat", err)
          return 1
        end
      end
    end
  end
}

shell.builtins["["] = shell.builtins.test

function shell.builtins.builtins()
  for k, v in pairs(shell.builtins) do
    print(k)
  end
end

return true
