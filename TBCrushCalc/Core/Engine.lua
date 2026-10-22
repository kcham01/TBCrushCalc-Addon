-- The character sheet, the boss's attack table and the damage you take: a line-for-line port of the
-- TBCrushCalc app's engine (src/engine.ts), so the addon and the app give the same numbers. The tests
-- (tests/run.lua) check it against the app's engine on the same characters.
--
-- Against a boss (fights as level 73, weapon skill 365) a level 70 tank (defense 350) loses 0.6% from
-- each of miss, dodge, parry and block. The character sheet shows values against a level 70, so the
-- uncrushable target on the sheet is 102.4% (less any "chance to hit" debuffs on the boss). Crushing
-- blows are a flat 15% from a level 73 attacker; they only disappear when miss + dodge + parry + block
-- fill the whole table.
local _, T = ...
local U = T.U
local E = {}
T.E = E

local floor, min, max, abs = math.floor, math.min, math.max, math.abs

E.R = {
  defense = 2.3654, dodge = 18.9231, parry = 23.6538, block = 7.8846, hit = 15.7692, crit = 22.0769, spellHit = 12.6154,
  res = 39.4231, exp = 3.9423, haste = 15.7692,
}
local R = E.R
E.AGI_PER_DODGE = { warrior = 30, paladin = 25, druid = 14.7059 }
E.AGI_PER_CRIT = { warrior = 33, paladin = 25, druid = 25 }
E.INT_PER_SPELL_CRIT = { warrior = 0, paladin = 80, druid = 79.4 }
--- the default boss: a level 73 raid boss swinging every 2 seconds
E.BOSS = { level = 73, crush = 15, crit = 5.6, cap = 102.4, shearCap = 101.8 }

--- JavaScript truthiness for saved values (0, false, "" and nil are "off")
local function on(v) return v ~= nil and v ~= false and v ~= 0 and v ~= "" end
E.on = on

