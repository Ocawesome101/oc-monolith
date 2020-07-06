-- profile --

local shell = require("shell")
local users = require("users")

os.setenv("EDITOR", "/bin/vled.lua")
os.setenv("PS1", "\27[32m\\u\27[37m@\27[32m\\h\27[37m: \27[34m\\w\27[37m\\$ ")
os.setenv("HOME", users.home() or os.getenv("HOME") or "/")
os.setenv("PATH", os.getenv("PATH") or "/bin:/sbin:/usr/bin:/usr/local/bin:$HOME/.local/bin")

shell.setAlias("reboot", "shutdown -r")
shell.setAlias("poweroff", "shutdown -P")
shell.setAlias("logout", "exit")
shell.setAlias("ll", "ls -l")
shell.setAlias("la", "ls -a")
shell.setAlias("lh", "ls -lh")
shell.setAlias("edit", "$EDITOR")
