-- dmesg --

repeat
  local s, a, id, p1, p2, p3, p4, p5, p6, p7 = coroutine.yield()
  print(s, a, id, p1, p2, p3, p4, p5, p6, p7)
until s == "key_down" and string.char(id) == "q"
