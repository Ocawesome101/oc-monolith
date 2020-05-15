-- sh libs --

local shell = require("shell")
local fs = require("filesystem")
--local log = require("component").sandbox.log
local sh = {}

local psrep = {
  ["\\w"] = function()
    return (os.getenv("PWD") and os.getenv("PWD"):gsub("^" .. os.getenv("HOME") .. "?", "~")) or "/"
  end,
  ["\\W"] = function()
    return fs.name(os.getenv("PWD") or "/") or ""
  end,
  ["\\$"] = function()
    if os.getenv("UID") == 0 then
      return "#"
    else
      return "$"
    end
  end,
  ["\\u"] = function()
    return os.getenv("USER") or ""
  end,
  ["\\h"] = function()
    return os.getenv("HOSTNAME") or "localhost"
  end
}

function sh.prompt(p)
  checkArg(1, p, "string", "nil")
  p = p or os.getenv("PS1") or "\\w\\$ "
--log("resolve prompt", p)
  for k, v in pairs(psrep) do
    k = k:gsub("%$", "%%$") -- ouch
--  log("gsub", k, v())
    p = p:gsub(k, v())
  end
--log("done")
  return shell.vars(p)
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
end

return sh
