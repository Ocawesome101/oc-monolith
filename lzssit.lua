-- lzss it! --

-- the same lzss lib Monolith uses :P
local lzss = require("util.lib.lzss")

local IN = "release.cpio"
local OUT = "release.cpio.lzss"

local open, err = io.open(IN)
if not open then
  error(err)
end
local data = open:read("*a")
open:close()

local out, err = io.open(OUT, "w")
if not out then
  error(err)
end
out:write(lzss.compress(data))
out:close()
