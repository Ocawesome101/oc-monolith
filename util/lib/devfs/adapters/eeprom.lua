-- eeprom adapter --

local component = require("component")

local adp = {}

adp.name = "fl"

function adp.instance(addr)
  local prx = component.proxy(addr)
  local inst = {
    isDirectory = true,
    children = {
      eeprom = {
        isDirectory = false,
        read = function(h)
          if h.readEEPROM then return nil end
          h.readEEPROM = true
          return prx.get()
        end,
        write = function(h, d)
          h.readEEPROM = false
          return prx.set(d)
        end
      },
      data = {
        isDirectory = false,
        read = function(h)
          if h.readEEPROMData then return nil end
          h.readEEPROMData = true
          return prx.getData()
        end,
        write = function(h, d)
          h.readEEPROMData = false
          return prx.setData(d)
        end
      },
      address = {
        isDirectory = false,
        read = function(h)
          if h.readEEPROMAddress then return nil end
          h.readEEPROMAddress = true
          return prx.address
        end,
        write = function(h, d)
          error("component address not writable")
        end
      },
    }
  }
  return inst
end

return adp
