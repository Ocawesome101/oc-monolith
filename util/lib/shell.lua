-- shell --

local fs = require("filesystem")
local text = require("text")
local stream = require("stream")
local thread = require("thread")
--local log = require("component").sandbox.log

local shell = {}
local aliases = {}

--log("shell builtins")

shell.extensions = {
  "lua",
  "sh"
}

shell.codes = {
  success = 0,
  failure = 1,
  argument = 2,
  syntax = 3,
  misc = 127
}

os.setenv("PATH", os.getenv("PATH") or "/bin:/sbin:/usr/bin:/usr/local/bin:$HOME/.local/bin")

function shell.error(cmd, err)
  checkArg(1, cmd, "string")
  checkArg(2, err, "string")
--log("SHELL ERROR:", cmd, err)
  print(string.format("\27[31msh: %s: %s\27[37m", cmd, --[[debug.traceback(]]err--[[)]]))
  return 1
end

function shell.vars(str)
  checkArg(1, str, "string")
--log("substitute vars for", str)
  for var in str:gmatch("%$([%w_]+)") do
    str = str:gsub("%$" .. var, os.getenv(var) or "")
  end
--log("got", str)
  return str
end

local function findProgram(name)
  checkArg(1, name, "string")
  local cp = os.getenv("PATH")
  for p in cp:gmatch("[^:]+") do
    p = fs.canonical(p)
    local raw = string.format("%s/%s", p, name)
    if fs.exists(raw) then
      return raw
    else
      for _, fext in ipairs(shell.extensions) do
        local ext = string.format("%s.%s", raw, fext)
        if fs.exists(ext) then
          return ext, fext
        end
      end
    end
  end
end

function shell.resolve(path)
  checkArg(1, path, "string")
  local _path = path
  if _path:sub(1,1) == "/" and fs.exists(_path) then
    return path, path:match("[%g]%.(%g+)") or "lua"
  end
  if _path == "." then
    _path = os.getenv("PWD")
  end
  if _path:sub(1,1) ~= "/" then
    if _path:sub(1,2) == "./" then
      _path = path:sub(3)
    end
    _path = _path .. "/" .. (os.getenv("PWD") or "")
  end
  _path = fs.canonical(_path)
  if not fs.exists(_path) then
    return findProgram(path)
  end
  return _path
end

function shell.setWorkingDirectory(dir)
  checkArg(1, dir, "string")
  local fp = fs.canonical(dir)
  if not fs.exists(fp) then
    return nil, dir .. ": no such file or directory"
  end
  os.setenv("PWD", fp)
  return true
end

function shell.getWorkingDirectory()
  return os.getenv("PWD")
end

local function split(cmd, spt)
  local cmds = {}
  for _cmd in cmd:gmatch(spt) do
    cmds[#cmds + 1] = _cmd
  end
  return cmds
end

local function execute(cmd, ...)
  local tokens = text.tokenize(shell.vars(table.concat({cmd, ...}, " "):gsub("\\27", "\27")))
  if #tokens == 0 then return end
  if aliases[tokens[1]] then tokens[1] = aliases[tokens[1]]; tokens = text.tokenize(shell.vars(table.concat(tokens, " "))) end
  local path, ftype = shell.resolve(tokens[1])
  local stat, exit
  if path and ftype == "lua" then
    --[[print("exec lua", path)]]
    local ok, err = loadfile(path, nil, setmetatable({arg = table.pack(table.unpack(tokens, 2))}, {__index=_G}))
    if not ok then
      shell.error(tokens[1], err)
    else
      for i=0, #tokens - 1, 1 do
        os.setenv(tostring(i), tokens[i + 1])
      end
      stat, exit = pcall(ok, table.unpack(tokens, 2))
    end
  elseif path and ftype == "sh" then
    return require("sh").execute(path) -- not at the top because loops
  elseif shell.builtins[tokens[1]] then
    for i=0, #tokens - 1, 1 do
      os.setenv(tostring(i), tokens[i + 1])
    end
    local exec = shell.builtins[tokens[1]]
    stat, exit = pcall(function()exec(table.unpack(tokens, 2))end)
  else
    shell.error(tokens[1], "command not found")
    return
  end
  if not stat and exit then
    shell.error(tokens[1], exit)
  else
    exit = exit or shell.codes.success
    if exit == shell.codes.success then
      return true
    elseif exit == shell.codes.failure then
      shell.error(tokens[1], "failed")
    elseif exit == shell.codes.syntax then
      shell.error(tokens[1], "syntax error")
    elseif exit == shell.codes.argument then
      shell.error(tokens[1], "invalid argument")
    else
      shell.error(tokens[1], "errored")
    end
    return nil, "command errored"
  end
  return true
end

function shell.execute(cmd, ...)
  checkArg(1, cmd, "string")
  local long = shell.vars(table.concat({cmd, ...}, " "))
  local set = split(long, "[^;]+")
  for i=1, #set, 1 do
    execute(set[i])
  end
end

os.execute = shell.execute

-- kind-of smart-ish argument parsing
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

function shell.setAlias(alias, cmd)
  checkArg(1, alias, "string")
  checkArg(2, cmd, "string")
  aliases[alias] = cmd
end

function shell.getAlias(alias)
  checkArg(1, alias, "string")
  return aliases[alias] or "nil"
end

function shell.unsetAlias(alias)
  checkArg(1, alias, "string")
  aliases[alias] = nil
end

function shell.exit()
  error("attempt to exit shell")
end

setmetatable(shell, {
  __index = function(tbl, k)
    setmetatable(shell, {})
    local ok, err = dofile("/lib/shell_builtins.lua")
    if not ok then
      shell.error("builtins", err)
    end
    if tbl[k] then
      return tbl[k]
    end
  end
})

return shell
