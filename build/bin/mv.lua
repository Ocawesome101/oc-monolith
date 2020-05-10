-- mv --

local shell = require("shell")

local args, opts = shell.parse(...)

shell.execute("cp -r", table.unpack(args))
shell.execute("rm -r", table.unpack(args, 1, #args - 1))
