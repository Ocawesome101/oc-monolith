-- stty --

local shell = require("shell")
local args, opts = shell.parse(...)

local presets = {
  insane = "\27(l\27(R\27[8m",
  sane   = "\27(L\27(r\27[28m",
  raw    = "\27(R"
}

if #args == 0 then
  print("speed ~9600 baud; line = 0;")
  print("iutf8")
  os.exit()
end

if presets[args[1]] then
  io.write(presets[args[1]])
else
  print("invalid preset (expected insane, sane, raw)")
end
