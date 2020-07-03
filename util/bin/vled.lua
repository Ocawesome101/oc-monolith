-- vled - Visual Lua EDitor --
-- better than fled, probably worse than OpenOS's edit.lua. --

local editor = require("editor")
local shell = require("shell")
local readline = require("readline")

local cur = 1
local args, opts = shell.parse(...)

local rlopts = {
  actions = {
    up = function()
      line = line - 1
      return "return"
    end,
    down = function()
      line = line + 1
      return "return"
    end
  }
}
