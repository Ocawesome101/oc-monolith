-- less --

local shell = require("shell")
local readline = require("readline").readline

local args, opts = shell.parse(...)

if #args == 0 then
  return shell.codes.argument
end

local handle = assert(io.open(args[1], "r"))

io.write("\27[1000;1000H\27[6n\27[2J")
local resp = ""
repeat
  local c = io.read(1)
  resp = resp .. c
until c == "R"
local h, w = resp:match("\27%[(%d+);(%d+)R")
w, h = tonumber(w), tonumber(h)
local lines = {}
local screen = 0
for line in handle:lines() do
  lines[#lines + 1] = line:gsub("\n", "")
  screen = screen + math.max(1, math.ceil(#line / w))
end
handle:close()
local scroll = 0

local function drawLine(y, txt)
  io.write(string.format("\27[%d;1H%s", y, txt))
  return math.max(1, math.ceil(#txt / w))
end

local function redraw(a)
  io.write("\27[2J")
  local y = 1
  local n = 1
  while y < h - 1 do
    y = y + drawLine(y, lines[n + scroll] or "")
    n = n + 1
  end
  if scroll + h >= screen then
    drawLine(h, "\27[2K\27[30;47m(END)\27[37;40m")
  else
    drawLine(h, "\27[2K"..a..":")
  end
  --io.write(string.format("\27[%d;%dH%5d/%5d", w - 11, h, h + scroll, screen))
end

local fname = (not opts.noshow and not opts.n and args[1]) or ""
while true do
  redraw(fname)
  fname = ""
  local esc = readline(1)
  if esc == "\27" then esc = esc .. readline(2) end
  if esc == "\27[A" or esc == "w" then
    if scroll > 0 then
      scroll = scroll - 1
    end
  elseif esc == "\27[B" or esc == "s" then
    if scroll + h <= screen then
      scroll = scroll + 1
    end
  elseif esc == " " or esc == "\27[6" then
    if scroll + h*2 <= screen then
      scroll = scroll + h
    else
      scroll = screen - h
    end
  elseif esc == "\27[5" then -- pageup
    if scroll >= h then
      scroll = scroll - h
    else
      scroll = 0
    end
  elseif esc == "q" then
    io.write("\27[2J")
    break
  end
end
