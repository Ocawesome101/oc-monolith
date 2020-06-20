-- dmesg --

local args, opts = require("shell").parse(...)

if opts.e then
  repeat
    local e = table.pack(coroutine.yield())
    print(table.unpack(e))
  until e[1] == "key_down" and string.char(e[3]) == "q"
else
  local h = io.open("/tmp/monolith.log") or io.open("/monolith.log")
  print(h:read("*a"))
  h:close()
end
