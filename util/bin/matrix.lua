-- matrix

local component = require("component")
local matrix = component.matrix

matrix.removeAll()
local surface = matrix.addItem()

surface.setPosition(1,1)
surface.setLabel(string.rep("test", 50))
surface.setItem("Test")
