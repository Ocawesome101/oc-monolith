-- event library --

local thread = require("thread")
local computer = require("computer")
local log = require("component").sandbox.log

local event = {}

local handlers = {}
local id = 0

function event.register(evt, func, int, x)
  checkArg(1, evt, "string", "boolean")
  checkArg(2, func, "function")
  checkArg(3, int, "number", "nil")
  checkArg(4, x, "number", "nil")
  id = id + 1
  handlers[id] = {
    sig = evt,
    call = func,
    times = x or 1,
    int = int or math.huge
  }
  log("starting event listener")
  handlers[id].pid = thread.spawn(function()
    while handlers[id].times > 0 do
      handlers[id].times = handlers[id].times - 1
      local signal = table.pack(coroutine.yield(handlers[id].int))
      if handlers[id].sig and handlers[id].sig ~= false and handlers[id].sig == signal[1] then
        local s, r = pcall(handlers[id].call, table.unpack(signal))
        if not s or r == false then break end
      end
    end
  end, string.format("evtlisten[%d:%s]", id, evt), function(...)log(...)end)
  return id
end

function event.listen(sig, func)
  checkArg(1, sig, "string")
  checkArg(2, func, "function")
  for i, handler in pairs(handlers) do
    if handler.sig == sig and handler.call == call then
      return false
    end
  end
  return event.register(sig, func, math.huge, math.huge)
end

function event.timer(int, call, x)
  checkArg(1, int, "number")
  checkArg(2, call, "function")
  checkArg(3, x, "number", "nil")
  return event.register(false, call, int, x)
end

function event.ignore(sig, func)
  checkArg(1, sig, "string")
  checkArg(2, func, "function")
  for i, handler in pairs(handlers) do
    if handler.sig == sig and handler.call == func then
      handlers[i] = nil
      thread.kill(handler.pid)
      return true
    end
  end
  return false
end

function event.cancel(id)
  checkArg(1, id, "number")
  if handlers[id] then
    handlers[id] = nil
    return true
  end
  return false
end

event.pull = coroutine.yield
event.push = computer.pushSignal

return event
