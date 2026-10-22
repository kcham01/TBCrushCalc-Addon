-- Loading the character you're playing: race, class, the gear you wear (with its gems and enchants) and
-- your talents, read from the game. Something the phone app can't do.
local _, T = ...
local U, E = T.U, T.E

local RACE_TOKEN = { Human = "human", Dwarf = "dwarf", NightElf = "nightelf", Gnome = "gnome", Draenei = "draenei", Orc = "orc",
  Scourge = "undead", Undead = "undead", Tauren = "tauren", Troll = "troll", BloodElf = "bloodelf" }

--- "+15 Defense Rating" or "Stamina +12" -> stats, using the app's stat names
local NAME_TO_STAT
local function parseStats(text)
  if not NAME_TO_STAT then
    NAME_TO_STAT = {}
    for k, v in pairs(T.STAT_NAMES) do NAME_TO_STAT[v:lower()] = k end
    NAME_TO_STAT["defense"] = "def" NAME_TO_STAT["dodge"] = "dodge" NAME_TO_STAT["parry"] = "parry"
    NAME_TO_STAT["block"] = "block" NAME_TO_STAT["shield block rating"] = "block" NAME_TO_STAT["resilience"] = "res"
    NAME_TO_STAT["hit"] = "hit" NAME_TO_STAT["critical strike rating"] = "crit" NAME_TO_STAT["all stats"] = "all"
  end
  local st = {}
  local any = false
  for piece in (text .. " and "):gmatch("(.-)%s+and%s+") do
    for chunk in (piece .. ","):gmatch("([^,]+),") do
      local n, word = chunk:match("([%+%-]?%d+)%s+(.+)")
      if not n then word, n = chunk:match("(.-)%s+([%+%-]?%d+)$") end
      if n and word then
        word = U.trim(word):lower():gsub("^to%s+", "")
        local k = NAME_TO_STAT[word]
        if k == "all" then
          for _, s in ipairs({ "str", "agi", "sta", "int", "spi" }) do st[s] = tonumber(n) end
          any = true
        elseif k then
          st[k] = (st[k] or 0) + tonumber(n)
          any = true
        end
      end
    end
  end
  return any and st or nil
end
T.parseEnchantStats = parseStats

local function sameStats(a, b)
  for k, v in pairs(a) do if b[k] ~= v then return false end end
  for k, v in pairs(b) do if k ~= "rap" and a[k] ~= v then return false end end
  return true
end

