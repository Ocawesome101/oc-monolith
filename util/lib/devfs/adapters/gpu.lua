-- eeprom adapter --

local component = require("component")

local adp = {}

function adp.instance(addr)
  local prx = component.proxy(addr)
  local raddr = "readGPUAddress" .. addr
  local rmaxres = "readGPUMaxRes" .. addr
  local rcurres = "readGPUCurRes" .. addr
  local rmaxdepth = "readGPUMaxDepth" .. addr
  local rcurdepth = "readGPUCurDepth" .. addr
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
      maxResolution = {
        isDirectory = false,
        read = function(h)
          if h[rmaxres] then return nil end
          h[rmaxres] = true
          local w, h = prx.maxResolution()
          return w .. " " .. h
        end,
        write = function(h)
          error("max resolution not writable")
        end
      },
      resolution = {
        isDirectory = false,
        read = function(h)
          if h[rcurres] then return nil end
          h[rcurres] = true
          local w, h = prx.getResolution()
          return w .. " " .. h
        end,
        write = function(h,d)
          h[rcurres] = false
          local w, h = d:match("(%d+) (%d+)")
          w, h = assert(tonumber(w), "invalid or missing width parameter"), assert(tonumber(h), "invalid or missing height parameter")
          return true
        end
      },
      maxDepth = {
        isDirectory = false,
        read = function(h)
          if h[rmaxdepth] then return nil end
          h[rmaxdepth] = true
          return tostring(prx.maxDepth())
        end,
        write = function()
          error("max depth not writable")
        end
      },
      depth = {
        isDirectory = false,
        read = function(h)
          if h[rcurdepth] then return nil end
          h[rcurdepth] = true
          return tostring(prx.getDepth())
        end,
        write = function(h,d)
          h[rcurdepth] = false
          prx.setDepth(assert(tonumber(d), "invalid or missing depth parameter"))
          return true
        end
      }
    }
  }
  return inst
end

return adp
