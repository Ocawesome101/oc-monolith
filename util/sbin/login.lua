-- login --

local users = require("users")
local thread = require("thread")
local readline = require("readline")

local out = io.output()
local inp = io.input()

local logo = [[
 _____                 _  o  _-_  _
|     | ___  ___  ___ | | _ |_ _|| |_
| | | || . ||   || . || || | | | |   |
|_|_|_||___||_|_||___||_||_| |_| |_|_|
 This is the Monolith system. Welcome.]]

out:write("\27[2J\27[1;1H\27[0;37m" .. logo .. "\n\n")
while true do
  local uname = readline.readline({prompt=(os.getenv("HOSTNAME") or "localhost").." login: "})
  uname = (uname or ""):gsub("\n", "")
  local pwd = readline.readline({prompt="password: ", pwchar="*", notrail = true})
  out:write("\n")

  local ok, err = users.login(uname, pwd)
  if not ok then
    out:write("\27[31m" .. err .. "\27[37m\n")
  else
    local shell = os.getenv("SHELL") or "/bin/sh.lua"
    local ok, err = loadfile(shell)
    if not ok then
      out:write("\27[31m" .. err .. "\27[37m\n")
    else
      local pid = thread.spawn(ok, shell, function(err)out:write("\27[31m" .. err .. "\27[37m\n")end)
      repeat
        local sig, dpid, err = coroutine.yield()
        if sig == "thread_errored" and err and dpid == pid then
          io.write("\27[31m" .. err .. "\27[37m\nResetting in 10 seconds.\n")
          os.sleep(10)
        end
      until ((sig == "thread_died" or sig == "thread_errored") and dpid == pid) and (not thread.info(pid))
      out:write("\27[2J\27[1;1H\27[0m") -- reset screen attributes
    end
  end
end
