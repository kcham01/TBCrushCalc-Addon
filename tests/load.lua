-- Loads the addon's files in TOC order into a fresh namespace, the way the game does
-- (each file gets the addon name and the shared namespace table as `...`).
local M = {}

local function readToc(root, addon)
  addon = addon or "TBCrushCalc"
  local files = {}
  for line in io.lines(root .. "/" .. addon .. "/" .. addon .. ".toc") do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
  end
  return files
end

local function expand(root, f)
  if false and f:match("%.xml$") then
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

local function loadAddon(root, addon, T, want, env)
  for _, f in ipairs(readToc(root, addon)) do
    for _, file in ipairs(expand(root, f)) do
      if not want or want(file) then
        local chunk, err = loadfile(root .. "/" .. addon .. "/" .. file)
        if not chunk then error(err) end
        if env then setfenv(chunk, env) end
        chunk(addon, T)
      end
    end
  end
end

--- loads the addon (every file whose path passes `want`, all of them when nil); returns its namespace.
--- With `withData`, also loads TBCrushCalc_Data and indexes it, as opening the window does in game.
function M.load(root, want, env, withData)
  local T = {}
  loadAddon(root, "TBCrushCalc", T, want, env)
  if withData then
    M.loadData(root, env)
    T.indexData()
    T.dataReady = true
  end
  return T
end

--- loads TBCrushCalc_Data (its files find the namespace through the TBCrushCalcNS global)
function M.loadData(root, env)
  loadAddon(root, "TBCrushCalc_Data", {}, nil, env)
end

function M.readFile(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

return M
