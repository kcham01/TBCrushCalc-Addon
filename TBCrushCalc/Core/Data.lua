-- Lookups and rules over the game data (TBCrushCalc/Data, exported from the app): which items a class
-- can wear in which slot, which enchants fit which items, and links / icons for the game.
local _, T = ...
local U = T.U

T.ITEM_BY_ID, T.GEM_BY_ID, T.ENCHANT_BY_ID, T.CONSUMABLE_BY_ID, T.BOSS_BY_ID, T.BUFF_BY_ID = {}, {}, {}, {}, {}, {}
T.ENCHANT_BY_EFF = {}

--- fills the lookup tables (called once the data files have loaded)
function T.indexData()
  for _, it in ipairs(T.ITEMS) do T.ITEM_BY_ID[it.id] = it end
  for _, g in ipairs(T.GEMS) do T.GEM_BY_ID[g.id] = g end
  for _, e in ipairs(T.ENCHANTS) do
    T.ENCHANT_BY_ID[e.k] = e
    if e.eff then T.ENCHANT_BY_EFF[e.eff] = e end
  end
  for _, c in ipairs(T.CONSUMABLES) do T.CONSUMABLE_BY_ID[c.id] = c end
  for _, b in ipairs(T.BOSSES) do T.BOSS_BY_ID[b.id] = b end
  T.ALL_BUFFS = {}
  for _, list in ipairs({ T.RAID_BUFFS, T.DEBUFFS, T.WORLD_BUFFS }) do
    for _, b in ipairs(list) do T.ALL_BUFFS[#T.ALL_BUFFS + 1] = b T.BUFF_BY_ID[b.id] = b end
  end
  T.SLOT_BY_ID = {}
  for _, s in ipairs(T.SLOTS) do T.SLOT_BY_ID[s.id] = s end
end

function T.canUse(cls, it, slot)
  if it.cl and not U.contains(it.cl, cls) then return false end
  if it.at and not U.contains(T.ARMOR[cls], it.at) then return false end
  if it.s == "weapon" then
    if it.wt and not U.contains(T.WEAPONS[cls], it.wt) then return false end
    if slot == "mainhand" and it.ht == "oh" then return false end
    if slot == "offhand" then
      if it.ht ~= "oh" and not (it.ht == "1h" and cls == "warrior") then return false end   -- only warriors dual wield
    end
  end
  if it.s == "ranged" and it.rt and not U.contains(T.RANGED[cls], it.rt) then return false end
  return true
end

function T.slotAccepts(slot, it)
  return T.SLOT_BY_ID[slot].item == it.s
end

--- the enchant slots an item takes
function T.enchantSlotsOf(it)
  if it.s == "weapon" then
    if it.wt == "shield" then return { "shield" } end
    if it.wt == "offhand" then return {} end
    return it.ht == "2h" and { "weapon", "2h" } or { "weapon" }
  end
  if it.s == "ranged" then
    return U.contains({ "bow", "gun", "crossbow" }, it.rt) and { "ranged" } or {}
  end
  if U.contains({ "neck", "waist", "trinket" }, it.s) then return {} end
  return { it.s }
end

--- can this enchant go on this item? nil if yes, or the reason it can't
function T.enchantProblem(e, it, cls)
  local slots = T.enchantSlotsOf(it)
  local fits = false
  for _, x in ipairs(e.sl) do if U.contains(slots, x) then fits = true end end
  if not fits then
    if U.contains(e.sl, "2h") and it.s == "weapon" then return "Two-handed weapons only" end
    return "Does not fit this item"
  end
  if e.cl and e.cl ~= cls then return U.ucfirst(e.cl) .. "s only" end
  if e.req and e.req > 0 and it.il < e.req then
    return ("Requires a level %d or higher item (this one is level %d)"):format(e.req, it.il)
  end
  return nil
end

function T.icon(name)
  if not name or name == "" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
  return "Interface\\Icons\\" .. name
end

function T.classOf(cls)
  return U.find(T.CLASSES, function(c) return c.id == cls end)
end

--- web addresses, shown in a box you can copy (addons can't open a browser)
function T.wowheadItemUrl(id) return "https://www.wowhead.com/tbc/item=" .. id end
function T.wowheadSpellUrl(id) return "https://www.wowhead.com/tbc/spell=" .. id end
function T.wowheadNpcUrl(id) return "https://www.wowhead.com/tbc/npc=" .. id end
function T.wowheadSearchUrl(q) return "https://www.wowhead.com/tbc/search?q=" .. q:gsub("[^%w%-_%.~]", function(c) return ("%%%02X"):format(c:byte()) end) end
function T.enchantUrl(e)
  if e.id and e.id > 0 then return e.spell and T.wowheadSpellUrl(e.id) or T.wowheadItemUrl(e.id) end
  return T.wowheadSearchUrl(e.n)
end

--- the game's item link text for a piece, written the way the client writes its own links:
--- item:id:enchant:gem1:gem2:gem3:gem4, gems as item ids, empty fields left blank
function T.itemString(piece)
  if not piece then return nil end
  local e = piece.ench and T.ENCHANT_BY_ID[piece.ench]
  local g = piece.gems or {}
  local function f(v) return (v and v > 0) and tostring(v) or "" end
  return ("item:%d:%s:%s:%s:%s:%s"):format(piece.id, f(e and e.eff), f(g[1]), f(g[2]), f(g[3]), f(g[4]))
end

local DATA = "TBCrushCalc_Data"
local REASONS = {
  MISSING = "the TBCrushCalc_Data folder isn't in Interface\\AddOns",
  DISABLED = "TBCrushCalc_Data is switched off in the AddOns list",
  INTERFACE_VERSION = "the game calls TBCrushCalc_Data out of date: tick \"Load out of date AddOns\"",
  DEP_MISSING = "TBCrushCalc_Data can't find TBCrushCalc",
  DEP_DISABLED = "TBCrushCalc_Data needs TBCrushCalc switched on",
  CORRUPT = "the TBCrushCalc_Data files are damaged: download the zip again",
  BANNED = "the game blocked TBCrushCalc_Data",
  INSECURE = "the game blocked TBCrushCalc_Data",
}

--- if the data's tables landed somewhere other than this namespace, bring them over
local function adopt()
  local ns = TBCrushCalcNS
  if type(ns) == "table" and ns ~= T then
    for k, v in pairs(ns) do if T[k] == nil or (k == "ITEMS" and #T.ITEMS == 0) then T[k] = v end end
    TBCrushCalcNS = T
  end
end

--- loads TBCrushCalc_Data (once) and indexes it; returns true when the data is there. When it can't,
--- T.dataError says why in words: the game's own reason, or the first Lua error from the data files
function T.loadData()
  if T.dataReady then return true end
  adopt()
  if not T.GEMS then
    local firstError
    local handler = geterrorhandler()
    seterrorhandler(function(msg, ...)
      firstError = firstError or tostring(msg)
      return handler(msg, ...)
    end)
    local ok, loaded, why = pcall(C_AddOns.LoadAddOn, DATA)
    seterrorhandler(handler)
    if not ok then firstError = firstError or tostring(loaded) loaded = false end
    adopt()
    if not T.GEMS or not T.STAT_NAMES or #T.ITEMS == 0 then
      if not why then
        local _, _, _, loadable, reason = C_AddOns.GetAddOnInfo(DATA)
        if not loadable and reason and reason ~= "" then why = reason end
      end
      if firstError then
        T.dataError = "a data file errored: " .. firstError
      elseif why then
        T.dataError = REASONS[why] or ("the game said " .. tostring(why))
      elseif loaded then
        T.dataError = "TBCrushCalc_Data loaded but its tables are empty (gems " .. tostring(T.GEMS ~= nil) ..
          ", items " .. #T.ITEMS .. ")"
      else
        T.dataError = "the game wouldn't load TBCrushCalc_Data and didn't say why"
      end
      return false
    end
  end
  T.indexData()
  T.dataReady = true
  return true
end
