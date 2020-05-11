-- install --

local shell = require("shell")
local component = require("component")
local fs = require("filesystem")
local config = require("config")

local args, opts = shell.parse(...)

local from = opts.from or args[1] or false
local to = opts.to or args[2] or false

local help = [[install (c) 2020 Ocawesome101 under the MIT license.
usage:
    install --from=<from> --to=<to>
or: install <from> <to>]]

if type(from) ~= "string" or type(to) ~= "string" then
  return shell.codes.argument
end

local ienv = setmetatable({install = {from = from, to = to}}, {__index = _G})

if not fs.exists(from) then
  shell.error("install", "source directory does not exist")
  return shell.codes.failure
end

if not fs.isDirectory(from) then
  shell.error("install", "source must be a directory")
  return shell.codes.failure
end

if fs.exists(to) and not fs.isDirectory(to) then
  shell.error("install", "destination must be a directory")
  return shell.codes.failure
end

fs.makeDirectory(to)
local check = fs.concat(from, ".install")
local prop = fs.concat(from, ".prop")

local ok, err
if fs.exists(check) then
  ok, err = xpcall(assert(loadfile(check, "bt", ienv)), debug.traceback)
elseif fs.exists(prop) then
  local cfg = config.load(prop)
  ok, err = xpcall(shell.execute, debug.traceback, "cp -rvi ")
else
end
