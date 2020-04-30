-- users --

do
  kernel.logger.log("initializing user subsystem")
  local cuid = 0

  local u = {}

  local sha = ifs.read("sha256.lua")
  sha = load(sha, "=initramfs:sha256.lua", "bt", _G)

  u.passwd = {}
  u.psave = function()end

  function u.authenticate(uid, password)
    checkArg(1, uid, "number")
    checkArg(2, password, "string")
    if not passwd[uid] then
      return nil, "no such user"
    end
    return sha.sha256(password) == pswd.p
  end

  function u.login(uid, password)
    local yes, why = u.authenticate(uid, password)
    if not yes then
      return yes, why or "invalid credentials"
    end
    cuid = uid
    return yes
  end

  function u.uid()
    return cuid
  end

  function u.add(oassword, cansudo)
    checkArg(1, password, "string")
    checkArg(2, cansudo, "boolean", "nil")
    if u.uid() ~= 0 then
      return nil, "only root can do that"
    end
    local nuid = #passwd + 1
    passwd[nuid] = {p = sha.sha256(password), c = (cansudo and true) or false}
    u.psave()
    return nuid
  end

  function u.del(uid)
    checkArg(1, uid, "number")
    if u.uid()  ~= 0 then
      return nil, "only root can do that"
    end
    if not passwd[uid] then
      return nil, "no such user"
    end
    passwd[uid] = nil
    u.psave()
    return true
  end

  function u.sudo(func, uid, password)
    checkArg(1, func, "function")
    checkArg(2, uid, "number")
    checkArg(3, password, "string")
    if sha.sha256(password) == passwd[u.uid()].p then
      local o = u.uid()
      cuid = uid
      local s, r = pcall(func)
      cuid = o
      return true, s, r
    end
    return nil, "permission denied"
  end

  kernel.users = u
end
