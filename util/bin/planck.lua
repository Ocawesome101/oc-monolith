local file = ...
file = file or "/tmp/.f"
local component = component or require("component")
local computer = computer or require("computer")
local ver = "1.0"
local gpu = io.stdout.gpu
local lines = {}

print("WARNING: planck will NOT WORK PROPERLY when using multiple screens!")
print("WARNING: planck is not made by me, and as such I take no liability for it!")
print("Continuing to the editor in 2 seconds.")

os.sleep(2)

local f = io.open(file, "r")
if (f) then
	for line in f:lines() do
		lines[#lines+1] = line
	end
	f:close()
else
	lines[#lines+1] = ""
end
--local lines = string.pack("I3", 1)

local kd = {}

local keys = {
	lcontrol        = 0x1D,
	back            = 0x0E, -- backspace
	delete          = 0xD3,
	down            = 0xD0,
	enter           = 0x1C,
	home            = 0xC7,
	left            = 0xCB,
	lshift          = 0x2A,
	pageDown        = 0xD1,
	rcontrol        = 0x9D,
	right           = 0xCD,
	rmenu           = 0xB8, -- right Alt
	rshift          = 0x36,
	space           = 0x39,
	tab             = 0x0F,
	up              = 0xC8,
	["end"]         = 0xCF,
	tab             = 0x0F,
	numpadenter     = 0x9C,
}

--f:seek("set", 0)

local w, h
local x, y = 1, 1
local function getpos()
	return x, y
end

local function getttysize()
	return gpu.getViewport()
end

local fg, bg = 0xFFFFFF, 0

local function update_colors()
	gpu.setBackground(bg)
	gpu.setForeground(fg)
end

local function invert()
	local _f, _b = bg, fg
	bg, fg = _b, _f
	update_colors()
end

local function move_cursor(_x, _y)
	x = _x or 1
	y = _y or 1
	if (x > w) then x = w end
	if (y > h) then y = h end
end

local function write(str)
	gpu.set(x, y, str)
	x = x + #str
	if (x > w) then x = w end
end

w, h = getttysize()

gpu.fill(1, 1, w, h, " ")

local function display_line(ln, start_char, curinfo, pos)
	--ttyout:write("\27[7l\n")
	--[[local start, pend = string.unpack("I3I3", lines:sub((3*(line-1))+1, (3*line)+1))
	local size = pend-start-1
	f:seek("set", start)
	local line = line:read(size)]]
	local line = lines[ln] or " - "
	--ttyout:write(string.format("\27[1;%dH", pos))
	move_cursor(1, pos)
	--ttyout:write()
	write(string.rep(" ", w))
	--ttyout:write(string.format("\27[1;%dH", pos))
	move_cursor(1, pos)
	local ex = 1
	for i=1, #line do
		local c = line:sub(i, i)
		if (c == "\t") then
			ex = ex + 2
			c = "  "
		else
			ex = ex + 1
		end
		if (ex >= start_char) then
			if (i == curinfo.x and pos == curinfo.y) then
				invert()
			end
			--ttyout:write(c)
			write(c)
			if (i == curinfo.x and pos == curinfo.y) then
				invert()
			end
		end
	end
	if (curinfo.x > #line and pos == curinfo.y) then
		invert()
		write(" ")
		invert()
	end
	local _x, _y = getpos()
	--ttyout:write(string.format("\27[999;%dH\n", pos))
	move_cursor(w-1, pos)
	if (ex - start_char > _x) then
		invert()
		write(">")
		invert()
		--ttyout:write("\27[7m>\27[7m\n")
	end
	--ttyout:write("\27[7h\n")
end

local function insert_char(c, line, pos)
	local l = lines[line]
	local _l1, _l2 = l:sub(1, pos-1), l:sub(pos)
	lines[line] = _l1 .. c .. _l2
end

local function split_line(line, pos)
	local l = lines[line]
	local _l1, _l2 = l:sub(1, pos-1), l:sub(pos)
	lines[line] = _l1
	table.insert(lines, line+1, _l2)
end

local function join_next_line(line)
	local l1, l2 = lines[line], lines[line+1]
	lines[line] = l1 .. l2
	table.remove(lines, line+1)
end

local function join_prev_line(line)
	local l1, l2 = lines[line-1], lines[line]
	lines[line-1] = l1 .. l2
	table.remove(lines, line)
	return #l1
end

local function bksp(line, pos)
	if (pos == 1 and line ~= 1) then
		return true, join_prev_line(line)
	elseif (pos > 1) then
		local l1, l2 = lines[line]:sub(1, pos-2), lines[line]:sub(pos)
		lines[line] = l1 .. l2
	end
end

local function del(line, pos)
	if (line ~= #lines and pos == #lines[line]+1) then
		join_next_line(line)
	elseif (pos < #lines[line]+1) then
		local l1, l2 = lines[line]:sub(1, pos-1), lines[line]:sub(pos+1)
		lines[line] = l1 .. l2
	end
end

local function write_out()
	local f = io.open(file, "w")
	f:write(table.concat(lines, "\n"))
	f:close()
end

local ci = {x = 1, y = 1}
local si = {x = 1, y = 1}

while true do
	for i=1, h-1 do
		display_line(si.x+i-1, si.y, ci, i)
	end
	--ttyout:write(string.format("\27[1;%d", h))
	move_cursor(1, h)
	invert()
	write(string.rep(" ", w))
	invert()
	move_cursor(1, h)
	invert()
	--ttyout:write(string.format("PLANCK %s | ^S - Save | ^W - Close | %d, %d\n", ver, si.x, si.y))
	write(string.format("PLANCK %s | %s | F1 - Save | F2 - Close | %d, %d", ver, file:match("^.*/(.+)$") or file, si.x+ci.x-1, si.y+ci.y-1))
	invert()
	--gpu.set(1, h, string.format("PLANCK %s | ^S - Save | ^W - Close | %d, %d", ver, si.x, si.y))
	--And now we process controls.
	local sig = {computer.pullSignal()}
	--gpu.set(1, h-1, string.rep(" ", w))
	--gpu.set(1, h-1, string.format("%s %d %d", tostring(sig[1] or ""), tonumber(sig[3]) or 0, tonumber(sig[4]) or 0))
	--gpu.set(1, h-2, tostring(#lines))
	for k, v in pairs(keys) do
		if (sig[1] == "key_down" and sig[4] == v) then
			kd[k] = true
		elseif (sig[3] == "key_up" and sig[4] == v) then
			kd[k] = false
		end
	end
	if (sig[1] == "key_down") then
		if sig[4] == 0x3b then
			write_out()
		elseif sig[4] == 0x3c then
			break
		elseif (sig[3] == string.byte("\t") or (sig[3] > 31 and sig[3] < 127)) then
			insert_char(string.char(sig[3]), si.y+ci.y-1, si.x+ci.x-1)
			ci.x = ci.x+1
		elseif (sig[4] == keys.down) then
			ci.y = ci.y + 1
			if (si.y+ci.y-1 > #lines) then
				ci.y = #lines - si.y + 1
			end
			if (ci.y > h) then
				si.y = si.y + 1
				ci.y = h
			end
			if (si.x+ci.x-1 > #lines[si.y+ci.y-1]+1) then
				ci.x = #lines[si.y+ci.y-1] - si.x + 2
			end
			if (ci.x > w) then
				si.x = si.x + 1
				ci.x = w
			end
		elseif (sig[4] == keys.up) then
			ci.y = ci.y - 1
			if (si.y == 1 and ci.y == 0) then
				ci.y = 1
			end
			if (ci.y == 0) then
				si.y = si.y - 1
				ci.y = 1
			end
			if (si.x+ci.x-1 > #lines[si.y+ci.y-1]+1) then
				ci.x = #lines[si.y+ci.y-1] - si.x + 2
			end
			if (ci.x > w) then
				si.x = si.x + 1
				ci.x = w
			end
		elseif (sig[4] == keys.left) then
			ci.x = ci.x - 1
			if (si.x == 1 and ci.x == 0) then
				ci.x = 1
			end
			if (ci.x == 0) then
				si.x = si.x - 1
				ci.x = 1
			end
		elseif (sig[4] == keys.right) then
			ci.x = ci.x + 1
			if (si.x+ci.x-1 > #lines[si.y+ci.y-1]+1) then
				ci.x = #lines[si.y+ci.y-1] - si.x + 2
			end
			if (ci.x > w) then
				si.x = si.x + 1
				ci.x = w
			end
		elseif (sig[4] == keys["end"]) then
			if (#lines[si.y+ci.y-1] <= w) then
				si.x = 1
				ci.x = #lines[si.y+ci.y-1]+1
			else
				si.x = #lines[si.y+ci.y-1]-w+1
				ci.x = w
			end
		elseif (sig[4] == keys.home) then
			si.x = 1
			ci.x = 1
		elseif (sig[4] == keys.delete) then
			del(si.y+ci.y-1, ci.x+si.x-1)
		elseif (sig[4] == keys.back) then
			local bk, pos = bksp(si.y+ci.y-1, ci.x+si.x-1)
			if (bk) then
				if (pos < w) then
					si.x = 1
					ci.x = pos+1
				else
					si.x = pos-w
					ci.x = w
				end
				ci.y = ci.y - 1
				if (si.y == 1 and ci.y == 0) then
					ci.y = 1
				end
				if (ci.y == 0) then
					si.y = si.y - 1
					ci.y = 1
				end
				if (si.x+ci.x-1 > #lines[si.y+ci.y-1]+1) then
					ci.x = #lines[si.y+ci.y-1] - si.x + 2
				end
				if (ci.x > w) then
					si.x = si.x + 1
					ci.x = w
				end
			else
				ci.x = ci.x - 1
				if (si.x == 1 and ci.x == 0) then
					ci.x = 1
				end
				if (ci.x == 0) then
					si.x = si.x - 1
					ci.x = 1
				end
			end
		elseif (sig[4] == keys.enter) then
			local pos = split_line(si.y+ci.y-1, ci.x+si.x-1)
			si.x = 1
			ci.x = 1
			ci.y = ci.y + 1
			if (si.y+ci.y-1 > #lines) then
				ci.y = #lines - si.y + 1
			end
			if (ci.y > h) then
				si.y = si.y + 1
				ci.y = h
			end
			if (si.x+ci.x-1 > #lines[si.y+ci.y-1]+1) then
				ci.x = #lines[si.y+ci.y-1] - si.x + 2
			end
			if (ci.x > w) then
				si.x = si.x + 1
				ci.x = w
			end
		end
	end
end
