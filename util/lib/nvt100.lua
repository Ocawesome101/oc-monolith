-- A new vt100 emulator, with some major improvements. --
-- This is actually ported from the failed Paragon project.

local event = require("event")
local buffer = require("buffer")
local unicode = require("unicode")
local computer = require("computer")
local component = require("component")

local vt = {}

-- these are the default VGA colors
-- TODO: support loading from /etc/vtcolors.cfg
local colors = {
  0x000000,
  0xaa0000,
  0x00aa00,
  0xaaaa00,
  0x0000aa,
  0xaa00aa,
  0x00aaaa,
  0xaaaaaa
}
local bright = {
  0x555555,
  0xff5555,
  0x55ff55,
  0xffff55,
  0x5555ff,
  0xff55ff,
  0x55ffff,
  0xffffff
}
-- and these are the 240 \27[38;5;NNNm colors
local palette = {
  0x000000,
  0xaa0000,
  0x00aa00,
  0xaaaa00,
  0x0000aa,
  0xaa00aa,
  0x00aaaa,
  0xaaaaaa,
  0x555555,
  0xff5555,
  0x55ff55,
  0xffff55,
  0x5555ff,
  0xff55ff,
  0x55ffff,
  0xffffff,
  0x000000
}
-- programmatically generate the rest since they follow a pattern
local function inc(n)
  if n >= 0xff then
    return 0
  else
    return n + 40
  end
end
local function pack(r,g,b)
  return (r << 16) + (g << 8) + b
end
local r, g, b = 0x5f, 0, 0
local i = 0

repeat
  table.insert(palette, pack(r, g, b))
  b = inc(b)
  if b == 0 then
    b = 0x5f
    g = inc(g)
  end
  if g == 0 then
    g = 0x5f
    r = inc(r)
  end
  if r == 0 then
    break
  end
until r == 0xff and g == 0xff and b == 0xff

table.insert(palette, pack(r,g,b))

for i=0x8, 0xee, 10 do
  table.insert(palette, pack(i,i,i))
end

local min, max = math.min, math.max

-- This function takes a gpu and screen address and returns a (non-buffered!) stream.
function vt.emu(gpu, screen)
  checkArg(1, gpu, "string", "table")
  checkArg(2, screen, "string", "nil")
  if type(gpu) == "string" then gpu = component.proxy(gpu) end
  if screen then gpu.bind(screen) end
  local mode = 0
  -- TTY modes:
  -- 0: regular text
  -- 1: received '\27'
  -- 2: received '\27[', in escape
  local rb = ""
  local wb = ""
  local nb = ""
  local ec = true -- local echo
  local lm = true -- line mode
  local cx, cy = 1, 1
  local fg, bg = colors[8], colors[1]
  local w, h = gpu.maxResolution()
  gpu.setResolution(w, h)

  local function scroll(n)
    n = n or 1
    gpu.copy(1, 1, w, h, 0, -n)
    gpu.fill(1, h - n + 1, w, n + 1, " ")
  end

  local function checkCursor()
    if cx > w then cx, cy = 1, cy + 1 end
    if cy >= h then cy = h - 1scroll(1) end
    if cx < 1 then cx = w cy = cy - 1 end
    if cy < 1 then cy = 1 end
  end

  local function flushwb()
    while unicode.len(wb) > 0 do
      checkCursor()
      local ln = unicode.sub(wb, 1, w - cx + 1)
      if ec then
        gpu.set(cx, cy, ln)
        cx = cx + unicode.len(ln)
      end
      wb = unicode.sub(wb, unicode.len(ln) + 1)
    end
  end

  local stream = {}

  local p = {}
  -- Write a string to the stream. The string will be parsed for vt100 codes.
  function stream:write(str)
    checkArg(1, str, "string")
    if self.closed then
      return nil, "input/output error"
    end
    str = str:gsub("\8", "\27[D")
    local _c = gpu.get(cx, cy)
    gpu.setForeground(fg)
    gpu.setBackground(bg)
    gpu.set(cx, cy, _c)
    for c in str:gmatch(".") do
      if mode == 0 then
        if c == "\n" then
          flushwb()
          cx, cy = 1, cy + 1
          checkCursor()
        elseif c == "\t" then
          if cx + 8 > w then
            cx, cy = 1, cy + 1
            checkCursor()
          else
            wb = wb .. (" "):rep(max(1, (cx + 4) % 8))
          end
        elseif c == "\27" then
          flushwb()
          mode = 1
        elseif c == "\7" then -- ascii BEL
          computer.beep(".")
        else
          wb = wb .. c
        end
      elseif mode == 1 then
        if c == "[" then
          mode = 2
        else
          mode = 0
        end
      elseif mode == 2 then
        if c:match("%d+") then
          nb = nb .. c
        elseif c == ";" then
          if #nb > 0 then
            p[#p+1] = tonumber(nb) or 0
            nb = ""
          end
        else
          mode = 0
          if #nb > 0 then
            p[#p+1] = tonumber(nb) or 0
            nb = ""
          end
          if c == "A" then
            cy = cy + max(0, p[1] or 1)
          elseif c == "B" then
            cy = cy - max(0, p[1] or 1)
          elseif c == "C" then
            cx = cx + max(0, p[1] or 1)
          elseif c == "D" then
            cx = cx - max(0, p[1] or 1)
          elseif c == "E" then
            cx, cy = 1, cy + max(0, p[1] or 1)
          elseif c == "F" then
            cx, cy = 1, cy - max(0, p[1] or 1)
          elseif c == "G" then
            cx = min(w, max(p[1] or 1))
          elseif c == "H" or c == "f" then
            cx, cy = min(w, max(0, p[2] or 1)), min(h, max(0, p[1] or 1))
          elseif c == "J" then
            local n = p[1] or 0
            if n == 0 then
              gpu.fill(cx, cy, w, 1, " ")
              gpu.fill(cx, cy + 1, h, " ")
            elseif n == 1 then
              gpu.fill(1, 1, w, cy - 1, " ")
              gpu.fill(cx, cy, w, 1, " ")
            elseif n == 2 then
              gpu.fill(1, 1, w, h, " ")
            end
          elseif c == "K" then
            local n = p[1] or 0
            if n == 0 then
              gpu.fill(cx, cy, w, 1, " ")
            elseif n == 1 then
              gpu.fill(1, cy, cx, 1, " ")
            elseif n == 2 then
              gpu.fill(1, cy, w, 1, " ")
            end
          elseif c == "S" then
            scroll(max(0, p[1] or 1))
            checkCursor()
          elseif c == "T" then
            scroll(-max(0, p[1] or 1))
            checkCursor()
          elseif c == "m" then
            local ic = false -- in RGB-color escape
            local icm = 0 -- RGB-color mode: 2 = 240-color, 5 = 24-bit R;G;B
            local icc = 0 -- the color
            local icv = 0 -- fg or bg?
            local icn = 0 -- which segment we're on: 1 = R, 2 = G, 3 = B
            p[1] = p[1] or 0
            for i=1, #p, 1 do
              local n = p[i]
              if ic then
                if icm == 0 then
                  icm = n
                elseif icm == 2 then
                  if icn < 3 then
                    icn = icn + 1
                    icc = icc + n << (8 * (3 - icn))
                  else
                    ic = false
                    if icv == 1 then
                      bg = icc
                    else
                      fg = icc
                    end
                  end
                elseif icm == 5 then
                  if palette[n] then
                    icc = palette[n]
                  end
                  ic = false
                  if icv == 1 then
                    bg = icc
                  else
                  fg = icc
                  end
                end
              else
                icm = 0
                icc = 0
                icv = 0
                icn = 0
                if n == 0 then -- reset terminal attributes
                  fg, bg = colors[8], colors[1]
                  ec = true
                  lm = true
                elseif n == 8 then -- disable local echo
                  ec = false
                elseif n == 28 then -- enable local echo
                  ec = true
                elseif n > 29 and n < 38 then -- foreground color
                  fg = colors[n - 29]
                elseif n > 39 and n < 48 then -- background color
                  bg = colors[n - 39]
                elseif n == 38 then -- 256/24-bit color, foreground
                  ic = true
                  icv = 0
                elseif n == 48 then -- 256/24-bit color, background
                  ic = true
                  icv = 1
                elseif n == 39 then -- default foreground
                  fg = colors[8]
                elseif n == 49 then -- default background
                bg = colors[1]
                elseif n > 89 and n < 98 then -- bright foreground
                  fg = bright[n - 89]
                elseif n > 99 and n < 108 then -- bright background
                  bg = bright[n - 99]
                elseif n == 108 then -- disable line mode
                  lm = false
                elseif n == 128 then -- enable line mode
                  lm = true
                end
                gpu.setForeground(fg)
                gpu.setBackground(bg)
              end
            end
          elseif c == "n" then
            if p[1] and p[1] == 6 then
              rb = rb .. string.format("\27[%d;%dR", cy, cx)
            end
          end
        end
        p = {}
      end
    end
    flushwb()
    checkCursor()
    local _c, f, b = gpu.get(cx, cy)
    gpu.setForeground(b)
    gpu.setBackground(f)
    gpu.set(cx, cy, _c)
    gpu.setForeground(fg)
    gpu.setBackground(bg)
    return true
  end

  local keys = {
    lcontrol = 0x1D,
    rcontrol = 0x9D,
  }

  local keyboards = {}
  local ctrlHeld = false
  for k,v in pairs(component.invoke(screen or gpu.getScreen(),"getKeyboards"))do
    keyboards[v] = true
  end

  local function key_down(sig, kb, char, code)
    if keyboards[kb] then
      if char == 8 then
        if #rb > 0 and rb:sub(-1) ~= "\n" then
          rb = unicode.sub(rb, 1, -2)
          stream:write("\8 \8")
        end
      elseif char == 13 then
        stream:write("\n")
        rb = rb .. "\n"
      elseif char == 0 and code > 200 then
        local add = ctrlHeld and "\27[1;5" or "\27["
        if code == keys.lcontrol or code == keys.rcontrol then
          ctrlHeld = true
          add = ""
        elseif code == 200 then -- up
          add = add .. "A"
        elseif code == 201 then -- page up
          -- TODO: does this behave differently when ctrl is held?
          add = "\27[5~"
        elseif code == 203 then -- left
          add = add .. "D"
        elseif code == 205 then
          add = add .. "C"
        elseif code == 208 then -- down
          add = add .. "B"
        elseif code == 209 then -- page down
          add = add .. "6~"
        end
        rb = rb .. add
        stream:write((add:gsub("\27", "^")))
      elseif char ~= 0 then
        local c = unicode.char(char)
        stream:write(c)
        rb = rb .. c
      end
    end
  end

  local function key_up(sig, kb, char, code)
    if keyboards[kb] then
      if code == keys.lcontrol or code == keys.rcontrol then
        ctrlHeld = false
      end
    end
  end

  event.listen("key_down", key_down)
  event.listen("key_up", key_up)

  -- simpler than the original stream:read implementation:
  --   -> required 'n' argument
  --   -> does not support 'n' as string
  --   -> far simpler text reading logic
  function stream:read(n)
    checkArg(1, n, "number")
    if lm then
      while (not rb:find("\n")) or (rb:find("\n") < n) do
        coroutine.yield()
      end
    else
      while #rb < n do
        coroutine.yield()
      end
    end
    local ret = rb:sub(1, n)
    rb = rb:sub(n + 1)
    return ret
  end

  function stream:seek()
    return nil, "Illegal seek"
  end

  function stream:close()
    self.closed = true
    event.ignore("key_down", key_down)
    event.ignore("key_up", key_up)
    return true
  end

  local new = buffer.new("rwb", stream)
  new.tty = true
  new.bufferSize = 0
  new:setvbuf("no")
  return new
end

return vt
