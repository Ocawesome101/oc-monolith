-- shell --

local fs = require("filesystem")

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
      shell.error(string.format("sh: cd: %s: no such file or directory", dir))
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
  alias = function()
  end,
  sleep = function()
  end,
  test = function(...) -- taken from JackMacWindows' CASH shell
    local args = {...}
    if #args < 1 then
      printError("sh: test: unary operator expected")
      return -1
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
      printError("sh: test: unary operator expected")
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
        printError(err)
        return 1
      end
    end
  end
}

shell.builtins["["] = shell.builtins.test
