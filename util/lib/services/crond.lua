-- cron jobs! --

local computer = require("computer")

local started = computer.uptime()

local intervals = {
  hour = 3600, -- hour
  half = 1800, -- half-hour
  minute = 60  -- for performance reasons, a minute is the smallest innnnnnnnnnterval supported
}
local scheduled = {}
