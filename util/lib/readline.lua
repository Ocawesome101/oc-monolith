-- relatively flexible readline implementation --

local component = require("component")
local thread = require("thread")
local rl = {}

local buffers = {}

local replacements = {
  [200] = "\27[A", -- up
  [201] = "\27[5", -- page up
  [203] = "\27[D", -- left
  [205] = "\27[C", -- right
  [208] = "\27[B", -- down
  [209] = "\27[6"  -- page down
}

-- needed modifier keys for readline
local keys = {
  lcontrol = 0x1D,
  rcontrol = 0x9D,
  lshift   = 0x2A,
  rshift   = 0x36
}

-- setup the metatable for convenience
setmetatable(replacements, {__index = function() return "" end})

-- first, we need to set up the key listener
-- on a keypress, this does a couple of things
-- 1. it checks if the keyboard is registered
-- 2. if the keyboard is registered, it checks the character code
-- 3. if the character code is >0, we concatenate it to the screen's buffer with string.char, else goto step 4
-- 4. if the character code is 0, we concatenate one of the keycode replacements, or nothing
--
-- I'm fairly certain that one single key input thread will be
-- faster, in most cases, than one per terminal session
local function listener()
  while true do
    local signal, keyboard, character, keycode = coroutine.yield()
    if signal == "key_down" and buffers[keyboard] then
      local screen = buffers[keyboard]
      local concat = string.char(character)
      if character == 0 then
        concat = replacements[keycode]
      end
      buffers[screen].buffer = buffers[screen].buffer .. concat
      buffers[screen].down[keycode] = true
    elseif signal == "key_up" and buffers[keyboard] then
      local screen = buffers[keyboard]
      buffers[screen].down[keycode] = false
    elseif signal == "clipboard" and buffers[keyboard] then
      local screen = buffers[keyboard]
      buffers[screen].buffer = buffers[screen].buffer .. character
    elseif signal == "vt_response" and buffers[keyboard] then
      local screen = keyboard
      buffers[screen].buffer = buffers[screen].buffer .. character
    end
  end
end

thread.spawn(listener, "readline", error)

function rl.addscreen(screen, gpu)
  checkArg(1, screen, "string")
  checkArg(2, gpu, "string", "table")
  if buffers[screen] then return true end
  if type(gpu) == "string" then
    gpu = assert(component.proxy(gpu))
  end
  buffers[screen] = {keyboards = {}, down = {}, buffer = "", gpu = gpu}
  buffers[gpu.address] = buffers[screen]
  for k, v in pairs(component.invoke(screen, "getKeyboards")) do
    buffers[screen].keyboards[v] = true
    buffers[v] = screen
  end
  return true
end

-- basic readline function similar to the original vt100.session one
function rl.readlinebasic(screen, n)
  checkArg(1, screen, "string")
  checkArg(1, n, "number", "nil")
  if not buffers[screen] then
    return nil, "no such screen"
  end
  local buf = buffers[screen]
  while #buf.buffer < n or (not n and not buf.buffer:find("\n")) do
    coroutine.yield()
  end
  if buf.buffer:find("\4") then
    os.exit()
  end
  local n = n or buf.buffer:find("\n")
  local returnstr = buf.buffer:sub(1, n)
  if returnstr:sub(-1) == "\n" then returnstr = returnstr:sub(1,-2) end
  buf.buffer = buf.buffer:sub(n + 1)
  return returnstr
end

function rl.buffersize(screen)
  checkArg(1, screen, "string")
  if not buffers[screen] then
    return nil, "no such screen"
  end
  return buffers[screen].buffer:len()
end

