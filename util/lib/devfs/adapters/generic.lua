-- generic adapter --

local component = require("component")

local adp = {}

function adp.instance(addr)
  local prx = component.proxy(addr)
  local raddr = "readAddress" .. addr
  local rtype = "readType" .. addr
  local inst = {
    isDirectory = true,
    children = {
      address = {
        isDirectory = false,
        read = function(h)
          if h[raddr] then return nil end
          h[raddr] = true
          return prx.address
        end,
        write = function(h, d)
          error("component address not writable")
        end
      },
      type = {
        isDirectory = false,
        read = function(h)
          if h[rtype] then return nil end
          h[rtype] = true
          return prx.type
        end,
        write = function(h, d)
          error("component address not writable")
        end
      }
    }
  }
  return inst
end

return adp