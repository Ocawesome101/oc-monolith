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
  set = function(...)
    local set, opts = shell.parse(...)
    if #set == 0 or opts.p then
      for k,v in pairs(thread.info().data.env) do
        print(string.format("%s=%s", k, tostring(v):gsub("\27", "\\27")))
      end
    else
      for k, v in pairs(set) do
        local var, val = v:match("(.+)=(.+)")
        os.setenv(var, val:gsub("\\27", "\27"))
      end
    end
  end,
  shutdown = function(...)
    local args, opts = shell.parse(...)
    local computer = require("computer")

    local pwr = opts.poweroff or opts.P or opts.h or false
    local rbt = opts.reboot or opts.r or false
    local msg = opts.k or false

    if opts.help or not (pwr or rbt or msg) then
      print([[
usage: shutdown [options]
options:
  --poweroff, -P, -h    power off
  --reboot, -r          reboot
  -k                    send the shutdown signal but do not shut down
      ]])
      return
    end

    computer.pushSignal("shutdown")
    coroutine.yield()

    if (pwr or rbt or hlt) and not msg then
      computer.shutdown(rbt)
    end

    return shell.codes.argument
  end,
  reboot = function()
    shell.execute("shutdown --reboot")
  end,
  poweroff = function()
    shell.execute("shutdown --poweroff")
  end
}

package.delay(shell.builtins, "/lib/full/builtins.lua")

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

-- fancier split that deals with args like `prog print "this is cool" --text="this is also cool"`
function shell.split(str)
  checkArg(1, str, "string")
  local inblock = false
  local ret = {}
  local cur = ""
  local last = ""
  for char in str:gmatch(".") do
    if char == "'" then
      if inblock == false then inblock = true end
    elseif char == " " then
      if inblock then
        cur = cur .. " "
      else
        ret[#ret + 1] = cur:gsub("\\27", "\27")
        cur = ""
      end
    else
      cur = cur .. char
    end
    last = char
  end
  if #cur > 0 then
    ret[#ret + 1] = cur:gsub("\\27", "\27")
  end
  return ret
end

function shell.resolve(path, ext)
  checkArg(1, path, "string")
  checkArg(2, ext, "string", "nil")
  ext = ext or ""
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
  return fs.canonical(path)
end

local function execute(...)
  local commands = text.split(table.concat({...}, " "), "|")
  local has_builtin = false
  local builtin = {}
  for k, v in pairs(commands) do
    commands[k] = shell.split(v)
    if shell.builtins[commands[k][1]] then
      has_builtin = true
      builtin = commands[k]
    else
      commands[k][1] = shell.resolve(commands[k][1], "lua") or commands[k][1]
    end
  end
  if #commands > 1 and has_builtin then
    shell.error("sh", "cannot pipe to or from builtin command")
    return false
  end
  if has_builtin then
    local cmd = commands[1]
    return shell.builtins[cmd[1]](table.unpack(cmd, 2))
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
    coroutine.yield(0.01)
  end
  return true
end

function shell.execute(...)
  local commands = text.split(table.concat({...}, " "), ";")
  for i=1, #commands, 1 do
    local x = execute(commands[i])
    if x and x ~= 0 then
      return
    end
  end
end

package.delay(shell, "/lib/full/shell.lua")

return shell
