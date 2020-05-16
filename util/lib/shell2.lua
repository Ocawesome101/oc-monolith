-- improved shell API --

local fs = require("filesystem")
local text = require("text")
local time = require("time").formatTime
local pipe = require("pipe")
local users = require("users")
local thread = require("thread")

local shell = {}
local aliases = {}

function shell.error(cmd, err)
  checkArg(1, cmd, "string")
  checkArg(2, err, "string")
  print(string.format("\27[31m%s: %s\27[37m", cmd, err))
end

shell.codes = {
  misc = -1,
  success = 0,
  failure = 1,
  argument = 2,
  permission = 127
}

shell.errors = {
  [shell.codes.misc] = "errored",
  [shell.codes.failure] = "failed",
  [shell.codes.argument] = "bad argument",
  [shell.codes.permission] = "permission denied"
}

shell.builtins = {
  echo = function(...) print(table.concat({...}, " ")) end,
  cd = function(dir)
    local path = dir or os.getenv("HOME") or "/"
    if path:sub(1,1) == "~" then path = (os.getenv("HOME") or "/") .. path:sub(2)
    elseif path:sub(1,1) ~= "/" then path = fs.concat(os.getenv("PWD") or "/", path) end
    if not fs.exists(path) then
      shell.error("sh: cd", string.format("%s: no such file or directory", path))
      return shell.codes.failure
    end
    if not fs.isDirectory(path) then
      shell.error("sh: cd", string.format("%s: is not a directory", path))
    end
  end,
  exit = function(code)
    shell.exit(tonumber(code or 0))
  end,
  pwd = function()
    print(os.getenv("PWD"))
  end,
  ps = function(mode)
    local thd = thread.threads()
    if not mode then         ocawesome101
      print("PID  | PARENT | OWNER        | NAME")
    elseif mode == "a" then
      print("PID  | PARENT | OWNER        | START    | TIME     | NAME")
    else
      return shell.codes.argument
    end
    for n, pid in ipairs(thd) do
      local info = thread.info(pid)
      if not mode then
        print(string.format("%04x |   %04x | %12s | %s", pid, info.parent, users.getname(info.owner), info.name))
      elseif mode == "a" then
        print(string.format("%04x |   %04x | %12s | %8s | %8s | %s", pid, info.parent, users.getname(info.owner), time(info.started, "s", true), time(info.uptime, "s", true), info.name))
      end
    end
  end,
  kill = function(...)
    local signals = require("signals")
    local args, opts = shell.parse({long = "-", short = "--"}, ...)
    local pid = tonumber(args[1] or "")
    if #args == 0 or not pid then
      shell.error("sh: kill", "usage: kill [-<signal>] <PID>")
      return shell.codes.argument
    end
    local sig
    if opts.SIGKILL or opts[signals.kill] then
      sig = signals.kill
    elseif opts.SIGINT or opts[signals.interrupt] then
      sig = signals.interrupt
    elseif opts.USR1 or opts[signals.usr1] then
      sig = signals.usr1
    elseif opts.USR2 or opts[signals.usr2] then
      sig = signals.usr2
    elseif opts.SIGQUIT or opts[signals.quit] then
      sig = signals.quit
    elseif opts.SIGTERM or opts[signals.term] then
      sig = signals.term
    else
      sig = signals.kill
    end
    local ok, err = thread.signal(pid, sig)
    if not ok then
      shell.error("sh: kill", err)
      return shell.codes.failure
    end
  end
}
