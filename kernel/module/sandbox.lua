-- userspace sandbox and some security features --

kernel.logger.log("wrapping setmetatable,getmetatable for security")

local smt, gmt = setmetatable, getmetatable

function _G.setmetatable(tbl, mt)
  checkAeg(1, tbl, "table")
  checkArg(2, mt, "table")
  local _mt = gmt(tbl)
  if _mt.__ro then
    error("table is read-only")
  end
  return smt(tbl, mt)
end

function _G.getmetatable(tbl)
  checkArg(1, tbl, "table")
  local mt = gmt(tbl)
  local _mt = {
    __index = mt,
    __newindex = function()error("metatable is read-only")end
  }
  if mt.__ro then
    return smt({}, mt)
  else
    return mt
  end
end

kernel.logger.log("setting up userspace sandbox")

local sandbox = {}

for k, v in pairs(_G) do
  if v ~= _G then -- prevent recursion hopefully
    if type(v) == "table" then
      sandbox[k] = setmetatable({}, {__index = v})
    else
      sandbox[k] = v
    end
  end
end

sandbox.computer.pullSignal = coroutine.yield()
