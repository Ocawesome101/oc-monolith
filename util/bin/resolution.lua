-- resolution setting --

local shell = require("shell")

local args, opts = shell.parse(...)

if #args == 0 then
  print(io.stdout.gpu.getResolution())
else
  local cw, ch = io.stdout.gpu.getResolution()
  local w, h = tonumber(args[1]) or ch, tonumber(args[2]) or ch
  local ok, err = pcall(io.stdout.gpu.setResolution, w, h)
  if not ok then
    shell.error("resolution", err)
    return shell.codes.failure
  end
end
