-- mpm- the Monolith Package Manager --

local   shell  = require (   "shell"  )
local  config  = require (  "config"  )
local   cpio   = require (   "cpio"   )
local    fs    = require ("filesystem")
local internet = require ( "internet" )
local    cp    = loadfile("/bin/cp.lua")
local    rm    = loadfile("/bin/rm.lua")

local cfg = config.load("/etc/mpm/mpm.cfg")
cfg.names = cfg.names or {"ocawesome101"}
cfg.baseURL = cfg.baseURL or "https://raw.githubusercontent.com"
config.save(cfg, "/etc/mpm/mpm.cfg")

local function lprint(...)
  local msg = table.concat({...}, " ")
  print("\27[93m-> \27[37m" .. msg)
end

lprint("Initializing MPM")

local function download(url, file)
  lprint("Downloading", url, "as", file)
  local handle = internet.request(url)
  local out, err = io.open(file, "w")
  if not out then
    handle.close()
    error(err)
  end
  for chunk in handle do
    out:write(chunk)
  end
  out:close()
end

local function getParts(s)
  return s:match("(.+)[/+](.+)[/+](.+)") or nil, s:match("(.+)[/+](.+)")
end

local function randomFileName()
  local base = "/tmp"
  local random = math.random(111111, 999999)
  return string.format("%s/%d", base, random)
end

local function check(user, repo, pkg)
  local url     = string.format("%s/%s/%s/master/packages/%s.cpio", cfg.baseURL, user, repo, pkg)
  lprint("Checking URL:\27[94m", url, "\27[37m....")
  local ok, err = pcall(download, url, "/dev/null") -- :^)
  return ok
end

local function getPackageConfig(package)
  local user, repo, pkg = getParts(package)
  if not user then
    lprint("No username provided - checking name list from configuration")
    for _, v in pairs(cfg.names) do
      local ok = check(v, repo, pkg)
      if ok then
        lprint("Found user with matching repository and package:", v)
        user = v
        break
      end
    end
    if not user then
      lprint("\27[91mError: Could not find a user with a matching repository and package")
      error()
    end
  end
  local url = string.format("%s/%s/%s/master/packages/%s.cpio", cfg.baseURL, user, repo, pkg)
  local exTo = string.format("/tmp/%s", pkg)
  local file = string.format("/tmp/%s.cpio", pkg)
  download(url, file)
  cpio.extract(file, exTo)
  return exTo, string.format("%s/%s/%s", user, repo, pkg), config.load(string.format("%s/package.cfg", exTo))
end

local function install(package)
  lprint("Installing package", package)
  local installed = config.load("/etc/mpm/installed.cfg")
  local path, urp, cfg = getPackageConfig(package)
  if not (cfg.name and cfg.creator and cfg.files) then
    lprint("\27[91mError: Invalid package configuration file (missing one of: name, creator, files)")
    return shell.codes.failure
  end
  lprint("Registering package....")
  installed[urp:lower()] = {
    name = cfg.name,
    creator = cfg.creator,
    files = cfg.files,
    description = cfg.description or "MPM Package"
  }
  lprint("Saving configuration....")
  config.save(installed, "/etc/mpm/installed.cfg")
  lprint("Copying files....")
  for _, file in pairs(cfg.files) do
    local src = fs.concat(path, file)
    local dest = file
    cp("-rvi", src, dest)
  end
  lprint("Done.")
end

local function remove(package)
  lprint("Removing package", package)
  local installed = config.load("/etc/mpm/installed.cfg")
  if not installed[package:lower()] then
    lprint("\27[91mError: Package", package, "is not installed!")
    error()
  end
  local ent = installed[package:lower()]
  lprint("Removing files....")
  for _, file in pairs(ent.files) do
    rm("-rvi", file)
  end
  lprint("Unregistering package....")
  installed[package:lower()] = nil
  lprint("Saving configuration....")
  config.save(installed, "/etc/mpm/installed.cfg")
  lprint("Done.")
end

local function list()
  lprint("Loading configuration....")
  local installed = config.load("/etc/mpm/installed.cfg")
  for k, v in pairs(installed) do
    lprint(string.format("\27[92m%s: %s\n  \27[37m%s", v.creator, k, v.description))
  end
end

local function search()
end

local usage = [[MPM - the Monolith Package Manager, (c) 2020 Ocawesome101 under the MIT license.
Usage:
  mpm <command> ...

Available commands are:
  install <package>     Where <package> is in the form of [<user>/]<repo>/<package>, installs <package>. Does not resolve dependencies.
  list                  Show all installed packages.
  search  <package>     Where <package> is in the form of [<user>/]<repo>/<package>
  remove  <package>     Where <package> is in the form of <user>/<repo>/<package>, removes <package>. Does not remove dependencies or warn if <package> is a dependency.
]]

local ops = {
  install = install,
  list = list,
  search = search,
  remove = remove
}

local args, opts = shell.parse(...)

if opts.help then
  print(usage)
  return 1
end

if #args == 0 then
  shell.error("usage", "mpm COMMAND ...")
  return shell.codes.argument
end

local cmd = args[1]

if ops[cmd] then
  ops[cmd](table.unpack(args, 2))
else
  return shell.codes.argument
end
