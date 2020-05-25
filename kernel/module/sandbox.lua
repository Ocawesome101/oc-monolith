-- userspace sandbox and some security features --

kernel.logger.log("wrapping setmetatable, getmetatable for security, type for reasons")

local smt, gmt, typ, err = setmetatable, getmetatable, type, error

function _G.error(e, l)
  local pref = "/"
  if fs.get("/").isReadOnly() then
    pref = "/tmp/"
  end
  local handle = kernel.filesystem.open(pref .. "err_" .. os.date():gsub("[ :\\/]", "_"), "w")
  handle:write(debug.traceback(e))
  --kernel.logger.log(debug.traceback(e))
  handle:close()
  err(e, l)
end

function _G.setmetatable(tbl, mt)
  checkArg(1, tbl, "table")
  checkArg(2, mt, "table")
  local _mt = gmt(tbl)
  if _mt and _mt.__ro then
    error("table is read-only")
  end
  return smt(tbl, mt)
end

function _G.getmetatable(tbl)
  checkArg(1, tbl, "table")
  local mt = gmt(tbl)
  local _mt = {
    __index = mt,
    __newindex = function()error("metatable is read-only")end,
    __ro = true
  }
  if mt and mt.__ro then
    return smt({}, _mt)
  else
    return mt
  end
end

function _G.type(obj)
  local t = typ(obj)
  if t == "table" and getmetatable(obj) and getmetatable(obj).__type then
    return getmetatable(obj).__type
  end
  return t
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

sandbox._G = sandbox
sandbox.computer.pullSignal = coroutine.yield
