-- Saved characters (in the addon's saved variables, shared by all your characters on the account), the
-- example characters, auto-gear, and share codes. Codes are the app's own "TBCC1:" format, so a
-- character can be copied from the phone into the game and back.
local _, T = ...
local U, E = T.U, T.E
local S = {}
T.Store = S

S.PROFILE_VERSION = 2

local function consId(name)
  local c = U.find(T.CONSUMABLES, function(x) return x.n == name end)
  return c and c.id
end

function S.defaultAbilities(cls)
  if cls == "warrior" then return { defstance = true, shieldBlock = true } end
  if cls == "paladin" then return { rf = true, holyShield = true } end
  return { bear = true }
end

function S.newProfile(cls, race, name)
  return {
    v = S.PROFILE_VERSION, id = U.newId(), name = name, cls = cls, race = race, gear = {}, talents = {},
    buffs = {}, cons = {}, abil = S.defaultAbilities(cls),
    opts = { uses = {}, swing = 2.0, adds = 0 },
    updated = U.now(),
  }
end

--- brings characters saved by older versions up to date (and cleans up anything a code left out)
function S.fixup(p)
  if not p.v or p.v < 2 then
    -- version 1: consumables were buff ids, cooldowns were options, enchants were wowsims ids
    local old = p.buffs or {}
    local cons = {}
    local map = {
      flaskfort = { "flask", "Flask of Fortification" }, flaskchrom = { "flask", "Flask of Chromatic Wonder" },
      majoragi = { "battle", "Elixir of Major Agility" }, mastery = { "battle", "Elixir of Mastery" },
      majordef = { "guardian", "Elixir of Major Defense" }, ironskin = { "guardian", "Elixir of Ironskin" }, majorfort = { "guardian", "Elixir of Major Fortitude" },
      foodsta = { "food", "Fisherman's Feast" }, foodagi = { "food", "Warp Burger" },
    }
    local buffs = {}
    for k, v in pairs(old) do
      if map[k] then
        local id = consId(map[k][2])
        if id then cons[map[k][1]] = id end
      else
        buffs[k] = v
      end
    end
    p.buffs = buffs
    p.cons = cons
    local o = p.opts or {}
    p.abil = S.defaultAbilities(p.cls)
    p.abil.holyShield = o.holyShield ~= false
    p.abil.shieldBlock = o.shieldBlock ~= false
    p.abil.redoubt = E.on(o.redoubt)
    p.abil.bear = p.cls == "druid" and o.bear ~= false or false
    for _, g in pairs(p.gear or {}) do
      if type(g) == "table" and E.on(g.ench) then g.ench = T.ENCHANT_ALIAS[g.ench] end
    end
    p.v = S.PROFILE_VERSION
  end
  local opts = { uses = {}, swing = 2, adds = 0 }
  for k, v in pairs(p.opts or {}) do opts[k] = v end
  p.opts = opts
  p.buffs = p.buffs or {}
  p.talents = p.talents or {}
  p.gear = p.gear or {}
  p.cons = p.cons or {}
  p.abil = p.abil or S.defaultAbilities(p.cls)
  if not T.BASES[p.cls][p.race] then p.race = U.keys(T.BASES[p.cls])[1] end
  return p
end

--- the arrays in a saved character (everything else is an object in JSON)
local ARRAYS = { gems = true, scrolls = true }

function S.exportCode(p)
  local c = U.copy(p)
  c.id = nil
  return "TBCC1:" .. U.b64encode(U.json(c, ARRAYS))
end

function S.importCode(code)
  local body = U.trim(code or ""):gsub("^TBCC1:", "")
  local raw = U.b64decode(body)
  if not raw then return nil end
  local p = U.parseJson(raw)
  if type(p) ~= "table" or not U.contains({ "warrior", "paladin", "druid" }, p.cls) then return nil end
  p.id = U.newId()
  p.updated = U.now()
  -- JSON arrays come back 1-based already; gear, talents and buffs come back keyed by name
  local ok, res = pcall(S.fixup, p)
  if not ok then return nil end
  return res
end

--- a talent build given as tree (0-based) -> field -> rank, checked against the real trees
local function build(cls, spec)
  local out = {}
  local trees = T.TALENTS[cls]
  for ti, fields in pairs(spec) do
    for f, r in pairs(fields) do
      local t = U.find(trees[ti + 1].talents, function(x) return x.f == f end)
      if t then out[ti .. "." .. f] = math.min(t.max, r) end
    end
  end
  return out
end

--- a typical raid: Kings, Mark, Fortitude, Devotion, Flask of Fortification and Fisherman's Feast
function S.raidSetup(p)
  p.buffs = { kings = 1, motw = 2, fort = 2, devo = 1 }
  p.cons = { flask = consId("Flask of Fortification"), food = consId("Fisherman's Feast") }
  if p.cls == "warrior" then p.buffs.cshout = 1 end
end

--- picks the best avoidance item per slot from a phase (level 70 gear only), used for new and example characters
function S.autoGear(p, phase)
  local gear = {}
  local used = {}
  local druid = p.cls == "druid"
  local function score(st)
    return (st.def or 0) * 0.07 + (st.dodge or 0) * 0.053 + (st.parry or 0) * 0.042 + (st.block or 0) * (druid and 0 or 0.127)
      + (st.agi or 0) * (druid and 0.07 or 0.035) + (st.sta or 0) * 0.03 + (st.armor or 0) * (druid and 0.004 or 0.0005)
  end
  local ARMOR_SLOTS = { "head", "shoulder", "chest", "wrist", "hands", "waist", "legs", "feet" }
  for _, s in ipairs(T.SLOTS) do
    local slot = s.id
    if not (slot == "offhand" and druid) then
      local pool = {}
      for _, it in ipairs(T.ITEMS) do
        if it.s == s.item and math.max(1, it.ph) <= phase and it.q >= 3 and (it.rl or 0) >= 68 and T.canUse(p.cls, it, slot)
          and (slot ~= "offhand" or it.wt == "shield") and (slot ~= "mainhand" or (druid and it.ht == "2h" or (not druid and it.ht ~= "2h")))
          and (not it.at or it.at == (druid and "leather" or "plate") or not U.contains(ARMOR_SLOTS, it.s))
          and not (E.on(it.u) and used[it.id]) then
          pool[#pool + 1] = it
        end
      end
      local sc = {}
      for _, it in ipairs(pool) do sc[it] = score(it.st) end
      U.sort(pool, function(a, b) return sc[b] - sc[a] end)
      local best = pool[1]
      if best then gear[slot] = { id = best.id } used[best.id] = true end
    end
  end
  return gear
end

--- example characters so the addon opens with something on it (clearly named as examples)
function S.examples()
  local pal = S.newProfile("paladin", "human", "Example Paladin")
  pal.talents = build("paladin", {
    [0] = { divineStrength = 5, divineIntellect = 5 },
    [1] = { redoubt = 5, precision = 3, toughness = 5, blessingOfKings = 1, improvedRighteousFury = 3, shieldSpecialization = 3, anticipation = 5,
      spellWarding = 2, blessingOfSanctuary = 1, reckoning = 2, sacredDuty = 2, oneHandedWeaponSpecialization = 5,
      holyShield = 1, improvedHolyShield = 2, ardentDefender = 5, combatExpertise = 5, avengersShield = 1 },
  })
  pal.gear = S.autoGear(pal, 1)
  S.raidSetup(pal)

  local war = S.newProfile("warrior", "human", "Example Warrior")
  war.talents = build("warrior", {
    [0] = { improvedHeroicStrike = 3, deflection = 5, improvedThunderClap = 3 },
    [2] = { tacticalMastery = 3, anticipation = 5, shieldSpecialization = 5, toughness = 5, lastStand = 1, improvedShieldBlock = 1, defiance = 3,
      improvedSunderArmor = 3, improvedShieldWall = 2, concussionBlow = 1, shieldMastery = 3, oneHandedWeaponSpecialization = 5,
      improvedDefensiveStance = 3, shieldSlam = 1, focusedRage = 3, vitality = 5, devastate = 1 },
  })
  war.gear = S.autoGear(war, 1)
  S.raidSetup(war)

  local dru = S.newProfile("druid", "tauren", "Example Bear")
  dru.talents = build("druid", {
    [1] = { ferocity = 5, feralInstinct = 3, thickHide = 3, feralSwiftness = 2, feralCharge = 1, sharpenedClaws = 3, shreddingAttacks = 2,
      predatoryStrikes = 3, primalFury = 2, savageFury = 2, faerieFire = 1, heartOfTheWild = 5, survivalOfTheFittest = 3, leaderOfThePack = 1,
      improvedLeaderOfThePack = 2, predatoryInstincts = 5, mangle = 1, brutalImpact = 2 },
    [2] = { improvedMarkOfTheWild = 5, furor = 5, naturalist = 5 },
  })
  dru.gear = S.autoGear(dru, 1)
  S.raidSetup(dru)
  return { pal, war, dru }
end

---------------------------------------------------------------------- saved variables
--- TBCrushCalcDB = { profiles = { ... }, current = id, ui = { ... } }
function S.load(db)
  db.profiles = db.profiles or {}
  local list = {}
  for _, p in ipairs(db.profiles) do
    local ok, fixed = pcall(S.fixup, p)
    if ok then list[#list + 1] = fixed end
  end
  if #list == 0 then list = S.examples() end
  db.profiles = list
  db.ui = db.ui or {}
  return db
end
