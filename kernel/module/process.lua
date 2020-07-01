-- it's finally time to rewrite the scheduler and related things. here we go!! --

do
  kernel.logger.log("initializing 'process' type")

  local proc_type = {} -- the base "process" template

  function proc_type:resume(...) -- resumes every thread in the process, in order
    if self.stopped then return nil end
    local timeout = math.huge
    for n, thread in ipairs(self.threads) do
      local ok, ret = coroutine.resume(thread, ...)
      kernel.logger.log(tostring(ok) .. " " .. tostring(ret))
      if not ok and ret then
        self.threads[n] = nil
        self.handlers.default(string.format("process %d: error in thread %d: %s", self.pid, n, ret or "not specified"))
      end
      if type(ret) == "number" then
        local newTimeout = computer.uptime() + ret
        if newTimeout < timeout then
          timeout = newTimeout
        end
      end
    end
    if #self.threads == 0 then
      self.dead = true
    end
    return timeout
  end

  function proc_type:addthread(func) -- add a "child" thread (coroutine)
    local new = coroutine.create(function()
      assert(xpcall(func, debug.traceback)) -- this gives us a stack traceback if the thread errors while still propagating the error, and exits cleanly if it doesn't.
    end)
    table.insert(self.threads, new)
    return #self.threads
  end

  function proc_type:delthread(n)
    self.threads[n] = nil
    return true
  end

  function proc_type:kill()
    self.dead = true
  end

  function proc_type:stop()
    self.stopped = true
  end

  function proc_type:continue()
    self.stopped = false
  end

  function proc_type:interrupt()
    self.handlers.interrupt("interrupted")
  end

  function proc_type:terminate()
    self.handlers.terminate("terminated")
  end

  function proc_type:usr1()
    self.handlers.usr1("user signal 1")
  end

  function proc_type:usr2()
    self.handlers.usr2("EXECUTE ORDER 66")
  end

  function proc_type.new(name, handlers, env)
    local new = {
      name = name,
      handlers = handlers or {default = kernel.logger.panic},
      env = env or {},
      threads = {},
      pid = 0,
      dead = false,
      owner = kernel.users.uid(),
      users = {kernel.users.uid()},
      stopped = false,
      started = computer.uptime(),
      io = {[0] = {}, [1] = {}, [2] = {}},
      signals = {},
      deadline = 0
    }
    new.env.PWD = new.env.PWD or "/"
    new.env.UID = new.owner
    handlers.default = handlers.default or kernel.logger.panic
    setmetatable(new.handlers, {__index = function() return new.handlers.default end})
    local ts = tostring(new):gsub("table", "process")
    return setmetatable(new, {__type = "process", __tostring = function() return ts end, __index = proc_type})
  end

  ------------------------------------------------------------------------------------------

  kernel.logger.log("initializing scheduler")
  local process, processes, lastpid, current = {}, {}, 0, 0

  function process.spawn(func, name, handlers, env)
    checkArg(1, func, "function")
    checkArg(2, name, "string")
    checkArg(3, handlers, "function", "table", "nil")
    checkArg(4, env, "table", "nil")
    if type(handlers) == "function" then handlers = {default = handlers} end
    handlers = handlers or {default = kernel.logger.panic}
    env = env or kernel.table_copy((processes[current] or {env = {}}).env)
    local new = proc_type.new(name, handlers, env)
    lastpid = lastpid + 1
    new.pid = lastpid
    new.parent = current
    local dummy = {io = {[0] = {}, [1] = {}, [2] = {}}}
    new.io[0] = (processes[current] or dummy).io[0]
    new.io[1] = (processes[current] or dummy).io[1]
    new.io[2] = (processes[current] or dummy).io[2]
    new:addthread(func)
    processes[lastpid] = new
