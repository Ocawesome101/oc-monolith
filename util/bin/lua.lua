-- a lua shell --

local readline = require("readline").readline

local function tryget(...)
  local s, m = pcall(require, ...)
  if s then
    return m
  end
end

local function showerror(err)
  print(string.format("\27[31m%s\27[37m", err))
end

local exit = false
local env = setmetatable({}, {__index = _G})
env._PROMPT = "\27[37m> "

env.os = setmetatable({}, {__index = os})
function env.os.exit()
  exit = true
end

io.write("\27[37m" .. _VERSION .. " Copyright (C) 1994-2018 Lua.org, PUC-Rio\n")
while not exit do
  local run = readline(env._PROMPT)
  local exec, reason
  if run:sub(1,1) == "=" then
    exec, reason = load("return " .. run:sub(1,2), "=stdin", "t", env)
  else
    exec, reason = load("return " .. run, "=stdin", "t", env)
    if not exec then
      exec, reason = load(run, "=stdin", "t", env)
    end
  end
  if exec then
    local ret = {xpcall(exec, debug.traceback)}
    if not ret[1] then
      showerror(ret[2])
    else
      local ok, why = pcall(function()
        for i=2, #ret, 1 do
          io.write(tostring(ret[i]) .. "\t")
        end
      end)
      io.write("\n")
      if not ok then
        showerror("failed printing result: " .. tostring(why))
      end
    end
  else
    showerror(reason)
  end
end
