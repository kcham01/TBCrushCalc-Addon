-- The Buffs screen: your own stances and cooldowns, consumables (drop-down lists with every TBC flask,
-- elixir, food, scroll and potion), raid buffs, boss debuffs and world buffs as icon grids, and the fight:
-- which boss you're tanking (its swing speed, hit size and abilities) and extra attackers (the app's ui/buffs.ts).
local _, T = ...
local U, E, K = T.U, T.E, T.K

local floor, max = math.floor, math.max

local WHO_ORDER = { "Paladin", "Druid", "Priest", "Warrior", "Shaman", "Warlock", "Hunter", "Mage", "Draenei", "Leatherworker", "Jewelcrafter" }
local function whoRank(w) for i, x in ipairs(WHO_ORDER) do if x == w then return i end end return 99 end

function T.buffsView(flow, p)
  T.abilitiesFrame(flow, p)
  T.consumablesFrame(flow, p)
  T.gridFrame(flow, p, "Raid Buffs", T.RAID_BUFFS, "Click a buff to switch it on, click again for the talented (improved) version. Right-click a buff for details.")
  T.gridFrame(flow, p, "Boss Debuffs", T.DEBUFFS, "Debuffs on the boss: less chance to hit you, slower swings, less attack power. They change the Caps and damage numbers.")
  T.gridFrame(flow, p, "World Buffs", T.WORLD_BUFFS, "TBC Classic and Anniversary realms remove world buffs when a raid boss encounter starts, so these only count for dungeons, trash and the open world.")
  T.fightFrame(flow, p)
end

