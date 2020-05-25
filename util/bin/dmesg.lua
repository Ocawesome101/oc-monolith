-- dmesg --

repeat
  local e = table.pack(coroutine.yield())
  print(table.unpack(e))
until e[1] == "key_down" and string.char(e[3]) == "q"
