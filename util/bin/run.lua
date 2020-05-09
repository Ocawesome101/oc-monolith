-- spawn processes --

print(pcall(loadfile(({require("shell").parse(...)})[1][1])))
