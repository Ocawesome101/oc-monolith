-- run levels --

do
  kernel.logger.log("innitializing runlevels")
  local rl = {}
  rl.levels = {
    [0] = {
      booted = false,
      init = false,
      services = false,
      multiuser = false
    },
    [1] = {
      booted = true,
      init = true,
      services = false,
      multiuser = false
    },
    [2] = {
      booted = true,
      init = true,
      multiuser = false,
      services = true
    },
    [3] = {
      booted = true,
      init = true,
      multiuser = true,
      services = true
    }
  }
  local level = 0
  function rl.setrunlevel(n)
    if not rl.levels[n] or n > flags.runlevel then
      return nil, "invalid runlevel"
    end
    if kernel.users.uid() ~= 0 then
      return nil, "permission denied"
    end
    level = n
    return true
  end

  function rl.getrunlevel()
    return level
  end

  kernel.runlevel = rl
  kernel.logger.log("runlevels initialized")
end
