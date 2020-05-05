-- filesystem management --

do
  local fs = {}
--local log = component.sandbox.log
  local mounts = {}

  local protected = {
    "/boot",
    "/sbin",
    "/initramfs.bin"
  }

  local function split(path)
    local segments = {}
--  log("split " .. path)
    for seg in path:gmatch("[^/]+") do
      if seg == ".." then
        table.remove(segments, #segments)
      else
        table.insert(segments, seg)
      end
    end
    return segments
  end

  function fs.name(path)
    checkArg(1, path, "string")
    local s = split(path)
    return s[#s]
  end

  function fs.path(path)
    checkArg(1, path, "string")
    local s = split(path)
    return fs.canonical(table.concat(s, "/", 1, #s - 1))
  end

  local function resolve(path, noexist)
--  log("resolve " .. path)
    if path == "." then path = os.getenv("PWD") or "/" end
    if path:sub(1,1) ~= "/" then path = (os.getenv("PWD") or "/") .. path end
    local s = split(path)
    for i=1, #s, 1 do
      local cur = table.concat(s, "/", 1, i)
--    log("check " .. cur .. " for " .. table.concat(s, "/", i))
      if mounts[cur] and mounts[cur].exists(table.concat(s, "/", i)) then
--      log("found")
        return mounts[cur], table.concat(s, "/", i)
      end
    end
    if mounts["/"].exists(path) or noexist then
--    log("found at rootfs")
      return mounts["/"], path
    end
    if mounts[path] then
--    log("found at " .. path)
      return mounts[path], "/"
    end
--  log("no such file or directory")
    return nil, path .. ": no such file or directory"
  end

  local basic =  {"makeDirectory", "exists", "isDirectory", "list", "lastModified", "remove", "size", "spaceUsed", "spaceTotal", "isReadOnly", "getLabel"}
  for k, v in pairs(basic) do
    fs[v] = function(path)
      checkArg(1, path, "string", "nil")
--    log("called basic function " .. v .. " with argument " .. tostring(path))
      local mt, p = resolve(path, v == "makeDirectory")
      if path and not mt then
        return nil, p
      end
--    log("resolved to " .. mt.address .. ", path " .. p)
      return mt[v](p)
    end
  end

  local function fread(self, amount)
    checkArg(1, amount, "number", "string")
    if amount == math.huge or amount == "*a" then
      local r = ""
      repeat
        local d = self.fs.read(self.handle, math.huge)
        r = r .. (d or "")
      until not d
      return r
    end
    return self.fs.read(self.handle, amount)
  end

  local function fwrite(self, data)
    checkArg(1, data, "string")
    return self.fs.write(self.handle, data)
  end

  local function fseek(self, whence, offset)
    checkArg(1, whence, "string")
    checkArg(2, offset, "number", "nil")
    offset = offset or 0
    return self.fs.seek(self.handle, whence, offset)
  end

  local open = {}

  local function fclose(self)
    open[self.handle] = nil
    return self.fs.close(self.handle)
  end

  function fs.open(path, mode)
    checkArg(1, path, "string")
    checkArg(2, mode, "string", "nil")
    local m = mode or "r"
    mode = {}
    for c in m:gmatch(".") do
      mode[c] = true
    end
    local node, rpath = resolve(path, true)
    if not node then
      return nil, rpath
    end

    local handle = node.open(rpath, m)
    if handle then
      local ret = {
        fs = node,
        handle = handle,
        seek = fseek,
        close = fclose
      }
      open[handle] = ret
      if mode.r then
        ret.read = fread
      end
      if mode.w or mode.a then
        ret.write = fwrite
      end
      return ret
    else
      return nil, path .. ": no such file or directory"
    end
  end

  function fs.closeAll()
    for _, h in pairs(open) do
      h:close()
    end
  end

  function fs.copy(from, to)
    checkArg(1, from, "string")
    checkArg(2, to, "string")
    local fhdl, ferr = fs.open(from, "r")
    if not fhdl then
      return nil, ferr
    end
    local thdl, terr = fs.open(to, "w")
    if not thdl then
      return nil, terr
    end
    thdl:write(fhdl:read("*a"))
    thdl:close()
    fhdl:close()
    return true
  end

  function fs.rename(from, to)
    checkArg(1, from, "string")
    checkArg(2, to, "string")
    local ok, err = fs.copy(from, to)
    if not ok then
      return nil, err
    end
    local ok, err = fs.remove(from)
    if not ok then
      return nil, err
    end
    return true
  end

  function fs.canonical(path)
    checkArg(1, path, "string")
    if path == "." then
      path = os.getenv("PWD") or "/"
    elseif path:sub(1,1) ~= "/" then
      path = (os.getenv("PWD") or "/") .. path
    end
    return "/" .. table.concat(split(path), "/")
  end

  function fs.concat(path1, path2, ...)
    checkArg(1, path1, "string")
    checkArg(2, path2, "string")
    local args = {...}
    for i=1, #args, 1 do
      checkArg(i + 2, args[i], "string")
    end
    local path = table.concat({path1, path2, ...}, "/")
    return fs.canonical(path)
  end

  local function rowrap(prx)
    local function t()
      return true
    end
    local function roerr()
      error(prx.address:sub(1,8) .. ": filesystem is read-only")
    end
    local mt = {
      __index = prx,
      __newindex = function()error("table is read-only")end,
      __ro = true
    }
    return setmetatable({
      isReadOnly = t,
      write = roerr,
      makeDirectory = roerr,
      remove = roerr,
      setLabel = roerr,
      open = function(f, m)
        m = m or "r"
        if m:find("[wa]") then
          return nil, "filesystem is read-only"
        end
        return prx.open(f, m)
      end
    }, mt)
  end

  local function proxywrap(prx)
    local mt = {
      __index = prx,
      __newindex = function()error("table is read-only")end,
      __ro = true
    }
    return setmetatable({}, mt)
  end

  function fs.mount(fsp, path, ro)
    checkArg(1, fsp, "string", "table")
    checkArg(2, path, "string")
    checkArg(2, ro, "boolean", "nil")
    --path = fs.canonical(path)
    if type(fsp) == "string" then
      fsp = component.proxy(fsp)
    end
    if mounts[path] == fsp then
      return true
    end
    if ro then
      mounts[path] = rowrap(fsp)
    else
      mounts[path] = proxywrap(fsp)
    end
    return true
  end

  function fs.mounts()
    local m = {}
    for path, proxy in pairs(mts) do
      m[path] = proxy.address
    end
    return m
  end

  function fs.umount(path)
    checkArg(1, path, "string")
    if not mounts[path] then
      return nil, "no filesystem mounted at " .. path
    end
    mounts[path] = nil
    return true
  end

--[[ loading things from the initramfs fstab is just broken. No separate boot drive for now.
  local fstab = ifs.read("fstab"):sub(1, -2) -- there's some weird char at the end we don't want, and I don't know what it is
  ifs.close()
  local fstab, err = load("return " .. fstab, "=initramfs:fstab", "bt", {})
  if not fstab then
    kernel.logger.panic(err)
  end
  fstab = fstab()

  for i, b in pairs(fstab) do
    local addr = component.get(b.address)
    kernel.logger.log("mounting " .. addr .. " at " .. b.path)
    fs.mount(addr, b.path)
  end]]

  fs.mount(computer.getBootAddress(), "/")
  fs.mount(computer.tmpAddress(), "/tmp")

  kernel.filesystem = fs
end
