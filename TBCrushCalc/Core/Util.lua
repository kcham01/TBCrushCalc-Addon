-- Small helpers shared by the engine and the UI: table copies, number formatting, JSON and base64 for
-- share codes (the same "TBCC1:" codes the phone app uses, so characters move between the two).
local _, T = ...
local U = {}
T.U = U

local floor, abs, format = math.floor, math.abs, string.format

function U.copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = U.copy(x) end
  return out
end

function U.keys(t)
  local out = {}
  for k in pairs(t) do out[#out + 1] = k end
  table.sort(out, function(a, b)
    if type(a) == "number" and type(b) == "number" then return a < b end
    return tostring(a) < tostring(b)
  end)
  return out
end

function U.count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

function U.contains(list, v)
  if not list then return false end
  for i = 1, #list do if list[i] == v then return true end end
  return false
end

function U.find(list, fn)
  for i = 1, #list do if fn(list[i]) then return list[i], i end end
  return nil
end

function U.filter(list, fn)
  local out = {}
  for i = 1, #list do if fn(list[i]) then out[#out + 1] = list[i] end end
  return out
end

function U.map(list, fn)
  local out = {}
  for i = 1, #list do out[i] = fn(list[i], i) end
  return out
end

--- JavaScript's toFixed: rounds half away from zero on the decimal string (close enough for display)
function U.fixed(n, d)
  d = d or 2
  local m = 10 ^ d
  local r = floor(n * m + 0.5) / m
  if r == 0 then r = 0 end           -- no "-0.00"
  return format("%." .. d .. "f", r)
end
--- the app's fmt(): Math.round(n * 10^d) / 10^d, then toFixed(d)
function U.fmt(n, d) return U.fixed(n, d or 2) end
function U.pct(n, d) return U.fmt(n, d or 2) .. "%" end

--- 1234567 -> "1,234,567" (toLocaleString for whole numbers)
function U.commas(n)
  local s = tostring(floor(n + 0.5))
  local neg = s:sub(1, 1) == "-"
  if neg then s = s:sub(2) end
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  if out:sub(1, 1) == "," then out = out:sub(2) end
  return (neg and "-" or "") .. out
end

function U.trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

function U.ucfirst(s) return s:sub(1, 1):upper() .. s:sub(2) end

--- "#a335ee" -> r, g, b (0..1)
function U.hex(c)
  c = c:gsub("#", "")
  return tonumber(c:sub(1, 2), 16) / 255, tonumber(c:sub(3, 4), 16) / 255, tonumber(c:sub(5, 6), 16) / 255
end
--- "|cffa335ee" colour escape for a "#rrggbb" colour
function U.esc(c) return "|cff" .. c:gsub("#", "") end

--- a random id like the app's Math.random().toString(36).slice(2, 10)
function U.newId()
  local chars = "0123456789abcdefghijklmnopqrstuvwxyz"
  local out = {}
  for i = 1, 8 do local k = math.random(1, 36) out[i] = chars:sub(k, k) end
  return table.concat(out)
end

--- the time in milliseconds, like the app's Date.now()
function U.now() return floor((time and time() or os.time()) * 1000) end

---------------------------------------------------------------------- JSON
local function encStr(s)
  s = s:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' end
    if c == "\\" then return "\\\\" end
    if c == "\n" then return "\\n" end
    if c == "\r" then return "\\r" end
    if c == "\t" then return "\\t" end
    return format("\\u%04x", c:byte())
  end)
  return '"' .. s .. '"'
end
local function encNum(n)
  if n == floor(n) and abs(n) < 1e15 then return format("%.0f", n) end   -- %d overflows past 2^31 on some builds
  return format("%.17g", n)
end

