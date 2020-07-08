-- loggers --

local logger = {}

logger.prefixes = {
  bracket = {
    ok   = "\27[37m[ \27[92m OK \27[37m ]",
    info = "\27[37m[ \27[94mINFO\27[37m ]",
    warn = "\27[37m[ \27[93mWARN\27[37m ]"
    fail = "\27[37m[ \27[91mFAIL\27[37m ]"
  },
  arrow = {
    ok   = "\27[92m->\27[37m"
    info = "\27[94m->\27[37m"
    warn = "\27[93m->\27[37m"
    fail = "\27[91m->\27[37m"
  },
  double = {
    ok   = "\27[92m>>\27[37m"
    info = "\27[94m>>\27[37m"
    warn = "\27[93m>>\27[37m"
    fail = "\27[91m>>\27[37m"
  }
}

function logger:ok(...)
  print(table.concat({self.style.ok, ...}))
end

function logger:info(...)
  print(table.concat({self.style.info, ...}))
end

function logger:warn(...)
  print(table.concat({self.style.warn, ...}))
end

function logger:fail(...)
  print(table.concat({self.style.fail, ...}))
end

function logger.new(style)
  if not logger.prefixes[style] then
    return nil, "no such style"
  end
  return setmetatable({
    style = logger.prefixes[style]
  },
  {
    __index = logger
  })
end

return logger
