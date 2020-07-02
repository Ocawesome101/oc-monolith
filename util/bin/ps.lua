local args, opts = require("shell").parse(...)
local thread = require("thread")
local users = require("users")
local mode = args[1]
local time = require("time").formatTime -- time! time! give me more time!

local out = ""
local thd = thread.threads()
if not mode then
  print("PID  | PARENT | OWNER        | NAME")
elseif mode == "a" then
  print("PID  | PARENT | OWNER        | START    | TIME     | NAME")
else
  return require("shell").codes.argument
end
for n, pid in ipairs(thd) do
  local info = thread.info(pid)
  if not mode then
    print(string.format("%4x |   %4x | %12s | %s", pid, info.parent, users.getname(info.owner), info.name))
  elseif mode == "a" then
    print(string.format("%4x |   %4x | %12s | %8s | %8s | %s", pid, info.parent, users.getname(info.owner), time(info.started, "s", true), time(info.uptime, "s", true), info.name))
  end
end

io.write(out)