function E.talentRank(p, field)
  local r = 0
  local suffix = "." .. field
  for k, v in pairs(p.talents) do
    if k:sub(-#suffix) == suffix then r = r + (tonumber(v) or 0) end
  end
  return r
end

local function add(a, b, k)
  if not b then return end
  k = k or 1
  for s, v in pairs(b) do a[s] = (a[s] or 0) + v * k end
end
E.add = add

--- gem colours that fit a socket
local FITS = { red = { "red", "orange", "purple" }, yellow = { "yellow", "orange", "green" }, blue = { "blue", "purple", "green" } }
function E.gemFits(socket, gemColor)
  if socket == "meta" then return gemColor == "meta" end
  if gemColor == "meta" then return false end
  if gemColor == "prismatic" then return true end
  return U.contains(FITS[socket] or {}, gemColor)
end
local COLOR_PARTS = {
  red = { "red" }, yellow = { "yellow" }, blue = { "blue" }, orange = { "red", "yellow" }, purple = { "red", "blue" },
  green = { "yellow", "blue" }, prismatic = { "red", "yellow", "blue" },
}

--- do the gems you wear meet a meta gem's requirement?
function E.metaActive(req, counts)
  if not req then return true end
  for _, r in ipairs(req) do
    local lr = r:lower()
    local n, c = lr:match("at least (%d+) (%w+) gems?")
    if n then
      if (counts[c] or 0) < tonumber(n) then return false end
    else
      local a, b = lr:match("more (%w+) gems than (%w+) gems")
      if a then
        if (counts[a] or 0) <= (counts[b] or 0) then return false end
      else
        n, c = lr:match("exactly (%d+) (%w+) gems?")
        if n and (counts[c] or 0) ~= tonumber(n) then return false end
      end
    end
  end
  return true
end

function E.sumGear(p)
  local st = {}
  local itemArmor = 0
  local colorCounts = { red = 0, yellow = 0, blue = 0 }
  local setCounts = {}
  local socketsMatched = {}
  local meta = nil
  local shield, weapon = nil, nil
  local seenUnique = {}
  local uniqueClash = {}
  for _, s in ipairs(T.SLOTS) do
    local slot = s.id
    local g = p.gear[slot]
    local it = g and T.ITEM_BY_ID[g.id]
    if it then
      if on(it.u) then
        if seenUnique[it.id] then uniqueClash[#uniqueClash + 1] = it.n end
        seenUnique[it.id] = true
      end
      if slot == "offhand" and it.wt == "shield" then shield = it end
      if slot == "mainhand" then weapon = it end
      -- armor on items (and armor enchants) is "armor from items" for talents and Dire Bear Form, as in wowsims
      local st2 = U.copy(it.st)
      if on(st2.armor) then itemArmor = itemArmor + st2.armor st2.armor = nil end
      add(st, st2)
      if it.setId then setCounts[it.setId] = (setCounts[it.setId] or 0) + 1 end
      local matched = it.so ~= nil and #it.so > 0
      for i, sock in ipairs(it.so or {}) do
        local gid = g.gems and g.gems[i]
        local gem = on(gid) and T.GEM_BY_ID[gid] or nil
        if not gem then
          matched = false
        else
          if gem.c == "meta" then meta = { gem = gem.id, active = true, req = gem.req }
          else
            for _, c in ipairs(COLOR_PARTS[gem.c] or {}) do colorCounts[c] = colorCounts[c] + 1 end
            add(st, gem.st)
          end
          if not E.gemFits(sock, gem.c) then matched = false end
        end
      end
      socketsMatched[slot] = matched
      if matched and it.sb then add(st, it.sb) end
      if on(g.ench) then
        local e = T.ENCHANT_BY_ID[g.ench]
        if e then
          local es = U.copy(e.st)
          if on(es.armor) then itemArmor = itemArmor + es.armor es.armor = nil end
          add(st, es)
        end
      end
    end
  end
  local eternalMeta = false
  if meta then
    meta.active = E.metaActive(meta.req, colorCounts)
    local gem = T.GEM_BY_ID[meta.gem]
    if meta.active then
      add(st, gem.st)
      if (gem.tx or ""):lower():find("shield block value", 1, true) then eternalMeta = true end
    end
  end
  local setBonuses = {}
  for _, sid in ipairs(U.keys(setCounts)) do
    local set = T.SETS[sid]
    if set then
      for _, b in ipairs(set.b) do
        if setCounts[sid] >= b[1] then
          setBonuses[#setBonuses + 1] = { set = set.n, count = b[1], text = b[2] }
          add(st, b[3])
        end
      end
    end
  end
  local twoHand = weapon ~= nil and weapon.ht == "2h"
  local ranged = p.gear.ranged and T.ITEM_BY_ID[p.gear.ranged.id] or nil
  return {
    st = st, itemArmor = itemArmor, shield = (not twoHand) and shield or nil, weapon = weapon, ranged = ranged, twoHand = twoHand,
    meta = meta, colorCounts = colorCounts, setCounts = setCounts, setBonuses = setBonuses,
    libramOfRepentance = ranged ~= nil and ranged.id == 29388, eternalMeta = eternalMeta, socketsMatched = socketsMatched, uniqueClash = uniqueClash,
  }
end

local function sumValues(t)
  local s = 0
  if t then for _, v in pairs(t) do s = s + v end end
  return s
end

--- buffs that are on, with "doesn't stack" groups resolved (the larger one counts)
function E.activeBuffs(p, mode)
  local list = {}
  local best = {}
  for _, b in ipairs(T.ALL_BUFFS) do
    local lvl = p.buffs[b.id]
    if on(lvl) and not (b.proc and mode ~= "procs") then
      local imp = lvl == 2 and b.imp ~= nil
      if b.excl then
        local v = sumValues(b.st) + sumValues(b.pct) * 1000 + (imp and sumValues(b.imp.st) or 0)
        if not best[b.excl] or best[b.excl].v < v then best[b.excl] = { b = b, imp = imp, v = v } end
      else
        list[#list + 1] = { b = b, imp = imp }
      end
    end
  end
  for _, k in ipairs(U.keys(best)) do list[#list + 1] = { b = best[k].b, imp = best[k].imp } end
  return list
end

--- the boss you are tanking (or a default level 73 boss), with debuffs on it
function E.bossCtx(p)
  local boss = on(p.opts.boss) and T.BOSS_BY_ID[p.opts.boss] or nil
  local hitRed, apRed, slow = 0, 0, 0
  for _, x in ipairs(E.activeBuffs(p, "procs")) do
    local st = U.copy(x.b.st or {})
    if x.imp then add(st, x.b.imp.st) end
    hitRed = hitRed + (st.hitred or 0)
    apRed = apRed + (st.apred or 0)
    slow = slow + (st.slow or 0)
  end
  local level = boss and boss.lvl or E.BOSS.level
  local baseSwing = boss and boss.swing or (on(p.opts.swing) and p.opts.swing or 2)
  local swing = baseSwing / (1 - slow / 100)
  local deficit = max(0, (level * 5 - 350) * 0.04)
  return {
    level = level, baseSwing = baseSwing, swing = swing, dmg = boss and boss.dmg or nil, hitRed = hitRed, apRed = apRed, slow = slow,
    attackers = 1 + (p.opts.adds or 0) + ((boss and on(boss.dw)) and 1 or 0),
    name = boss and boss.n or "a level 73 boss", dualWield = boss ~= nil and on(boss.dw), deficit = deficit,
    crush = (level - 70 >= 3) and max(0, (level * 5 - 350) * 2 - 15) or 0,
    critBase = 5 + deficit,
  }
end

local THICK_HIDE = { [0] = 0, 0.04, 0.07, 0.10 }

--- The character sheet. mode: "passive" = gear, talents, buffs and consumables; "cooldown" adds Holy Shield or
--- Shield Block if switched on; "procs" also adds Redoubt, proc buffs, potions, on-use trinkets and cooldowns.
function E.computeSheet(p, mode)
  mode = mode or "procs"
  local cls = p.cls
  local base = T.BASES[cls][p.race]
  if not base then for _, b in pairs(T.BASES[cls]) do base = b break end end
  local gear = E.sumGear(p)
  local parts = {}
  local function note(k, label, value)
    if abs(value) > 1e-9 then
      parts[k] = parts[k] or {}
      parts[k][#parts[k] + 1] = { label = label, value = value }
    end
  end
  local bear = cls == "druid" and on(p.abil.bear)
  local function Tr(f) return E.talentRank(p, f) end
  local function ab(id) return on(p.abil[id]) end

  -- flat stats: gear, buffs, consumables
  local flat = U.copy(gear.st)
  local pct = {}
  local function mulPct(k, v) pct[k] = (1 + (pct[k] or 0)) * (1 + v) - 1 end
  local flatReduction = 0
  for _, x in ipairs(E.activeBuffs(p, mode)) do
    local b = x.b
    add(flat, b.st)
    if x.imp then add(flat, b.imp.st) end
    for k, v in pairs(b.pct or {}) do mulPct(k, v) end
    if x.imp then for k, v in pairs(b.imp.pct or {}) do mulPct(k, v) end end
    flatReduction = flatReduction + (b.flat or 0)
  end
  local c = p.cons or {}
  local consIds = {}
  local function push(id) if on(id) then consIds[#consIds + 1] = id end end
  push(c.flask)
  if not on(c.flask) then push(c.battle) push(c.guardian) end
  push(c.food)
  for _, id in ipairs(c.scrolls or {}) do push(id) end
  if mode == "procs" then push(c.potion) end
  for _, id in ipairs(consIds) do
    local x = T.CONSUMABLE_BY_ID[id]
    if x then
      add(flat, x.st)
      flatReduction = flatReduction + (x.st.flat or 0)
    end
  end
  -- on-use trinkets switched on (procs view)
  local usesOn = {}
  if mode == "procs" then
    for _, slot in ipairs({ "trinket1", "trinket2" }) do
      local g = p.gear[slot]
      local it = g and T.ITEM_BY_ID[g.id]
      if it and it.fx and on(p.opts.uses[tostring(it.id)]) then
        for _, e in ipairs(it.fx) do flat[e.stat] = (flat[e.stat] or 0) + e.amount end
        usesOn[#usesOn + 1] = it.n
      end
    end
  end

  -- primary stats with % modifiers
  local mul = { str = 1, agi = 1, sta = 1, int = 1, spi = 1 }
  for _, k in ipairs({ "str", "agi", "sta", "int", "spi" }) do mul[k] = mul[k] * (1 + (pct.all or 0)) * (1 + (pct[k] or 0)) end
  if cls == "warrior" then mul.sta = mul.sta * (1 + 0.01 * Tr("vitality")) mul.str = mul.str * (1 + 0.02 * Tr("vitality")) end
  if cls == "paladin" then
    mul.str = mul.str * (1 + 0.02 * Tr("divineStrength"))
    mul.int = mul.int * (1 + 0.02 * Tr("divineIntellect"))
    mul.sta = mul.sta * (1 + 0.03 * Tr("sacredDuty"))
    mul.sta = mul.sta * (1 + 0.02 * Tr("combatExpertise"))
  end
  if cls == "druid" then
    local sotfMul = 1 + 0.01 * Tr("survivalOfTheFittest")
    for _, k in ipairs({ "str", "agi", "sta", "int", "spi" }) do mul[k] = mul[k] * sotfMul end
    mul.int = mul.int * (1 + 0.04 * Tr("heartOfTheWild"))
    if bear then mul.sta = mul.sta * (1 + 0.04 * Tr("heartOfTheWild")) mul.sta = mul.sta * 1.25 end
  end
  local str = (base.str + (flat.str or 0)) * mul.str
  local agi = (base.agi + (flat.agi or 0)) * mul.agi
  local sta = (base.sta + (flat.sta or 0)) * mul.sta
  local int = (base.int + (flat.int or 0)) * mul.int
  local spi = (base.spi + (flat.spi or 0)) * mul.spi

  -- health: wowsims' base health already counts the first 20 stamina as 10 health each
  local health = base.hp + sta * 10 + (flat.hp or 0)
  if p.race == "tauren" then health = health * 1.05 end
  if mode == "procs" and cls == "warrior" and ab("laststand") and Tr("lastStand") > 0 then health = health * 1.3 end

  -- armor: items x talents (x5 in Dire Bear Form, Thick Hide on top), + 2 per agility, + buffs
  local itemArmorMul = 1
  if cls == "warrior" or cls == "paladin" then itemArmorMul = itemArmorMul + 0.02 * Tr("toughness") end
  if cls == "druid" then itemArmorMul = (bear and 5 or 1) * (1 + THICK_HIDE[min(3, Tr("thickHide"))]) end
  local bonusArmor = (flat.armor or 0) + (bear and (flat.beararmor or 0) or 0)
  local armor = (gear.itemArmor * itemArmorMul + agi * 2 + bonusArmor) * (1 + (pct.armor or 0))
  local bc = E.bossCtx(p)
  local armorConst = 467.5 * bc.level - 22167.5
  local armorReduction = min(75, armor / (armor + armorConst) * 100)
  note("armor", "Armor from items", gear.itemArmor * itemArmorMul)
  note("armor", "Agility", agi * 2)
  note("armor", "Bonus armor (buffs, set bonuses, consumables)", bonusArmor)

  -- defense
  local defRating = flat.def or 0
  local talentDef = (cls == "warrior" or cls == "paladin") and 4 * Tr("anticipation") or 0
  local defenseSkill = 350 + talentDef + defRating / R.defense
  local defenseFloor = 350 + talentDef + floor(defRating / R.defense)
  local defBonus = (defenseSkill - 350) * 0.04

  -- miss
  local miss = 5 + defBonus
  note("miss", "Base", 5)
  note("miss", "Defense", defBonus)

  -- dodge
  local dodge = base.dodge + agi / E.AGI_PER_DODGE[cls] + (flat.dodge or 0) / R.dodge + defBonus
  note("dodge", "Base", base.dodge)
  note("dodge", "Agility", agi / E.AGI_PER_DODGE[cls])
  note("dodge", "Dodge rating", (flat.dodge or 0) / R.dodge)
  note("dodge", "Defense", defBonus)
  if p.race == "nightelf" then dodge = dodge + 1 note("dodge", "Quickness (Night Elf)", 1) end
  if cls == "druid" and bear then dodge = dodge + 2 * Tr("feralSwiftness") note("dodge", "Feral Swiftness", 2 * Tr("feralSwiftness")) end

  -- parry: needs a weapon; bears can't parry
  local canParry = (not bear) and gear.weapon ~= nil
  local parry = 0
  if canParry then
    local defl = Tr("deflection")
    parry = 5 + (flat.parry or 0) / R.parry + defl + defBonus
    note("parry", "Base", 5)
    note("parry", "Parry rating", (flat.parry or 0) / R.parry)
    note("parry", "Deflection", defl)
    note("parry", "Defense", defBonus)
  end

  -- block: needs a shield
  local canBlock = gear.shield ~= nil and cls ~= "druid"
  local block = 0
  local blockRating = flat.block or 0
  local holyShieldOn = cls == "paladin" and canBlock and ab("holyShield") and Tr("holyShield") > 0 and mode ~= "passive"
  local shieldBlockOn = cls == "warrior" and canBlock and ab("shieldBlock") and mode ~= "passive"
  local redoubtOn = cls == "paladin" and canBlock and ab("redoubt") and Tr("redoubt") > 0 and mode == "procs"
  if holyShieldOn and gear.libramOfRepentance then blockRating = blockRating + 42 end
  if canBlock then
    block = 5 + blockRating / R.block + defBonus
    note("block", "Base", 5)
    note("block", (gear.libramOfRepentance and holyShieldOn) and "Block rating (incl. Libram of Repentance)" or "Block rating", blockRating / R.block)
    note("block", "Defense", defBonus)
    if cls == "warrior" then local s = Tr("shieldSpecialization") block = block + s note("block", "Shield Specialization", s) end
    if holyShieldOn then block = block + 30 note("block", "Holy Shield", 30) end
    if shieldBlockOn then block = block + 75 note("block", "Shield Block", 75) end
    if redoubtOn then local r = 6 * Tr("redoubt") block = block + r note("block", "Redoubt (proc)", r) end
  end

  -- block value, as the game server works it out (cmangos Player::GetShieldBlockValue, every class with a shield):
  -- (items + strength / 20 - 1) x talents and meta gem, rounded down
  local blockValue, bvMul = 0, 1
  if canBlock then
    if cls == "warrior" then bvMul = bvMul + 0.1 * Tr("shieldMastery") end
    if cls == "paladin" then bvMul = bvMul + 0.1 * Tr("shieldSpecialization") end
    if gear.eternalMeta then bvMul = bvMul * 1.1 end            -- percent modifiers multiply on the server
    blockValue = max(0, floor(((flat.bv or 0) + str / 20 - 1) * bvMul + 1e-9))
    note("bv", "Shield and gear", flat.bv or 0)
    note("bv", "Strength / 20 - 1", str / 20 - 1)
    if bvMul ~= 1 then note("bv", ("Talents and meta gem (x%s)"):format(U.fixed(bvMul, 2)), ((flat.bv or 0) + str / 20 - 1) * (bvMul - 1)) end
  end

  -- crit reduction
  local resilience = flat.res or 0
  local sotf = cls == "druid" and Tr("survivalOfTheFittest") or 0
  local critReduction = (defenseSkill - 350) * 0.04 + resilience / R.res + sotf
  local critReductionSafe = (defenseFloor - 350) * 0.04 + resilience / R.res + sotf
  note("crit", "Defense", (defenseSkill - 350) * 0.04)
  note("crit", "Resilience", resilience / R.res)
  if cls == "druid" then note("crit", "Survival of the Fittest", sotf) end

  -- melee
  local precision = (cls == "paladin" or cls == "warrior") and Tr("precision") or 0
  local hit = (flat.hit or 0) / R.hit + precision + (flat.hitpct or 0)
  local expertise = floor((flat.exp or 0) / R.exp) + (cls == "warrior" and 2 * Tr("defiance") or 0) + (cls == "paladin" and Tr("combatExpertise") or 0)
  local ownLotp = (cls == "druid" and Tr("leaderOfThePack") > 0 and bear and not on(p.buffs.lotp)) and 5 or 0
  local crit = base.crit + agi / E.AGI_PER_CRIT[cls] + (flat.crit or 0) / R.crit + (flat.critpct or 0) + ownLotp + (bear and 2 * Tr("sharpenedClaws") or 0)
  local ap = base.ap + str * 2 + (flat.ap or 0)
  if bear then ap = ap + 210 + (flat.fap or 0) + 35 * Tr("predatoryStrikes") end
  ap = ap * (1 + (pct.ap or 0))
  local haste = (flat.haste or 0) / R.haste

  -- ranged (warriors shoot; paladins and druids hold a relic)
  local rw = gear.ranged
  local hasRanged = cls == "warrior" and rw ~= nil and rw.dmg ~= nil
  local rap = cls == "warrior" and (agi + 60 + (flat.rap or 0)) * (1 + (pct.ap or 0)) or 0
  local rhit = ((flat.hit or 0) + (flat.rhit or 0)) / R.hit + (flat.hitpct or 0)
  local rcrit = base.crit + agi / E.AGI_PER_CRIT[cls] + ((flat.crit or 0) + (flat.rcrit or 0)) / R.crit + (flat.critpct or 0)

  -- spells
  local sp = flat.sp or 0
  local heal = flat.heal or 0
  local shit = (flat.shit or 0) / R.spellHit + (flat.hitpct or 0) + (flat.shitpct or 0)
  local scrit = 0
  if cls ~= "warrior" then
    scrit = base.scrit + (E.INT_PER_SPELL_CRIT[cls] ~= 0 and int / E.INT_PER_SPELL_CRIT[cls] or 0) + (flat.scrit or 0) / R.crit + (flat.scritpct or 0)
  end
  local shaste = (flat.shaste or 0) / R.haste
  local mana = cls == "warrior" and 0 or base.mana + int * 15 + (flat.mana or 0)
  local mp5 = flat.mp5 or 0

  -- damage taken modifiers
  local dmgTakenMult = 1
  if cls == "warrior" and ab("defstance") then dmgTakenMult = dmgTakenMult * 0.9 end
  if cls == "paladin" and ab("rf") then dmgTakenMult = dmgTakenMult * (1 - 0.02 * Tr("improvedRighteousFury")) end
  if mode == "procs" and cls == "warrior" and ab("shieldwall") then dmgTakenMult = dmgTakenMult * 0.25 end

  local resist = {}
  for _, k in ipairs({ "arcres", "fireres", "natres", "frostres", "shadres" }) do resist[k] = flat[k] or 0 end

  local total = miss + dodge + parry + block
  return {
    cls = cls, race = p.race, bear = bear, str = str, agi = agi, sta = sta, int = int, spi = spi, health = health, armor = armor,
    armorReduction = armorReduction, defenseSkill = defenseSkill, defenseFloor = defenseFloor, defRating = defRating,
    miss = miss, dodge = dodge, parry = parry, block = block, total = total, canBlock = canBlock, canParry = canParry,
    blockValue = blockValue, bvMul = bvMul, critReduction = critReduction, critReductionSafe = critReductionSafe, resilience = resilience,
    hit = hit, expertise = expertise, ap = ap, crit = crit, haste = haste,
    rap = rap, rhit = rhit, rcrit = rcrit, rangedSpeed = (rw and rw.dmg) and rw.dmg[3] or 0,
    rangedDmg = (rw and rw.dmg) and { rw.dmg[1], rw.dmg[2] } or nil, hasRanged = hasRanged,
    sp = sp, heal = heal, shit = shit, scrit = scrit, shaste = shaste, mp5 = mp5, mana = mana, resist = resist,
    dmgTakenMult = dmgTakenMult, flatReduction = flatReduction,
    parts = parts, holyShieldOn = holyShieldOn, shieldBlockOn = shieldBlockOn, redoubtOn = redoubtOn, usesOn = usesOn, gear = gear,
  }
end

--- one white swing from the boss: the slices of the single roll, in order
function E.bossTable(s, bc)
  local d = bc.deficit
  local left = 100
  local function take(v) local x = max(0, min(left, v)) left = left - x return x end
  local miss = take(s.miss - d + bc.hitRed)
  local dodge = take(s.dodge - d)
  local parry = s.canParry and take(s.parry - d) or 0
  local block = s.canBlock and take(s.block - d) or 0
  local crit = take(max(0, bc.critBase - s.critReduction))
  local crush = take(bc.crush)
  return { miss = miss, dodge = dodge, parry = parry, block = block, crit = crit, crush = crush, hit = left }
end

--- the sheet total you need so crushing blows (or, without crushes, normal hits) are off the table
function E.capFor(s, bc)
  local comps = 2 + (s.canParry and 1 or 0) + (s.canBlock and 1 or 0)
  return 100 + bc.deficit * comps - bc.hitRed
end

function E.verdict(p, mode)
  local s = E.computeSheet(p, mode)
  local bc = E.bossCtx(p)
  local t = E.bossTable(s, bc)
  local cap = E.capFor(s, bc)
  return { mode = mode, total = s.total, cap = cap, short = max(0, cap - s.total), uncrushable = s.total >= cap - 1e-9, table = t, crushes = bc.crush > 0 }
end

--- what one point of each rating adds toward the cap for this character
function E.capValues(s, bc)
  local short = max(0, E.capFor(s, bc) - s.total)
  local comps = 2 + (s.canParry and 1 or 0) + (s.canBlock and 1 or 0)
  local rows = {
    { stat = "block", label = "Block rating", perPoint = s.canBlock and 1 / R.block or 0 },
    { stat = "def", label = "Defense rating", perPoint = 0.04 * comps / R.defense },
    { stat = "dodge", label = "Dodge rating", perPoint = 1 / R.dodge },
    { stat = "parry", label = "Parry rating", perPoint = s.canParry and 1 / R.parry or 0 },
    { stat = "agi", label = "Agility", perPoint = 1 / E.AGI_PER_DODGE[s.cls] },
  }
  local out = {}
  for _, r in ipairs(rows) do
    if r.perPoint > 0 then
      r.needed = short > 0 and math.ceil(short / r.perPoint) or 0
      out[#out + 1] = r
    end
  end
  -- a stable sort (as in JavaScript): equal rates keep their order
  for i = 2, #out do
    local x, j = out[i], i - 1
    while j >= 1 and out[j].perPoint < x.perPoint do out[j + 1] = out[j] j = j - 1 end
    out[j + 1] = x
  end
  return out
end

--- crit immunity uses whole defense points only, to be safe: the game may round fractional defense down
function E.critCap(s, bc)
  local need = bc.critBase
  local ok = s.critReductionSafe >= need - 1e-9
  local rounding = (not ok) and s.critReduction >= need - 1e-9
  local gap = max(0, need - s.critReductionSafe)
  local sotf = 0
  if s.cls == "druid" then
    for _, x in ipairs(s.parts.crit or {}) do if x.label == "Survival of the Fittest" then sotf = x.value end end
  end
  return {
    reduction = s.critReductionSafe, needed = need, ok = ok, rounding = rounding,
    defSkillNeeded = math.ceil(350 + (need - sotf) / 0.04 - 1e-9),
    defRatingShort = math.ceil(gap / 0.04 * R.defense), resShort = math.ceil(gap * R.res),
  }
end

--- attacks that can't miss (Illidan's Shear): only dodge, parry and block count
function E.shear(s, bc)
  local comps = 1 + (s.canParry and 1 or 0) + (s.canBlock and 1 or 0)
  local cap = 100 + bc.deficit * comps
  local v = s.dodge + (s.canParry and s.parry or 0) + (s.canBlock and s.block or 0)
  return { value = v, cap = cap, ok = v >= cap - 1e-9, short = max(0, cap - v) }
end

--- Melee damage from the boss: its hit range (cmangos data) less attack power debuffs, then your armor and
--- damage reduction, averaged over the attack table. Without boss data, per 10,000 damage before armor.
function E.intake(s, bc, t)
  local raw = bc.dmg
  local avgRaw = raw and (raw[1] + raw[2]) / 2 or 10000
  local apLoss = bc.apRed / 14 * bc.baseSwing
  local unmit = max(0, avgRaw - apLoss)
  local mit = (1 - s.armorReduction / 100) * s.dmgTakenMult
  local perHit = max(0, unmit * mit - s.flatReduction)
  local critHit = max(0, unmit * 2 * mit - s.flatReduction)
  local crushHit = max(0, unmit * 1.5 * mit - s.flatReduction)
  local blockedHit = max(0, perHit - s.blockValue)
  local perSwing = (t.hit * perHit + t.crit * critHit + t.crush * crushHit + t.block * blockedHit) / 100
  local perSecond = perSwing / bc.swing * (bc.dualWield and 1.5 or 1)
  return {
    raw = raw, perHit = perHit, perSwing = perSwing, perSecond = perSecond, crushHit = crushHit, critHit = critHit, blockedHit = blockedHit,
    swing = bc.swing, hitsToKill = perHit > 0 and math.ceil(s.health / perHit) or math.huge, effectiveHealth = s.health / mit,
  }
end

--- talent points spent per tree
function E.treePoints(p)
  local out = {}
  for i, tree in ipairs(T.TALENTS[p.cls]) do
    local n = 0
    for _, tl in ipairs(tree.talents) do n = n + (tonumber(p.talents[(i - 1) .. "." .. tl.f]) or 0) end
    out[i] = n
  end
  return out
end
