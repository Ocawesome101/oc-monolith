-- install Monolith --

local CPIO = "https://raw.githubusercontent.com/ocawesome101/oc-monolith/master/release.cpio"
local ARCPATH = "/mnt/monolith.cpio"
local MOUNT = "/mnt/install/"

-- pretty requires
local serialization = require("serialization")
local component    = require("component")
local computer    = require("computer")
local internet   = require("internet")
local fs      = require("filesystem")

if fs.isReadOnly("/") then
  print("Your OpenOS filesystem must be writable - exiting")
  os.exit(1)
end

-- get sha3 if we don't have it
if not require("sha3") then
  print("SHA-3 library not found - downloading")
  assert(loadfile("/bin/wget.lua"))("https://github.com/ocawesome101/oc-monolith/raw/master/util/lib/sha3.lua", "/lib/sha3.lua")
end
local sha3 = require("sha3")

local ask = {}
local fsl = component.list("filesystem")
local blacklist = {[computer.getBootAddress()] = true, [computer.tmpAddress()] = true}
for fsa, _ in fsl do
  if not blacklist[fsa] then
    ask[#ask + 1] = fsa
  end
end

-- uncpio credit to AdorableCatgirl, slightly modified
local function uncpio(file, dest)
  checkArg(1, file, "string")
  checkArg(2, dest, "string")
  local dir = dest
  local file = io.open(file, "rb")
  local filesystem = fs

  local dent = {
    magic = 0,
    dev = 0,
    ino = 0,
    mode = 0,
    uid = 0,
    gid = 0,
    nlink = 0,
    rdev = 0,
    mtime = 0,
    namesize = 0,
    filesize = 0,
  }

  local function readint(amt, rev)
    local tmp = 0
    for i=(rev and amt) or 1, (rev and 1) or amt, (rev and -1) or 1 do
      tmp = tmp | (file:read(1):byte() << ((i-1)*8))
    end
    return tmp
  end

  local function fwrite()
    local _dir = dent.name:match("(.+)/.*%.?.+")
    if (_dir) then
      filesystem.makeDirectory(dir.."/".._dir)
--      dir = dir .. "/" .. _dir
    end
    local hand = assert(io.open(dir.."/"..dent.name, "w"))
    hand:write(file:read(dent.filesize))
    hand:close()
  end

  while true do
    dent.magic = readint(2)
    local rev = false
    if (dent.magic ~= tonumber("070707", 8)) then rev = true end
    dent.dev = readint(2)
    dent.ino = readint(2)
    dent.mode = readint(2)
    dent.uid = readint(2)
    dent.gid = readint(2)
    dent.nlink = readint(2)
    dent.rdev = readint(2)
    dent.mtime = (readint(2) << 16) | readint(2)
    dent.namesize = readint(2)
    dent.filesize = (readint(2) << 16) | readint(2)
    local name = file:read(dent.namesize):sub(1, dent.namesize-1)
    if (name == "TRAILER!!!") then break end
    dent.name = name
    print(name)
    if (dent.namesize % 2 ~= 0) then
      file:seek("cur", 1)
    end
    if (dent.mode & 32768 ~= 0) then
      fwrite()
    end
    if (dent.filesize % 2 ~= 0) then
      file:seek("cur", 1)
    end
  end
end

local function menu(opts)
  print("\27[2J\27[1;1HPlease choose one:")
  for k, v in ipairs(opts) do
    print(string.format(" %d. %s", k, v))
  end
  local n
  repeat
    print("Enter a number.")
    io.write("> ")
    n = io.read():gsub("\n", "")
  until tonumber(n)
  return opts[tonumber(n)]
end

local function prompt(msg)
  local inp = ""
  repeat
    io.write(msg)
    inp = (io.read() or ""):gsub("\n", "")
  until inp ~= ""
  return inp
end

local function download(url, file)
  local handle, err = internet.request(url)
  if not handle then error(err) end
  local out = io.open(file, "w")
  if not out then error(err) end
  for chunk in handle do out:write(chunk) end
  out:close()
end

ask[#ask + 1] = "Quit"
local ifs = menu(ask)
if ifs == "Quit" then return 0 end

fs.mount(ifs, MOUNT)
print("Mounted install fs at " .. MOUNT)

print("Downloading " .. CPIO .. " as " .. ARCPATH)
download(CPIO, ARCPATH)

print("Extracting CPIO to " .. MOUNT)
uncpio(ARCPATH, MOUNT)

print("Cleaning up installation files...")
fs.remove(ARCPATH)

print("Now that the system has been installed, you should set up a user.")

local rootpass = prompt("root password: \27[30;40m")

io.write("\27[0m")
local name = prompt("username: ")

local password = prompt("password: \27[30;40m")
local passwd = fs.concat(MOUNT, "/etc/passwd")

local function tohex(str)
  local r = ""
  for char in str:gmatch(".") do
    r = r .. string.format("%02x", char:byte())
  end
  return r
end

-- remove special chars from a string
local function strip(str)
  local special = "[^%w%-_]"
  return str:gsub(special, "_")
end

local tpasswd = {
  [0] = {
    u = 0,
    c = true,
    n = "root",
    h = "/root",
    p = tohex(sha3.sha256(rootpass))
  },
  [1] = {
    u = 1,
    c = true,
    n = name,
    h = "/home/" .. strip(name),
    p = tohex(sha3.sha256(password))
  }
}

print("\27[0mAdding user to /etc/passwd")

local handle, err = io.open(passwd, "w")
if not handle then error("failed opening etc/passwd: " .. err) end
handle:write(serialization.serialize(tpasswd))
handle:close()

print("Creating user home directories")

fs.makeDirectory(fs.concat(MOUNT, "/root"))
fs.makeDirectory(fs.concat(MOUNT, "/home"))
fs.makeDirectory(fs.concat(MOUNT, tpasswd[1].h))

print("Done!")
