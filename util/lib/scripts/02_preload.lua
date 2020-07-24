-- preload libraries used later --

local libs = {
  "vt100",
  "config",
  "readline",
  "stream",
  "shell",
  "sh",
  "event"
}

for i=1, #libs, 1 do
  require(libs[i])
end
