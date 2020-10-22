-- mostly mappings of users to names --

local users = {}

local config = require("config")
local sha3 = require("sha3")
local fs = require("filesystem")

local old = kernel.users

old.sha = sha3
old.passwd = config.load("/etc/passwd")

local function getuid(name)
  if type(name) == "number" then
    return name
  end
  for uid, data in pairs(old.passwd) do
    if data.n == name then
      return uid
    end
  end
  return -1
end

function users.getname(uid)
  checkArg(1, uid, "number", "string")
  if type(uid) == "string" then return uid end
  if old.passwd[uid] then
    return old.passwd[uid].n
  end
  return "UID: " .. tostring(uid)
end

function users.login(user, password)
  checkArg(1, user, "string", "number")
  checkArg(2, password, "string")
  local uid = getuid(user)
  local ok, err = old.login(uid, password)
  if ok then
    os.setenv("USER", old.passwd[uid].n)
    os.setenv("UID", uid)
    os.setenv("HOME", old.passwd[uid].h)
    os.setenv("SHELL", old.passwd[uid].s)
  end
  return ok, (not ok) and err
end

function users.logout()
  return old.logout()
end

function users.uid()
  return old.uid()
end

function users.add(name, password, cansudo)
  checkArg(1, name, "string")
  checkArg(2, password, "string")
  checkArg(3, cansudo, "boolean", "nil")
  local uid, err = old.add(password, cansudo)
  if not uid then
    return nil, err
  end
  old.passwd[uid].n = name
  old.passwd[uid].h = "/home/" .. name
  fs.makeDirectory(old.passwd[uid].h)
  old.passwd[uid].s = "/bin/sh.lua"
  config.save(old.passwd, "/etc/passwd")
end

function users.setShell(file)
  checkArg(1, file, "string")
  if fs.exists(file) then
    old.passwd[users.uid()].s = file
    config.save(old.passwd, "/etc/passwd")
  end
end

function users.del(user)
  checkArg(1, user, "string", "number")
  local uid = getuid(user)
  local ok, err = old.del(user)
  config.save(old.passwd, "/etc/passwd")
  return ok, err
end

function users.home()
  return os.getenv("HOME")
end

function users.shell()
  return os.getenv("SHELL")
end

function users.sudo(func, uname, password)
  checkArg(1, func, "function")
  checkArg(2, uname, "string", "number")
  checkArg(3, password, "string")
  uid = getuid(uname)
  if not old.passwd[users.uid()].c then
    return nil, "user is not allowed to sudo"
  end
  if old.authenticate(users.uid(), password) then
    local uuid = users.uid
    local name = os.getenv("USER")
    local ouid = uuid()
    function users.uid()
      return uid
    end
    os.setenv("USER", users.getname(uname))
    os.setenv("UID", uid)
    local s, r = pcall(func)
    u.uid = uuid
    os.setenv("USER", name)
    os.setenv("UID", ouid)
    return true, s, r
  end
  return nil, "permission denied"
end

return package.protect(users, "users")
