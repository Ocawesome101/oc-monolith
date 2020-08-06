log("INFO", "Running scripts from /lib/init/scripts/...")

local files = kernel.filesystem.list("/lib/init/scripts/")
if files then
  table.sort(files)
  for k, v in ipairs(files) do
    log("WAIT", v)
    local full = kernel.filesystem.concat("/lib/init/scripts/", v)
    local ok, err = loadfile(full)
    if not ok then
      panic(err)
    end
    local s, r = xpcall(ok, debug.traceback)
    if not s and r then
      kernel.logger.y = kernel.logger.y - 1
      log("FAIL", v)
      panic(r)
    end
  end
end
