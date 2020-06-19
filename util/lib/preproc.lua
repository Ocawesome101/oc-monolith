-- Written by Izaya for PsychOS 2. --

local preproc = {}
preproc.directives = {}

function preproc.parsewords(line) -- string -- table -- Returns a table of words from the string *line*, parsing quotes and escapes.
 local rt = {""}
 local escaped, quoted = false, false
 for c in line:gmatch(".") do
  if escaped then
   rt[#rt] = rt[#rt]..c
  elseif c == '"' or c == "'" then
   quoted = not quoted
  elseif c == "\\" then
   escaped = true
  elseif c:match("%s") and not quoted and rt[#rt]:len() > 0 then
   rt[#rt+1] = ""
  else
   rt[#rt] = rt[#rt]..c
  end
 end
 return rt
end

function preproc.line(line) -- string -- -- Returns either a function - which can be called to get lines until it returns nil - or a string from processing *line* using preprocessor directives.
 if line:match("^%-%-#") then
  local directive, args = line:match("^%-%-#(%S+)%s(.+)")
  print(directive,args)
  local args = preproc.parsewords(args)
  if preproc.directives[directive] then
   return preproc.directives[directive](table.unpack(args))
  else
   error("unknown preprocessor directive: "..directive)
  end
 --[[elseif line:match("$%[%[(.-)%]%]") then
  local command = line:match("%$%[%[(.-)%]%]")
  print("shell", command)
  local cmd = assert(io.popen(command, "rw"))
  local result = cmd:read()
  cmd:close()
  line = line:gsub(command:gsub("%$%[%]", "%%1"), result)
  return line]]
 else
  return line
 end
end

function preproc.preproc(...) -- string -- string -- Returns the output from preprocessing the files listed in *...*.
 local tA = {...}
 local output = ""
 for _,fname in ipairs(tA) do
  local f,e = io.open(fname)
  if not f then error("unable to open file "..fname..": "..e) end
  print("proc", fname)
  for line in f:lines() do
   local r = preproc.line(line)
   if type(r) == "function" then
    while true do
     local rs = r()
     if not rs then break end
     output = output .. rs .. "\n"
    end
   else
    output = output .. r .. "\n"
   end
  end
 end
 return output
end

preproc.directives.include = preproc.preproc

return setmetatable(preproc,{__call=function(_,...)
 local tA = {...}
 local out = table.remove(tA,#tA)
 local f,e = io.open(out,"wb")
 if not f then error("unable to open file "..out..": "..e) end
 f:write(preproc.preproc(table.unpack(tA)))
 f:close()
end})
