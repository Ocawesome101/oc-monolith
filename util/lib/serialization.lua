-- serialization. Not sure if recursion protection works. --

local s = {}

local function internal(tbl, ident, seen)
  local isp = string.rep(" ", ident)

  local r = isp .. "{\n"

  local last = 0
  for k, v in pairs(tbl) do
    if type(k) == "string" then
      if k:match("[^%w_]") or k:sub(1,1):match("[%d]") then
        k = string.format("[\"%s\"]", k)
      end
    elseif type(k) == "number" then
      k = string.format("[%d]", k)
    else
      k = string.format("[%s]", tostring(k))
    end
    if type(v) == "table" then
      if seen[v] then
        v = tostring(v)
      else
        v = internal(v, ident + 2, seen)
      end
    elseif type(v) == "string" then
      v = string.format("\"%s\"", v)
    else
      v = tostring(v)
    end

    r = string.format("%s  %s = %s,\n", r, k, v)
  end

  r = r .. isp .. "}"

  return r
end

function s.serialize(tbl)
  checkArg(1, tbl, "table")

  return internal(tbl, 0, setmetatable({}, {__mode = "k"}))
end

function s.deserialize(str)
  checkArg(1, str, "string")

  local ok, err = load("return " .. str, "=deserialization", "bt", {os = {getenv = os.getenv}})

  if not ok then
    return nil, "deserialization failed: " .. err
  end

  local st, rt = pcall(ok)
  if not st then
    return nl, "deserialization failed: " .. rt
  end

  return rt
end

s.unserialize = s.deserialize

return s
