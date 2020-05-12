-- man --

local shell = require("shell")
local fs = require("filesystem")

local args, opts = shell.parse(...)

if #args == 0 then
  print("What manual page do you want?\nFor example, try 'man man'.")
  return 0
end

local less = assert(loadfile("/bin/less.lua"))
local manpath = os.getenv("MAN_PATH") or "/usr/man:/usr/local/man:/usr/share/man"
os.setenv("MAN_PATH", manpath)

local function search(page)
  for path in manpath:gmatch("[^:]+") do
    local try = path .. "/" .. page
    if fs.exists(try) then
      return try
    end
  end
  return nil, "no manual entry for " .. page
end

for i=1, #args, 1 do
  less(assert(search(args[i])))
end
