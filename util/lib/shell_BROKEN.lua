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

--[[shell.builtins = {
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
}]]

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

function shell.parse(...)
  local params = {...}
  local inopt = false
  local cropt = ""
  local args, opts = {}, {}
  for i=1, #params, 1 do
    local p = params[i]
    if p:sub(1,2) == "--" then -- "long" option
      local o = p:sub(3)
      local op, vl = o:match("([%w]+)=([%w/,:]+)") -- I amaze myself with these patterns sometimes
      if op and vl then
        opts[op] = vl or true
      else
        opts[o] = true
      end
    elseif p:sub(1,1) == "-" then -- "short" option
      for opt in p:gmatch(".") do
        opts[opt] = true
      end
    else
      args[#args + 1] = p
    end
  end
  return args, opts
end

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

function shell.execute(...)
  local commands = text.split(table.concat({...}, " "), "|")
  --print("EXEC", table.unpack(commands))
  for k, v in pairs(commands) do
    commands[k] = text.split(v)
    commands[k][1] = shell.resolve(commands[k][1], "lua")
  end
  local pids, err = pipe.chain(commands)
  if not pids then
    return shell.error("sh", err)
  end
  local running = true
  while running do
    running = false
    for _, pid in pairs(pids) do
      if thread.info(pid) then
        running = true
      end
    end
    coroutine.yield()
  end
  return true
end

return shell
