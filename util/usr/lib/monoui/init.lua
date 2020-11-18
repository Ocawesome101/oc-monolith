-- monoui core --

local class = require("class")
local component = require("component")
local lib = {}

local base = class()

function base:__init(gpu, screen)
  checkArg(1, gpu, "string")
  checkArg(2, screen, "string")
  
end

function lib.init(...)
  return base(...)
end

return lib
