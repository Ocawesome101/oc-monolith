-- modules --

local shell = require("shell")
local mod = require("module")
local args, opts = shell.parse(...)

local rm = opts.r or opts.remove or false

if #args < 1 then
  shell.error("mod", "usage: mod [-r] MODULE1 MODULE2 ...")
  return shell.codes.argument
end

if rm then
  for _, m in ipairs(args) do
    local ok, err = mod.unload(m)
    if not ok then
      shell.error("mod", err)
      return shell.codes.failure
    end
  end
else
  for _, m in ipairs(args) do
    local ok, err = mod.load(m)
    if not ok then
      shell.error("mod", err)
      return shell.codes.failure
    end
  end
end
