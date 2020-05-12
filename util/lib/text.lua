-- Text utils --

local unicode = require("unicode")
local text = {}

-- from https://lua-users.org/wiki/StringTrim, with argument checking
function text.trim(value)
  checkArg(1, value, "string")
  local from = string.match(value, "^%s*()") -- these patterms are magic
  return from > #value and "" or string.match(value, ".*%S", from) -- magic, I say!
end

-- These two functions are copied from OpenOS' text lib for compatibility. Thanks, Payonel :)

-- Pretty sure this puts a \ in front of special chars, maybe a %
function text.escapeMagic(txt)
  checkArg(1, txt, "string")
  return txt:gsub("[%(%)%.%%%+%-%*%?%[%^%$]", "%%%1")
end

-- These patterns are illegible
function text.removeEscapes(txt)
  checkArg(1, txt, "string")
  return txt:gsub("%%([%9%0%.%%%+%-%*%?%[%^%$])", "%1")
end

function text.tokenize(str)
  checkArg(1, str, "string")
  local words = {}
  for word in str:gmatch("[^ ]+") do
    words[#words + 1] = word
  end

  return words
end

-- text.split is present in the OpenOS API, but not documented on the wiki.
function text.split(str, sep)
  checkArg(1, str, "string")
  checkArg(2, sep, "string", "nil")
  local pattern = string.format("[^%s]+", sep)
  local words = {}
  for word in str:gmatch(pattern) do
    words[#words + 1] = word
  end
  return words
end

-- There may be minor incompatibilities or inconsistencies in my code vs. OpenOS's.
function text.detab(str, width)
  checkArg(1, str, "string")
  checkArg(2, width, "number", "nil")
  local tab = (" "):rep(width or 2)
  return str:gsub("\t", tab)
end

function text.padRight(str, len)
  checkArg(1, str, "string", "nil")
  checkArg(2, len, "number")
  str = str or ""

  return str .. string.rep(" ", len - unicode.wlen(str))
end

function text.padLeft(str, len)
  checkArg(1, str, "string", "nil")
  checkArg(2, len, "number")
  str = str or ""

  return string.rep(" ", len - unicode.wlen(str)) .. str
end

-- TODO: implement these
function text.wrap()
  error("TOOD: implement text.wrap")
end

function text.wrappedLines()
  error("TODO: implement text.wrappedLines")
end

return text
