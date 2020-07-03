-- classes --

local function class(tbl)
  checkArg(1, tbl, "table")
  local new = setmetatable({}, {__index=tbl, __call=function(_,...)local c = setmetatable({}, {__index=tbl}) if c.__init then c:__init(...) end end})
  return new
end

return class
