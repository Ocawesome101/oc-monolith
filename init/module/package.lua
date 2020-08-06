-- `package` library --

loadfile("/lib/init/package.lua")()
package.loaded.filesystem = kernel.filesystem
package.loaded.thread = kernel.thread
package.loaded.signals = kernel.thread.signals
package.loaded.module = kernel.module
package.loaded.modules = kernel.modules
package.loaded.kinfo = kernel.info
package.loaded.runlevel = runlevel
package.loaded.syslog = {
  log = function(s,m)if not m then m, s = s, "OK"end log(s,m) end
}
package.loaded.users = setmetatable({}, {__index = function(_,k) _G.kernel = kernel package.loaded.users = require("users", true) _G.kernel = nil return package.loaded.users[k] end})
_G.kernel = nil
