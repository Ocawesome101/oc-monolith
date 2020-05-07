-- user manager utility --

local shell = require("shell")
local users = require("users")

local args, opts = shell.parse(...)

local function getPasswordInput()
  local read = ""
  io.write("password: \27[8m")
  read = io.read():gsub("\n", "")
  io.write("\27[m\n")
  return read
end

local function getNameInput()
  local read = ""
  io.write("username: ")
  read = io.read():gsub("\n", "")
  io.write("\n")
  return read
end

local usage, interactive
local function execute(action, param, param2)
  local pawd
  if action == "add" then
    pawd = getPasswordInput()
  end
  if action == "add" or action == "del" then
    param = param or getNameInput()
  end
  param2 = param2 == "true"
  if action == "help" then
    print(usage)
  elseif action == "exit" then
    if interactive then
      interactive = false
    end
  elseif action == "add" then
    return users.add(param, pawd, param2)
  elseif action == "del" then
    return users.del(param)
  end
end

usage = [[usermgr (c) 2020 Ocawesome101 under the MIT license.
available commands:
  help:                 display this help
  exit:                 exit interactive mode
  add [user] [cansudo]: add a user - requires root
  del [user]:           delete a user - requires root]]

if opts.h or opts.help then
  print(usage)
  return
end

if #args == 0 then -- enter interactive mode
  interactive = true
  while interactive do
    io.write("usermgr> ")
    local cmd = require("text").split(io.read():gsub("\n",""))
    local ok, err = execute(table.unpack(cmd))
    if not ok and err then
      shell.error("usermgr", err)
    end
  end
else -- enter CLI mode
  local ok, err = execute(table.unpack(args))
  if not ok and err then
    shell.error("usermgr", err)
    return shell.codes.failure
  end
end
