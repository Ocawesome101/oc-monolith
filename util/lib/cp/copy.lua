-- used in cp --

local fs = require("filesystem")

local cp = {}
cp.verbose = false
cp.recurse = false

function cp.copy(...)
  local args = {...}
  local to = fs.canonical(args[#args])
  if #args > 2 and fs.exists(to) and not fs.isDirectory(to) then
    error("cannot copy multiple files to one file")
  end
  args[#args] = nil
  for i, path in ipairs(args) do
    if cp.verbose then
      print(string.format("%s -> %s", path, to))
    end
    local cpath = fs.canonical(path)
    if fs.isDirectory(cpath) and cp.recurse then
      if fs.exists(to) then
        fs.makeDirectory(fs.concat(to, path))
        for file in fs.list(cpath) do
          cp.copy(fs.concat(cpath, file), fs.concat(to, path, file))
        end
      else
        fs.makeDirectory(to)
        for file in fs.list(cpath) do
          cp.copy(fs.concat(cpath, file), fs.concat(to, file))
        end
      end
    elseif fs.isDirectory(cpath) then
      print("cp: -r not specified: skipping " .. path)
    else
      fs.copy(cpath, to)
    end
  end
end

return cp
