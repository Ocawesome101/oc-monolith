-- login --

local users = require("users")
local thread = require("thread")

local out = io.output()
local inp = io.input()
out:write("\27[2J\27[1;1H\27[0m")
while true do
  out:write((os.getenv("HOSTNAME") or "localhost") .. " login: ")
--  print("LOGIN READ")
  local uname = inp:read():gsub("\n", "")
  out:write("password: \27[8m")
  local pwd = inp:read():gsub("\n", "")
  out:write("\27[0m\n")

  local ok, err = users.login(uname, pwd)
  if not ok then
    out:write("\27[31m" .. err .. "\27[37m\n")
  else
    local shell = os.getenv("SHELL") or "/bin/sh.lua"
    local ok, err = loadfile(shell)
    if not ok then
      out:write("\27[31m" .. err .. "\27[37m\n")
    else
      local pid = thread.spawn(ok, shell, function(err)out:write("\27[31m" .. err .. "\27[37m\n")end, nil, inp, out)
      repeat
        local sig, dpid, err = coroutine.yield()
        if sig == "thread_errored" and err then
          io.write("\27[31m" .. err .. "\27[37m\n")
        end
      until sig == "thread_died" or sig == "thread_errored" and dpid == pid
      out:write("\27[2J\27[1;1H\27[0m") -- reset screen attributes
    end
  end
end
