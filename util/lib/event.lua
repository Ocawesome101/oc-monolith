-- basic event stuff. Only here for GERTi/Minitel usage --

local computer = require("computer")

local handlers = {}

local event = {}

function event.register(sig, call, int, times, _handlers)
  checkArg(1, sig, "string")
  checkArg(2, call, "function")
  checkArg(3, int, "number", "nil")
  checkArg(4, times, "number", "nil")
  checkArg(5, _handlers, "table", "nil")
  local new = {
    signal = sig,
    times = times or 1,
    callback = call,
    interval = int or math.huge,
    timeout  = (int or math.huge) + computer.uptime()
  }

  _handlers = _handlers or handlers

  local id = 0
  while _handlers[id] do
    id = id + 1
  end

  _handlers[id] = new
  return id
end

-- may or may not be an almost-direct-copy of the OpenOS function
local pull = computer.pullSignal
function computer.pullSignal(timeout)
  checkArg(1, timeout, "number", "nil")
  timeout = timeout or math.huge
  local up = computer.uptime
  local max = up() + timeout
  repeat
    local closest = max
    for _, handler in pairs(handlers) do
      closest = math.min(handler.timeout, closest)
    end

    local evtdata = {pull(closest - uptime())}
    local signal = evtdata[1]
    for id, handler in pairs(handlers) do
      if (handler.signal == nil or handler.signal == signal) or up() >= handler.timeout then
        handler.times = handler.times - 1
        handler.timeout = handler.timeout + handler.interval
        if handler.times <= 0 and handlers[id] == handler then
          handlers[id] = nil
        end

        local result, message = pcall(handler.callback, table.unpack(evtdata))
        if not result then
          pcall(event.onError, message)
        elseif message == false and handlers[id] == handler then
          handlers[id] = nil
        end
      end
    end
    if signal then
      return table.unpack(signal)
    end
  until up() >= max
end

function event.listen(sig, call)
  checkArg(1, sig,  "string")
  checkArg(2, call, "function")
  for id, handler in pairs(handlers) do
    if handler.signal == sig and handler.callback == call then
      return false
    end
  end
  return event.register(sig, call, math.huge, math.huge)
end

function event.ignore(sig, call)
  checkArg(1, sig, "string")
  checkArg(2, call, "function")
  for id, handler in pairs(handlers) do
    if handler.signal == sig and handler.callback == call then
      handlers[id] = nil
      return true
    end
  end
  return false
end

function event.timer(int, call, num)
  checkArg(1, int,  "number")
  checkArg(2, call, "function")
  checkArg(3, num,  "number", "nil")
  return event.register(false, call, int, num)
end

function eevent.cancel(id)
  checkArg(1, id, "number")
  if handlers[id] then
    handlers[id] = nil
    return true
  end
  return false
end

function event.onError(msg)
  local log = io.open("/tmp/event.log", "a")
  if log then
    pcall(log.write, log, tostring(msg) .. "\n")
    log:close()
  end
end

-- the following is copied verbatim from OpenOS
local function createPlainFilter(name, ...)
  local filter = table.pack(...)
  if name == nil and filter.n == 0 then
    return nil
  end

  return function(...)
    local signal = table.pack(...)
    if name and not (type(signal[1]) == "string" and signal[1]:match(name)) then
      return false
    end
    for i = 1, filter.n do
      if filter[i] ~= nil and filter[i] ~= signal[i + 1] then
        return false
      end
    end
    return true
  end
end

function event.pullFiltered(...)
  local args = table.pack(...)
  local seconds, filter = math.huge

  if type(args[1]) == "function" then
    filter = args[1]
  else
    checkArg(1, args[1], "number", "nil")
    checkArg(2, args[2], "function", "nil")
    seconds = args[1]
    filter = args[2]
  end

  repeat
    local signal = table.pack(computer.pullSignal(seconds))
    if signal.n > 0 then
      if not (seconds or filter) or filter == nil or filter(table.unpack(signal, 1, signal.n)) then
        return table.unpack(signal, 1, signal.n)
      end
    end
  until signal.n == 0
end

function event.pull(...)
  local args = table.pack(...)
  if type(args[1]) == "string" then
    return event.pullFiltered(createPlainFilter(...))
  else
    checkArg(1, args[1], "number", "nil")
    checkArg(2, args[2], "string", "nil")
    return event.pullFiltered(args[1], createPlainFilter(select(2, ...)))
  end
end

event.push = computer.pushSignal

-- end verbatim copy

return event
