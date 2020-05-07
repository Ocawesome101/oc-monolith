-- used in cp --

local fs = require("filesystem")

local cp = {}
cp.verbose = false
cp.recurse = false

function cp.copy(...)
  local args = {...}
  for _, path in ipairs(args) do
    args[_] = fs.canonical(path)
  end
  local to = table.remove(args, #args)
  if not fs.exists(to) then
    if #args > 1 then
      fs.makeDirectory(to)
    end
  end
  for i=1, #args, 1 do
    local path = args[i]
    if cp.verbose then
      if fs.isDirectory(to) then
        print(string.format("%s -> %s", path, fs.concat(to, fs.name(path))))
      else
        print(string.format("%s -> %s", path, to))
      end
    end
    if not fs.isDirectory(path) then
      if fs.isDirectory(to) then
        fs.copy(path, fs.concat(to, fs.name(path)))
      elseif #args == 1 then
        fs.copy(path, to)
      else
        error("multiple sources cannot be copied to one file")
      end
    elseif not cp.recurse then
      print(string.format("cp: -r not specified: skipping %s"))
    else
      if fs.isDirectory(to) then
        fs.makeDirectory(to .. fs.name(path))
        for file in fs.list(path) do
          local from = fs.concat(path, file)
          copy(from, to)
        end
      elseif #args == 1 then
        fs.copy(path, to)
      else
        error("multiple sources cannot be copied to one file")
      end
    end
  end
end

return cp
