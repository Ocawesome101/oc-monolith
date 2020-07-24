-- cron jobs! --

local fs = require("filesystem")
local config = require("config")
local computer = require("computer")

local started = computer.uptime()
local log = io.open("/tmp/cron.log", "a")
local logwrite = function(...)log:write(...)end

-- intervals in seconds
local intervals = {
  hour = 3600, -- hour
  half = 1800, -- half-hour
  minute = 60  -- for performance reasons, a minute is the smallest interval supported by default
}

local scheduled = {}

-- haha i punny
local cronfig = config.load("/etc/cron.cfg") or {}
cronfig.intervals = cronfig.intervals or intervals
local jobd = "/etc/cron.d/"
config.save(cronfig, "/etc/cron.cfg")

local function search(dir, interval)
  scheduled[interval] = scheduled[interval] or {}
  for file in fs.list(dir) do
    logwrite("cron: adding job " .. fs.concat(dir, file) .. " at interval " .. interval)
    table.insert(scheduled[interval], fs.concat(dir, file))
  end
end

fs.makeDirectory(jobd)

if fs.exists(jobd) then
  for dir in fs.list(jobd) do
    logwrite("cron: adding jobs from " .. jobd .. dir)
    search(jobd .. dir, cronfig.intervals[dir])
  end
end

local last = {}
while true do
  coroutine.yield(5)
  for k, v in pairs(scheduled) do
    if computer.uptime() - last[k] >= k then
      logwrite("cron: resuming jobs at interval: " .. k)
      for n, job in pairs(v) do
        local ok, err = pcall(dofile, job)
        if not ok and err then
          local err = "cron: error in " .. job .. ":\n" .. err
          logwrite(err)
        end
      end
      last[k] = computer.uptime()
    end
  end
end

log:close()
