-- protect tables. Really protect them a lot. --

local function roerr()
  error("table is read-only")
end

local function protect(tbl, mtblro)
  checkArg(1, tbl, "table")
  checkArg(2, mtblro, "boolean", "nil")
  local mt = {
    __newindex = roerr,
    __metatable = (mtblro and {}) or nil
  }

  return setmetatable(tbl, mt)
end

return protect
