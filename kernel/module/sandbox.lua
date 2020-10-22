-- userspace sandbox and some security features --

local typ, err = type, error

function _G.error(e, l)
  local pref = "/tmp/"
  if flags.debug and not kernel.filesystem.get("/").isReadOnly() then
    pref = "/"
  end
  local handle = kernel.filesystem.open(pref .. "err_" .. os.date():gsub("[ :\\/]", "_"), "a")
  handle:write(debug.traceback(e).."\n")
  handle:close()
  err(e, l)
end

function _G.type(obj)
  local t = typ(obj)
  if t == "table" and getmetatable(obj) and getmetatable(obj).__type then
    return getmetatable(obj).__type
  end
  return t
end

local sandbox = {}

-- it is now time for an actually working sandbox!
function kernel.table_copy(t)
  checkArg(1, t, "table")
  local seen = {}
  local function copy(tbl)
    local ret = {}
    tbl = tbl or {}
    for k, v in pairs(tbl) do
      if type(v) == "table" and not seen[v] then
        seen[v] = true
        ret[k] = copy(v)
      else
        ret[k] = v
      end
    end
    return ret
  end
  return copy(t)
end

sandbox = kernel.table_copy(_G)
sandbox._G = sandbox
sandbox.computer.pullSignal = coroutine.yield
sandbox.kernel.thread.start = nil -- calling this from userspace causes a
                                  -- kernel panic without actually causing a
                                  -- kernal panic

sandbox.kernel.users = kernel.users -- this is a hack fix for a weird annoying
                                    -- bug

sandbox.kernel.logger = kernel.logger -- ensure that any kernel logs are in the
                                      -- proper spot after init logging
