-- utility for controlling the OpenSecurity Security Terminal --

local component = require("component")
local logger = require("logger").new("arrow")
local shell = require("shell")

local args, opts = shell.parse(...)

local st = component.os_securityterminal

local actions = {}

local function getpass()
  io.write("security terminal password: \27[0;8m")
  local pwd = io.read()
  io.write("\27[0m")
  return pwd
end

function actions.particle(a)
  local pass =getpass()
  if a == "on" then
    logger:info("Enabling border particles")
    while not st.toggleParticle(pass) do end
    logger:ok("Border particles enabled")
  elseif a == "off" then
    logger:info("Disabling border particles")
    while st.toggleParticle(pass) do end
    logger:ok("Border particles disabled")
  else
    logger:fail("Expected 'on' or 'off' as argument to 'particle'")
    os.exit()
  end
end

function actions.setpass()
  local pass = getpass()
  logger:info("Setting password")
  return st.setPassword(pass)
end

function actions.add(uname)
  local password = getpass()
  logger:info("Adding user '"..uname.."'")
  return st.addUser(password, uname)
end

function actions.del(uname)
  logger:info("Removing user '"..uname.."'")
  return assert(st.delUser(getpass(), uname))
end

function actions.range(r)
  local n = tonumber(r)
  if n < 1 or n > 4 then
    logger:fail("expected [1-4] as argument to 'range'")
    os.exit()
  end
  logger:info("Setting block range to "..r)
  return st.setRange(getpass(), n)
end

function actions.enable()
  local pass = getpass()
  logger:info("Enabling security terminal")
  return st.enable(pass)
end

function actions.disable()
  local pass = getpass()
  logger:info("Disabling security terminal")
  return st.disable(pass)
end

function actions.list()
  logger:ok(table.unpack(assert(st.getAllowedUsers(getpass()))))
end

function actions.help()
  os.execute("man secterm")
end

if actions[args[1]] then
  actions[args[1]](table.unpack(args, 2))
else
  logger:fail("bad action")
end
