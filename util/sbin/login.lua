-- login --

local users = require("users")
local thread = require("thread")

io.write("\27[2J\27[1;1H\27[0m")
while true do
  io.write((os.getenv("HOSTNAME") or "localhost") .. " login: ")
  local uname = io.read():gsub("\n", "")
  io.write("password: \27[8m")
  local pwd = io.read():gsub("\n", "")
  io.write("\27[0m\n")

  local ok, err = users.login(uname, pwd)
  if not ok then
    io.write("\27[31m" .. err .. "\27[37m\n")
  else
    local shell = os.getenv("SHELL") or "/bin/sh.lua"
    local ok, err = loadfile(shell)
    if not ok then
      io.write("\27[31m" .. err .. "\27[37m\n")
    else
      local pid = thread.spawn(shell, "/bin/sh.lua", function(err)io.write("\27[31m" .. err .. "\27[37m\n")end)
      repeat
        local sig, pid = coroutine.yield()
      until sig == "thread_died" and dpid == pid
    end
  end
end
