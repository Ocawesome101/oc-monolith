-- improved shell API --

local fs = require("filesystem")
local pipe = require("pipe")
local thread = require("thread")

local shell = {}
local aliases = {}
shell.aliases = aliases

function shell.setAlias(k, v)
  checkArg(1, k, "string")
  checkArg(2, v, "string")
  shell.aliases[k] = v
end

function shell.error(cmd, err)
  checkArg(1, cmd, "string")
  checkArg(2, err, "string")
  io.stderr:write(string.format("\27[31m%s: %s\27[37m\n", cmd, err))
end

local defaultPath = "/bin:/sbin:/usr/bin:/usr/local/bin"
os.setenv("PATH", os.getenv("PATH") or defaultPath)

shell.extensions = {
  lua = true,
  sh = true
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
    os.setenv("PWD", path)
  end,
  set = function(...)
    local set, opts = shell.parse(...)
    if #set == 0 or opts.p then
      for k,v in pairs(thread.info().data.env) do
        print(string.format("%s=%s", k, tostring(v):gsub("\27", "\\27")))
      end
    else
      for k, v in pairs(set) do
        local var, val = v:match("(.-)=(.+)")
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
  alias = function(...)
    local ali, opts = shell.parse(...)
    if #ali == 0 then
      for k, v in pairs(shell.aliases) do
        print(string.format("alias %s='%s'", k, v))
      end
    else
      for k, v in pairs(ali) do
        local a, c = v:match("(.+)=(.+)")
        if not c then
          if shell.aliases[a] then
            print(string.format("alias %s='%s'", a, shell.aliases[a]))
          end
        else
          aliases[a] = c
        end
      end
    end
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
  -- variable-in-brace expansion and brace expansion will come eventually
  -- variable expansion
  for var in str:gmatch("%$([%w_#@]+)") do
    str = str:gsub("%$" .. var, os.getenv(var) or "")
  end
  -- basic asterisk expansion
  if str:find("%*") then
    local split = shell.split(str)
    for i=2, #split, 1 do
      if split[i]:sub(-1) == "*" then
        local fpath = shell.resolve(split[i]:sub(1,-2))
        if fpath and fs.isDirectory(fpath) then
          split[i] = nil
          for file in fs.list(fpath) do
            table.insert(split, i, fs.concat(fpath, file))
          end
        end
      end
    end
    str = table.concat(split, " ")
  end
  return str
end

shell.vars = shell.expand -- backwards compatibility

function shell.parse(...)
  local params = {...}
  local inopt = true
  local cropt = ""
  local args, opts = {}, {}
  for i=1, #params, 1 do
    local p = tostring(params[i])
    if p == "--" then
      inopt = false
    elseif p:sub(1,2) == "--" and inopt then -- "long" option
      local o = p:sub(3)
      local op, vl = o:match([[([%w]+)=([%w%/%,%.%:%s%'%"%=]+)]]) -- I amaze myself with these patterns sometimes
      if op and vl then
        opts[op] = vl or true
      else
        opts[o] = true
      end
    elseif p:sub(1,1) == "-" and #p > 1 and inopt then -- "short" option
      for opt in p:gmatch(".") do
        opts[opt] = true
      end
    else
      args[#args + 1] = p
    end
  end
  return args, opts
end

function shell.resolve(cmd)
  if fs.exists(cmd) then
    return cmd
  end
  if fs.exists(cmd..".lua") then
    return cmd..".lua"
  end
  for path in os.getenv("PATH"):gmatch("[^:]+") do
    local check = fs.concat(path, cmd)
    if fs.exists(check) then
      return check
    end
    if fs.exists(check..".lua") then
      return check..".lua"
    end
  end
  return nil, cmd..": command not found"
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
      elseif cur ~= "" then
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

local function split(str, pat)
  local sep = {}
  for seg in str:gmatch(pat) do
    sep[#sep + 1] = seg
  end
  return sep
end

-- "a | b > c" -> {{cmd = {"a"}, i = <std>, o = <pipe>}, {cmd = {"b"}, i = <pipe>, o = <handle_to_c>}}
local function setup(str)
  str = shell.expand(str)
  local tokens = shell.split(str)
  local stdin = io.input()
  local stdout = io.output()
  local ret = {}
  local cur = {cmd = {}, i = stdin, o = stdout}
  local i = 1
  while i <= #tokens do
    local t = tokens[i]
    if t:match("(.-)=(.+)") and #cur.cmd == 0 then
      local k, v = t:match("(.-)=(.+)")
      cur.env = cur.env or {}
      cur.env[k] = v
    elseif t == "|" then
      if #cur.cmd == 0 or i == #tokens then
        return nil, "syntax error near unexpected token `|`"
      end
      local new = pipe.create()
      cur.o = new
      table.insert(ret, cur)
      cur = {cmd = {}, i = pipe, o = stdout}
    elseif t == ">" or t == ">>" then -- > write, >> append
      if #cur.cmd == 0 or i == #tokens then
        return nil, "syntax error near unexpected token `"..t.."`"
      end
      i = i + 1
      local handle, err = io.open(tokens[i], t == ">" and "w" or "a")
      if not handle then
        return nil, err
      end
      cur.o = handle
    elseif t == "<" then
      if #cur.cmd == 0 or i == #tokens then
        return nil, "syntax error near unexpected token `<`"
      end
      i = i + 1
      local handle, err = io.open(tokens[i], "r")
      if not handle then
        return nil, err
      end
      cur.i = handle
    elseif shell.aliases[t] and #cur.cmd == 0 then
      local ps = shell.split(shell.expand(shell.aliases[t]))
      cur.cmd = ps
    else
      cur.cmd[#cur.cmd + 1] = t
    end
    i = i + 1
  end
  if #cur.cmd > 0 then
    table.insert(ret, cur)
  end
  return ret
end

local immediate = {set = true, cd = true}
local function execute(str)
  local exec, err = setup(str)
  if not exec then
    return nil, err
  end
  local pids = {}
  local errno = false
  for i=1, #exec, 1 do
    local func
    local ex = exec[i]
    local cmd = ex.cmd[1]
    if shell.builtins[cmd] then
      if immediate[cmd] then
        shell.builtins[cmd](table.unpack(ex.cmd, 2))
      end
      func = shell.builtins[cmd]
    else
      local path, err = shell.resolve(cmd)
      if not path then
        shell.error("sh", err)
        return nil, err
      end
      local ok, err = loadfile(path)
      if not ok then
        shell.error(err)
        return nil, err
      end
      func = ok
    end
    local f = function()
      io.input(ex.i)
      io.output(ex.o)
      if ex.env then
        for k, v in pairs(ex.env) do
          os.setenv(k, v)
        end
      end
      local ok, ret = pcall(func, table.unpack(ex.cmd, 2))
      if not ok and ret then
        errno = ret
        io.stderr:write(ret,"\n")
        for i=1, #pids, 1 do
          thread.signal(pids[i], thread.signals.kill)
        end
      end
    end
    table.insert(pids, thread.spawn(f, table.concat(ex.cmd, " ")))
  end
  while true do
    coroutine.yield(0)
    local run = false
    for k, pid in pairs(pids) do
      if thread.info(pid) then
        run = true
      end
    end
    if errno or not run then break end
  end
  if errno then
    return nil, errno
  end
  return true
end

function shell.execute(...)
  local args = table.pack(...)
  if args[2] == nil or type(args[2]) == "table" then -- discard the 'env' argument OpenOS programs may supply
    pcall(table.remove, args, 2)
  end
  local commands = split(shell.expand(table.concat(args, " ")), "[^%;]+")
  for i=1, #commands, 1 do
    execute(commands[i])
  end
  return true
end

package.delay(shell, "/lib/full/shell.lua")

return shell
