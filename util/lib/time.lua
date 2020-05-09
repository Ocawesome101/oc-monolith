-- time utils --

local time = {}

-- format time for printing.
-- supported units: TODO
-- * 'ms' or 1000: milliseconds, default
-- * 's' or 1: seconds
-- * 'm': minutes
-- * 'h': hours
function time.formatTime(time, unit, from)
  checkArg(1, time, "number")
  checkArg(2, unit, "string", "number", "nil")
  checkArg(3, from, "boolean", "nil")
  time = time // 1
  unit = unit or "ms"
  local fmt = ""
  if unit == "ms" or unit == 1000 then
    time = time // 1000
  end
  local date = os.date("*t", time)
  fmt = string.format("%02d:%02d:%02d", (date.hour and date.hour - (from and 19 or 0)) or 0, date.min or 0, date.sec or 0) -- make sure it doesn't look like we're in 1969!
  return fmt or "00:00:00"
end

return time
