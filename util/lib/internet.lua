-- basically a clone of the OpenOS one, but slightly modified --

local buffer = require("buffer")
local component = require("component")

local internet = {}

function internet.request(url, data, headers, method)
  checkArg(1, url, "string")
  checkArg(2, data, "string", "table", "nil")
  checkArg(3, headers, "table", "nil")
  checkArg(4, method, "string", "nil")

  local inet = component.internet

  local post
  if type(data) == "string" then
    post = data
  elseif type(data) == "table" then
    for k, v in pairs(data) do
      post = post and (post .. "&") or ""
      post = post .. tostring(k) .. "=" .. tostring(v)
    end
  end

  local request, reason = inet.request(url, post, headers, method)
  if not request then
    error(reason, 2)
  end

  return setmetatable(
  {
    close = setmetatable({},
    {
      __call = request.close
    })
  },
  {
    __call = function()
      while true do
        local data, reason = request.read()
        if not data then
          request.close()
          if reason then
            error(reason, 2)
          else
            return nil
          end
        elseif #data > 0 then
          return data
        else
          error("download failed", 2)
        end
        os.sleep(0)
      end
    end,
    __index = request
  })
end

local socket = {}

function socket:close()
  if self.socket then
    self.socket.close()
    self.socket = nil
  end
end

function socket:seek()
  return nil, "bad file descriptor"
end

function socket:read(n)
  if not self.socket then
    return nil, "connection is closed"
  end
  return self.socket.read(n)
end

function socket:write(d)
  if not self.socket then
    return nil, "connection is closed"
  end
  while #d > 0 do
    local w, r = self.socket.write(d)
    if not w then
      return nil, r
    end
    d = d:sub(w + 1)
  end
  return true
end

function internet.socket(address, port)
  checkArg(1, address, "string")
  checkArg(2, port, "number", "nil")
  if port then
    address = address .. ":" .. port
  end

  local inet = component.internet
  -- this was a typo but it works so I'm leaving it
  local sicket, reason = inet.connect(address)
  if not sicket then
    return nil, reason
  end

  local stream = {
    inet = inet, socket = sicket
  }
  local mt = {
    __index = socket,
    __metatable = "socketstream"
  }
  return setmetatable(stream, metatable)
end

function internet.open(address, port)
  local stream, reason = internet.socket(address, port)
  if not stream then
    return nil, reason
  end
  return buffer.new("rwb", stream)
end

return internet
