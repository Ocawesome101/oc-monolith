-- shell --

local fs = require("filesystem")
local text = require("text")

local shell = {}

shell.builtins = {
  [":"] = function() return 0 end,
  ["."] = function(path)
    checkArg(1, path, "string")
    return shell.execute(path)
  end,
  echo = function(...) print(...) end,
  cd = function(dir)
    local path = fs.canonical(dir)
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
  set = function(...)
    local ts = {...}
    if #ts == 0 or ts[1] == "-p" then
      for k, v in pairs(os.getenv()) do
        print(string.format("%s = %s", k, v))
      end
    else
      for k, v in pairs(ts) do
        local vr, vl = v:match("(.+)=(.+)")
        os.setenv(vr, vl)
      end
    end
  end,
  alias = function(var, cmd)
    shell.setAlias(var, cmd)
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
    for k, v in ipairs({...}) do
      local file, err = io.open(v, "r")
      if file then
        print(file:read("*a"))
        file:close()
      else
        shell.error("cat", err)
        return 1
      end
    end
  end
}

shell.builtins["["] = shell.builtins.test

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
  print(string.format("\27[31msh: %s: %s\27[37m", cmd, err))
  return 1
end

function shell.vars(str)
  checkArg(1, str, "string")
  for var in str:gmatch("%$([%w_]+)") do
    str = str:gsub(var, os.getenv(var) or "")
  end
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
  if path == "." then
    _path = os.getenv("PWD")
  end
  if path:sub(1,1) ~= "/" then
    _path = path .. "/" .. (os.getenv("PWD") or "")
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

function shell.execute(cmd, ...)
  checkArg(1, cmd, "string")
  local tokens = text.split(table.concat({cmd, ...}, " "))
  if #tokens == 0 then return end
  local path, ftype = shell.resolve(tokens[1])
  if path and ftype == "lua" then
    local ok, err = loadfile(path)
    if not ok then
      shell.error(tokens[1], err)
    else
      for i=0, #tokens - 1, 1 do
        os.setenv(tonumber(i), tokens[i + 1])
      end
      local stat, exit = pcall(ok, table.unpack(tokens, 2))
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
    end
  elseif path and ftype == "sh" then
    return require("sh").execute(path) -- not at the top because loops
  else
    shell.error(tokens[1], "command not found")
  end
end

os.execute = shell.execute

return shell
