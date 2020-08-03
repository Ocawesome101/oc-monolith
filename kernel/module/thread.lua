-- big fancy scheduler. this may not be the best but at least it's pretty reliable! --

do
  kernel.logger.log("thread: initializing cooperative scheduler")
  local thread, threads, sbuf, last, cur = {}, {}, {}, 0, 0
  local pullSignal = computer.pullSignal
  local liveCoro = coroutine.create(function()end)

  local function checkDead(thd)
    local p = threads[thd.parent] or {dead = false, coro = liveCoro}
    if thd.dead or p.dead or coroutine.status(thd.coro) == "dead" or coroutine.status(p.coro) == "dead" then
      p = nil
      return true
    end
    p = nil
  end

  local function getMinTimeout()
    local min = math.huge
    for pid, thd in pairs(threads) do
      if thd.deadline - computer.uptime() < min then
        min = computer.uptime() - thd.deadline
      end
      if min <= 0 then
        min = 0
        break
      end
    end
    return min
  end

  local function cleanup()
    local dead = {}
    for pid, thd in pairs(threads) do
      if checkDead(thd) then
        computer.pushSignal("thread_died", pid)
        dead[#dead + 1] = pid
      end
    end
    for i=1, #dead, 1 do
      threads[dead[i]] = nil
    end

    local timeout = getMinTimeout()
    local sig = {pullSignal(timeout)}
    if #sig > 0 then
      sbuf[#sbuf + 1] = sig
    end
  end

  local function getHandler(thd)
    local p = threads[thd.parent] or {}
    return thd.handler or p.handler or getHandler(p) or kernel.logger.panic
  end

  local function handleProcessError(thd, err)
    local h = getHandler(thd)
    threads[thd.pid] = nil
    computer.pushSignal("thread_errored", thd.pid, string.format("error in thread '%s' (PID %d): %s", thd.name, thd.pid, err))
    kernel.logger.log("thread errored: " .. string.format("error in thread '%s' (PID %d): %s", thd.name, thd.pid, err))
    h(thd.name .. ": " .. err)
  end

  local global_env = {}

  function thread.spawn(func, name, handler, env)
    checkArg(1, func, "function")
    checkArg(2, name, "string")
    checkArg(3, handler, "function", "nil")
    checkArg(4, env, "table", "nil")
    last = last + 1
    local current = thread.info() or { data = { io = {[0] = {}, [1] = {}, [2] = {} }, env = {} } }
    env = env or kernel.table_copy(current.data.env)
    local new = {
      coro = coroutine.create(func),            -- the thread
      pid = last,                               -- process/thread ID
      parent = cur,                             -- parent thread's PID
      name = name,                              -- thread name
      handler = handler or kernel.logger.panic, -- error handler
      user = kernel.users.uid(),                -- current user
      users = {},                               -- user history
      owner = kernel.users.uid(),               -- thread owner
      sig = {},                                 -- signal buffer
      ipc = {},                                 -- IPC buffer
      env = env,                                -- environment variables
      deadline = computer.uptime(),             -- signal deadline
      priority = priority,                      -- thread priority
      uptime = 0,                               -- thread uptime
      stopped = false,                          -- is it stopped?
      started = computer.uptime(),              -- time of thread creation
      io      = {                               -- thread I/O streams
        [0] = current.data.io[0],
        [1] = current.data.io[1],
        [2] = current.data.io[2] or current.data.io[1]
      }
    }
    if not new.env.PWD then
      new.env.PWD = "/"
    end
    setmetatable(new, {__index = threads[cur] or {}})
    threads[last] = new
    computer.pushSignal("thread_spawned", last)
    return last
  end

  kernel.logger.log("thread: (re)defining login, logout to be thread-local")
  -- define kernel.users stuff to be thread-local. Not done in module/users.lua as it requires low-level thread access.
  function kernel.users.login(uid, password)
    checkArg(1, uid, "number")
    checkArg(2, password, "string")
    local ok, err = kernel.users.authenticate(uid, password)
    if not ok then
      return nil, err
    end
    if threads[cur] then
      table.insert(threads[cur].users, 1, threads[cur].user)
      threads[cur].user = uid
      return true
    end
    return true
  end

  function kernel.users.logout()
    if threads[cur] then
      threads[cur].user = -1
      if #threads[cur].users > 0 then
        threads[cur].user = table.remove(threads[cur].users, 1)
      else
        threads[cur].user = -1 -- guest, no privileges
      end
      return true
    end
    return false -- kernel is always root
  end

  function kernel.users.uid()
    if threads[cur] then
      return threads[cur].user
    else
      return 0 -- again, kernel is always root
    end
  end

  function thread.threads()
    local t = {}
    for pid, _ in pairs(threads) do
      t[#t + 1] = pid
    end
    table.sort(t, function(a,b) return a < b end)
    return t
  end

  function thread.info(pid)
    checkArg(1, pid, "number", "nil")
    pid = pid or cur
    if not threads[pid] then
      return nil, "no such thread"
    end
    local t = threads[pid]
    local inf = {
      name = t.name,
      owner = t.owner,
      priority = t.priority,
      parent = t.parent,
      uptime = t.uptime,
      started = t.started
    }
    if pid == cur then
      inf.data = {
        io = t.io,
        env = t.env
      }
    end
    return inf
  end

  function thread.signal(pid, sig)
    checkArg(1, pid, "number")
    checkArg(2, sig, "number")
    if not threads[pid] then
      return nil, "no such thread"
    end
    if threads[pid].owner ~= kernel.users.uid() and kernel.users.uid() ~= 0 then
      return nil, "permission denied"
    end
    local msg = {"signal", cur, sig}
    table.insert(threads[pid].sig, msg)
    return true
  end

  function thread.ipc(pid, ...)
    checkArg(1, pid, "number")
    if not threads[pid] then
      return nil, "no such thread"
    end
    local ipc = table.pack("ipc", cur, ...)
    table.insert(threads[pid].ipc, ipc)
    return true
  end

  function thread.current()
    return cur
  end

  -- detach from the parent thread
  function thread.detach()
    threads[cur].parent = 1
  end

  -- detach any child thread, parent it to init
  function thread.orphan(pid)
    checkArg(1, pid, "number")
    if not threads[pid] then
      return nil, "no such thread"
    end
    if threads[pid].parent ~= cur then
      return nil, "specified thread is not a child of the current thread"
    end
    threads[pid].parent = 1 -- init
  end

  thread.signals = {
    interrupt = 2,
    quit      = 3,
    kill      = 9,
    term      = 15,
    terminate = 15,
    continue  = 18,
    stop      = 19,
    usr1      = 65,
    usr2      = 66,
  }

  function thread.kill(pid, sig)
    return thread.signal(pid, sig or thread.signals.term)
  end

  function thread.start()
    thread.start = nil
    kernel.logger.log("thread: starting main loop")
    while #threads > 0 do
      local run = {}
      for pid, thd in pairs(threads) do
        threads[pid].uptime = computer.uptime() - thd.started
        if (thd.deadline <= computer.uptime() or #sbuf > 0 or #thd.ipc > 0 or #thd.sig > 0) and not thd.stopped then
          run[#run + 1] = thd
        end
      end

      local sig = table.remove(sbuf, 1)

      for i, thd in ipairs(run) do
        cur = thd.pid
        local ok, r1
        if #thd.ipc > 0 then
          local ipc = table.remove(thd.ipc, 1)
          ok, r1 = coroutine.resume(thd.coro, table.unpack(ipc))
        elseif #thd.sig > 0 then
          local nsig = table.remove(thd.sig, 1)
          if nsig[3] == thread.signals.kill then
            thd.dead = true
            ok, r1 = true, "killed"
          elseif nsig[3] == thread.signals.stop then
            thd.stopped = true
          elseif nsig[3] == thread.signals.continue then
            thd.stopped = false
          else
            ok, r1 = coroutine.resume(thd.coro, table.unpack(nsig))
          end
        elseif sig and #sig > 0 then
          ok, r1 = coroutine.resume(thd.coro, table.unpack(sig))
        else
          ok, r1 = coroutine.resume(thd.coro)
        end
        --kernel.logger.log(tostring(ok) .. " " .. tostring(r1))
        if (not ok) and r1 then
          handleProcessError(thd, r1)
        elseif ok then
          if r1 and type(r1) == "number" then
            thd.deadline = computer.uptime() + r1
          else
            thd.deadline = math.huge
          end
          thd.uptime = computer.uptime() - thd.started
        end
      end

      if computer.freeMemory() < 512 then -- oh no, we're out of memory
        kernel.logger.log("Low memory - collecting garbage")
        collectgarbage()
        if computer.freeMemory() < 512 then -- GC didn't help. Panic!
          kernel.logger.panic("ran out of memory")
        end
      end
      cleanup()
    end
    kernel.logger.log("thread: exited cleanly! this SHOULD NOT HAPPEN!")
    kernel.logger.panic("thread: all threads died!")
  end

  kernel.thread = thread
  kernel.logger.log("thread: initialized scheduler")
end
