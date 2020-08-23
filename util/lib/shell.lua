-- improved shell API --

local fs = require("filesystem")
local text = require("text")
local pipe = require("pipe")
local users = require("users")
local thread = require("thread")

local shell = {}
local aliases = {}
shell.aliases = aliases

function shell.error(cmd, err)
  checkArg(1, cmd, "string")
  checkArg(2, err, "string")
  io.stderr:write(string.format("\27[31m%s: %s\27[37m\n", cmd, err))
end

local defaultPath = "/bin:/usr/bin:/usr/local/bin"
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
  if ext then
    return path
  end
  return fs.canonical(path)
end

-- replaces shell.split
-- splits into tokens, such that
-- "prg arg1 arg2 | prg 'arg with spaces' > outfile; ls /" becomes {{"prg", "arg1", "arg2"}, "|", {"prg", "arg with spaces"}, ">", {"outfile"}, ";", {"ls", "/"}}
local special = {
  [">"] = true,
  [">>"] = true,
  ["|"] = true
}

function shell.tokens(str)
  checkArg(1, str, "string")
  str = shell.expand(str)
  local ret = {}
  local in_str = false
  local str_char = ""
  local cur = ""
  local cur_tab = {}
  local i = 1
  for char in str:gmatch(".") do
    if char == "'" or char == "\"" then
      if in_str then
        if str_char == char then
          in_str = false
        else
          cur = cur .. char
        end
      else
        in_str = true
        str_char = char
      end
    elseif special[char] then
      if cur ~= "" then table.insert(cur_tab, cur) end
      ret[i] = cur_tab
      cur_tab = {}
      cur = ""
      ret[i + 1] = char
      i = i + 2
    elseif char == " " and not in_str then
      if cur ~= "" then table.insert(cur_tab, cur) end
    else
      cur = cur .. char
    end
  end
  return ret
end

local basePipeStream = {
  read = function(self, len)
    checkArg(1, len, "number", "nil")
    if self.closed and #self.buf == 0 then
      return nil
    end
    while not ((len and #self.buf >= len) or self.buf:find("\n") or self.closed) do
      coroutine.yield()
    end
    len = len or self.buf:find("\n") or #self.buf
    local ret = self.buf:sub(1, len)
    self.buf = self.buf:sub(len + 1)
    return ret
  end,
  write = function(self, data)
    checkArg(1, data, "string")
    if self.closed then
      return nil, "broken pipe"
    end
    self.buf = self.buf .. data
    return true
  end,
  close = function()
    self.closed = true
  end
}

-- this function isn't pretty.
local function execute(cmd)
  local tokens = shell.tokens(cmd)
  if #tokens == 0 then
    return
  end
  local pids = {}
  local last_pipe
  local command
  local curcmd, totcmd = 1, 0
  local orig = {input = io.input, output = io.output}
  for i=1, #tokens, 1 do
    local tok, l = tokens[i], tokens[i - 1] or nil
    if type(tok) == "table" and ((not l) or (l ~= ">" and l ~= "<")) then
      totcmd = totcmd + 1
    end
  end

  for i=1, #tokens, 1 do
    local token = tokens[i]
    if type(token) == "table" then
      if iscmd then
        if shell.builtins[token[1]] then
          token[1] = {builtin = true, func = shell.builtins[token[1]]}
          token[1].func(table.unpack(token, 2))
          goto cont
        else
          local path, err = shell.resolve(token[1])
          if not path then
            return shell.error("sh: "..token[1], "command not found")
          end
          token[1] = {builtin = false, func = loadfile(path), name = path}
        end
      else
        token[1] = fs.canonical(token[1])
      end
      if command then
        table.insert(pids, thread.spawn(function() command[1].func(table.unpack(command, 2)) end, command[1].name))
      end
      command = token
      ::cont::
    elseif token == "|" then
      if i == 1 or i == #tokens or not command then -- invalid as first or last token or if there isn't a command
        return shell.error("sh", "syntax error near unexpected token '|'")
      end
      local commnd = command
      if commnd[1].builtin then
        return shell.error("sh", "cannot pipe builtin command")
      end
      local new_pipe = setmetatable({buf = ""}, {__index = basePipeStream})
      local lp, np = last_pipe, new_pipe
      local cmdn = curcmd
      local new = thread.spawn(function()
        io.input(cmdn > 1 and lp or orig.input)
        io.output(cmdn < totcmd and np or orig.output)
        commnd[1].func(table.unpack(commnd, 2))
      end, commnd[1].name, shell.error)
      table.insert(pids, new)
      curcmd = curcmd + 1
      last_pipe = new_pipe
      command = nil
    end
  end

  local run = true
  while run do
    run = false
    for i, pid in pairs(pids) do
      if thread.info(pid) then
        run = true
      else
        pids[i] = nil
      end
    end
    local sig = table.pack(coroutine.yield(0))
    if sig[1] == "thread_errored" then
      for k, v in pairs(pids) do
        if sig[2] == v then
          io.stderr:write("\27[31m" .. sig[3] .. "\27[37m\n")
        end
      end
    end
  end
  return true
end

local function split(s, p)
  local S = {}
  for m in s:gmatch(p) do
    S[#S+1]=m
  end
  return S
end

function shell.execute(...)
  local args = table.pack(...)
  if args[2] == nil or type(args[2]) == "table" then -- discard the 'env' argument OpenOS programs may supply
    pcall(table.remove, args, 2)
  end
  local commands = split(shell.expand(table.concat(args, "")), "[^%;]+")
  for i=1, #commands, 1 do
    execute(commands[i])
  end
  return true
end

package.delay(shell, "/lib/full/shell.lua")

return shell
