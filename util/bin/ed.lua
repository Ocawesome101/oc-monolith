-- lua version of, you guessed it, ed --
-- written entirely in standard lua 5.3 --

local args={...}

local buf={""}
local cur=1
local prompt=false
local file = args[1]
local handle = io.open(file or "")
if handle then
  buf={}
  for line in handle:lines()do
    buf[#buf+1]=line.."\n"
  end
  handle:close()
end

local commands = {}
function commands.a(n)
  commands.i((n or#buf)+1)
end
function commands.c(a,b)
  commands.d(a,b)
  commands.i(a)
end
function commands.d(a,b)
  for i=a,b,1 do
    table.remove(buf,a)
  end
end
function commands.i(n)
  n=tonumber(n)or cur
  while true do
    local l=io.read()
    if l=="."or l==".\n" then break end
    table.insert(buf,n,l.."\n")
    n=n+1
  end
  cur=n
end
function commands.l()
  print(#buf)
end
function commands.p(a,b)
  for i=a,b,1 do
    io.write(buf[i]or"\n")
  end
end
function commands.P()
  prompt=not prompt
end
function commands.q()
  os.exit()
end
function commands.s(a,b,r)
  local old,new = r:match("/(%S*)/(%S*)/")
  for i=a, b, 1 do
    buf[i] = buf[i]:gsub(old,new)
  end
end
function commands.w(_,_,f)
  f=f or file
  f=f:gsub(" ","")
  if not f then
    print("?")
    return
  end
  local h=io.open(f,"w")
  local w=table.concat(buf)
  print(#w)
  h:write(w)
  h:close()
end

local pattern = "^(%d*)(,?)(%d*)(.)(%S*)$"

local function exec(c)
  if c:sub(1,1)=="#"then
    return
  end
  local l1,ca,l2,cm,rg=c:match(pattern)
  l1,l2=tonumber(l1),tonumber(l2)
  ca=ca==","
  if cm==""then
    if l1 then
      cur=l1
    end
    return
  end
  rg=(rg~=""and rg) or nil
  if not (l1 or l2) then
    if ca then
      l1=1
      l2=#buf
    else
      l1=cur
      l2=cur
    end
  elseif l1 and not l2 then
    if ca then
      l2=#buf
    else
      l2=l1
    end
  end
  --print(l1,ca,l2,cm,rg)
  if commands[cm] then
    local ok, err = pcall(commands[cm], l1,l2,rg)
    if not ok and err then
      print("?")
    end
  else
    print("?")
  end
end

while true do
  if prompt then io.write("*")end
  exec(io.read():gsub("\n",""))
end
