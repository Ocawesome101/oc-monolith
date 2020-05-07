-- spawn processes --

local args = {...}
print(pcall(loadfile(args[1])))
