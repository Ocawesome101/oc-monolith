-- vled - Visual Lua EDitor --
-- better than fled, probably worse than OpenOS's edit.lua. --

local editor = require("editor")
local shell = require("shell")
local readline = require("readline").readline

local w, h = io.stdout.gpu.getResolution()
local cur = 1
local cmd = true
local line = 1
local args, opts = shell.parse(...)

local help = opts.help or false
if opts.help then
  print()
  return
end

local file = args[1]
cur = editor.new(file)

local rlopts_insert = {
  actions = {
    up = function()
      line = line - 1
      return "return"
    end,
    down = function()
      line = line + 1
      return "return"
    end
  },
  highlighter = function(x) return x end,
  tabact = function(b)
    cmd = true
    return nil, "return"
  end,
  prompt = "~ ",
}

local cmdhistory = {}
local rlopts_cmd = {
  prompt = ":",
  history = cmdhistory,
  tabact = function(b)
    cmd = false
    return nil, "return"
  end,
  notrail = true
}

local running = true
-- this is very vi-inspired
local ops = {
  ["wq$"] = function()
    editor.buffers[cur]:save()
    running = false
  end,
  ["w$"] = function()
    editor.buffers[cur]:save()
  end,
  ["w (%S*)"] = function(f)
    editor.buffers[cur]:save(f)
  end,
  ["q$"] = function()
    running = false
  end,
  ["d(%d*)"] = function(n)
    n = tonumber(n) or 1
    for i=1,n,1 do
      table.remove(editor.buffers[cur].lines, line)
    end
  end,
  ["%%s/(%S+)/(%S*)/"] = function(f,r)
    for _,line in ipairs(editor.buffers[cur].lines) do
      line = line:gsub(f,r) or line
    end
  end,
  ["s/(%S+)/(%S*)/"] = function(f,r)
    editor.buffers[cur].lines[line] = editor.buffers[cur].line:gsub(f,r) or editor.buffers[cur].line
  end
}

local function parsecmd(c)
  for pat, func in pairs(ops) do
    if c:match(pat) then
      local a,b = pcall(func, c:match(pat))
      io.write("\n",tostring(a),"\t",tostring(b))
      return
    end
  end
end

io.write("\27[2J")
editor.buffers[cur]:draw()
while running do
  editor.buffers[cur]:draw()
  if cmd then
    io.write(string.format("\27[%d;1H", h - 1))
    parsecmd(readline(rlopts_cmd))
  else
    io.write(string.format("\27[%d;1H", line - editor.buffers[cur].scroll.h))
    rlopts_insert.prompt = string.format("\27[31m%"..tostring(#editor.buffers[cur].lines):len().."d\27[37m ", line)
    rlopts_insert.text = editor.buffers[cur].lines[line]
    local curl = line
    local text = readline(rlopts_insert)
    editor.buffers[cur].lines[curl] = text
    if line < 1 then line = 1 end
    if line > #editor.buffers[cur].lines then line = #editor.buffers[cur].lines end
    if line == curl then line = line + 1 table.insert(editor.buffers[cur].lines, line, "") end
  end
end
