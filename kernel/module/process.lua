-- it's finally time to rewrite the scheduler and related things. here we go!! --

do
  kernel.logger.log("initializing 'process' type")

  local proc = {} -- the base "process" template
  
  function proc:resume(...) -- resumes every thread in the process, in order
    if self.stopped then return nil end
    local timeout = math.huge
    for n, thread in ipairs(self.threads) do
      local ok, ret = coroutine.resume(thread, ...)
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

  function proc:addthread(func) -- add a "child" thread (coroutine)
    local new = coroutine.create(function()
      assert(xpcall(func, debug.traceback)) -- this gives us a stack traceback if the thread errors while still propagating the error, and exits cleanly if it doesn't.
    end)
    table.insert(self.threads, new)
    return #self.threads
  end

  function proc:delthread(n)
    self.threads[n] = nil
    return true
  end

  function proc:kill()
    self.dead = true
  end

  function proc:stop()
    self.stopped = true
  end

  function proc:continue()
    self.stopped = false
  end

  function proc:interrupt()
    self.handlers.interrupt("interrupted")
  end

  function proc:terminate()
    self.handlers.terminate("terminated")
  end
  
  function proc:usr1()
    self.handlers.usr1("user signal 1")
  end

  function proc:usr2()
    self.handlers.usr2("EXECUTE ORDER 66")
  end

  function proc.new(name, handlers, env)
    local new = setmetatable({
      name = name,
      handlers = handlers or {default = kernel.logger.panic},
      env = env or {},
      threads = {},
      pid = 0,
      dead = false,
      owner = kernel.users.uid(),
      stopped = false,
      started = computer.uptime(),
      io = {[0] = {}, [1] = {}, [2] = {}},
      signals = {}
    }, {__index = proc})
    new.env.PWD = new.env.PWD or "/"
    new.env.UID = new.owner
    handlers.default = handlers.default or kernel.logger.panic
    setmetatable(new.handlers, {__index = function() return new.handlers.default end})
    local ts = tostring(new):gsub("table", "process")
    return setmetatable(new, {__type = "process", __tostring = function() return ts end})
  end

  ------------------------------------------------------------------------------------------

  kernel.logger.log("initializing scheduler")
  local process, processes, lastpid, current = {}, {}, 0, 0

  function process.spawn(func, name, handlers, env)
    checkArg(1, func, "function")
    checkArg(2, name, "string")
    checkArg(3, handlers, "table", "nil")
    checkArg(4, env, "table", "nil")
    env = env or kernel.table_copy((processes[current] or {env = {}}).env)
    local new = proc.new(name, handlers, env)
    lastpid = lastpid + 1
    new.pid = lastpid
    new.parent = current
    local dummy = {io = {[0] = {}, [1] = {}, [2] = {}}}
    new.io[0] = (processes[current] or dummy).io[0]
    new.io[1] = (processes[current] or dummy).io[1]
    new.io[2] = (processes[current] or dummy).io[2]
    new:addthread(func)
    processes[lastpid] = new
    coroutine.yield(0)
    return lastpid
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
      return nil, "no such process"
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

  kernel.process = process
end