--    coroutine.yield(0)
    return lastpid
  end

  -- os.setenv and os.getenv are defined in init now rather than here

  -- (re)define kernel.users stuff to be thread-local. Not done in module/users.lua as it requires low-level access.
  local ulogin, ulogout, uuid = kernel.users.login, kernel.users.logout, kernel.users.uid
  function kernel.users.login(uid, password)
    checkArg(1, uid, "number")
    checkArg(2, password, "string")
    local ok, err = kernel.users.authenticate(uid, password)
    if not ok then
      return nil, err
    end
    local ok, err = ulogin(uid, password)
    if not ok then
      return nil, err
    end
    if processes[current] then
      table.insert(processes[current].users, 1, uid)
      return true
    end
  end

  function kernel.users.logout()
    if processes[current] then
      table.remove(processes[current].users, 1)
      return true
    end
    return false -- kernel is always root
  end

  function kernel.users.uid()
    if processes[current] then
      return processes[current].users[1]
    else
      return 0 -- again, kernel is always root
    end
  end

  function process.processes()
    local p = {}
    for pid, _ in pairs(processes) do
      p[#p+1] = pid
    end
    return p
  end

  function process.info(pid)
    checkArg(1, pid, "number", "nil")
    pid = pid or current
    local p = processes[pid]
    if not p then
      return nil, "no such process: " .. pid
    end
    local info = {
      name = p.name,
      owner = p.owner,
      started = p.started,
      threads = #p.threads,
      stopped = p.stopped
    }
    if pid == current then
      local data = {
        env = p.env,
        ipc = p.ipc,
        handlers = p.handlers,
        io = p.io,
        threads = p.threads
      }
      info.data = data
    end
    return info
  end

  process.signals = {
    [2]         = "interrupt",
    [9]         = "kill",
    [15]        = "terminate",
    [18]        = "continue",
    [19]        = "stop",
    [65]        = "usr1",
    [66]        = "usr2",
    interrupt   = 2,
    kill        = 9,
    terminate   = 15,
    continue    = 18,
    stop        = 19,
    usr1        = 65,
    usr2        = 66
  }

  function process.signal(pid, sig)
    checkArg(1, pid, "number")
    checkArg(2, sig, "number", "string")
    if not processes[pid] then
      return nil, "no such process"
    end
    if not process.signals[sig] then
      return nil, "unrecognized signal"
    end
    if type(sig) == "number" then sig = process.signals[sig] end
    processes[pid][sig](processes[pid])
    return true
  end

  function process.ipc(pid, ...)
    checkArg(1, pid, "number")
    if not processes[pid] then
      return nil, "no such process"
    end
    local sig = table.pack("ipc", pid, ...)
    table.insert(processes[pid].signals, sig)
    return true
  end

  function process.current()
    return current
  end

  function process.detach()
    processes[cur].parent = 0
  end

  function process.orphan(pid)
    checkArg(1, pid, "number")
    if not processes[pid] then
      return nil, "no such thread"
    end
    if processes[pid].parent ~= current then
      return nil, "specified process is not a child of the current process"
    end
    processes[pid].parent = 0
    return true
  end

  local function null_concat(t)
    local s = ""
    for i=1, #t, 1 do
      s = s .. ' ' .. tostring(t[i])
    end
    return s
  end

  function process.start()
    process.start = nil
    while #processes > 0 do
      local signal = {}
      local timeout = math.huge
      local uptime = computer.uptime()
      kernel.logger.log("PROC GET_TIMEOUT")
      for pid, proc in pairs(processes) do
        if uptime - proc.deadline >= 0 and uptime - proc.deadline < timeout then
          timeout = uptime - proc.deadline
          kernel.logger.log("PROC SET_TIMEOUT " .. timeout)
          if timeout <= 0 then
            timeout = 0
            kernel.logger.log("PROC END_GET_TIMEOUT")
            break
          end
        end
      end
      kernel.logger.log("PROC PULL_SIGNAL::" .. timeout)
      signal = table.pack(computer.pullSignal(timeout))
      local run = {}
      kernel.logger.log("PROC CHECK_PROC_RUN_STATUS")
      for pid, proc in pairs(processes) do
        if (proc.deadline < uptime or #proc.signals > 0 or signal.n > 0) and not proc.stopped then
          run[#run + 1] = proc
          kernel.logger.log("PROC RUN PID::" .. pid)
          if #proc.signals > 0 and signal.n > 0 then
            kernel.logger.log("PROC TOOMANYSIGNALSINSERTTOPROCBUFFERHELPMEMYSPACEBARBROKE")
            table.insert(proc.signals, signal)
          end
        end
      end

      local start = computer.uptime()
      for _, proc in ipairs(run) do
        current = proc.pid
        local rsig = {}
        if #proc.signals > 0 then
          kernel.logger.log("PROC SIG_FROM_INTERNAL_QUEUE")
          rsig = table.remove(proc.signals)
        else
          kernel.logger.log("PROC SIG_FROM_PULLSIGNAL")
          rsig = signal
        end
        kernel.logger.log("PROC RESUME PID::" .. proc.pid .. "NAME::" .. proc.name .. " SIGNAL::'" .. null_concat(rsig) .. "'")
        local timeout = proc:resume(table.unpack(rsig))
        if timeout then
          proc.deadline = computer.uptime() + timeout
          kernel.logger.log("PROC SET_PROCESS_DEADLINE " .. proc.deadline)
        end
        if computer.uptime() - start > 5 then
          kernel.logger.log("PROC EXIT_LOOP_CLEANUP")
          goto cleanup
        end
      end

      ::cleanup::
      for pid, proc in pairs(processes) do
        if proc.dead then
          kernel.logger.log("PROC DEAD ".. pid)
          processes[pid] = nil
        end
      end
    end
  end

  kernel.process = process
end
