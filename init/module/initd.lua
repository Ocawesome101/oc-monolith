log("Running scripts out of /lib/init/....")

local files = kernel.filesystem.list("/lib/init/")
if files then
  table.sort(files)
  for k, v in ipairs(files) do
    log(v)
    local full = kernel.filesystem.concat("/lib/init", v)
    local ok, err = loadfile(full)
    if not ok then
      panic(err)
    end
  end
end
