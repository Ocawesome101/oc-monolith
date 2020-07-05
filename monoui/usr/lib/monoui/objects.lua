-- window objects --

local lib = {}

-- viewport allocation map for gpus
local alloc = {}

function lib.alloc(g,w,h)
  alloc[g.address] = alloc[g.address] or {}
  local mw, mh = g.maxResolution()
  if w > mw/2 or h > mh/2 then
    error("requested area too large")
  end
end

function lib.new(w,h)
  local gpu = io.stdout.gpu
  local x, y = lib.alloc(gpu,w,h)
  local win = {
    tlx = 
  }

  return win
end

return lib
