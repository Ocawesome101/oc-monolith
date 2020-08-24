local computer = require("computer")
local shell = require("shell")
local thread = require("thread")
local builtins = shell.builtins
local aliases = shell.aliases

builtins.unset = function(...)
  local ust, opts = shell.parse(...)
  for k, v in pairs(ust) do
    os.setenv(v, nil)
  end
end
builtins.unalias = function(...)
  local una, opts = shell.parse(...)
  for k, v in pairs(una) do
    aliases[v] = nil
  end
end
builtins.sleep = function(t)
  os.sleep(tonumber(t) or 1)
end
builtins.exit = function(code)
  shell.exit(tonumber(code) or 0)
end
builtins.pwd = function()
  print(os.getenv("PWD"))
end
builtins.kill = function(...)
  local signals = require("signals")
  local args, opts = shell.parse(...)
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
builtins.time = function(...)
  local start = computer.uptime()
  shell.execute(table.concat(table.pack(...), " "))
  local total = computer.uptime() - start
  print("real", total .. "s")
end
builtins.builtin = function(b, ...)
  if builtins[b] then
    return builtins[b](...)
  else
    return shell.error("sh: builtin", "no such builtin")
  end
end
builtins.whoami = function()
  print(os.getenv("USER"))
end
builtins.builtins = function()
  for k, v in pairs(builtins) do
    print(k)
  end
end
