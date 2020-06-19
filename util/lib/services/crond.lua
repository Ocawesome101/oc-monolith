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
  minute = 60  -- for performance reasons, a minute is the smallest interval supported
}

local scheduled = {}

-- haha i punny
local cronfig = config.load("/etc/cron.cfg") or {}
cronfig.intervals = cronfig.intervals or intervals
local jobd = "/etc/cron.d/"

local function search(dir, interval)
  scheduled[interval] = scheduled[interval] or {}
  for file in fs.list(dir) do
    logwrite("adding job " .. fs.concat(dir, file) .. " at interval " .. interval)
    table.insert(scheduled[interval], fs.concat(dir, file))
  end
end

for dir in fs.list(jobd) do
  logwrite("adding jobs from " .. jobd .. dir)
  search(jobd .. dir, cronfig.intervals[dir])
end
