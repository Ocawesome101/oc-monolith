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

local patterns = {
  ["[\"'].-[\"']"]                      = colors.red,
  ["([%s%(%)]+)(true)([%s%(%)]+)"]      = "%1\27[95m%2\27[37m%3",
  ["([%s%(%)]+)(false)([%s%(%)]+)"]     = "%1\27[95m%2\27[37m%3",
  ["([%s%(%)]+)(nil)([%s%(%)]+)"]       = "%1\27[95m%2\27[37m%3",
  ["([%{%}])"]                          = colors.bright.green,
  ["([^\"']?)if (.-) then([^\"']?)"]    = "%1\27[93mif\27[37m %2 \27[93mthen\27[37m%3",
  ["(%S-)(%()"]                         = "\27[94m%1\27[37m%2",
  ["while (.-) do"]                     = "\27[93mwhile\27[37m %1 \27[93mdo\27[37m",
  ["for (.-) do"]                       = "\27[93mfor\27[37m %1 \27[93mdo\27[37m",
  ["if (.-) then (.-) end"]             = "\27[93mif\27[37m %1\27[37mthen\27[37m %2 \27[93mend\27[37m",
  ["while (.-) do (.-) end"]            = "\27[93mwhile\27[37m %1\27[37mdo\27[37m %2 \27[93mend\27[37m",
  ["for (.-) do (.-) end"]              = "\27[93mfor\27[37m %1\27[37mdo\27[37m %2 \27[93mend\27[37m",
  ["local (.+)"]                        = "\27[93mlocal\27[37m %1",
  ["return (.+)"]                       = "\27[93mreturn\27[37m %1",
  ["not (.+)"]                          = "\27[93mnot\27[37m %1",
  ["function (.+)"]                     = "\27[94mfunction\27[37m %1",
  [" else "]                            = colors.bright.yellow
}

local function color(c)
  return string.format("\27[%dm", c)
end

local function highlight(line)
  local trim = text.trim(line)
  if trim:sub(1,2) == "--" or line:sub(1,3) == "#!/" then -- comment or shebang
    return color(colors.bright.blue) .. line
  elseif trim == "do" or trim == "end" or trim == "else" then
    return color(colors.bright.yellow) .. line
  else
    for pat, col in pairs(patterns) do
      if type(col) == "string" then line = line:gsub(pat, col) else
        line = line:gsub(pat, color(col) .. "%1\27[37m") end
    end
  end
  return line .. "\27[37m"
end

return highlight
