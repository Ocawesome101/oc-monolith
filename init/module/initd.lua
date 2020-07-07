log("WAIT", "Running scripts in /lib/init")

local files = kernel.filesystem.list("/lib/init/")
if files then
  table.sort(files)
  for k, v in ipairs(files) do
    log("WAIT", v)
    local full = kernel.filesystem.concat("/lib/init", v)
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

log("OK", "Run scripts in /lib/init")
