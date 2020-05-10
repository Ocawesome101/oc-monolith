-- profile --

local shell = require("shell")
local users = require("users")

os.setenv("EDITOR", "/bin/ed.lua")
os.setenv("PS1", "\27[32m\\u\27[37m@\27[32m\\h\27[37m: \27[34m\\w\27[37m\\$ ")
os.setenv("HOME", users.home() or os.getenv("HOME") or "/")

shell.setAlias("reboot", "shutdown -r")
shell.setAlias("poweroff", "shutdown -P")
shell.setAlias("ll", "ls -l")
shell.setAlias("la", "ls -a")
shell.setAlias("lh", "ls -lh")