---------------------------------------------------------------------- icon grids
--- lays tiles out in rows; tiles = { { ic, name, state (0 off, 1 on, 2 improved), hasImp, locked, auto, tap, detail, tip } }
local function grid(f, tiles)
  local cols = floor((f.width + 2) / 68)
  local cw = f.width / cols
  for i, t in ipairs(tiles) do
    local b = K.get(f.owner, "tile", f.parent)
    local col, row = (i - 1) % cols, floor((i - 1) / cols)
    b:SetPoint("TOPLEFT", f.parent, "TOPLEFT", f.x + floor(col * cw + (cw - 66) / 2), -(f.y + row * 70))
    b.icon:SetTexture(T.icon(t.ic))
    b.name:SetText(t.name)
    if t.state == 2 then
      b.ring:SetColorTexture(0.12, 1, 0, 1)
      b.name:SetTextColor(0.12, 1, 0)
      b.badge:Show() b.badge:SetColorTexture(0.12, 1, 0, 1) b.badgeText:SetText("|cff000000+|r")
    elseif t.state == 1 then
      b.ring:SetColorTexture(1, 0.82, 0, 1)
      b.name:SetTextColor(1, 1, 1)
      if t.hasImp then b.badge:Show() b.badge:SetColorTexture(0.3, 0.27, 0.2, 1) b.badgeText:SetText("+") end
    else
      b.ring:SetColorTexture(0.23, 0.18, 0.12, 1)
      b.name:SetTextColor(0.55, 0.51, 0.45)
      b.icon:SetDesaturated(true)
      b.icon:SetVertexColor(0.6, 0.6, 0.6)
    end
    if t.locked then b.icon:SetDesaturated(true) b.icon:SetVertexColor(0.35, 0.35, 0.35) end
    if t.auto then b.ring:SetColorTexture(0.48, 0.42, 0.27, 1) b.icon:SetDesaturated(false) b.icon:SetVertexColor(1, 1, 1) end
    b:SetScript("OnClick", function(_, button) if button == "RightButton" then t.detail() else t.tap() end end)
    K.tooltipOn(b, function(tt)
      tt:SetText(t.name, 1, 0.82, 0)
      if t.who then tt:AddLine(t.who, 0.75, 0.75, 0.75) end
      tt:AddLine(t.text, 1, 1, 1, true)
      tt:AddLine(t.hasImp and "Click: off / on / improved. Right-click: details." or "Click to switch. Right-click: details.", 0.5, 0.5, 0.5, true)
    end)
  end
  f.y = f.y + math.ceil(#tiles / cols) * 70 + 4
end

local function detail(ic, name, who, text, state, imp, set)
  T.openSheet(name, function(f, h)
    local ib = K.get(f.owner, "talent", f.parent)
    ib:SetPoint("TOPLEFT", f.parent, "TOPLEFT", f.x, -f.y)
    ib:SetSize(44, 44)
    ib.icon:SetTexture(T.icon(ic))
    ib.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    ib:SetBackdropBorderColor(0.48, 0.42, 0.32, 1)
    ib:SetScript("OnClick", nil)
    local inner = K.flow(f.owner, f.parent, f.x + 54, f.y, f.width - 54)
    inner:text(name, { font = "GameFontNormal", gap = 1 })
    inner:text(who, { font = "GameFontHighlightSmall", color = K.SUB, gap = 4 })
    inner:text(text)
    f.y = math.max(f.y + 48, inner.y) + 6
    if set then
      local opts = { { 0, "Off" }, { 1, "On" } }
      if imp then opts[#opts + 1] = { 2, imp } end
      local list = {}
      for _, o in ipairs(opts) do
        list[#list + 1] = { label = o[2], on = state == o[1], width = floor((f.width - 4 * #opts) / #opts), click = function() h.close() set(o[1]) end }
      end
      f:chips(list)
    end
    f:buttons({ { label = "Search Wowhead", click = function() T.showUrl(name, T.wowheadSearchUrl(name)) end } }, "left")
  end)
end

local function setBuff(p, b, v)
  if v == 0 then p.buffs[b.id] = nil return end
  if b.excl then
    local replaced = {}
    for _, o in ipairs(T.ALL_BUFFS) do
      if o.id ~= b.id and o.excl == b.excl and E.on(p.buffs[o.id]) then p.buffs[o.id] = nil replaced[#replaced + 1] = o.name end
    end
    if #replaced > 0 then T.toast("Replaces " .. table.concat(replaced, ", ") .. " (they don't stack)") end
  end
  p.buffs[b.id] = (v == 2 and b.imp) and 2 or 1
end

function T.gridFrame(flow, p, title, list, noteText)
  local groups, keys = {}, {}
  for _, b in ipairs(list) do
    if not groups[b.who] then groups[b.who] = {} keys[#keys + 1] = b.who end
    table.insert(groups[b.who], b)
  end
  U.sort(keys, function(a, b) return whoRank(a) - whoRank(b) end)
  local ownLotp = p.cls == "druid" and E.talentRank(p, "leaderOfThePack") > 0 and E.on(p.abil.bear)
  local count = 0
  for _, b in ipairs(list) do if E.on(p.buffs[b.id]) then count = count + 1 end end
  flow:panel(title .. (count > 0 and (" (" .. count .. ")") or ""), function(f)
    f:note(noteText)
    local byWho = list == T.WORLD_BUFFS and { { "", list } } or U.map(keys, function(k) return { k, groups[k] } end)
    for _, g in ipairs(byWho) do
      if g[1] ~= "" then f:text(g[1]:upper(), { font = "GameFontNormalSmall", color = K.GOLD, gap = 3 }) end
      local tiles = {}
      for _, b in ipairs(g[2]) do
        local state = tonumber(p.buffs[b.id]) or 0
        local nextState = state == 0 and 1 or ((state == 1 and b.imp) and 2 or 0)
        tiles[#tiles + 1] = {
          ic = b.icon, name = b.name, state = state, hasImp = b.imp ~= nil, who = b.who .. (b.imp and (" - improved: " .. b.imp.name) or ""), text = b.text,
          auto = b.id == "lotp" and ownLotp and state == 0,
          tap = function() setBuff(p, b, nextState) T.commit() end,
          detail = function()
            detail(b.icon, b.name, b.who .. (b.imp and (" - improved: " .. b.imp.name) or ""), b.text, state, b.imp and "Improved" or false,
              function(v) setBuff(p, b, v) T.commit() end)
          end,
        }
      end
      grid(f, tiles)
    end
    if list == T.RAID_BUFFS and ownLotp then f:note("You have Leader of the Pack yourself: it counts in bear form without switching it on here.") end
  end)
end

---------------------------------------------------------------------- your abilities
function T.abilitiesFrame(flow, p)
  flow:panel("Your Abilities", function(f)
    local tiles = {}
    for _, a in ipairs(T.ABILITIES[p.cls]) do
      local needs = (a.talent and E.talentRank(p, a.talent) <= 0) and ("Needs the " .. a.name .. " talent") or nil
      local on = E.on(p.abil[a.id]) and not needs
      local text = a.text .. (a.mode == "always" and "" or a.mode == "cooldown" and " (cooldown)" or " (proc)")
      tiles[#tiles + 1] = {
        ic = a.icon, name = a.name, state = on and 1 or 0, locked = needs ~= nil, text = needs or text, who = "Your ability",
        tap = function() if needs then T.toast(needs) return end p.abil[a.id] = not E.on(p.abil[a.id]) T.commit() end,
        detail = function() detail(a.icon, a.name, needs or "Your ability", text, on and 1 or 0, false, (not needs) and function(v) p.abil[a.id] = v ~= 0 T.commit() end or nil) end,
      }
    end
    for _, s in ipairs({ "trinket1", "trinket2" }) do
      local it = p.gear[s] and T.ITEM_BY_ID[p.gear[s].id]
      if it and it.fx and #it.fx > 0 then
        local on = E.on(p.opts.uses[tostring(it.id)])
        local e = it.fx[1]
        local what = table.concat(U.map(it.fx, function(x) return ("+%d %s"):format(x.amount, T.STAT_NAMES[x.stat] or x.stat) end), ", ")
        local cd = e.cd and (", " .. (e.cd >= 60 and (U.fmt(e.cd / 60, 0) .. " min") or (e.cd .. " sec")) .. " cooldown") or ""
        local text = ("%s: %s%s%s%s. Counted in the \"procs\" view."):format(e.kind == "use" and "Use" or "Proc", what, e.dur and (" for " .. e.dur .. " sec") or "", cd, e.note and (" (" .. e.note .. ")") or "")
        tiles[#tiles + 1] = {
          ic = it.ic, name = it.n, state = on and 1 or 0, text = text, who = "Trinket",
          tap = function() p.opts.uses[tostring(it.id)] = not on T.commit() end,
          detail = function() detail(it.ic, it.n, "Trinket", text, on and 1 or 0, false, function(v) p.opts.uses[tostring(it.id)] = v ~= 0 T.commit() end) end,
        }
      end
    end
    grid(f, tiles)
    f:note('Stances count all the time. Cooldowns count in the "cooldown" and "procs" views on the Caps screen; procs and trinkets only in "procs".')
  end)
end

---------------------------------------------------------------------- consumables
local CAT_TITLE = { flask = "Flask", battle = "Battle Elixir", guardian = "Guardian Elixir", food = "Food", potion = "Potion" }

local function consRows(list)
  return U.map(list, function(c)
    local bits = {}
    if c.where then bits[#bits + 1] = c.where end
    if c.rl and c.rl > 1 then bits[#bits + 1] = "Requires level " .. c.rl end
    return {
      key = c.id, name = c.n, ic = c.ic, color = T.QUALITY_COLOR[c.q + 1] or "#ffffff",
      sub = T.statText(c.st) ~= "" and T.statText(c.st) or c.tx, sub2 = #bits > 0 and table.concat(bits, " - ") or nil,
      group = c.c == "flask" and (c.where and (c.where:find("Unstable") and "Unstable flasks" or "Shattrath flasks") or "Flasks") or nil,
      search = c.tx, tip = T.gemTip(c.id),
      info = function(f)
        f:text(c.n, { font = "GameFontNormalLarge", color = { U.hex(T.QUALITY_COLOR[c.q + 1] or "#ffffff") } })
        f:text("Use: " .. c.tx, { color = K.GREEN })
        if c.where then f:text(c.where, { color = K.GOLD }) end
        f:buttons({ { label = "Wowhead link", click = function() T.showUrl(c.n, T.wowheadItemUrl(c.id)) end } }, "left")
      end,
    }
  end)
end

--- a rough "how useful is this to a tank" order for the lists: survival stats first, then the rest
local function tankValue(c)
  local s = c.st
  return (s.sta or 0) * 1.5 + (s.hp or 0) * 0.15 + (s.def or 0) * 2 + (s.armor or 0) * 0.08 + (s.agi or 0) * 1.2 + (s.dodge or 0) * 1.5
    + (s.block or 0) + (s.bv or 0) * 0.5 + (s.str or 0) * 0.5 + (s.hit or 0) + (s.exp or 0) + (s.ap or 0) * 0.2 + (s.res or 0)
end

function T.consumablesFrame(flow, p)
  local c = p.cons
  flow:panel("Consumables", function(f)
    local function row(cat, disabled)
      local id = c[cat]
      local sel = E.on(id) and T.CONSUMABLE_BY_ID[id]
      local pool = U.filter(T.CONSUMABLES, function(x) return x.c == cat end)
      U.sort(pool, function(a, b)
        if cat == "flask" then local d = (a.where and 1 or 0) - (b.where and 1 or 0) if d ~= 0 then return d end end
        local d = tankValue(b) - tankValue(a)
        if d ~= 0 then return d end
        return U.cmp(a.n, b.n)
      end)
      T.selectRow(f, CAT_TITLE[cat], sel and { name = sel.n, ic = sel.ic, color = T.QUALITY_COLOR[sel.q + 1], sub = T.statText(sel.st) ~= "" and T.statText(sel.st) or sel.tx } or nil, function()
        T.pickFrom({
          title = CAT_TITLE[cat], rows = consRows(pool), selected = sel and id or nil, none = "No " .. CAT_TITLE[cat]:lower(),
          placeholder = ("Search %d %s"):format(#pool, cat == "food" and "foods" or (CAT_TITLE[cat]:lower() .. "s")),
          note = cat == "potion" and 'Potions last seconds, not hours: they only count in the "procs" view.' or nil,
          onPick = function(k)
            c[cat] = k
            if cat == "flask" and k and (c.battle or c.guardian) then c.battle = nil c.guardian = nil T.toast("Elixirs removed") end
            T.commit()
          end,
        })
      end, disabled)
    end
    row("flask")
    row("battle", E.on(c.flask) and "Flask active" or nil)
    row("guardian", E.on(c.flask) and "Flask active" or nil)
    row("food")
    -- scrolls: one of each kind (scrolls of different kinds stack)
    local groups, seen = {}, {}
    for _, x in ipairs(T.CONSUMABLES) do if x.c == "scroll" and not seen[x.g] then seen[x.g] = true groups[#groups + 1] = x.g end end
    table.sort(groups)
    for _, g in ipairs(groups) do
      local pool = U.filter(T.CONSUMABLES, function(x) return x.c == "scroll" and x.g == g end)
      U.sort(pool, function(a, b) return b.rl - a.rl end)
      local selId = U.find(c.scrolls or {}, function(id) local x = T.CONSUMABLE_BY_ID[id] return x and x.g == g end)
      local sel = selId and T.CONSUMABLE_BY_ID[selId]
      T.selectRow(f, g:gsub("Scroll of ", "Scroll: "), sel and { name = sel.n, ic = sel.ic, color = T.QUALITY_COLOR[sel.q + 1], sub = T.statText(sel.st) } or nil, function()
        T.pickFrom({
          title = g, rows = consRows(pool), selected = selId, none = "None",
          onPick = function(k)
            local rest = U.filter(c.scrolls or {}, function(id) local x = T.CONSUMABLE_BY_ID[id] return not (x and x.g == g) end)
            if k then rest[#rest + 1] = k end
            c.scrolls = #rest > 0 and rest or nil
            T.commit()
          end,
        })
      end)
    end
    row("potion")
    f:note("Scrolls of different kinds stack.")
  end)
end

---------------------------------------------------------------------- the fight
local function hitText(b)
  return b.dmg and ("%s-%s per hit"):format(U.commas(b.dmg[1]), U.commas(b.dmg[2])) or "no melee to speak of"
end

function T.bossCard(f, b)
  f:text(b.n, { font = "GameFontNormalLarge" , gap = 1 })
  f:text(("%s - Level %d (boss)"):format(b.raid, b.lvl), { font = "GameFontHighlightSmall", color = K.SUB, gap = 4 })
  f:kv({
    { "Swing", U.fmt(b.swing, 1) .. " sec" .. (E.on(b.dw) and ", two weapons" or "") },
    { "Melee hit (before armor)", b.dmg and (U.commas(b.dmg[1]) .. "-" .. U.commas(b.dmg[2])) or "-" },
  })
  f:gap(4)
  f:text(b.note, { font = "GameFontHighlightSmall" })
  if #b.ab > 0 then
    f:text("Abilities", { font = "GameFontNormal", gap = 2 })
    for _, a in ipairs(b.ab) do
      local r = K.get(f.owner, "row", f.parent)
      r.name:SetPoint("TOPLEFT", 6, -3)
      r.name:SetWidth(f.width - 12)
      r.name:SetText("|cff8fd0ff" .. a.n .. "|r" .. (a.d and ("|cffbdb4a2 - " .. a.d .. "|r") or ""))
      r.icon:Hide() r.border:Hide()
      r:SetBackdropColor(0, 0, 0, 0) r:SetBackdropBorderColor(0, 0, 0, 0)
      r:SetScript("OnClick", function() T.showUrl(a.n, a.id and T.wowheadSpellUrl(a.id) or T.wowheadSearchUrl(a.n)) end)
      if a.id then K.tooltipOn(r, function(tt) tt:SetSpellByID(a.id) end) end
      f:place(r, 18, 6, f.width - 6)
    end
  end
  f:note("Hit sizes from the cmangos TBC server data (base damage and attack power for the boss's level).")
end

function T.bossRows()
  return U.map(T.BOSSES, function(b)
    return {
      key = b.id, name = b.n, group = b.raid,
      sub = ("Level %d - %s sec swing%s - %s"):format(b.lvl, U.fmt(b.swing, 1), E.on(b.dw) and " - two weapons" or "", hitText(b)),
      sub2 = b.note, search = table.concat(U.map(b.ab, function(a) return a.n end), " "),
      info = function(f) T.bossCard(f, b) end,
    }
  end)
end

function T.pickBoss(p)
  T.pickFrom({
    title = "Boss", rows = T.bossRows(), selected = E.on(p.opts.boss) and p.opts.boss or nil, none = "Any level 73 boss (set the swing speed yourself)",
    placeholder = ("Search %d bosses, raids or abilities"):format(#T.BOSSES),
    onPick = function(k) p.opts.boss = k T.commit() end,
  })
end

function T.fightFrame(flow, p)
  local b = E.on(p.opts.boss) and T.BOSS_BY_ID[p.opts.boss]
  flow:panel("The Fight", function(f)
    T.selectRow(f, "Boss", b and { name = b.n, ic = "inv_misc_bone_humanskull_01", sub = ("%s - %s sec%s"):format(b.raid, U.fmt(b.swing, 1), E.on(b.dw) and " - two weapons" or "") }
      or { name = "Any level 73 boss", ic = "inv_misc_head_dragon_01" }, function() T.pickBoss(p) end)
    if b then
      f:gap(4)
      T.bossCard(f, b)
    else
      local swing = p.opts.swing or 2
      local label = K.get(f.owner, "kv", f.parent)
      label.k:SetText("Swing speed") label.k:SetTextColor(K.rgb(K.TEXT))
      label.v:SetText(U.fmt(swing, 1) .. " sec") label.v:SetTextColor(1, 0.82, 0)
      label:SetWidth(f.width)
      f:gap(6)
      f:place(label, 18)
      local s = K.get(f.owner, "slider", f.parent)
      s:SetMinMaxValues(1, 3.5)
      s:SetValueStep(0.1)
      s:SetValue(swing)
      s:SetScript("OnValueChanged", function(_, v)
        v = floor(v * 10 + 0.5) / 10
        label.v:SetText(U.fmt(v, 1) .. " sec")
        s.pending = v
      end)
      s:SetScript("OnMouseUp", function() if s.pending then p.opts.swing = s.pending s.pending = nil T.commit() end end)
      f:place(s, 17, 4, f.width - 8)
      f:gap(4)
      f:note("Pick a boss above for its real swing speed, hit size and abilities. Most raid bosses swing every 2.0 seconds.")
    end
    local adds = p.opts.adds or 0
    local list = { { label = "Extra attackers on you:", plain = true } }
    for n = 0, 4 do list[#list + 1] = { label = tostring(n), on = adds == n, width = 26, click = function() p.opts.adds = n T.commit() end } end
    f:gap(4)
    f:chips(list)
    f:note("Adds hitting you use up Holy Shield and Shield Block charges too, which leaves more of the boss's swings uncovered (see Caps).")
  end)
end
