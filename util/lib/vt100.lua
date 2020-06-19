-- A vt100 emulator because why tf not? Supports as much of the vt100 stuff as I can manage to puzzle out --
-- Heavily inspired by the PsychOS VT100 emulator.

local component = require("component")
local computer = require("computer")
local thread = require("thread")
local config = require("config")
local vt = {}

local cfg
function vt.reload()
  cfg = config.load("/etc/vtcolors.cfg")
end

vt.reload()
function vt.emu(gpu)
  checkArg(1, gpu, "table")
  
  local w, h = gpu.maxResolution()
  gpu.setResolution(w, h)
  local cx, cy, w, h = 1, 1, gpu.getResolution()
  local sx, sy = 1, 1
  local echo = true
  local dhist = false
--  local wrap = true
  local wbuf = ""
  local ebuf = ""
  local mode = 0 -- 0 normal, 1 escape, 2 command
  local colors = cfg.normal or {
    0x000000,
    0xDD0000,
    0x00DD00,
    0x0000DD,
    0xDDDD00,
    0xDD00DD,
    0x00DDDD,
    0xDDDDDD
  }
  local bright = cfg.bright or {
    0x111111,
    0xFF0000,
    0x00FF00,
    0xFFFF00,
    0x0000FF,
    0xFF00FF,
    0x00FFFF,
    0xFFFFFF
  }
  local fg, bg = 0xFFFFFF, 0x000000
  
  local function checkCursor()
    if cx > w then
      cx, cy = 1, cy + 1
    end
    
    if cy > h then
      gpu.copy(1, 1, w, h, 0, -1)
      gpu.fill(1, h, w, 1, " ")
      cy = h
    end
    
    if cx < 1 then cx = w cy = cy - 1 end
    if cy < 1 then cy = 1 end
  end
  
  local function flush()
    while #wbuf > 0 do
      checkCursor()
      local ln = wbuf:sub(1, w - cx + 1)
      wbuf = wbuf:sub(#ln + 1)
      if echo then gpu.set(cx, cy, ln) end
      cx = cx + #ln
    end
  end
  
  local function vtwrite(str)
    checkArg(1, str, "string")
    str = str:gsub("\8","\27[D")
    local resp = ""
    local _c = gpu.get(cx, cy)
    gpu.setForeground(fg)
    gpu.setBackground(bg)
    gpu.set(cx, cy, _c)
    for char in str:gmatch(".") do
      if mode == 0 then
        if char == "\n" then
          flush()
          cx, cy = 1, cy + 1
        elseif char == "\t" then
          wbuf = wbuf .. (" "):rep(math.max(1, (cx+4) % 8))
        elseif char == "\27" then
          flush()
          mode = 1
        else
          wbuf = wbuf .. char
        end
      elseif mode == 1 then
        if char == "[" then
          mode = 2
        else
          if char == "D" then
            gpu.copy(1, 1, w, h, 0, -1)
            gpu.fill(1, h, w, 1, " ")
          elseif char == "M" then
            gpu.copy(1, 1, w, h, 0, 1)
            gpu.fill(1, 1, w, 1, " ")
          elseif char == "7" then
            sx, sy = cx, cy
          elseif char == "8" then
            cx, cy = sx, sy
          end
          mode = 0
        end
      elseif mode == 2 then
        if char:match("[%d;]") then
          ebuf = ebuf .. char
        else
          mode = 0
          local params = {}
          for number in ebuf:gmatch("%d+") do
            params[#params + 1] = tonumber(number)
          end
          if char == "H" then
            cx, cy = math.min(w, params[2] or 1), math.min(h, params[1] or 1)
          elseif char == "A" then
            cy = cy - (params[1] or 1)
          elseif char == "B" then
            cy = cy + (params[1] or 1)
          elseif char == "C" then
            cx = cx + (params[1] or 1)
          elseif char == "D" then
            cx = cx - (params[1] or 1)
          elseif char == "E" then
            cx, cy = 1, cy + (params[1] or 1)
          elseif char == "F" then
            cx, cy = 1, cy - (params[1] or 1)
          elseif char == "f" then -- identical to H
            cx, cy = math.min(w, params[2] or 1), math.min(h, params[1] or 1)
          elseif char == "s" then
            sx, sy = cx, cy
          elseif char == "u" then
            cx, cy = sx, sy
          elseif char == "n" then 
            if params[1] == 6 then
              resp = string.format("%s\27[%d;%dR", resp, cy, cx)
            elseif params[1] == 5 then
              resp = string.format("%s\27[%dn", resp, (gpu and gpu.getScreen() and 0) or 3)
            end
          elseif char == "c" then -- not really necessary, may remove
            resp = string.format("%s\27[?1;ocansi0c", resp)
          elseif char == "K" then
            if params[1] == 1 then
              gpu.fill(1, cy, cx, 1, " ")
            elseif params[1] == 2 then
              gpu.fill(cx, cy, w, 1, " ")
            elseif not params[1] or params[1] == 0 then
              gpu.fill(1, cy, w, 1, " ")
            end
          elseif char == "J" then
            if params[1] == 1 then
              gpu.fill(1, 1, w, cy, " ")
            elseif params[1] == 2 then
              gpu.fill(1, 1, w, h, " ")
              cx, cy = 1, 1
            elseif not params[1] or params[1] == 0 then
              gpu.fill(1, cy, w, h, " ")
            end
          elseif char == "S" then
            gpu.copy(1, 1, w, h, 0, -1)
            gpu.fill(1, h, w, 1, " ")
          elseif char == "T" then
            gpu.copy(1, 1, w, h, 0, 1)
            gpu.fill(1, 1, w, 1, " ")
          elseif char == "m" then
            if #params == 0 then
              echo = true
              --hist = false
              fg = colors[8]
              bg = colors[1]
            end
            for i=1, #params, 1 do
              local n = params[i]
              if n == 8 then
                echo = false
              elseif n == 28 then
                echo = true
              elseif n == 0 then
                echo = true
                --hist = false
                fg = colors[8]
                bg = colors[1]
              elseif n == 7 or n == 27 then
                fg, bg = bg, fg
              elseif n > 29 and n < 38 then
                fg = colors[n - 29]
              elseif n > 39 and n < 48 then
                bg = colors[n - 39]
              elseif n > 89 and n < 98 then
                fg = bright[n - 89]
              elseif n > 99 and n < 108 then
                bg = bright[n - 99]
              end
            end
            gpu.setForeground(fg)
            gpu.setBackground(bg)
          end
          ebuf = ""
          checkCursor()
        end
      end
    end
    flush()
    checkCursor()
    local char = gpu.get(cx, cy)
    gpu.setForeground(bg)
    gpu.setBackground(fg)
    gpu.set(cx, cy, char)
    gpu.setForeground(fg)
    gpu.setBackground(bg)
    if resp ~= "" then
      computer.pushSignal("vt_response", gpu.getScreen(), resp)
      resp = ""
    end
    --return resp, echo--, dhist
  end
  return vtwrite
end

-- Create a session with i/o and everything. Returns read, write, and close functions.
-- This function is deprecated.
function vt.session(gpu, screen)
  checkArg(1, gpu, "string", "table")
  checkArg(2, screen, "string")
  error("vt100.session is deprecated and should not be used")
  if type(gpu) == "string" then
    gpu = component.proxy(gpu)
  end
  gpu.bind(screen)
  
  local write = vt.emu(gpu)
  local keyboards = {}
  for _, addr in pairs(component.invoke(screen, "getKeyboards")) do
    keyboards[addr] = true
  end
  
  local buf, echo, last, hist, hp, dh = "", true, computer.uptime(), {}, 1, false
  local function proc()
    while true do
      local sig, kba, chr, cod = coroutine.yield(cto)
      if sig == "key_down" and keyboards[kba] then
        if chr == 13 then chr = 10 end
        if chr == 8 then
          if buf ~= "" then
            if echo then write("\8 \8") end
            buf = buf:sub(1, -2)
          end
        elseif chr > 0 then
          if echo then write(string.char(chr)) end
          buf = buf .. string.char(chr)
        elseif chr == 0 then
          if cod == 200 then
            if dh then
              if hp > 1 then hp = hp - 1 end
              local nbuf = hist[hp] or ""
              write(("\8 \8"):rep(#buf))
              write(nbuf)
              buf = nbuf
            else
              write("^[A")
              buf = buf .. "\27[A\n"
            end
          elseif cod == 208 then
            if dh then
              if hp <= #hist then hp = hp + 1 end
              local nbuf = (hist[hp] or ""):gsub("\n", "")
              write(("\8 \8"):rep(#buf))
              write(nbuf)
              buf = nbuf
            else
              write("^[B")
              buf = buf .. "\27[B\n"
            end
          --[[elseif cod == 205 then
            c = "C"
          elseif cod == 203 then
            c = "D"]]
          end
          --[[if c then
            local p = string.format("\27[%s", c)
            if cpt then
              akb[#akb + 1] = p
            elseif echo then
              write(p)
            end
          end]]
        end
      end
    end
  end
  local pid = thread.spawn(proc, string.format("tty(%s:%s)", gpu.address:sub(1, 8), screen:sub(1, 8)))
  
  local function sread()
    while not buf:find("\n") do
      coroutine.yield()
    end
    local n = buf:find("\n")
    local ret = buf:sub(1, n - 1)
    buf = buf:sub(n + 1)
    if dh then hist[#hist + 1] = ret hp = #hist + 1
      if #hist > 16 then table.remove(hist, 1) end end
    return ret
  end
  
  local function swrite(str)
    checkArg(1, str, "string")
    local response, localEcho, doh = write(str)
    if localEcho ~= nil then echo = localEcho end
    if doh ~= nil then dh = doh end
    return response
  end
  
  local function sclose()
    os.kill(pid)
    io.write("\27[2J\27[H")
  end
  
  return sread, swrite, sclose
end

return vt
