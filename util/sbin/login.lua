-- login --

local users = require("users")
local process = require("process")
local readline = require("readline")

local out = io.output()
local inp = io.input()
out:write("\27[2J\27[1;1H\27[0;37m" .. _OSVERSION .. --[[" - " .. require("computer").freeMemory() // 1024 .. "k free]]"\n\n")
while true do
  --print("LOGIN READ")
  local uname = readline.readline({prompt=(os.getenv("HOSTNAME") or "localhost").." login: "}):gsub("\n", "")
  --print("READ DONE")
  local pwd = readline.readline({prompt="password: ", pwchar="*", notrail = true})
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
      local pid = process.spawn(ok, shell, function(err)out:write("\27[31m" .. err .. "\27[37m\n")end)
      repeat
        local sig, dpid, err = coroutine.yield()
        if sig == "thread_errored" and err and dpid == pid then
          io.write("\27[31m" .. err .. "\27[37m\n")
          os.sleep(10)
        end
      until ((sig == "thread_died" or sig == "thread_errored") and dpid == pid) and (not thread.info(pid))
      --os.sleep(10)
      out:write("\27[2J\27[1;1H\27[0m") -- reset screen attributes
    end
  end
end
