-- ed clone in pure Lua --

local buffers = {}

local help = [[LuaEd 0.4.0 copyright (c) 2020 Ocawesome101 under the GNU GPLv3.
Commands:
'h':     Show this help
'e':     Open a file
'a':     Append to a file
'o':     Overwrite a file
'i' <l>: Insert at line
's' [f]: Save the current buffer
'c':     Close the current buffer
'b' [n]: List buffers or, select buffer
'n' [n]: Create buffer
'r' <n>: Rename the current buffer
'p' [l] [l]: Print contents of current buffer from line to line
'l' [l]: Overwrite line
]]

local function promptread()
  io.write("\27[33med: \27[37m")
  return io.read()
end

local function lineread(line)
  io.write("\27[31m " .. line .. "\27[37m ")
  return io.read()
end

local function split(w)
  local W = {}
  for _w in w:gmatch("[^ \n]+") do
    table.insert(W, _w)
  end
  return W
end

local function fload(f)
  local handle, err = io.open(f, 'r')
  if not handle then
    return nil, err
  end
  local nbuf = #buffers + 1
  local buf = {}
  for line in handle:lines() do
    buf[#buf + 1] = line .. "\n"
  end
  handle:close()
  buffers[nbuf] = {buffer = buf, name = f}
  return nbuf
end

local function fsave(b, f)
  if not buffers[b] then
    return nil, "no such buffer"
  end
  local handle, err = io.open(f or buffers[b].name, "w")
  if not handle then
    return nil, err
  end
  for i=1, #buffers[b].buffer, 1 do
    handle:write(buffers[b].buffer[i])
  end
  handle:close()
end

local function bnew(name)
  local nbuf = #buffers + 1
  buffers[nbuf] = {buffer = {}, name = "<new>"}
  buffers[nbuf].name = name or "buffer: " .. tostring(buffers[nbuf].buffer):gsub("[^%x]+", "")
  return true
end

local function bname(b, n)
  if not buffers[b] then
    return nil, "no such buffer"
  end
  buffers[b].name = n
end

local function blist()
  for i=1, #buffers, 1 do
    io.write(string.format(" \27[31m%d \27[37m%s\n", i, buffers[i].name))
  end
  return true
end

local function bprint(b, l1, l2)
  if not buffers[b] then
    return nil, "no such buffer"
  end
  for i=(l1 or 1), (l2 or #buffers[b].buffer), 1 do
    io.write(string.format(" \27[31m%d \27[37m%s", i, buffers[b].buffer[i]))
  end
  io.write("\n")
  return true
end

local function bedit(b, m, c)
  if not buffers[b] then
    return nil, "no such buffer"
  end
  local buf = buffers[b].buffer
  local ln
  if m == "a" then
    ln = #buf
  elseif m == "o" then
    buf = {}
    ln = 1
  elseif m == "i" then
    ln = c
  elseif m == "l" then
    ln = c
    local line = lineread(ln):gsub("\n", "")
    buffers[b].buffer[ln] = line .. "\n"
    return true, buffers[b].buffer[ln]
  else
    return nil, "wrong mode"
  end
  while true do
    local line = lineread(ln):gsub("\n", "")
    if line == "." then
      buffers[b].buffer = buf
      return true
    else
      table.insert(buf, ln, line .. "\n")
      ln = ln + 1
    end
  end
  return true
end

local cur = 0
while true do
  local cin = split(promptread())
  if #cin > 0 then
    if cin[1] == 'h' then
      print(help)
    elseif cin[1] == 'e' then
      if not cin[2] then print(nil, "not enough parameters")
      else print(fload(cin[2])) end
    elseif cin[1] == 'o' then
      print(bedit(cur, "o"))
    elseif cin[1] == 'a' then
      print(bedit(cur, "a"))
    elseif cin[1] == 'i' then
      if not tonumber(cin[2]) then print(nil, "not enough parameters")
      else print(bedit(cur, 'i', tonumber(cin[2]))) end
    elseif cin[1] == 's' then
      print(fsave(cur, cin[2]))
    elseif cin[1] == 'c' then
      buffers[cur] = nil
    elseif cin[1] == 'b' then
      if cin[2] then
        local n = tonumber(cin[2])
        if buffers[n] then
          cur = n
        else
          print(nil, "no such buffer")
        end
      else
        blist()
      end
    elseif cin[1] == 'n' then
      print(bnew(cin[2]))
    elseif cin[1] == 'r' then
      if not cin[2] then print(nil, "not enough parameters")
      else print(bname(cur, cin[2])) end
    elseif cin[1] == 'x' then
      break
    elseif cin[1] == 'p' then
      print(bprint(cur, tonumber(cin[2]), tonumber(cin[3])))
    elseif cin[1] == 'l' then
      print(bedit(cur, 'l', tonumber(cin[2])))
    end
  end
end
