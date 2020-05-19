-- fs --

local component = require("component")
local fs = require("filesystem")

local adp = {}

adp.name = "fs"

function adp.instance(addr)
  local prx = component.proxy(addr)
  local r1, r2, r3, r4 = false, false, false, false
  local inst = {
    isDirectory = true,
    children = {
      label = {
        isDirectory = false,
        read = function()
          if r1 then if r1 >= 1 then r1 = false else r1 = r1 + 1 end return nil end
          r1 = 0
          return prx.getLabel()
        end,
        write = function(d)
          r1 = false
          return prx.setLabel()
        end
      },
      mount = {
        isDirectory = false,
        read = function()
          if r2 then if r2 >= 1 then r2 = false else r2 = r2 + 1 end return nil end
          r2 = 0
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
        read = function()
          if r3 then if r3 >= 1 then r3 = false else r3 = r3 + 1 end return nil end
          r3 = 0
          return prx.spaceTotal()
        end,
        write = function()
          error("cannot change fs space")
        end
      },
      spaceUsed = {
        isDirectory = false,
        read = function()
          if r4 then if r4 >= 1 then r4 = false else r3 = r3 + 1 end return nil end
          r4 = 0
          return prx.spaceTotal()
        end,
        write = function()
          error("write somewhere else!")
        end
      }
    }
  }
  return inst
end

return adp
