local shell = require("shell")

local args, opts = shell.parse(...)
if #args == 0 then
  local data = io.read()
  print(data)
  return 0
else
  for k, v in ipairs(args) do
    local file, err = io.open(v, "r")
    if file then
      repeat
        local chunk = file:read(2048)
        io.write(chunk or "")
      until not chunk
      file:close()
    else
      shell.error("cat", err)
      return 1
    end
  end
end
