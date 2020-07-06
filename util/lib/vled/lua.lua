-- basic Lua syntax highlighting for the VLED text editor --
-- uses vt100, so will NOT be fast. at all. --

local text = require("text")

-- VT100 colors
local colors = {
  bright = {
    red = 91,
    green = 92,
    yellow = 93,
    blue = 94,
    purple = 95,
    cyan = 96,
    white = 97
  },
  red = 31,
  green = 32,
  yellow = 33,
  blue = 34,
  purple = 35,
  cyan = 36,
  white = 37
}

-- match patterns with colors
local patterns = {
  ["(%S-)%("]                     = colors.bright.blue,
  ["(%-%-.+)"]                    = colors.bright.blue,
  ["([%{%}])"]                    = colors.bright.green,
  ["[\"'].-[\"']"]                = colors.red,
  ["[%s%)]?(function)[%s%(]+"]    = colors.bright.blue,
  ["[%s%)]?(end)[%s%(]+"]         = colors.bright.yellow,
  ["[%s%)]?(local)[%s%(]+"]       = colors.bright.yellow,
  ["[%s%;%)]?(if)[%s%(]+"]        = colors.bright.yellow,
  ["[%s%;%)]?(for)[%s%(]+"]       = colors.bright.yellow,
  ["[%s%)]+(else)[%s%(]+"]        = colors.bright.yellow,
  ["[%s%)]+(elseif)[%s%(]+"]      = colors.bright.yellow,
  ["[%s%)]+(return)[%s%(]+"]       = colors.bright.yellow,
  ["[%s%)]?(repeat)[%s%(]+"]      = colors.bright.yellow,
  ["[%s%)]?(until)[%s%(]+"]       = colors.bright.yellow,
  ["[%s%)]?(while)[%s%(]+"]       = colors.bright.yellow,
  ["[%s%)]+(do)[%s%(]+"]          = colors.bright.yellow,
  ["[%s%)]+(and)[%s%(]+"]         = colors.bright.yellow,
  ["[%s%)]+(in)[%s%(]+"]          = colors.bright.yellow,
  ["[%s%)]+(or)[%s%(]+"]          = colors.bright.yellow,
  ["[%s%)]?(not)[%s%(]+"]         = colors.bright.yellow,
  ["[%s%)]+(then)[%s%(]+"]        = colors.bright.yellow,
  ["[%s%(%)]+(true)[%s%(%)]+"]    = colors.bright.purple,
  ["[%s%(%)]+(false)[%s%(%)]+"]   = colors.bright.purple,
  ["[%s%(%)]+(nil)[%s%(%)]+"]     = colors.bright.purple
}

local function highlighter(s)
  for pat, col in pairs(patterns) do
    for match in s:gmatch(pat) do
      pcall(function()s = s:gsub(text.escapeMagic(match), string.format("\27[%dm%s\27[37m", col, match))end)
    end
  end
  return s
end

return highlighter
