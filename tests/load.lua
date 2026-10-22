-- Loads the addon's files in TOC order into a fresh namespace, the way the game does
-- (each file gets the addon name and the shared namespace table as `...`).
local M = {}

local function readToc(root)
  local files = {}
  for line in io.lines(root .. "/TBCrushCalc/TBCrushCalc.toc") do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
  end
  return files
end

local function expand(root, f)
  if f:match("%.xml$") then
    local dir = f:match("^(.*)/") or ""
    local out = {}
    for line in io.lines(root .. "/TBCrushCalc/" .. f) do
      local s = line:match('<Script file="([^"]+)"')
      if s then out[#out + 1] = (dir ~= "" and dir .. "/" or "") .. s:gsub("\\", "/") end
    end
    return out
  end
  return { f }
end

--- loads every file whose path passes `want` (all of them when nil); returns the namespace
function M.load(root, want, env)
  local T = {}
  for _, f in ipairs(readToc(root)) do
    for _, file in ipairs(expand(root, f)) do
      if not want or want(file) then
        local chunk, err = loadfile(root .. "/TBCrushCalc/" .. file)
        if not chunk then error(err) end
        if env then setfenv(chunk, env) end
        chunk("TBCrushCalc", T)
      end
    end
  end
  return T
end

function M.readFile(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

return M
