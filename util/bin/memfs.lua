-- memfs --

error("memfs is broken, sorry :/")
local shell = require("shell")
local memfs = require("memfs")
local files = require("filesystem")

local args, opts = shell.parse(...)

if opts.create then
  local new = memfs.new(opts.label or "memfs", opts.ro or false)
  files.mount(new, opts.mount or "/mnt/" .. new.address:sub(1,3))
end
