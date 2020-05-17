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

local defaultPath = "/bin:/usr/bin:/usr/local/bin"

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

setmetatable(shell.errors, {__index = function()return "failed" end})

shell.extensions = {
  lua = true
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
    if not mode then
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
  end,
  set = function(...)
    local set, opts = shell.parse(...)
    if #set == 0 or opts.p then
      for k,v in pairs(os.getenv()) do
        print(string.format("%s=%s", k, v))
      end
    else
      for k, v in pairs(set) do
        local var, val = v:match("(.+)=(.+)")
        os.setenv(var, val)
      end
    end
  end,
  unset = function(...)
    local ust, opts = shell.parse(...)
    for k, v in pairs(ust) do
      os.setenv(v, nil)
    end
  end,
  alias = function(...)
    local ali, opts = shell.parse(...)
    if #ali == 0 then
      for k, v in pairs(aliases) do
        print(string.format("alias %s='%s'", k, v))
      end
    else
      for k, v in pairs(ali) do
        local a, c = v:match("(.+)=(.+)")
        if not c then
          if aliases[a] then
            print(string.format("alias %s='%s'", a, aliases[a]))
          end
        else
          aliases[a] = c
        end
      end
    end
  end,
  unalias = function(...)
    local una, opts = shell.parse(...)
    for k, v in pairs(una) do
      aliases[v] = nil
    end
  end,
  sleep = function(t)
    os.sleep(tonumber(t) or 1)
  end
}

local function percent(s)
  local r = ""
  local special = "[%[%]%^%*%+%-%$%.%?%%]"
  for c in s:gmatch(".") do
    if s:find(special) then
      r = r .. "%" .. c
    else
      r = r .. c
    end
  end
  return r
end

function shell.expand(str)
  checkArg(1, str, "string")
  -- variable-brace expansion
  -- ...and brace expansion will come eventually
  -- variable expansion
  for var in str:gmatch("%$([%w_#@]+)") do
    str = str:gsub("%$" .. var, os.getenv(var) or "")
  end
  return str
end

shell.vars = shell.expand

shell.parse = require("shell_old").parse
--[[function shell.parse(ops, ...)
  local parse = {ops, ...}
  local opts = (type(ops) == "table" and table.remove(parse, 1)) or {short = "-", long = "--"}
  local args, opts = {}, {}
  for i=1, #parse, 1 do
    local op = parse[i]
    if op:sub(1, 2) == "--" then
      table.insert(opts, op:sub(3))
    elseif op:sub(1, 1) == "-" then
      table.insert(opts, op:sub(2))
    else
      table.insert(args, op)
    end
  end
  --print(table.unpack(args), "OPTS", table.unpack(opts))
  return args, opts
end]]

function shell.setAlias(k, v)
  checkArg(1, k, "string")
  checkArg(2, v, "string")
  aliases[k] = v
end

function shell.unsetAlias(k)
  checkArg(1, k, "string")
  aliases[k] = nil
end

-- fancier split that deals with args like `prog print "this is cool" --text="this is also cool"`
function shell.split(str)
  checkArg(1, str, "string")
  local exp = shell.expand(str)
  local result = {}

  -- TODO: find and act on backquotes
  local cur = ""
  local ins = false
  local quote = "[\"']"
  for char in exp:gmatch(".") do
    if char:find(quote) then
      ins = not ins
    elseif char == " " and not ins then
      table.insert(result, cur)
      cur = ""
    else
      cur = cur .. char
    end
  end
  
  if cur ~= "" then table.insert(result, cur) end

  return result
end

function shell.resolve(path, ext)
  checkArg(1, path, "string")
  checkArg(2, ext, "string")
  local PATH = os.getenv("PATH") or defaultPath
  if path:sub(1,1) == "/" then
    path = fs.canonical(path)
    if fs.exists(path) then
      return path
    elseif fs.exists(path .. "." .. ext) then
      return path .. "." .. ext
    end
  end
  for s in PATH:gmatch("[^:]+") do
    local try = fs.concat(s, path)
    local txt = try .. "." .. ext
    if fs.exists(try) then
      return try
    elseif fs.exists(txt) then
      return txt
    end
  end
  return nil, path .. ": command not found"
end

local function spawnCommand(cmd, stdin, stdout, ...)
  local path, err = shell.resolve(cmd, "lua")
  local args = {...}
  print("SC", path, err)
  if not path then
    return nil, err
  end
  local ok, err = loadfile(path)
  print("LF", ok, err)
  if not ok then
    return nil, err
  end
  local env = {["0"] = cmd}
  for i=1, #args, 1 do
    env[tostring(i - 1)] = args[i]
  end
  local errno
  print("SPAWN", cmd, stdin, stdin == io.input(), stdout, stdout == io.output())
  local pid = thread.spawn(function()errno = ok(table.unpack(args))end, path, function(err)shell.error(cmd, err)end, env)--, stdin, stdout)
  print("WAIT", pid)
  while (not errno) and thread.info(pid) do coroutine.yield() end
  print("ERRNO", errno)
  return errno
end

local function pipeCommands(cmd1, cmd2, ...)
  local args = {cmd1, cmd2, ...}
  --print("PIPECMD", #args, cmd1, cmd2, ...)
  local result = 0
  local pipe = pipe.create()
  for i=1, #args, 1 do
    local input, output = io.input(), io.output()
    if #args == 1 then
      --print("STDIN UNCHANGED")
      -- stub
    elseif i % 2 == 0 and i < #args then
      input, output = pipe.input, pipe.output
    elseif i > 1 and i < #args then
      input, output = pipe.output, pipe.input
    elseif i == 1 then
      output = pipe.output
    elseif i == #args then
      if i % 2 == 0 then
        input = pipe.input
      else
        input = pipe.output
      end
    end
    local split = shell.split(args[i])
    --print("SPLIT", table.unpack(split))
    if aliases[split[1]] then
      split = shell.split(table.concat({aliases[split[1]], table.unpack(split, 2)}, " "))
    end
    local cmd = split[1]
    local argc = {table.unpack(split, 2)}
    --print("PIPE", table.unpack(split))
    if shell.builtins[cmd] then
      --print("BUILTIN")
      result = shell.builtins[cmd](table.unpack(args))
    else
      --print("NOT BUILTIN")
      result = spawnCommand(cmd, input, output, table.unpack(argc))
    end
    if result and result ~= 0 then return result, cmd end
  end
  return result or 0
end

function shell.execute(...)
  local commands = text.split(table.concat({...}, " "), "|")
  --print("EXEC", table.unpack(commands))
  local exit, command = pipeCommands(table.unpack(commands))
  if exit ~= 0 then
    shell.error(command, shell.errors[exit])
    return nil, shell.errors[exit]
  end
  return true
end

return shell
