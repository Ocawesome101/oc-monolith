-- run programs as the root user --

local shell = require("shell")
local users = require("users")

local args = {...}

io.write("[sudo] password for " .. os.getenv("USER") .. ": \27[8m")
local pawd = io.read():gsub("\n", "")
io.write("\27[0m\n")

local ok, err = users.sudo(function()shell.execute(table.unpack(args))end, 0, pawd)
if not ok then
  shell.error("sudo", err)
  return shell.codes.failure
end
