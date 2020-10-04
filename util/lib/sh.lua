-- sh libs --

local shell = require("shell")
local fs = require("filesystem")
local sh = {}

local psrep = {
  ["\\w"] = function()
    return (os.getenv("PWD") and os.getenv("PWD"):gsub("^"..os.getenv("HOME").."?", "~")) or "/"
  end,
  ["\\W"] = function() return fs.name(os.getenv("PWD") or "/") end,
  ["\\h"] = function() return os.getenv("HOSTNAME") end,
  ["\\s"] = function() return "sh" end,
  ["\\v"] = function() return "0.1.0" end,
  ["\\a"] = function() return "\a" end,
  ["\\u"] = function() return os.getenv("USER") or "[unknown]" end,
  ["\\%$"] = function() return (os.getenv("UID") == 0 and "#" or "$") end
}

function sh.prompt(prompt)
  checkArg(1, p, "string", "nil")
  local ret = prompt
  for pat, rep in pairs(psrep) do
    ret = ret:gsub(pat, rep() or "")
  end
  return ret
end

-- runs shell scripts
function sh.execute(file)
  checkArg(1, file, "string")
  local handle, err = io.open(file)
  if not handle then
    return nil, err
  end
  for line in handle:lines("l") do
    shell.execute(line)
  end
  handle:close()
  return true
end



return sh
