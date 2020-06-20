-- mostly mappings of users to names --

local users = {}

local protect = require("protect")
local config = require("config")
local sha3 = require("sha3")
local fs = require("filesystem")
local syslog = require("syslog").log

local old = kernel.users

old.sha = sha3
old.passwd = config.load("/etc/passwd")
for k, v in pairs(old.passwd) do
  syslog(k .. " (UID) " .. v.n)
end

local function getuid(name)
  if type(name) == "number" then
    return name
  end
  for uid, data in pairs(old.passwd) do
    syslog("check " .. name .. " == " .. data.n .. " for UID " .. uid)
    if data.n == name then
      syslog("MATCH")
      return uid
    end
  end
  return -1
end

function users.getname(uid)
  checkArg(1, uid, "number")
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
    old.passwd[uid].s = file
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

users.sudo = old.sudo

return protect(users, true)
