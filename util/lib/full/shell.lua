local shell = require("shell")

shell.codes = {
  misc = -1,
  success = 0,
  failure = 1,
  argument = 2,
  permission = 127
}

shell.errors = {
  [shell.codes.misc] = "errored",
  [shell.codes.failure] = "failed",
  [shell.codes.argument] = "bad argument",
  [shell.codes.permission] = "permission denied"
}

setmetatable(shell.errors, {__index = function()return "failed" end})

function shell.setAlias(k, v)
  checkArg(1, k, "string")
  checkArg(2, v, "string")
  shell.aliases[k] = v
end

function shell.unsetAlias(k)
  checkArg(1, k, "string")
  shell.aliases[k] = nil
end

-- more advanced argument parser similar to GNU getopt()
function shell.getopt(args, argstring)
  local parsed_args, parsed_opts = {}, {}
  local done_opts = false
  local opts = {}
  local lastc = ""
  local lastopt = false
  for c in argstring:gmatch(".") do
    if c == ":" then
      if lastc == ":" then
        opts[lastopt] = {req = false, opt = true}
      else
        opts[lastopt] = {req = true, opt = true}
      end
    else
      opts[lastopt] = opts[lastopt] or {req = false, opt = false}
      lastopt = c
    end
    lastc = c
  end
  for i=1, #args, 1 do
    local parse = args[1]
    if parse == "-" then
      table.insert(parsed_args, parse)
    elseif parse == "--" and not done_opts then
      done_opts = true
    elseif parse:sub(1,1) == "-" and not done_opts then
      local opt = parse:sub(2,2)
      if opts[opt] and opts[opt].opt then
        if args[i + 1] then
          parsed_opts[opt] = args[i + 1]
          i = i + 2
        elseif opts[opt].req then
          shell.error("getopt", "missing argument")
          os.exit(-1)
        else
          parsed_opts[opt] = parsed_opts[opt] or true
        end
      else
        for c in opt:gmatch(".") do
          parsed_opts[c] = parsed_opts[c] or true
        end
      end
    else
      table.insert(parsed_args, parse)
    end
  end
  return parsed_args, parsed_opts
end
