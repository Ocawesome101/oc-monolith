-- rudimentary GitHub client - may add support for other protocols, we shall see --

local shell = require("shell")
local internet = require("internet")
local json = require("json")

local args, opts = shell.parse(...)
