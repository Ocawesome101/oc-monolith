-- build Monolith.... inside Monolith! --

local component = require("component")
local preproc = require("preproc")
local fs = require("filesystem")
local shell = require("shell")
local cp = require("cp")
cp.verbose = true
cp.recurse = true

local args, opts = shell.parse(...)

local build = fs.canonical("build/")

if opts.builddir and type(opts.builddir) == "string" then
  build = fs.canonical(opts.builddir)
end

local function log(...)
  print("\27[92m->\27[97m", ...)
end

log("Building kernel")
