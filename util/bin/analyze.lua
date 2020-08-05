-- print startup timing and things --

local times = require("times")

print(string.format("Startup finished in %fs (firmware) + %fs (kernel) + %fs (userspace) + %fs (getty) = %fs", times.kernel_start, times.kernel_finish - times.kernel_start, times.init_finish - times.init_start, times.getty_finish - times.getty_start, times.getty_finish - times.kernel_start))
