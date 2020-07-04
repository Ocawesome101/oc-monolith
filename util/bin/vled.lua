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
  prompt = "~ "
}

local cmdhistory = {}
local rlopts_cmd = {
  prompt = ":",
  history = cmdhistory,
  tabact = function(b)
    cmd = false
    return nil, "return"
  end
}

local running = true
-- this is very vi-inspired
local ops = {
  ["wq$"] = function()
    editor.buffers[cur]:save()
    running = false
  end,
  ["w$"] = function(f)
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
      print(xpcall(func, c:match(pat)))
      return
    end
  end
end

editor.buffers[cur]:draw()
while running do
  if cmd then
    io.write(string.format("\27[%dH", h))
    parsecmd(readline(rlopts_cmd))
  else
    editor.buffers[cur]:draw()
    rlopts_insert.prompt = string.format("%"..tostring(editor.buffers[cur].lines):len().."s ", line)
    rlopts_insert.text = editor.buffers[cur].lines[line]
    local line = readline(rlopts_insert)
  end
end