-- fancier readline designed to be used directly
function rl.readline(prompt, opts)
  checkArg(1, prompt, "string", "number", "table", "nil")
  checkArg(2, opts, "table", "nil")
  local screen = io.output().screen
  if type(prompt) == "table" then opts = prompt prompt = nil end
  if type(prompt) == "number" then return rl.readlinebasic(screen, prompt) end
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
  local acts = opts.acts or opts.actions or
    {
      up = function()
        if ent > 1 then
          ent = ent - 1
          buffer = (" "):rep(#buffer)
          redraw()
          buffer = history[ent] or ""
        end
      end,
      down = function()
        if ent <= #history then
          ent = ent + 1
          buffer = (" "):rep(#buffer)
          redraw()
          buffer = history[ent] or ""
        end
      end,
      left = function(ctrl)
        if ctrl then
          pos = #buffer
        end
        if pos <= #buffer then
          pos = pos + 1
        end
      end,
      right = function(ctrl)
        if ctrl then
          pos = 1
        end
        if pos > 1 then
          pos = pos - 1
        end
      end
    }
  local complete = opts.complete or function(x) return x end
  if not buffers[screen] then
    return nil--rl.addscreen(screen, io.output().gpu)
  end
  io.output():write("\27[6n")
  local resp = ""
  repeat
    local char = rl.readlinebasic(screen, 1)
    resp = resp .. char
    --print(char)
  until char == "R"
  if io.output().gpu.address ~= io.input().gpu.address or io.output().screen ~= io.input().screen then
    error("io gpu/screen mismatch")
  end
  --print(resp)
  local y, x = resp:match("\27%[(%d+);(%d+)R")
  local w, h = io.output().gpu.getResolution() -- :^)
  local sy = tonumber(y) or 1
  prompt = ("\27[C"):rep((tonumber(x) or 1) - 1) .. (prompt or "")
  local lines = 1
  function redraw()
    local write = buffer--highlighter(buffer)
    if pwchar then write = pwchar:rep(#buffer) end
    local written = math.max(1, math.ceil((#buffer + #prompt) / w))
    if written > lines then
      local diff = written - lines
      io.write(string.rep("\27[B", diff) .. string.rep("\27[A", diff))
      if (sy + diff + 1) >= h then
        sy = sy - diff
      end
      lines = written
    end
    io.write(string.format("\27[%d;%dH%s%s \27[2K%s", sy, 1, prompt, write, string.rep("\8", pos)))
  end
  while true do
    redraw()
    local char, err = rl.readlinebasic(screen, 1)
    --coroutine.yield()
    if char == "\27" then
      if arrows then -- ANSI escape start
        local esc = rl.readlinebasic(screen, 2)
        if esc == "[A" and acts.up then
          pcall(acts.up)
        elseif esc == "[B" and acts.down then
          pcall(acts.down)
        elseif esc == "[C" then
          pcall(acts.right, buffers[screen].down[keys.lcontrol] or buffers[screen].down[keys.rcontrol])
        elseif esc == "[D" then
          pcall(acts.left, buffers[screen].down[keys.lcontrol] or buffers[screen].down[keys.rcontrol])
        end
      else
        buffer = buffer .. "^"
      end
    elseif char == "\8" then
      if #buffer > 0 and pos <= #buffer then
        buffer = buffer:sub(1, (#buffer - pos)) .. buffer:sub((#buffer - pos) + 2)
      end
    elseif char == "\127" then
      buffer = buffer .. ""
    elseif char == "\13" or char == "\10" or char == "\n" then
      table.insert(history, buffer)
      io.write("\n")
      if not opts.notrail then buffer = buffer .. "\n" end
      return buffer, history
    elseif buffers[screen].down[keys.lcontrol] or buffers[screen].down[keys.rcontrol] then
      if char == "a" then
        pos = #buffer
      elseif char == "b" then
        pos = 1
      end
    elseif char == "\t" then
  --    buffer = complete(buffer)
    else
      buffer = buffer:sub(1, (#buffer - pos) + 1) .. char .. buffer:sub((#buffer - pos) + 2)
    end
  end
end

-- we don't need readlinebasic
return { readline = rl.readline, addscreen = rl.addscreen, buffersize = rl.buffersize }
