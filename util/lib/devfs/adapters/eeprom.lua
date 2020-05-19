-- eeprom adapter --

local component = require("component")

local adp = {}

function adp.instance(addr)
  local prx = component.proxy(addr)
  local er = false
  local dr = false
  local inst = {
    isDirectory = true,
    children = {
      eeprom = {
        isDirectory = false,
        read = function()
          if er then if er >= 1 then er = false else er = er + 1 end return nil end
          er = 0
          return prx.get()
        end,
        write = function(d)
          er = false
          return prx.set(d)
        end
      },
      data = {
        isDirectory = false,
        read = function()
          if dr then if dr >= 1 then dr = false else dr = dr + 1 end return nil end
          dr = 0
          return prx.getData()
        end,
        write = function(d)
          dr = false
          return prx.setData(d)
        end
      }
    }
  }
  return inst
end

return adp
