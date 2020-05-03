-- mkdir is usually one of the last commands I implement. This time it's the 4th or 5th. --

local shell = require("shell")
local fs = require("filesystem")

local args, opts = shell.parse(...)

local NO = opts.p or false

if #args == 0 then
  return shell.codes.argument
end

for i=1, #args, 1 do
end
