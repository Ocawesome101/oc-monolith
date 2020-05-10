-- label --

local shell = require("shell")
local component = require("component")
local fs = require("filesystem")

local args, opts = shell.parse(...)

if #args == 0 then
  shell.error("usage", "label <address> [label]")
  return shell.codes.argument
end

local fsa = args[1]

if fs.canonical(fsa) and fs.exists(fs.canonical(fsa)) then
  fsa = fs.get(fs.canonical(fsa)).address
else
  fsa = component.get(fsa)
end

if #args == 1 then
  print(string.format("label of %s is '%s'", fsa, component.invoke(fsa, "getLabel") or "nil"))
else
  local new = component.invoke(fsa, "setLabel", args[2])
  print(string.format("set label of %s to '%s'", fsa, new))
end
