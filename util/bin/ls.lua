-- ls --

local shell = require("shell")
local fs = require("filesystem")

local colors = {
  dir = 34,
  exec = 32,
  file = 37,
}

local args, opts = shell.parse(...)

local files = {}
local all = opts.a or opts.all or false
local inf = opts.l or false
local hmr = opts.h or opts["human-readable"] or false

local function color(col)
  return string.format("\27[%dm", col)
end

if #args == 0 then args[1] = os.getenv("PWD") or "/" end

local months = {
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec"
}

local function date(ms)
  local d = os.date("*t", ms)
  local day = tostring(d.day)
  if #day < 2 then day = day .. " " end
  return d.year, months[d.month], day, d.hour, d.min
end

local function fsize(size)
  local ret = size or 0
  if hmr and ret >= 1024 then
    ret = ((size / 1024) - ((size / 1024) % 0.1)) .. "k"
  end
  local r = tostring(ret)
  return r .. (" "):rep(6 - #r)
end

for i=1, #args, 1 do
  local dir = args[i]
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
  for i=1, #files, 1 do
    local f = files[i]
    local finfo = ""
    if inf then
      local full = dir .. "/" .. files[i]
      local size = fs.size(full)
      local isdr = fs.isDirectory(full)
      local isro = fs.isReadOnly(full)
      local yr, mon, day, hr, min = date(fs.lastModified(full))
      finfo = string.format("\27[37m%s%s %s %s %s %d %d:%d ", (isdr and "d") or "-", (isro and "r-") or "rw", fsize(size), mon, day, yr, hr, min)
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
      out = out .. f .. ((i < #files and "\n") or "")
    end
  end
  print(out .. color(37))
end

return shell.codes.exit
