-- fs --

local component = require("component")
local fs = require("filesystem")

local adp = {}

adp.name = "hd"

function adp.instance(addr)
  local prx = component.proxy(addr)
  local rfsl = "readFSLabel" .. addr
  local rfsm = "readFSMountPoint" .. addr
  local rfst = "readFSSpaceTotal" .. addr
  local rfsu = "readFSSpaceUsed" .. addr
  local rfsa = "readFSAddress" .. addr
  local inst = {
    isDirectory = true,
    children = {
      label = {
        isDirectory = false,
        read = function(h)
          if h[rfsl] then return nil end
          h[rfsl] = true print("GET LABEL")
          return prx.getLabel()
        end,
        write = function(h, d)
          h[rfsl] = false
          return prx.setLabel(d)
        end
      },
      address = {
        isDirectory = false,
        read = function(h)
          if h[rfsa] then return nil end
          h[rfsa] = true
          return prx.address
        end,
        write = function(h, d)
          error("component address not writable")
        end
      },
      mount = {
        isDirectory = false,
        read = function(h)
          if h[rfsm] then return nil end
          h[rfsm] = true
          local mounts = fs.mounts()
          for k, v in pairs(mounts) do
            if v == prx.address then
              return k
            end
          end
        end,
        write = function()
          error("cannot write to fs mount point")
        end
      },
      spaceTotal = {
        isDirectory = false,
        read = function(h)
          if h[rfst] then return nil end
          h[rfst] = true
          return tostring(prx.spaceTotal())
        end,
        write = function()
          error("cannot change fs space")
        end
      },
      spaceUsed = {
        isDirectory = false,
        read = function(h)
          if h[rfsu] then return nil end
          h[rfsu] = true
          return tostring(prx.spaceUsed())
        end,
        write = function()
          error("I'm sorry, Dave. I'm afraid I can't do that.")
        end
      }
    }
  }
  return inst
end

return adp
