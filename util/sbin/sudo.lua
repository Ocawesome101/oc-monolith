-- run programs as the root user --

local shell = require("shell")
local users = require("users")
local readline = require("readline").readline

local args = {...}

local pawd = readline("[sudo] password for " .. os.getenv("USER") .. ": ", { pwchar = "*", notrail = true })

local ok, err = users.sudo(function()shell.execute(table.unpack(args))end, 0, pawd)
if not ok then
  shell.error("sudo", err)
  return shell.codes.failure
end
