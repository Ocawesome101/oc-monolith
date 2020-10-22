--[[ Copyright (C) 2020 Ocawesome101

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details. ]]
local shell = require("shell")

local args, opts = shell.parse(...)

if #args == 0 then
  while true do
    local data = io.read()
    if not data then
      os.exit()
    end
    print(data)
  end
else
  for k, v in ipairs(args) do
    local file, err = io.open(v, "r")
    if file then
      repeat
        local data = file:read(2048)
        if data then io.write(data) end
      until not data
      file:close()
    else
      shell.error("cat", err)
      return 1
    end
  end
end
