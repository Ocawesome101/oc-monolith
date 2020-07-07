log("WAIT", "Running scripts from /lib/scripts/...")

local files = kernel.filesystem.list("/lib/scripts/")
if files then
  table.sort(files)
  for k, v in ipairs(files) do
    log("WAIT", v)
    local full = kernel.filesystem.concat("/lib/scripts/", v)
    local ok, err = loadfile(full)
    if not ok then
      panic(err)
    end
    local s, r = xpcall(ok, debug.traceback)
    if not s and r then
      log("FAIL", v)
      panic(r)
    end
    log("OK", v)
  end
end

log("OK", "Run scripts from /lib/scripts/")
