-- protect tables. Really protect them a lot. --

local function roerr()
  error("table is read-only")
end

local function protect(tbl, mtblro)
  checkArg(1, tbl, "table")
  checkArg(2, mtblro, "boolean", "nil")
  local mt = {
    __index = tbl,
    __newindex = roerr,
    __ro = mtblro
  }

  return setmetatable({}, mt)
end

return protect
