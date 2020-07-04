local shell = require("shell")

local args, opts = shell.parse(...)
if #args == 0 then
  while true do
    local data = io.read()
    print(data)
  end
else
  for k, v in ipairs(args) do
    local file, err = io.open(v, "r")
    if file then
      repeat
        local data = file:read(2048)
        io.write(data)
      until not data
      file:close()
    else
      shell.error("cat", err)
      return 1
    end
  end
end
