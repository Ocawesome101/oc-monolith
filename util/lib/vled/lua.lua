-- Lua highlighting for TLE --

local keyword_color, builtin_color, const_color, str_color,
                                                          cmt_color, kchar_color
    = 93,            94,            95,         95,       94,        92

local function esc(n)
  return string.format("\27[%dm", n)
end

keyword_color = esc(keyword_color)
builtin_color = esc(builtin_color)
kchar_color = esc(kchar_color)
const_color = esc(const_color)
str_color = esc(str_color)
cmt_color = esc(cmt_color)

local keywords = {
  ['local']    = true,
  ['while']    = true,
  ['for']      = true,
  ['repeat']   = true,
  ['until']    = true,
  ['do']       = true,
  ['if']       = true,
  ['in']       = true,
  ['else']     = true,
  ['elseif']   = true,
  ['and']      = true,
  ['or']       = true,
  ['not']      = true,
  ['then']     = true,
  ['end']      = true,
  ['function'] = true,
  ['return']   = true
}

local functions = {
  ['print'] = true,
  ['_G'] = true,
}

do
  local seen = {}
  local function add_highlight(k, obj)
    if type(obj) == "table" then
      if not seen[obj] then
        for _k, _v in pairs(obj) do
          add_highlight(k..".".._k, v)
        end
      end
      seen[obj] = true
    end
    functions[k] = true
  end
  seen = {}
  for k, v in pairs(_G) do
    add_highlight(k, v)
  end
end

local kchars = "[%{%}%[%]%(%)]"
local operators = ""

local function words(ln)
  local words = {}
  local ws, word = "", ""
  for char in ln:gmatch(".") do
    if char:match("[%{%}%[%]%(%)%s\"',%+%=%%%/%|%&%>%<%*]") then
      ws = char
      if #word > 0 then words[#words + 1] = word  end
      if #ws > 0 then words[#words + 1] = ws  end
      word = ""
      ws = ""
    else
      word = word .. char
    end
  end
  if #word > 0 then words[#words + 1] = word  end
  if #ws > 0 then words[#words + 1] = ws  end
  return words
end

local function highlight(line)
  local ret = ""
  local in_str = false
  local in_cmt = false
  for i, word in ipairs(words(line)) do
    if word:match("[\"']") and not in_str and not in_cmt then
      in_str = true
      ret = ret .. str_color .. word
    elseif in_str then
      ret = ret .. word
      if word:match("[\"']") then
        ret = ret .. "\27[39m"
        in_str = false
      end
    elseif word:sub(1,2) == "--" then
      in_cmt = true
      ret = ret .. cmt_color .. word
    elseif in_cmt then
      ret = ret .. word
    else
      local esc = (keywords[word] and keyword_color) or
                  (functions[word] and builtin_color) or
                  ((word == "true" or word == "false") and const_color) or
                  (word:match(kchars) and kchar_color) or
                  (word:match("^%d+$") and const_color) or ""
      if esc == "" then word = word:gsub("_G", builtin_color.."_G\27[39m") end
      ret = ret .. esc .. word .. (esc ~= "" and "\27[39m" or "")
    end
  end
  return ret
end

return highlight
