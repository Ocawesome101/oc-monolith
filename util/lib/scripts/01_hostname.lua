-- hostname stuff --

local function get()
  if os.getenv("HOSTNAME") then
    return os.getenv("HOSTNAME")
  else
    local handle, err = io.open("/etc/hostname", "rb")
    if not handle then
      return "localhost"
    end
    local name = handle:read("l")
    handle:close()
    os.setenv("HOSTNAME", name)
    return name
  end
end

local function set(n)
  checkArg(1, n, "string")
  local handle, err = io.open("/etc/hostname", "wb")
  if not handle then
    return nil, err
  end
  handle:write(n)
  handle:close()
  os.setenv("HOSTNAME", n)
  return true
end

package.loaded.hostname = {
  get = get,
  set = set
}

get()
