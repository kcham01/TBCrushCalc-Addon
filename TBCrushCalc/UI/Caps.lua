-- The Caps screen: the boss you're tanking, crush cap, damage taken, crit cap, how well block cooldowns
-- really cover you, Illidan's Shear, what closes the gap, and where every percent comes from
-- (the app's ui/caps.ts).
local _, T = ...
local U, E, K = T.U, T.E, T.K
local S = T.S

local floor, max = math.floor, math.max

local MODE_NAME = { passive = "Gear only", cooldown = "Cooldown", procs = "Procs too" }
local SLICES = {
  { "miss", "Miss", { 0.55, 0.55, 0.55 } }, { "dodge", "Dodge", { 0.2, 0.6, 1 } }, { "parry", "Parry", { 0.7, 0.45, 1 } },
  { "block", "Block", { 0.9, 0.78, 0.3 } }, { "crit", "Crit", { 1, 0.5, 0.1 } }, { "crush", "Crush", { 0.9, 0.12, 0.12 } }, { "hit", "Hit", { 0.32, 0.27, 0.22 } },
}
local num = U.commas

local function cards(f, list)
  local w = floor((f.width - 2 * 6) / 3)
  for i, c in ipairs(list) do
    local b = K.get(f.owner, "card", f.parent)
    b:SetPoint("TOPLEFT", f.parent, "TOPLEFT", f.x + (i - 1) * (w + 6), -f.y)
    b:SetWidth(w)
    b.l:SetText(c.l) b.n:SetText(c.n) b.s:SetText(c.s)
    if c.ok == true then b.s:SetTextColor(0.12, 1, 0) elseif c.ok == false then b.s:SetTextColor(1, 0.35, 0.3) end
    if c.selected then b:SetBackdropBorderColor(1, 0.82, 0, 1) end
    b:SetScript("OnClick", c.click)
    if c.click then b:Enable() end
  end
  f.y = f.y + 56 + 8
end

function T.capsView(flow, p)
  local modes = { "passive", "cooldown", "procs" }
  local sheets = {}
  for _, m in ipairs(modes) do sheets[m] = E.computeSheet(p, m) end
  local mode = S.capMode
  local s = sheets[mode]
  local bc = E.bossCtx(p)
  local t = E.bossTable(s, bc)
  local cap = E.capFor(s, bc)
  local ok = s.total >= cap - 1e-9
  local boss = E.on(p.opts.boss) and T.BOSS_BY_ID[p.opts.boss]
  local cov = T.coverage(p)

  -- who you're tanking
  local debuffs = {}
  if bc.hitRed > 0 then debuffs[#debuffs + 1] = U.fmt(bc.hitRed, 0) .. "% less chance to hit" end
  if bc.slow > 0 then debuffs[#debuffs + 1] = U.fmt(bc.slow, 0) .. "% slower swings" end
  if bc.apRed > 0 then debuffs[#debuffs + 1] = num(bc.apRed) .. " less attack power" end
  flow:panel("The Boss", function(f)
    local bits = {}
    if boss then bits[#bits + 1] = boss.raid end
    bits[#bits + 1] = "level " .. bc.level
    bits[#bits + 1] = ("swings every %s sec%s"):format(U.fmt(bc.swing, 2), bc.slow > 0 and (" (" .. U.fmt(bc.baseSwing, 1) .. " before slows)") or "")
    if bc.dualWield then bits[#bits + 1] = "two weapons" end
    if (p.opts.adds or 0) > 0 then bits[#bits + 1] = ("+%d add%s on you"):format(p.opts.adds, p.opts.adds > 1 and "s" or "") end
    local inner = K.flow(f.owner, f.parent, f.x, f.y, f.width - 96)
    inner:text(boss and boss.n or "Any level 73 boss", { font = "GameFontNormal", gap = 1 })
    inner:text(table.concat(bits, " - "), { font = "GameFontHighlightSmall", gap = 1 })
    if #debuffs > 0 then inner:text("Debuffs: " .. table.concat(debuffs, ", "), { font = "GameFontHighlightSmall", color = K.GREEN, gap = 1 }) end
    local btn = K.get(f.owner, "button", f.parent)
    btn:SetText("Change")
    btn:SetWidth(86)
    btn:SetPoint("TOPRIGHT", f.parent, "TOPRIGHT", -f.x, -(f.y + 4))
    btn:SetScript("OnClick", function() T.pickBoss(p) end)
    f.y = max(inner.y, f.y + 30)
  end)

  -- crush cap
  local cdName = p.cls == "paladin" and "Holy Shield" or p.cls == "warrior" and "Shield Block" or "nothing for bears"
  flow:panel("Crush Cap", function(f)
    local list = {}
    for _, m in ipairs(modes) do
      local v = sheets[m].total
      local c = E.capFor(sheets[m], bc)
      local good = v >= c - 1e-9
      list[#list + 1] = { l = MODE_NAME[m], n = U.pct(v, 1), s = good and "Uncrushable" or (U.fmt(c - v) .. "% short"), ok = good,
        selected = m == mode, click = function() S.capMode = m T.commit() end }
    end
    cards(f, list)
    f:note(mode == "passive" and "Gear, talents, buffs and consumables only: what you have every second."
      or mode == "cooldown" and ("Adds " .. cdName .. " while it is up (switch it on or off in Buffs).")
      or "Adds the procs, potion and trinkets switched on in Buffs: what you have at your best moment.")
    local vb = K.get(f.owner, "verdict", f.parent)
    local big = bc.crush == 0 and (ok and "Unhittable" or "No crushing blows") or (ok and "Uncrushable" or "Crushable")
    local of
    if bc.crush == 0 then of = ("This boss is below level 73, so it can't land crushing blows. %s of %s%% fills the table."):format(U.pct(s.total), U.fmt(cap, 1))
    elseif ok then of = ("%s on the sheet, %s%% needed. Crushing blows are off the table."):format(U.pct(s.total), U.fmt(cap, 1))
    else of = ("%s on the sheet, %s%% needed. %s of the boss's swings crush."):format(U.pct(s.total), U.fmt(cap, 1), U.pct(t.crush)) end
    vb:SetPoint("TOPLEFT", f.parent, "TOPLEFT", f.x, -f.y)
    local h = K.setVerdict(vb, ok, big, nil, of, f.width)
    vb:SetScript("OnClick", nil)
    f.y = f.y + h + 8
    if cov and mode ~= "passive" and ok and cov.crushPct > 0.05 and bc.crush > 0 then
      f:text(("But %s runs out of charges against %s: over a fight about %s of the boss's swings still crush. See %s Charges below.")
        :format(cov.ability, boss and boss.n or "this many swings", U.pct(cov.crushPct, 1), cov.ability), { font = "GameFontHighlightSmall", color = K.RED })
    end
    -- the attack table bar
    local bar = K.get(f.owner, "bar", f.parent)
    bar:SetPoint("TOPLEFT", f.parent, "TOPLEFT", f.x, -f.y)
    bar:SetSize(f.width, 16)
    local x = 1
    for i, sl in ipairs(SLICES) do
      local part = bar.parts[i]
      local w = (f.width - 2) * t[sl[1]] / 100
      part:ClearAllPoints()
      if w > 0.5 then
        part:SetColorTexture(sl[3][1], sl[3][2], sl[3][3], 1)
        part:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -1)
        part:SetSize(w, 14)
        part:Show()
        x = x + w
      else
        part:Hide()
      end
    end
    f.y = f.y + 22
    -- the legend, three to a line
    local lw = floor(f.width / 3)
    for i, sl in ipairs(SLICES) do
      local l = K.get(f.owner, "label", f.parent)
      l.text:SetFontObject("GameFontHighlightSmall")
      l.text:SetText(("|TInterface\\Buttons\\WHITE8X8:10:10:0:0:8:8:0:8:0:8:%d:%d:%d|t %s %s%%"):format(sl[3][1] * 255, sl[3][2] * 255, sl[3][3] * 255, sl[2], U.fmt(t[sl[1]], 1)))
      l:SetSize(lw, 14)
      l:SetPoint("TOPLEFT", f.parent, "TOPLEFT", f.x + ((i - 1) % 3) * lw, -(f.y + floor((i - 1) / 3) * 15))
    end
    f.y = f.y + 3 * 15 + 4
    f:note(("One swing from a level %d boss. Your sheet shows numbers against a level 70; each of miss, dodge, parry and block is %s%% lower against this boss%s.")
      :format(bc.level, U.fmt(bc.deficit, 1), bc.hitRed > 0 and (", and debuffs add " .. U.fmt(bc.hitRed, 0) .. "% to its misses") or ""))
  end)

  -- what closes the gap
  if not ok then
    local rows = E.capValues(s, bc)
    flow:panel("What Closes The Gap", function(f)
      f:note(("You are %s%% short. Any one of these would close it on its own:"):format(U.fmt(cap - s.total)))
      f:kv(U.map(rows, function(r) return { r.label, ("%d  (%s%% each)"):format(r.needed, U.fmt(r.perPoint, 3)) } end))
      if p.cls == "druid" then f:gap(4) f:note("Bears can't block or parry, so the crush cap is out of reach: bears soak crushing blows with armor and health instead.") end
    end)
  end

  -- damage taken
  local dm = E.intake(s, bc, t)
  local hasDmg = dm.raw ~= nil
  flow:panel("Damage Taken", function(f)
    cards(f, {
      { l = "Armor cuts", n = U.pct(s.armorReduction, 1), s = num(s.armor) .. " armor" },
      { l = "Effective health", n = num(dm.effectiveHealth), s = "vs. physical hits" },
      { l = hasDmg and "Per second" or "Per swing", n = hasDmg and num(dm.perSecond) or U.pct(dm.perSwing / 100, 1), s = hasDmg and "average" or "of a raw hit" },
    })
    if hasDmg then
      f:kv({
        { "Boss hit before armor", num(dm.raw[1]) .. "-" .. num(dm.raw[2]) },
        { "Normal hit on you", num(dm.perHit) },
        { "Blocked hit", s.canBlock and (num(dm.blockedHit) .. " (block value " .. s.blockValue .. ")") or "-" },
        { "Crushing blow", t.crush > 0 and num(dm.crushHit) or (num(dm.crushHit) .. " (off the table)"), t.crush > 0 and K.RED or nil },
        { "Critical hit", t.crit > 0 and num(dm.critHit) or (num(dm.critHit) .. " (off the table)"), t.crit > 0 and K.RED or nil },
        { "Average per swing", num(dm.perSwing) },
        { "Normal hits to kill you", tostring(dm.hitsToKill) },
        { "Crushes to kill you", dm.crushHit > 0 and tostring(math.ceil(s.health / dm.crushHit)) or "-" },
      })
    else
      f:note("Pick a boss in Buffs > The Fight to see how hard it hits you.")
    end
    local bits = {}
    if hasDmg then bits[#bits + 1] = "Boss hit sizes come from the cmangos TBC server data; attack power debuffs take 1 damage per 14 attack power per second of swing time." end
    if s.dmgTakenMult < 1 then bits[#bits + 1] = ("You take %s less damage from stances and talents."):format(U.pct((1 - s.dmgTakenMult) * 100, 0)) end
    if s.flatReduction > 0 then bits[#bits + 1] = ("Blessing of Sanctuary takes %d off every hit."):format(s.flatReduction) end
    bits[#bits + 1] = "Averaged over the attack table above."
    f:gap(4)
    f:note(table.concat(bits, " "))
  end)

  -- crit cap
  local cc = E.critCap(s, bc)
  flow:panel("Crit Cap", function(f)
    cards(f, {
      { l = "Defense", n = tostring(s.defenseFloor), s = cc.defSkillNeeded .. " alone" },
      { l = "Crit cut", n = U.pct(cc.reduction), s = U.fmt(cc.needed, 1) .. "% needed" },
      { l = "Status", n = cc.ok and "|cff1eff00Yes|r" or "|cffff5a4aNo|r", s = cc.ok and "Uncrittable" or "Crittable", ok = cc.ok },
    })
    local text
    if cc.ok then text = "Crits are off the table."
    elseif cc.rounding then text = ("You are right on the line: with fractional defense you reach %s%%, but the game counts whole defense points. One more point of defense (%d rating) makes it certain."):format(U.fmt(cc.needed, 1), math.ceil(E.R.defense))
    else text = ("Short by %d defense rating, or %d resilience rating."):format(cc.defRatingShort, cc.resShort) .. (p.cls == "druid" and " Survival of the Fittest counts 1% per rank." or "") end
    f:note(text)
    f:note(("Each point of defense above 350 removes 0.04%% crit chance; resilience works too (%s rating per 1%%)."):format(U.fmt(E.R.res, 1)))
  end)

  -- block charges
  if cov then
    flow:panel(cov.ability .. " Charges", function(f)
      f:kv({
        { "Charges / duration", ("%d / %d sec"):format(cov.charges, cov.duration) },
        { "Swings on you per use", U.fmt(cov.hitsPerCast, 1) },
        { "Charges used per use", U.fmt(cov.blocksPerCast, 1) },
        { "Boss swings that crush", U.pct(cov.crushPct), cov.crushPct > 0.05 and K.RED or K.GREEN },
        { "Without it", U.pct(cov.crushPctWithout) },
        { "Boss swings that crit", U.pct(cov.critPct) },
      })
      f:gap(4)
      f:note(cov.note)
      f:note(("An hour of %s swinging every %s sec%s%s, with %s pressed every time it is ready."):format(boss and boss.n or "a boss", U.fmt(cov.swing, 2),
        bc.dualWield and " with two weapons" or "", (p.opts.adds or 0) > 0 and (" and " .. p.opts.adds .. " add" .. (p.opts.adds > 1 and "s" or "")) or "", cov.ability))
    end)
  end

  -- Shear
  local sh = E.shear(s, bc)
  flow:panel("Illidan's Shear", function(f)
    f:kv({ { "Dodge + parry + block", ("%s / %s%%"):format(U.pct(sh.value), U.fmt(sh.cap, 1)), sh.ok and K.GREEN or K.RED, K.TEXT } })
    f:gap(3)
    f:note(sh.ok and "Shear can always be avoided or blocked." or ("Shear can't miss, so only dodge, parry and block count: %s%% short."):format(U.fmt(sh.short)))
  end)

  -- breakdown
  flow:panel("Where It Comes From", function(f)
    local function part(k, name, total, show, unit)
      if not show then return end
      f:kv({ { name, unit == "" and num(total) or U.pct(total) } })
      local lines = {}
      for _, b in ipairs(s.parts[k] or {}) do
        lines[#lines + 1] = { b.label, (b.value >= 0 and "+" or "") .. (unit == "" and num(b.value) or U.fmt(b.value)), nil, K.SUB }
      end
      f:kv(lines, { small = true, indent = 10 })
      f:gap(5)
    end
    part("miss", "Miss", s.miss, true)
    part("dodge", "Dodge", s.dodge, true)
    part("parry", "Parry", s.parry, s.canParry)
    part("block", "Block", s.block, s.canBlock)
    part("crit", "Crit reduction", s.critReduction, true)
    part("armor", "Armor", s.armor, true, "")
    part("bv", "Block value", s.blockValue, s.canBlock, "")
    f:kv({
      { "Defense skill", ("%s (%s rating)"):format(U.fmt(s.defenseSkill, 1), num(s.defRating)) },
      { "Health", num(s.health) },
      #s.usesOn > 0 and { "Trinkets on", table.concat(s.usesOn, ", ") } or false,
    })
  end)

  flow:panel("How It Works", function(f)
    local function sec(title, text)
      f:text(title, { font = "GameFontNormal", gap = 2 })
      f:text(text, { font = "GameFontHighlightSmall", gap = 8 })
    end
    sec("The attack table", "Every boss swing is one roll of a 100-sided die, read in order: miss, dodge, parry, block, crit, crushing blow, then a normal hit. Whatever is left after the earlier slices goes to the later ones. A level 73 boss has 15 more weapon skill than your 350 defense, which takes 0.6% off each of miss, dodge, parry and block. Crushing blows (150% damage) take a flat 15%. Push miss + dodge + parry + block to 100% against the boss (102.4% on your sheet) and there is no room left for crushes. \"Chance to hit\" debuffs like Scorpid Sting lower that target.")
    sec("Crits", "A level 73 boss crits 5.6% of the time. Each point of defense skill above 350 removes 0.04%, so 490 defense (415 for a druid with 3/3 Survival of the Fittest) makes you uncrittable. Resilience counts too.")
    sec("Damage", "Armor cuts physical damage by armor / (armor + 467.5 x boss level - 22,167.5), up to 75%. Blocks take your block value off a hit, Blessing of Sanctuary takes 80 off every hit, and Defensive Stance and Improved Righteous Fury cut what is left. Crushing blows do 150%, crits 200%.")
    sec("Block charges", "Holy Shield and Shield Block only last for a few blocks. If the boss (or adds) use them up before they run out, the rest of their duration gives no extra block, and those swings can crush.")
    sec("Stats in the app", "Ratings at level 70: Defense Rating, Dodge Rating, Parry Rating and Block Rating are 2.37, 18.9, 23.7 and 7.88 per point or percent. Agility per 1% dodge: warrior 30, paladin 25, druid 14.7. Block value follows the game server: (shield and gear + Strength / 20 - 1) x talents.")
    sec("Checked against", "The engine is the TBCrushCalc app's, line for line, and is tested against it on hundreds of characters. The app's engine is tested against the wowsims/tbc reference tanks (feral druid, protection warrior and paladin: strength, agility, stamina, intellect, health, armor, defense, dodge, parry, block, block value and attack power all match) and the in-game naked character values. Block value and the boss data follow the cmangos TBC server.")
  end)
end
