-- rm --

local shell = require("shell")
local fs = require("filesystem")

local args, opts = shell.parse(...)

if #args == 0 then
  return shell.codes.argument
end

local ask = opts.i or false
local force = opts.f or false
local prsv = (not opts["no-preserve-root"])
local rcrs = opts.r or opts.R or opts.recursive or false
local vrbs = opts.v or opts.verbose or false

for i=1, #args, 1 do
  local rm = args[i]
  local full = fs.canonical(args[i])
  if not fs.exists(full) then
    if not force then
      shell.error("rm", string.format("%s: no such file or directory", rm))
      return shell.codes.argument
    end
  elseif fs.isDirectory(full) and not rcrs then
    print(string.format("rm: cannot remove directory '%s'", rm))
  else
    local _rm = true
    if ask then
      io.write(string.format("rm: remove '%s'? [y/N]: "))
      local inp = io.read():gsub("\n", ""):lower()
      if inp == "y" then
        _rm = true
      else
        _rm = false
      end
    end
    if _rm then
      fs.remove(full)
    end
    if vrbs then
      print(string.format("%s '%s'", (_rm and "removed") or "skipped", rm))
    end
  end
end

return shell.codes.exit
