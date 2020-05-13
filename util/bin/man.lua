-- man --

local shell = require("shell")
local fs = require("filesystem")

local args, opts = shell.parse(...)

if #args == 0 or tonumber(args[1]) then
  print("What manual page do you want?\nFor example, try 'man man'.")
  return 0
end

local less = assert(loadfile("/bin/less.lua"))
local manpath = os.getenv("MANPATH") or "/usr/man:/usr/local/man:/usr/share/man"
os.setenv("MANPATH", manpath)

local sects = {
  ".1",
  ".3",
  ".4",
  ".2",
  ".5"
}

if opts.section then
  sects = {"." .. opts.section}
elseif tonumber(args[1]) then
  sects = {"." .. table.remove(args, 1)}
end

local function search(page)
  for path in manpath:gmatch("[^:]+") do
    local try = path .. "/" .. page
    for _, sect in pairs(sects) do
      if fs.exists(try .. sect) then
        return try .. sect
      end
    end
    if fs.exists(try) then
      return try
    end
  end
  return nil, "no manual entry for " .. page
end

for i=1, #args, 1 do
  less(assert(search(args[i])))
end
