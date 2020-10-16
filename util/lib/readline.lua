-- relatively flexible readline implementation --

local component = require("component")
local unicode = require("unicode")
local rl = {}

-- basic readline function similar to the original vt100.session one
local function rlbasic(n)
  io.write("\27[108m")
  local ret = io.read(1)
  io.write("\27[128m")
  return ret
end

local function getResolution()
  io.write("\27[9999;9999H\27[6n")
  local resp = ""
  repeat
    local c = rlbasic(1)
    resp = resp .. c
  until c == "R"
  local h, w = resp:match("\27%[(%d+);(%d+)R")
  return tonumber(w), tonumber(h)
end

-- fancier readline designed to be used directly
function rl.readline(prompt, opts)
  checkArg(1, prompt, "string", "number", "table", "nil")
  checkArg(2, opts, "table", "nil")
  if type(prompt) == "table" then opts = prompt prompt = nil end
  if type(prompt) == "number" then return rlbasic(prompt) end
  opts = opts or {}
  local pwchar = opts.pwchar or nil
  local history = opts.history or {}
  local ent = #history + 1
  local prompt = prompt or opts.prompt
  local arrows = opts.arrows
  if arrows == nil then arrows = true end
  local pos = 1
  local buffer = opts.default or opts.text or ""
  local highlighter = opts.highlighter or opts.syntax or function(e)return e end
  local redraw
  local acts = opts.acts or opts.actions or {}
  setmetatable(acts, {__index = {
    up = function()
      if ent > 1 then
        history[ent] = buffer
        ent = ent - 1
        buffer = (" "):rep(unicode.len(buffer))
        redraw()
        buffer = history[ent] or ""
        pos = 1
      end
    end,
    down = function()
      if ent <= #history then
        history[ent] = buffer
        ent = ent + 1
        buffer = (" "):rep(unicode.len(buffer))
        redraw()
        buffer = history[ent] or ""
        pos = 1
      end
    end,
    left = function(ctrl)
      if ctrl then
        pos = unicode.len(buffer) + 1
      elseif pos <= unicode.len(buffer) then
        pos = pos + 1
      end
    end,
    right = function(ctrl)
      if ctrl then
        pos = 1
      elseif pos > 1 then
        pos = pos - 1
      end
    end
  }})
  local tabact = opts.complete or opts.tab or opts.tabact or function(x) return x end
  io.output():write("\27[6n")
  local resp = ""
  repeat
    local char = rlbasic(1)
    resp = resp .. char
  until char == "R"
  local y, x = resp:match("\27%[(%d+);(%d+)R")
  local w, h = getResolution() -- :^)
  local sy = tonumber(y) or 1
  prompt = ("\27[C"):rep((tonumber(x) or 1) - 1) .. (prompt or "")
  local lines = 1
  function redraw()
    local write = highlighter(buffer)
    if pwchar then write = pwchar:rep(unicode.len(buffer)) end
    local written = math.max(1, math.ceil((unicode.len(buffer) + unicode.len(prompt)) / w))
    if written > lines then
      local diff = written - lines
      io.write(string.rep("\27[B", diff) .. string.rep("\27[A", diff))
      if (sy + diff + 1) >= h then
        sy = sy - diff
      end
      lines = written
    end
    io.write(string.format("\27[%d;%dH%s%s %s", sy, 1, prompt, write, string.rep("\8", pos)))
  end
  while true do
    redraw()
    local char, err = rlbasic(screen, 1)
    if char == "\27" then
      if arrows then -- ANSI escape start
        local esc = rlbasic(screen, 2)
        local _, r
        if esc == "[A" and acts.up then
          _, r = pcall(acts.up)
        elseif esc == "[B" and acts.down then
          _, r = pcall(acts.down)
        elseif esc == "[C" then
          _, r = pcall(acts.right, buffers[screen].down[keys.lcontrol] or buffers[screen].down[keys.rcontrol])
        elseif esc == "[D" then
          _, r = pcall(acts.left, buffers[screen].down[keys.lcontrol] or buffers[screen].down[keys.rcontrol])
        end
        if r == "return" then -- HAX
          table.insert(history, buffer)
          io.write("\n")
          if not opts.notrail then buffer = buffer .. "\n" end
          return buffer, history
        end
      else
        buffer = buffer .. "^"
      end
    elseif char == "\8" then
      if #buffer > 0 and pos <= unicode.len(buffer) then
        buffer = buffer:sub(1, (unicode.len(buffer) - pos)) .. buffer:sub((unicode.len(buffer) - pos) + 2)
      end
    elseif char == "\13" or char == "\10" or char == "\n" then
      table.insert(history, buffer)
      io.write("\n")
      if not opts.notrail then buffer = buffer .. "\n" end
      return buffer, history
    elseif buffers[screen].down[keys.lcontrol] or buffers[screen].down[keys.rcontrol] then
      if char == "a" then
        pos = unicode.len(buffer)
      elseif char == "b" then
        pos = 1
      end
    elseif char == "\t" then
      local nbuf, act = tabact(buffer)
      if nbuf then
        buffer = nbuf
      end
      if act == "return" then
        table.insert(history, buffer)
        io.write("\n")
        if not opts.notrail then buffer = buffer .. "\n" end
        return buffer, history
      elseif act == "return_none" then
        io.write("\n")
        return "\n"
      end
    else
      buffer = buffer:sub(1, (unicode.len(buffer) - pos) + 1) .. char .. buffer:sub((unicode.len(buffer) - pos) + 2)
    end
  end
end

return rl
