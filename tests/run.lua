-- Engine and data checks for the addon: lua5.1 tests/run.lua (from the repository root)
--  1. 400 random characters run through the app's engine (tests/fixtures/oracle.json, made by
--     tools/oracle.mjs) must give the same numbers here: every sheet field, attack table, cap, crit cap,
--     Shear, damage taken, block charge simulation and talent rule.
--  2. The three wowsims/tbc reference tanks and the in-game naked character values.
--  3. The same rule checks as the app's tests.
--  4. Share codes: the app's codes open here, and codes made here open again.
-- Prints each check, "errors N" at the end, and exits non-zero on a failure.
package.path = "./tests/?.lua;" .. package.path
pcall(require, "bit")
bit = bit or (package.loaded.bit)
local L = require("load")
local T = L.load(".")
local U, E, S, TR = T.U, T.E, T.Store, T.TR

local failed, passed = 0, 0
local function check(name, ok, detail)
  if ok then passed = passed + 1 else failed = failed + 1 end
  if not ok or os.getenv("VERBOSE") then print((ok and "ok   " or "FAIL ") .. name .. (detail and detail ~= "" and ("  " .. detail) or "")) end
end
local function near(a, b, eps) return math.abs(a - b) < (eps or 0.01) end

-- deep comparison of a Lua value with a value decoded from the app's JSON
local function same(a, b, path, diffs)
  if type(b) == "number" and b >= 1e299 then b = math.huge end
  if type(a) == "number" and type(b) == "number" then
    if a == b then return end
    local tol = math.max(1e-7, math.abs(b) * 1e-9)
    if math.abs(a - b) > tol then diffs[#diffs + 1] = ("%s: addon %.10g, app %.10g"):format(path, a, b) end
    return
  end
  if type(b) == "table" then
    if type(a) ~= "table" then diffs[#diffs + 1] = path .. ": addon " .. tostring(a) .. ", app table" return end
    for k, v in pairs(b) do same(a[k], v, path .. "." .. tostring(k), diffs) end
    for k, v in pairs(a) do
      if b[k] == nil and v ~= false and not (type(v) == "table" and next(v) == nil) then diffs[#diffs + 1] = path .. "." .. tostring(k) .. ": only in the addon" end
    end
    return
  end
  if a == nil and b == false then return end
  if a ~= b then diffs[#diffs + 1] = path .. ": addon " .. tostring(a) .. ", app " .. tostring(b) end
end
local function compare(name, a, b)
  local diffs = {}
  same(a, b, "", diffs)
  check(name, #diffs == 0, table.concat(diffs, "; ", 1, math.min(#diffs, 6)))
end

local function blank(cls, race)
  return { v = 2, id = "t", name = "t", cls = cls, race = race, gear = {}, talents = {}, buffs = {}, cons = {}, abil = S.defaultAbilities(cls), opts = { uses = {}, swing = 2, adds = 0 }, updated = 0 }
end
local function talent(p, field, rank)
  for i, tree in ipairs(T.TALENTS[p.cls]) do
    for _, t in ipairs(tree.talents) do if t.f == field then p.talents[(i - 1) .. "." .. field] = rank end end
  end
end
local function cons(name)
  local c = U.find(T.CONSUMABLES, function(x) return x.n == name end)
  if not c then check('consumable "' .. name .. '" exists', false) return 0 end
  return c.id
end

---------------------------------------------------------------------- 1. the app's engine on random characters
local oracle = assert(U.parseJson(L.readFile("tests/fixtures/oracle.json")))
local function sheetView(s)
  local out = {}
  for k, v in pairs(s) do if type(v) == "number" or type(v) == "boolean" then out[k] = v end end
  out.resist, out.rangedDmg, out.parts, out.usesOn = s.resist, s.rangedDmg, s.parts, s.usesOn
  out.setBonuses, out.socketsMatched, out.uniqueClash = s.gear.setBonuses, s.gear.socketsMatched, s.gear.uniqueClash
  out.metaActive = s.gear.meta and s.gear.meta.active or nil
  return out
end
local codes = {}
for n, c in ipairs(oracle.cases) do
  local p, want = c.p, c.res
  local tag = ("random %d (%s %s)"):format(n, p.race, p.cls)
  local bc = E.bossCtx(p)
  compare(tag .. ": boss", bc, want.bc)
  for _, m in ipairs({ "passive", "cooldown", "procs" }) do
    local s = E.computeSheet(p, m)
    local t = E.bossTable(s, bc)
    local w = want.modes[m]
    compare(tag .. " " .. m .. ": sheet", sheetView(s), w.sheet)
    compare(tag .. " " .. m .. ": table", t, w.table)
    compare(tag .. " " .. m .. ": cap", E.capFor(s, bc), w.cap)
    compare(tag .. " " .. m .. ": cap values", E.capValues(s, bc), w.capValues)
    compare(tag .. " " .. m .. ": crit cap", E.critCap(s, bc), w.critCap)
    compare(tag .. " " .. m .. ": shear", E.shear(s, bc), w.shear)
    compare(tag .. " " .. m .. ": damage taken", E.intake(s, bc, t), w.intake)
    compare(tag .. " " .. m .. ": verdict", E.verdict(p, m), w.verdict)
  end
  compare(tag .. ": block charges", T.coverage(p), want.coverage)
  compare(tag .. ": talent points", E.treePoints(p), want.treePoints)
  check(tag .. ": talents valid", TR.valid(p.cls, p.talents) == want.valid)
  -- the app's share code opens here as the same character
  local back = S.importCode(want.code)
  local q = U.copy(p)
  q.id, q.updated, back.id, back.updated = nil, nil, nil, nil
  compare(tag .. ": app share code", back, q)
  -- and a code made here opens again
  local mine = S.exportCode(p)
  local again = S.importCode(mine)
  again.id, again.updated = nil, nil
  compare(tag .. ": addon share code", again, q)
  codes[#codes + 1] = mine
end
for key, gear in pairs(oracle.autoGear) do
  local cls, ph = key:match("^(%a+)%.(%d)$")
  compare("auto-gear " .. key, S.autoGear({ cls = cls, race = U.keys(T.BASES[cls])[1], gear = {}, talents = {}, buffs = {}, cons = {}, abil = {}, opts = { uses = {} } }, tonumber(ph)), gear)
end
-- codes made here, for tools/check_codes.mjs to open with the app's own code
local f = io.open("build/addon_codes.json", "w")
if f then f:write("[" .. table.concat(U.map(codes, function(x) return '"' .. x .. '"' end), ",") .. "]") f:close() end

---------------------------------------------------------------------- 2. known numbers
do
  check("items loaded", #T.ITEMS > 14000, tostring(#T.ITEMS))
  check("all TBC gems", #T.GEMS >= 230, tostring(#T.GEMS))
  check("enchants", #T.ENCHANTS > 250, tostring(#T.ENCHANTS))
  check("raid bosses", #T.BOSSES >= 60, tostring(#T.BOSSES))
  local wb = T.ITEM_BY_ID[29011]
  check("Warbringer Greathelm", wb.st.armor == 1227 and wb.st.def == 24 and wb.st.block == 19 and wb.st.bv == 39 and wb.so[1] == "meta" and wb.sb.block == 4)

  local t = blank("druid", "tauren") t.abil = {}
  local s = E.computeSheet(t)
  check("naked Tauren druid health 4498", near(s.health, 4498, 1), U.fixed(s.health, 1))
  check("naked Tauren druid melee crit 3.56%", near(s.crit, 3.56, 0.02), U.fixed(s.crit, 3))
  check("naked Tauren druid spell crit 3.29%", near(s.scrit, 3.29, 0.02), U.fixed(s.scrit, 3))
  local n = blank("druid", "nightelf") n.abil = {}
  local sn = E.computeSheet(n)
  check("naked Night Elf druid health 4254", near(sn.health, 4254, 1), U.fixed(sn.health, 1))
  check("naked Night Elf druid melee crit 3.96%", near(sn.crit, 3.96, 0.02))
  check("naked Night Elf druid spell crit 3.35%", near(sn.scrit, 3.35, 0.02))
end

local refs = assert(U.parseJson(L.readFile("tests/fixtures/wowsims.json")))
for _, ref in ipairs(refs) do
  local p = blank(ref.cls, ref.race)
  p.abil = ref.abil
  for f, r in pairs(ref.talents) do talent(p, f, r) end
  for i, g in ipairs(ref.gear) do
    if type(g) == "table" and g.id then
      local slot = T.SLOTS[i].id
      local ench = g.enchant and T.ENCHANT_ALIAS[g.enchant]
      p.gear[slot] = { id = g.id, gems = g.gems, ench = ench }
    end
  end
  p.buffs = ref.buffs
  for k, v in pairs(ref.cons) do
    if k == "scrolls" then p.cons.scrolls = U.map(v, cons) else p.cons[k] = cons(v) end
  end
  local s = E.computeSheet(p, "passive")
  local e = ref.expect
  local defBonus = (s.defenseSkill - 350) * 0.04
  local mine = {
    str = s.str, agi = s.agi, sta = s.sta, int = s.int, hp = s.health, armor = s.armor, ap = s.ap,
    def = (s.defenseSkill - 350) * E.R.defense, dodge = (s.dodge - defBonus) * E.R.dodge,
  }
  if s.canParry then mine.parry = (s.parry - 5 - defBonus) * E.R.parry end
  if s.canBlock then
    mine.block = (s.block - 5 - defBonus) * E.R.block
    mine.bv = s.blockValue
    -- block value follows the game server (see the app's tests): adjust wowsims' figure the same way
    e.bv = ref.cls == "warrior" and math.floor(e.bv - s.bvMul + 1e-9) or math.floor(e.bv + (s.str / 20 - 1) * s.bvMul + 1e-9)
  end
  for k, got in pairs(mine) do
    local want = e[k] or 0
    check(ref.name .. ": " .. k, math.abs(got - want) <= math.max(1, math.abs(want) * 0.003), ("addon %.2f, wowsims %.2f"):format(got, want))
  end
end

---------------------------------------------------------------------- 3. rules
do
  local p = blank("paladin", "human")
  talent(p, "anticipation", 5)
  check("Anticipation 5/5 = 370 defense", near(E.computeSheet(p).defenseSkill, 370))
  local low = U.find(T.ITEMS, function(i) return i.s == "chest" and i.il < 20 and T.canUse("paladin", i) end)
  local eh = U.find(T.ENCHANTS, function(e) return e.n:find("Chest %- Exceptional Health") end)
  local why = T.enchantProblem(eh, low, "paladin")
  check("high-level enchant on a low-level item says why", why ~= nil and why:find("level %d+ or higher") ~= nil, tostring(why))
  local twoH = U.find(T.ENCHANTS, function(e) return e.n == "Enchant 2H Weapon - Major Agility" end)
  local oneH = U.find(T.ITEMS, function(i) return i.s == "weapon" and i.ht == "1h" and i.il > 100 end)
  check("2H enchant refused on a one-hander", T.enchantProblem(twoH, oneH, "paladin") == "Two-handed weapons only")

  local w = blank("warrior", "human")
  w.cons = { flask = cons("Flask of Fortification"), guardian = cons("Elixir of Major Defense") }
  local s1 = E.computeSheet(w)
  w.cons.flask = nil
  local s2 = E.computeSheet(w)
  check("flask on: the guardian elixir does not count", s1.armor < s2.armor and s1.health > s2.health)

  local pal = blank("paladin", "human")
  pal.gear.offhand = { id = 30882 }
  local sp = E.computeSheet(pal)
  local base = E.capFor(sp, E.bossCtx(pal))
  check("shield, no weapon: cap 101.8", near(base, 101.8))
  pal.buffs = { scorpid = 1, insect = 1 }
  check("Scorpid Sting + Insect Swarm: cap 5 lower", near(base - E.capFor(sp, E.bossCtx(pal)), 5))
  pal.buffs = { tclap = 2 }
  check("Improved Thunder Clap: 20% slower swings", near(E.bossCtx(pal).swing, 2.5))

  local wr = blank("warrior", "human")
  wr.gear.mainhand = { id = U.find(T.ITEMS, function(i) return i.s == "weapon" and i.ht == "1h" and T.canUse("warrior", i) end).id }
  wr.gear.offhand = { id = 30882 }
  local sw = E.computeSheet(wr, "passive")
  local bc = E.bossCtx(wr)
  check("cap with weapon and shield is 102.4", near(E.capFor(sw, bc), 102.4))
  check("block rating closes the gap fastest", E.capValues(sw, bc)[1].stat == "block")
  check("crit immunity needs 490 defense", E.critCap(sw, bc).defSkillNeeded == 490)
  check("Shear cap 101.8", near(E.shear(sw, bc).cap, 101.8))

  local hs = blank("paladin", "human")
  talent(hs, "holyShield", 1) talent(hs, "improvedHolyShield", 2)
  hs.gear.offhand = { id = 30882 }
  check("Holy Shield: 8 charges with 2/2 Improved Holy Shield", T.coverage(hs).charges == 8)

  local old = { id = "x", name = "old", cls = "paladin", race = "human", gear = { head = { id = 29011, ench = 29186 } }, talents = {},
    buffs = { kings = 1, flaskfort = 1, foodsta = 1 }, opts = { holyShield = true, shieldBlock = true, redoubt = true, bear = false, uses = {}, swing = 2, dualWield = false }, updated = 0 }
  local fx = S.fixup(old)
  check("old save: flask and food move to consumables", fx.cons.flask == cons("Flask of Fortification") and fx.cons.food == cons("Fisherman's Feast"))
  check("old save: cooldowns move to abilities", fx.abil.holyShield and fx.abil.redoubt)
  check("old save: enchant converted", T.ENCHANT_BY_ID[fx.gear.head.ench].n == "Glyph of the Defender")

  for _, ex in ipairs(S.examples()) do
    check(ex.name .. ": talents valid", TR.valid(ex.cls, ex.talents), tostring(TR.spent(ex.talents)))
  end
  check("JSON round trip with accents", U.parseJson(U.json({ n = "Thrall\195\169" })).n == "Thrall\195\169")
  check("base64 round trip", U.b64decode(U.b64encode("TBCrushCalc!?")) == "TBCrushCalc!?")
end

print(("passed %d"):format(passed))
print(("errors %d"):format(failed))
if failed > 0 then os.exit(1) end
