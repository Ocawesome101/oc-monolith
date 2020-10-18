-- vled - Visual Lua EDitor --
-- better than fled, probably worse than OpenOS's edit.lua. --

local vt = require("vt")
local editor = require("editor")
local shell = require("shell")
local readline = require("readline").readline

local w, h = vt.getResolution()
local cur = 1
local cmd = true
local line = 1
local args, opts = shell.parse(...)

local help = opts.help or false
if opts.help then
  print([[
vled / Visual Lua EDitor Copyright (C) 2020 Ocawesome101 under the GNU GPLv3.
usage:
  vled [options] [file]

options:
  -s  --syntax[=LANG]   Force syntax highlighting on.
  ]])
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
  prompt = "\27[93m~ \27[37m",
}

if file and opts.s or opts.highlight or opts.syntax then
  local ext = file:match(".+%.(.-)$") or opts.syntax
  if require("filesystem").exists("/lib/vled/"..ext..".lua") then
    local ok,hl=pcall(require, "vled."..ext, true)
    if not ok then
      print("WARNING: failed loading syntax for file extension " .. ext .. ": " .. hl)
      os.sleep(1)
      goto cont
    end
    rlopts_insert.highlighter = hl
    editor.buffers[cur].highlighter = hl
  end
end

::cont::
local cmdhistory = {}
local rlopts_cmd = {
  tabact = function(b)
    cmd = false
    return nil, "return_none"
  end,
  notrail = true,
  actions = {
    up = function()
      local c = editor.buffers[cur]
      if c.scroll.h > 3 then
        c.scroll.h = c.scroll.h - 4
      else
        c.scroll.h = 0
      end
      c:draw()
    end,
    down = function()
      local c = editor.buffers[cur]
      if c.scroll.h < #c.lines + h - 5 then
        c.scroll.h = c.scroll.h + 4
      else
        c.scroll.h = #c.lines + h - 2
      end
      c:draw()
    end
  }
}

local running = true
-- this is very vi-inspired
local ops = {
  ["^:wq$"] = function() -- write & quit
    editor.buffers[cur]:save()
    editor.buffers[cur] = nil
    running = false
  end,
  ["^:cq$"] = function() -- close & quit
    editor.buffers[cur] = nil
    running = false
  end,
  ["^:w$"] = function() -- write
    editor.buffers[cur]:save()
  end,
  ["^:w (%S*)"] = function(f) -- write to file
    editor.buffers[cur]:save(f)
  end,
  ["^:q$"] = function() -- quit
    running = false
  end,
  ["^:d(%d*)"] = function(n) -- delete lines
    n = tonumber(n) or 1
    for i=1,n,1 do
      table.remove(editor.buffers[cur].lines, line)
    end
  end,
  ["^:%%s/(%S+)/(%S*)/"] = function(f,r) -- global substitute
    for n,line in ipairs(editor.buffers[cur].lines) do
      editor.buffers[cur].lines[n] = line:gsub(f,r) or line
    end
  end,
  ["^:s/(%S+)/(%S*)/"] = function(f,r) -- current line substitute
    editor.buffers[cur].lines[line] = editor.buffers[cur].lines[line]:gsub(f,r) or editor.buffers[cur].lines[line]
  end,
  ["^:(%d+)$"] = function(n)
    n = tonumber(n)
    local min = 1
    local max = #editor.buffers[cur].lines
    line = (n > max and max) or (n < min and min) or n
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
  if #editor.buffers[cur].lines == 0 then
    editor.buffers[cur].lines[1] = "\n"
  end
  editor.buffers[cur]:draw()
  if line > #editor.buffers[cur].lines then line = #editor.buffers[cur].lines end
  if cmd then
    io.write(string.format("\27[%d;1H", h))
    parsecmd(readline(rlopts_cmd))
  else
    if editor.buffers[cur].scroll.h - line > h then
      line = editor.buffers[cur].scroll.h + 3
    end
    if line > editor.buffers[cur].scroll.h + h - 3 then
      line = editor.buffers[cur].scroll.h + h - 3
    end
    if (line - editor.buffers[cur].scroll.h) < 0 then
      line = editor.buffers[cur].scroll.h + 3
    end
    io.write(string.format("\27[%d;1H", line - editor.buffers[cur].scroll.h))
    rlopts_insert.prompt = string.format("\27[93m%"..tostring(#editor.buffers[cur].lines):len().."d\27[37m ", line)
    rlopts_insert.text = editor.buffers[cur].lines[line]:gsub("[\n]+", "")
    local curl = line
    local text = readline(rlopts_insert)
    if not (text == "" or text == "\n") then
      editor.buffers[cur].lines[curl] = text
    end
    if line < 1 then line = 1 end
    if line > #editor.buffers[cur].lines then line = #editor.buffers[cur].lines end
    if line == curl and not cmd then line = line + 1 table.insert(editor.buffers[cur].lines, line, "\n") end
    if line > editor.buffers[cur].scroll.h + h - 5 then editor.buffers[cur].scroll.h = editor.buffers[cur].scroll.h + 1 end
    if line < editor.buffers[cur].scroll.h + 5 and editor.buffers[cur].scroll.h > 0 then editor.buffers[cur].scroll.h = editor.buffers[cur].scroll.h - 1 end
  end
end

io.write("\27[2J\27[1H")
