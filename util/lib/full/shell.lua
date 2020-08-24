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

function shell.unsetAlias(k)
  checkArg(1, k, "string")
  shell.aliases[k] = nil
end

-- more advanced argument parser similar to GNU getopt() but with tables as arguments
function shell.getopt(args, argdefs)
  checkArg(1, args, "table")
  checkArg(2, argdefs, "table")
  local parsed_args, parsed_opts, done_opts, i = {}, {}, false, 1
  local function get(opt)
    local def = argdefs[opt] or {takesarg = false, reqarg = false}
    if def.takesarg then
      local try = args[i + 1] or nil
      if def.reqarg and not try then
        error("getopt: missing argument for option " .. opt)
      end
      parsed_opts[opt] = try or parsed_opts[opt] or true
      i = i + 1
    end
  end
  while i <= #args and not done_opts do
    local opt = args[i]
    if parse == "-" or done_opts then
      table.insert(parsed_args, opt)
    elseif parse == "--" then
      done_opts = true
    else
      local short = false
      if parse:sub(1,2) == "--" then
        parse = parse:sub(3)
      elseif parse:sub(1,1) == "-" then
        parse = parse:sub(2)
        short = true
      end
      if short then
        local o = parse:sub(1,1)
        parsed_opts[o] = #parse > 1 and (parse:sub(2)) or parsed_opts[o] or true
      else
        get(parse)
      end
    end
    i = i + 1
  end
  return parsed_args, parsed_opts
end