local scan
--- the enchant on an equipped item: by the game's enchant id when the data knows it, else by reading the
--- green enchant line off the item's tooltip and matching its stats (remembered for next time)
local function enchantFor(slotId, eff, it)
  if eff == 0 then return nil end
  local known = T.ENCHANT_BY_EFF[eff]
  if known then return known.k end
  local map = T.db.ui.effMap or {}
  T.db.ui.effMap = map
  if map[eff] and T.ENCHANT_BY_ID[map[eff]] then return map[eff] end
  if not scan then scan = CreateFrame("GameTooltip", "TBCrushCalcScanTip", UIParent, "GameTooltipTemplate") end
  scan:SetOwner(UIParent, "ANCHOR_NONE")
  scan:ClearLines()
  scan:SetInventoryItem("player", slotId)
  local candidates = {}
  local kinds = T.enchantSlotsOf(it)
  for _, e in ipairs(T.ENCHANTS) do
    for _, s in ipairs(e.sl) do if U.contains(kinds, s) then candidates[#candidates + 1] = e break end end
  end
  for i = 2, scan:NumLines() do
    local fs = _G["TBCrushCalcScanTipTextLeft" .. i]
    local text = fs and fs:GetText()
    if text then
      local r, g, b = fs:GetTextColor()
      if g > 0.9 and r < 0.2 and b < 0.2 and not text:find("^Equip:") and not text:find("^Use:") and not text:find("^Chance on hit:") and not text:find("^Socket Bonus") and not text:find("^%(") then
        local st = parseStats(text)
        if st then
          local hit
          for _, e in ipairs(candidates) do
            if sameStats(st, e.st) then
              if hit then hit = nil break end      -- more than one enchant with these stats: can't tell
              hit = e
            end
          end
          if hit then map[eff] = hit.k return hit.k end
        end
      end
    end
  end
  return nil
end

function T.loadMyCharacter()
  local _, clsToken = UnitClass("player")
  local cls = clsToken and clsToken:lower()
  if cls ~= "warrior" and cls ~= "paladin" and cls ~= "druid" then
    T.toast("TBCrushCalc is for warriors, paladins and druids")
    return
  end
  local _, raceToken = UnitRace("player")
  local race = RACE_TOKEN[raceToken] or U.keys(T.BASES[cls])[1]
  local name, realm = UnitName("player")
  local me = (name or "?") .. "-" .. (realm or GetRealmName() or "")

  local gear, unknownItems, unknownEnchants, unknownGems = {}, 0, 0, 0
  for _, s in ipairs(T.SLOTS) do
    local slotId = GetInventorySlotInfo(T.INV_SLOT[s.id])
    local link = GetInventoryItemLink("player", slotId)
    if link then
      local id, eff, g1, g2, g3, g4 = link:match("item:(%d+):?(%-?%d*):?(%-?%d*):?(%-?%d*):?(%-?%d*):?(%-?%d*)")
      id = tonumber(id)
      local it = id and T.ITEM_BY_ID[id]
      if it then
        local piece = { id = id }
        local gems, any = {}, false
        for i, g in ipairs({ g1, g2, g3, g4 }) do
          local gid = tonumber(g) or 0
          if i <= #(it.so or {}) then
            if gid > 0 and T.GEM_BY_ID[gid] then gems[i] = gid any = true
            else gems[i] = 0 if gid > 0 then unknownGems = unknownGems + 1 end end
          end
        end
        if any then piece.gems = gems end
        local effId = tonumber(eff) or 0
        if effId > 0 then
          local k = enchantFor(slotId, effId, it)
          if k then piece.ench = k else unknownEnchants = unknownEnchants + 1 end
        end
        gear[s.id] = piece
      else
        unknownItems = unknownItems + 1
      end
    end
  end

  local talents = {}
  for tab = 1, math.min(3, GetNumTalentTabs()) do
    local tree = T.TALENTS[cls][tab]
    for i = 1, GetNumTalents(tab) do
      -- the 2.5.5 client's way to read a talent (the old GetTalentInfo is only a deprecated wrapper around it)
      local info = C_SpecializationInfo.GetTalentInfo({ specializationIndex = tab, talentIndex = i })
      local tier, column, rank = info and info.tier, info and info.column, info and info.rank
      if rank and rank > 0 then
        local t = U.find(tree.talents, function(x) return x.r == tier - 1 and x.c == column - 1 end)
        if t then talents[(tab - 1) .. "." .. t.f] = rank end
      end
    end
  end

  local p = U.find(T.S.list, function(x) return x.me == me end)
  if p then
    p.cls, p.race, p.gear, p.talents = cls, race, gear, talents
    p.updated = U.now()
    T.save()
    T.select(p.id)
  else
    p = T.Store.newProfile(cls, race, name or "Me")
    p.me = me
    p.gear, p.talents = gear, talents
    p.abil = T.Store.defaultAbilities(cls)
    T.Store.raidSetup(p)
    T.addProfile(p)
  end
  local bits = {}
  if unknownItems > 0 then bits[#bits + 1] = unknownItems .. " item" .. (unknownItems > 1 and "s" or "") .. " not in the data" end
  if unknownEnchants > 0 then bits[#bits + 1] = unknownEnchants .. " enchant" .. (unknownEnchants > 1 and "s" or "") .. " not recognised" end
  if unknownGems > 0 then bits[#bits + 1] = unknownGems .. " gem" .. (unknownGems > 1 and "s" or "") .. " not recognised" end
  T.toast("Loaded " .. p.name .. (#bits > 0 and (" (" .. table.concat(bits, ", ") .. ")") or ""))
  T.S.tab = "char"
  T.render()
end
