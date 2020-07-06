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
