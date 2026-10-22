-- How stats, enchants and talents are written out (the app's ui/tooltip.ts helpers).
local _, T = ...
local U = T.U

local PCT_STATS = { critpct = "% crit", scritpct = "% spell crit", hitpct = "% hit", shitpct = "% spell hit", hitred = "% boss miss chance", slow = "% slower boss swings" }
local RES = { "arcres", "fireres", "frostres", "natres", "shadres" }

--- the app's statText: "+12 Stamina, +10 Defense Rating" (key order as the app lists them)
local ORDER = { "str", "agi", "sta", "int", "spi", "hp", "mana", "armor", "def", "dodge", "parry", "block", "bv", "res", "hit", "crit", "exp", "haste", "ap", "rap", "fap",
  "rhit", "rcrit", "arp", "sp", "heal", "shit", "scrit", "shaste", "spen", "mp5", "hp5", "arcsp", "firesp", "frostsp", "holysp", "natsp", "shadsp",
  "arcres", "fireres", "frostres", "natres", "shadres", "critpct", "scritpct", "hitpct", "shitpct", "hitred", "slow", "apred", "flat", "beararmor" }
local RANK = {}
for i, k in ipairs(ORDER) do RANK[k] = i end

function T.statText(st)
  if not st then return "" end
  local keys = {}
  for k in pairs(st) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return (RANK[a] or 999) < (RANK[b] or 999) or ((RANK[a] or 999) == (RANK[b] or 999) and a < b) end)
  local out, done = {}, {}
  local allRes = true
  for _, k in ipairs(RES) do if not st[k] or st[k] ~= st.arcres then allRes = false end end
  if allRes then out[#out + 1] = ("+%d All Resistances"):format(st.arcres) for _, k in ipairs(RES) do done[k] = true end end
  if st.sp and st.heal and st.sp == st.heal then out[#out + 1] = ("+%d Spell Damage and Healing"):format(st.sp) done.sp = true done.heal = true end
  if st.ap and st.rap and st.ap == st.rap then done.rap = true end
  for _, k in ipairs(keys) do
    if not done[k] then
      local v = st[k]
      local num = (v == math.floor(v)) and tostring(v) or U.fixed(v, 1)
      if PCT_STATS[k] then out[#out + 1] = (v > 0 and "+" or "") .. num .. PCT_STATS[k]
      elseif k == "apred" then out[#out + 1] = "-" .. num .. " boss attack power"
      elseif k == "beararmor" then out[#out + 1] = "+" .. num .. " Armor in Bear Form"
      else out[#out + 1] = (v >= 0 and "+" or "") .. num .. " " .. (T.STAT_NAMES[k] or k) end
    end
  end
  return table.concat(out, ", ")
end

function T.enchantText(e)
  local s = T.statText(e.st)
  local short = e.n:gsub("^Enchant [^-]+ %- ", "")
  return s ~= "" and (short .. " (" .. s .. ")") or e.n
end

--- an enchant's details, drawn into a panel
function T.enchantInfo(f, e)
  f:text(e.n, { font = "GameFontNormalLarge", color = T.K.GREEN })
  f:text(e.tx, { color = T.K.GREEN })
  if T.statText(e.st) ~= "" then f:text("Stats: " .. T.statText(e.st)) end
  if e.req and e.req > 0 then f:text(("Requires a level %d or higher item"):format(e.req), { color = { 1, 0.82, 0 } }) end
  if e.prof then f:note("Requires " .. e.prof) end
  if e.rep then f:note("Formula from " .. e.rep) end
  if e.cl then f:note(U.ucfirst(e.cl) .. "s only") end
  f:gap(4)
  f:buttons({ { label = e.id and e.id > 0 and "Wowhead link" or "Search Wowhead", click = function() T.showUrl(e.n, T.enchantUrl(e)) end } }, "left")
end

--- a gem's details, drawn into a panel (the game's tooltip, plus where it fits)
local COLOR_WORDS = { red = "Red", yellow = "Yellow", blue = "Blue", orange = "Red or Yellow", purple = "Red or Blue", green = "Yellow or Blue", prismatic = "Red, Yellow or Blue" }
function T.gemInfo(f, g)
  local tip = T.K.get(f.owner, "tip", f.parent)
  tip:SetOwner(f.parent, "ANCHOR_NONE")
  tip:SetPoint("TOPLEFT", f.parent, "TOPLEFT", f.x, -f.y)
  tip:SetHyperlink("item:" .. g.id)
  tip:SetMinimumWidth(f.width)
  tip:Show()
  local h = tip:GetHeight()
  if not h or h < 20 then h = 20 + tip:NumLines() * 14 end
  f.y = f.y + h + 6
  f:note(g.c == "meta" and "Only fits in a meta gem slot." or ("Matches a %s socket."):format(COLOR_WORDS[g.c] or g.c))
  f:buttons({ { label = "Wowhead link", click = function() T.showUrl(g.n, T.wowheadItemUrl(g.id)) end } }, "left")
end
