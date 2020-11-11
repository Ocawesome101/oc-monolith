-- ls --

local shell = require("shell")
local fs = require("filesystem")
local vt = require("vt")

local x, y = 1, 1
local w, h = math.huge, math.huge 
if io.stdout.tty and io.stdin.tty then
  x, y = vt.getCursor()
  w, h = vt.getResolution()
end

local args, opts = shell.parse(...)

local files = {}
local all = opts.a or opts.all or false
local inf = opts.l or false
local hmr = opts.h or opts["human-readable"] or false
local col = (not opts.nocolor) or (opts.color) or false

local colors = {dir=37, exec=37, file=37}
if col then
  local lscol = os.getenv("LS_COLORS") or "dir=34:exec=32:file=37"
  for seg in lscol:gmatch("[^:]+") do
    local k, v = seg:match("^(.-)=(.-)$")
    k = k or ""
    v = tonumber(v) or 37
    colors[k] = v
  end
end

local function color(colo)
  if not io.stdout.tty then -- not connected to a terminal
    return ""
  end
  return string.format("\27[%dm", col and colo or 39)
end

if #args == 0 then args[1] = os.getenv("PWD") or "/" end

local units = {
  "",
  "K",
  "M",
  "G",
  "T"
}

local function fsize(size)
  local ret = size or 0
  local unit = 1
  while hmr and ret >= 1024 do
    ret = ((size / 1024) - ((size / 1024) % 0.1))
    unit = unit + 1
  end
  local r = tostring(ret) .. units[unit]
  return r .. (" "):rep(5 - #r)
end

for i=1, #args, 1 do
  local dir = fs.canonical(args[i])
  if not fs.exists(dir) then
    shell.error("ls", string.format("%s: no such file or directory", dir))
    return shell.codes.failure
  end
  
  if #args > 1 then
    print(((i > 1 and "\n") or "") .. args[i] .. ":")
  end

  if fs.isDirectory(dir) then
    files = fs.list(dir)
    if all then
      table.insert(files, "./")
      if dir ~= "/" then table.insert(files, "../") end
    end
  else
    files = {fs.name(dir)}
    dir = fs.path(dir)
  end
  local out = ""
  local longest = 0
  table.sort(files)
  for i=1, #files, 1 do
    if #files[i] > longest then longest = #files[i] end
  end
  local n = 1
  for i=1, #files, 1 do
    local f = files[i]
    local finfo = ""
    if inf then
      local full = dir .. "/" .. files[i]
      local size = fs.size(full)
      local isdr = fs.isDirectory(full)
      local isro = fs.isReadOnly(full)
      local date = os.date("%b %d %Y %H:%M", fs.lastModified(full))
      finfo = string.format("\27[37m%s%s %s %s ",
                            isdr and "d" or "-",
                            isro and "r-" or "rw",
                            fsize(size), date)
    end
    out = out .. finfo
    if f:sub(-1) == "/" then
      out = out .. color(colors.dir)
    elseif f:sub(-4) == ".lua" then
      out = out .. color(colors.exec)
    else
      out = out .. color(colors.file)
    end
    if f:sub(1,1) ~= "." or all then
      if inf then out = out .. f .. "\n"
      else
        if n + longest >= w and n ~= 1 then out = out .. "\n" n = 1 end
        out = out .. f
        n = n + longest + 2
        if n + (longest - #f + 2) >= w then
          n = 1 out = out .. "\n"
        else
          out = out .. (" "):rep(longest - #f + 2)
        end
      end
    end
  end
  print(out .. color(37))
end

--print(w, h)
--print(x, y)
return shell.codes.exit
