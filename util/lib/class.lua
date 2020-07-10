-- classes --

local function class(tbl)
  checkArg(1, tbl, "table", "nil")
  tbl = tbl or {}
  local new = setmetatable(tbl, {__call=function(_,...)local c = setmetatable({}, {__index=tbl}) if c.__init then c:__init(...) end end})
  return new
end

return class
