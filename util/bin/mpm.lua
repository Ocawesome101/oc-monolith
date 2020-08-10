-- mpm - the Monolith Package Manager --

local  shell   = require (   "shell"  )
local  config  = require (  "config"  )
local   cpio   = require (   "cpio"   )
local    fs    = require ("filesystem")
local internet = require ( "internet" )
local  logger  = require (  "logger"  ).new("arrow")
local    cp    = loadfile("/bin/cp.lua")
local    rm    = loadfile("/bin/rm.lua")

logger:ok("Initializing MPM")

local cfg = config.load("/etc/mpm/mpm.cfg")
cfg.names = cfg.names or {"ocawesome101"}
cfg.baseURL = cfg.baseURL or "https://raw.githubusercontent.com"
config.save(cfg, "/etc/mpm/mpm.cfg")
local ok, err = fs.makeDirectory("/var/cache/mpm")
if not ok and err then
  shell.error("mpm", err)
  os.exit(-1)
end

local function download(url, file)
  logger:warn("Downloading", url, "as", file)
  local handle = internet.request(url)
  local out, err = io.open(file, "w")
  if not out then
    handle.close()
    shell.error("mpm", err)
    os.exit(-1)
  end
  for chunk in handle do
    out:write(chunk)
  end
  out:close()
  logger:ok("Downloaded")
end

local function getParts(s)
  local a, b, c = s:match("(.+)[/+](.+)[/+](.+)")
  if not (a and b and c) then
    return nil, s:match("(.+)[/+](.+)")
  end
  return a, b, c
end

local function randomFileName()
  local base = "/tmp"
  local random = math.random(111111, 999999)
  return string.format("%s/%d", base, random)
end

local function check(user, repo, pkg)
  local url     = string.format("%s/%s/%s/master/packages/%s.cpio", cfg.baseURL, user, repo, pkg)
  logger:info("Checking URL:\27[94m", url, "\27[37m....")
  local ok, err = pcall(internet.request, url) -- :^)
  return ok
end

local function getPackageConfig(pakg)
  local user, repo, pkg = getParts(pakg)
  if not user then
    logger:info("No username provided - checking name list from configuration")
    for _, v in pairs(cfg.names) do
      local ok = check(v, repo, pkg)
      if ok then
        logger:ok("Found user with matching repository and package:", v)
        user = v
        break
      end
    end
    if not user then
      logger:fail("\27[91mError: Could not find a user with a matching repository and package")
      error()
    end
  end
  local url = string.format("%s/%s/%s/master/packages/%s.cpio", cfg.baseURL, user, repo, pkg)
  local exTo = string.format("/var/cache/mpm/%s", pkg)
  local file = string.format("/var/cache/mpm/%s.cpio", pkg)
  download(url, file)
  logger:info("Extracting", file, "to", exTo)
  cpio.extract(file, exTo)
  return exTo, string.format("%s/%s/%s", user, repo, pkg), config.load(string.format("%s/package.cfg", exTo))
end

local function install(pack)
  logger:info("Installing package", pack)
  local installed = config.load("/etc/mpm/installed.cfg")
  local path, urp, cfg = getPackageConfig(pack)
  if not (cfg.name and cfg.creator and cfg.files) then
    logger:fail("\27[91mError: Invalid package configuration file (missing one of: name, creator, files)")
    return shell.codes.failure
  end
  logger:info("Registering package....")
  installed[urp:lower()] = {
    name = cfg.name,
    creator = cfg.creator,
    files = cfg.files,
    description = cfg.description or "MPM Package"
  }
  logger:info("Saving configuration....")
  config.save(installed, "/etc/mpm/installed.cfg")
  logger:info("Copying files....")
  for _, file in pairs(cfg.files) do
    local src = fs.concat(path, file)
    local dest = file
    cp("-rvi", src, dest)
  end
  logger:ok("Done.")
end

local function remove(package)
  logger:info("Removing package", package)
  local installed = config.load("/etc/mpm/installed.cfg")
  if not installed[package:lower()] then
    logger:fail("\27[91mError: Package", package, "is not installed!")
    error()
  end
  local ent = installed[package:lower()]
  logger:info("Removing files....")
  for _, file in pairs(ent.files) do
    rm("-rv", (opts.y and "" or "-i"), file)
  end
  logger:info("Unregistering package....")
  installed[package:lower()] = nil
  logger:info("Saving configuration....")
  config.save(installed, "/etc/mpm/installed.cfg")
  logger:ok("Done.")
end

local function list()
  logger:info("Loading configuration....")
  local installed = config.load("/etc/mpm/installed.cfg")
  for k, v in pairs(installed) do
    logger:info(string.format("\27[92m%s: %s\n  \27[37m%s", v.creator, k, v.description))
  end
end

local function search()
end

local usage = [[
MPM - the Monolith Package Manager, copyright (c) 2020 Ocawesome101 under the GNU GPLv3.
Usage:
  mpm <command> ...

Available commands are:
  install <package>     Where <package> is in the form of [<user>/]<repo>/<package>, installs <package>. Does not resolve dependencies.
  list                  Show all installed packages.
  search  <package>     Where <package> is in the form of [<user>/]<repo>/<package>. Self explanatory.
  remove  <package>     Where <package> is in the form of <user>/<repo>/<package>, removes <package>. Does not remove dependencies or warn if <package> is a dependency.
  clean                 Clean the package cache. Equivalent to `rm -r /var/cache/mpm/`.
]]

local ops = {
  install = install,
  list = list,
  search = search,
  remove = remove,
  clean = function()shell.execute("rm -r /var/cache/mpm")end
}

local args, opts = shell.parse(...)

if opts.help then
  print(usage)
  return
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