--- encodes a value; `arrays` names the keys whose tables are JSON arrays (everything else is an object)
function U.json(v, arrays, key)
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "boolean" then return v and "true" or "false" end
  if t == "number" then return encNum(v) end
  if t == "string" then return encStr(v) end
  if arrays and arrays[key] then
    local parts = {}
    for i = 1, #v do parts[i] = U.json(v[i], arrays, key .. "[]") end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  local parts = {}
  for _, k in ipairs(U.keys(v)) do
    parts[#parts + 1] = encStr(tostring(k)) .. ":" .. U.json(v[k], arrays, tostring(k))
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function utf8(cp)
  if cp < 0x80 then return string.char(cp) end
  if cp < 0x800 then return string.char(0xC0 + floor(cp / 64), 0x80 + cp % 64) end
  return string.char(0xE0 + floor(cp / 4096), 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64)
end

--- parses JSON; returns the value or nil, error
function U.parseJson(s)
  local i = 1
  local n = #s
  local value
  local function ws() while i <= n and s:sub(i, i):match("%s") do i = i + 1 end end
  local function fail(msg) error("json: " .. msg .. " at " .. i, 0) end
  local function str()
    i = i + 1
    local out = {}
    while i <= n do
      local c = s:sub(i, i)
      if c == '"' then i = i + 1 return table.concat(out) end
      if c == "\\" then
        local e = s:sub(i + 1, i + 1)
        if e == "u" then
          local cp = tonumber(s:sub(i + 2, i + 5), 16) or fail("bad \\u")
          if cp >= 0xD800 and cp <= 0xDBFF and s:sub(i + 6, i + 7) == "\\u" then
            local lo = tonumber(s:sub(i + 8, i + 11), 16)
            if lo then cp = 0x10000 + (cp - 0xD800) * 1024 + (lo - 0xDC00) i = i + 6 end
          end
          if cp >= 0x10000 then
            out[#out + 1] = string.char(0xF0 + floor(cp / 262144), 0x80 + floor(cp / 4096) % 64, 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64)
          else
            out[#out + 1] = utf8(cp)
          end
          i = i + 6
        else
          local map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
          out[#out + 1] = map[e] or e
          i = i + 2
        end
      else
        out[#out + 1] = c
        i = i + 1
      end
    end
    fail("unterminated string")
  end
  function value()
    ws()
    local c = s:sub(i, i)
    if c == "{" then
      i = i + 1
      local obj = {}
      ws()
      if s:sub(i, i) == "}" then i = i + 1 return obj end
      while true do
        ws()
        if s:sub(i, i) ~= '"' then fail("expected key") end
        local k = str()
        ws()
        if s:sub(i, i) ~= ":" then fail("expected :") end
        i = i + 1
        obj[k] = value()
        ws()
        local d = s:sub(i, i)
        i = i + 1
        if d == "}" then return obj end
        if d ~= "," then fail("expected , or }") end
      end
    elseif c == "[" then
      i = i + 1
      local arr = {}
      ws()
      if s:sub(i, i) == "]" then i = i + 1 return arr end
      while true do
        arr[#arr + 1] = value()
        ws()
        local d = s:sub(i, i)
        i = i + 1
        if d == "]" then return arr end
        if d ~= "," then fail("expected , or ]") end
      end
    elseif c == '"' then
      return str()
    elseif s:sub(i, i + 3) == "true" then i = i + 4 return true
    elseif s:sub(i, i + 4) == "false" then i = i + 5 return false
    elseif s:sub(i, i + 3) == "null" then i = i + 4 return nil
    else
      local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
      if not num or num == "" then fail("unexpected " .. c) end
      i = i + #num
      return tonumber(num)
    end
  end
  local ok, res = pcall(value)
  if not ok then return nil, res end
  return res
end

---------------------------------------------------------------------- base64
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64I = {}
for k = 1, 64 do B64I[B64:sub(k, k)] = k - 1 end

function U.b64encode(s)
  local out = {}
  for k = 1, #s, 3 do
    local a, b, c = s:byte(k, k + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    local q1, q2, q3, q4 = floor(n / 262144), floor(n / 4096) % 64, floor(n / 64) % 64, n % 64
    out[#out + 1] = B64:sub(q1 + 1, q1 + 1) .. B64:sub(q2 + 1, q2 + 1)
      .. (b and B64:sub(q3 + 1, q3 + 1) or "=") .. (c and B64:sub(q4 + 1, q4 + 1) or "=")
  end
  return table.concat(out)
end

function U.b64decode(s)
  s = s:gsub("[^%w%+/=]", "")
  local out = {}
  for k = 1, #s, 4 do
    local chunk = s:sub(k, k + 3)
    local v = { B64I[chunk:sub(1, 1)], B64I[chunk:sub(2, 2)], B64I[chunk:sub(3, 3)], B64I[chunk:sub(4, 4)] }
    if not v[1] or not v[2] then return nil end
    local n = v[1] * 262144 + v[2] * 4096 + (v[3] or 0) * 64 + (v[4] or 0)
    out[#out + 1] = string.char(floor(n / 65536))
    if v[3] then out[#out + 1] = string.char(floor(n / 256) % 256) end
    if v[4] then out[#out + 1] = string.char(n % 256) end
  end
  return table.concat(out)
end

--- a stable sort like JavaScript's Array.prototype.sort: cmp(a, b) < 0 puts a first; equal items keep their order
function U.sort(list, cmp)
  local n = #list
  if n < 2 then return list end
  local src, dst = list, {}
  local width = 1
  while width < n do
    local i = 1
    while i <= n do
      local mid, hi = math.min(i + width, n + 1), math.min(i + 2 * width, n + 1)
      local a, b, k = i, mid, i
      while a < mid and b < hi do
        if cmp(src[b], src[a]) < 0 then dst[k] = src[b] b = b + 1 else dst[k] = src[a] a = a + 1 end
        k = k + 1
      end
      while a < mid do dst[k] = src[a] a = a + 1 k = k + 1 end
      while b < hi do dst[k] = src[b] b = b + 1 k = k + 1 end
      i = i + 2 * width
    end
    src, dst = dst, src
    width = width * 2
  end
  if src ~= list then for i = 1, n do list[i] = src[i] end end
  return list
end

--- a JavaScript-style comparison of two numbers or strings (for U.sort)
function U.cmp(a, b) if a < b then return -1 elseif a > b then return 1 end return 0 end
