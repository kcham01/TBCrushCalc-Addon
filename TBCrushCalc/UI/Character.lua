-- The Character screen, laid out like the game's character pane: equipment slots down both sides, the
-- character in the middle, weapons along the bottom, and the stat panels underneath (the app's ui/character.ts).
local _, T = ...
local U, E, K = T.U, T.E, T.K
local S = T.S

local floor, max, min = math.floor, math.max, math.min

local LEFT = { "head", "neck", "shoulder", "back", "chest", "shirt", "tabard", "wrist" }
local RIGHT = { "hands", "waist", "legs", "feet", "finger1", "finger2", "trinket1", "trinket2" }
local BOTTOM = { "mainhand", "offhand", "ranged" }
local ARMOR_SLOTS = { head = 1, shoulder = 1, chest = 1, wrist = 1, hands = 1, waist = 1, legs = 1, feet = 1 }
local INV = {
  head = "HeadSlot", neck = "NeckSlot", shoulder = "ShoulderSlot", back = "BackSlot", chest = "ChestSlot", shirt = "ShirtSlot", tabard = "TabardSlot",
  wrist = "WristSlot", hands = "HandsSlot", waist = "WaistSlot", legs = "LegsSlot", feet = "FeetSlot", finger1 = "Finger0Slot", finger2 = "Finger1Slot",
  trinket1 = "Trinket0Slot", trinket2 = "Trinket1Slot", mainhand = "MainHandSlot", offhand = "SecondaryHandSlot", ranged = "RangedSlot",
}
T.INV_SLOT = INV
local function slotLabel(s) if s == "shirt" then return "Shirt" elseif s == "tabard" then return "Tabard" end return T.SLOT_BY_ID[s].label end
local TYPE_NAME = {
  cloth = "Cloth", leather = "Leather", mail = "Mail", plate = "Plate", shield = "Shield", offhand = "Held In Off-hand", axe = "Axe", mace = "Mace", sword = "Sword",
  dagger = "Dagger", fist = "Fist Weapon", polearm = "Polearm", staff = "Staff", bow = "Bow", gun = "Gun", crossbow = "Crossbow", thrown = "Thrown", libram = "Libram", idol = "Idol",
}
local SOCK_COLOR = { red = { 0.88, 0.19, 0.16 }, yellow = { 0.95, 0.82, 0.18 }, blue = { 0.2, 0.47, 0.88 }, meta = { 0.79, 0.79, 0.79 },
  orange = { 0.94, 0.54, 0.12 }, purple = { 0.61, 0.23, 0.82 }, green = { 0.24, 0.71, 0.23 }, prismatic = { 0.9, 0.9, 0.9 } }
T.SOCK_COLOR = SOCK_COLOR

local function emptyTexture(slot)
  local _, tex = GetInventorySlotInfo(INV[slot])
  return tex
end

---------------------------------------------------------------------- the screen
function T.characterView(flow, p)
  local sheet = E.computeSheet(p, T.mainMode(p))
  flow:panel("Character", function(f)
    local SL, GAP = 40, 4
    local colH = #LEFT * (SL + GAP) - GAP
    local function slotEl(s, x, y)
      local b = K.get(f.owner, "slot", f.parent)
      b:SetPoint("TOPLEFT", f.parent, "TOPLEFT", f.x + x, -(f.y + y))
      b:SetBackdropColor(0.05, 0.04, 0.03, 1)
      b:SetBackdropBorderColor(0.29, 0.23, 0.13, 1)
      if s == "shirt" or s == "tabard" then
        b.icon:SetTexture(emptyTexture(s))
        b.icon:SetAlpha(0.45)
        b:SetScript("OnClick", nil)
        K.tooltipOn(b, function(tt) tt:SetText(slotLabel(s) .. ": not used by the calculator") end)
        return
      end
      local g = p.gear[s]
      local it = g and T.ITEM_BY_ID[g.id]
      b:SetScript("OnClick", function() T.openSlot(s) end)
      if not it then
        b.icon:SetTexture(emptyTexture(s))
        K.tooltipOn(b, function(tt) tt:SetText(slotLabel(s)) tt:AddLine("Click to choose an item.", 1, 1, 1) end)
        return
      end
      b.icon:SetTexture(T.icon(it.ic))
      b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      local qc = { U.hex(T.QUALITY_COLOR[it.q + 1] or "#ffffff") }
      b:SetBackdropBorderColor(qc[1], qc[2], qc[3], 1)
      if it.q >= 2 then b.glow:Show() b.glow:SetVertexColor(qc[1], qc[2], qc[3], 0.7) end
      for i, c in ipairs(it.so or {}) do
        local gid = g.gems and g.gems[i]
        local gem = E.on(gid) and T.GEM_BY_ID[gid]
        local col = gem and SOCK_COLOR[gem.c] or { 0.13, 0.13, 0.13 }
        b.dots[i]:SetColorTexture(col[1], col[2], col[3], 1)
        b.dots[i]:Show()
      end
      if E.on(g.ench) then b.ench:Show() end
      K.tooltipOn(b, T.itemTip(g))
    end
    for i, s in ipairs(LEFT) do slotEl(s, 0, (i - 1) * (SL + GAP)) end
    for i, s in ipairs(RIGHT) do slotEl(s, f.width - SL, (i - 1) * (SL + GAP)) end

    -- the middle: resistances, portrait, verdict
    local midX, midW = SL + 8, f.width - 2 * SL - 16
    local mid = K.get(f.owner, "box", f.parent)
    mid:SetBackdrop(K.INSET)
    mid:SetBackdropColor(0, 0, 0, 0.45)
    mid:SetBackdropBorderColor(0.42, 0.33, 0.19, 1)
    mid:SetPoint("TOPLEFT", f.parent, "TOPLEFT", f.x + midX, -f.y)
    mid:SetSize(midW, colH)
    local mf = K.flow(f.owner, mid, 8, 8, midW - 16)
    -- resistances, as the game's character pane shows them
    local RES = { { "arcres", { 1, 1, 1 }, "Arcane" }, { "fireres", { 1, 0.4, 0.2 }, "Fire" }, { "natres", { 0.3, 1, 0.3 }, "Nature" }, { "frostres", { 0.4, 0.7, 1 }, "Frost" }, { "shadres", { 0.7, 0.4, 1 }, "Shadow" } }
    local rw = (mf.width - 4 * 4) / 5
    for i, r in ipairs(RES) do
      local c = K.get(f.owner, "card", mid)
      c:SetSize(rw, 22)
      c:SetPoint("TOPLEFT", mid, "TOPLEFT", 8 + (i - 1) * (rw + 4), -8)
      c.l:SetText("") c.s:SetText("")
      c.n:SetFontObject("GameFontHighlightSmall")
      c.n:ClearAllPoints() c.n:SetPoint("CENTER", 0, 0)
      c.n:SetText(tostring(floor(sheet.resist[r[1]] or 0)))
      c.n:SetTextColor(r[2][1], r[2][2], r[2][3])
      c:SetBackdropBorderColor(r[2][1] * 0.6, r[2][2] * 0.6, r[2][3] * 0.6, 1)
      c:SetScript("OnClick", nil)
      K.tooltipOn(c, function(tt) tt:SetText(r[3] .. " Resistance " .. floor(sheet.resist[r[1]] or 0)) end)
    end
    mf.y = 38
    mf:text(p.name, { font = "GameFontNormal", color = { U.hex(T.classOf(p).color) }, justify = "CENTER", gap = 0 })
    mf:text(T.describe(p), { font = "GameFontHighlightSmall", justify = "CENTER", gap = 4 })
    local v = E.verdict(p, T.mainMode(p))
    local cd0 = p.cls == "paladin" and (sheet.holyShieldOn and "with Holy Shield" or "no Holy Shield")
      or p.cls == "warrior" and (sheet.shieldBlockOn and "with Shield Block" or "no Shield Block") or "bear form"
    local vbox = K.get(f.owner, "verdict", mid)
    vbox:SetPoint("BOTTOMLEFT", mid, "BOTTOMLEFT", 6, 6)
    local vh = K.setVerdict(vbox, v.uncrushable, v.uncrushable and "Uncrushable" or "Crushable", U.pct(v.total),
      v.uncrushable and ("of %s%% - %s"):format(U.fmt(v.cap, 1), cd0) or ("%s%% short - %s"):format(U.fmt(v.short), cd0), midW - 12)
    vbox:SetScript("OnClick", function() T.go("caps") end)
    -- the character itself: your own character in 3D wearing this gear when the race is yours (the game only
    -- lets addons show the character you're playing), else the race portrait
    local modelTop, modelBottom = mf.y, colH - vh - 10
    if T.showModel(p, mid, modelTop, modelBottom, midW) then
      -- shown
    else
      local portrait = K.get(f.owner, "portrait", mid)
      portrait:SetPoint("TOP", mid, "TOP", 0, -(modelTop + math.max(0, (modelBottom - modelTop - 68) / 2)))
      T.raceIcon(portrait.tex, p.race)
    end
    -- weapons along the bottom
    local by = colH + 8
    local bx = floor((f.width - (3 * SL + 2 * 6)) / 2)
    for i, s in ipairs(BOTTOM) do slotEl(s, bx + (i - 1) * (SL + 6), by) end
    f.y = f.y + by + SL + 10

    -- the stat panels
    local half = floor((f.width - 6) / 2)
    T.statBox(f, sheet, "statL", 0, half)
    T.statBox(f, sheet, "statR", half + 6, half)
    f.y = f.y + 32 + 8 * 14 + 10
    f:gap(4)
    f:buttons({
      { label = "Auto-gear", click = function() T.openAutoGear() end },
      { label = "Unequip all", click = function() T.confirmSheet("Unequip everything", ("Take off every item %s is wearing?"):format(p.name), "Unequip", function() p.gear = {} T.commit() end) end },
    }, "center")
  end)

  local notes = T.gearNotes(p, sheet)
  if #notes > 0 then
    flow:panel("Gear Notes", function(f)
      for _, n in ipairs(notes) do f:text(n[1], { font = "GameFontHighlightSmall", color = n[2], gap = 3 }) end
    end)
  end
end

---------------------------------------------------------------------- the 3D character
local RACE_TOKEN = { Human = "human", Dwarf = "dwarf", NightElf = "nightelf", Gnome = "gnome", Draenei = "draenei", Orc = "orc",
  Scourge = "undead", Tauren = "tauren", Troll = "troll", BloodElf = "bloodelf" }
local model

local function makeModel()
  local m = CreateFrame("DressUpModel", "TBCrushCalcModel", UIParent)
  m:EnableMouse(true)
  m:EnableMouseWheel(true)
  m.rotation, m.zoom = 0.6, 0
  m:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
      self.dragX = GetCursorPosition()
      self:SetScript("OnUpdate", function(me)
        local x = GetCursorPosition()
        me.rotation = me.rotation + (x - me.dragX) * 0.012
        me.dragX = x
        me:SetRotation(me.rotation)
      end)
    end
  end)
  m:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
  m:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
  m:SetScript("OnMouseWheel", function(self, delta)
    self.zoom = math.max(0, math.min(0.9, self.zoom + delta * 0.1))
    self:SetPortraitZoom(self.zoom)
  end)
  m:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Your character in this gear")
    GameTooltip:AddLine("Drag to turn, scroll to zoom.", 1, 1, 1)
    GameTooltip:Show()
  end)
  m:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return m
end

--- dresses the model in the character's gear inside `parent` between two heights; false when it can't be shown
function T.showModel(p, parent, top, bottom, width)
  local _, raceToken = UnitRace("player")
  if RACE_TOKEN[raceToken] ~= p.race or bottom - top < 80 then
    if model then model:Hide() end
    return false
  end
  model = model or makeModel()
  model:SetParent(parent)
  model:SetFrameLevel(parent:GetFrameLevel() + 2)
  model:ClearAllPoints()
  model:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -top)
  model:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", width - 4, -bottom)
  model:Show()
  model:SetUnit("player")
  model:Undress()
  for _, s in ipairs(T.SLOTS) do
    local g = p.gear[s.id]
    if g then model:TryOn("item:" .. g.id) end
  end
  model:SetRotation(model.rotation)
  model:SetPortraitZoom(model.zoom)
  T.model = model
  return true
end

--- models aren't clipped by scroll areas: hide it while it's partly scrolled out of view
function T.clipModel(view)
  if not model or not model:IsShown() or not model:GetTop() then return end
  local inside = model:GetTop() <= view:GetTop() + 1 and model:GetBottom() >= view:GetBottom() - 1
  model:SetAlpha(inside and 1 or 0)
  model:EnableMouse(inside)
end

function T.hideModel() if model then model:Hide() end end

---------------------------------------------------------------------- stat panels
local VIEW_NAME = { base = "Base Stats", def = "Defenses", melee = "Melee", ranged = "Ranged", spell = "Spell" }
function T.statViews(cls)
  return cls == "warrior" and { "base", "def", "melee", "ranged" } or { "base", "def", "melee", "spell" }
end

function T.statBox(f, s, which, x, w)
  local views = T.statViews(s.cls)
  local view = U.contains(views, S[which]) and S[which] or (which == "statL" and "base" or "def")
  local b = K.get(f.owner, "statbox", f.parent)
  b:SetPoint("TOPLEFT", f.parent, "TOPLEFT", f.x + x, -f.y)
  b:SetSize(w, 32 + 8 * 14 + 4)
  b.drop.text:SetText(VIEW_NAME[view])
  b.drop:SetScript("OnClick", function(btn)
    T.menu(btn, views, function(v) return VIEW_NAME[v] end, view, function(v) S[which] = v T.commit() end)
  end)
  local n = function(x2) return tostring(floor(x2 + 1e-9)) end
  local pct = U.pct
  local lines = {}
  local function line(k, v, up) lines[#lines + 1] = { k, v, up } end
  if view == "base" then
    line("Strength", n(s.str)) line("Agility", n(s.agi)) line("Stamina", n(s.sta)) line("Intellect", n(s.int)) line("Spirit", n(s.spi)) line("Armor", n(s.armor), true)
  elseif view == "def" then
    line("Health", U.commas(s.health)) line("Armor", n(s.armor), true) line("Defense", tostring(s.defenseFloor), s.defenseFloor > 350)
    line("Dodge", pct(s.dodge)) line("Parry", s.canParry and pct(s.parry) or "-") line("Block", s.canBlock and pct(s.block) or "-")
    line("Block Value", s.canBlock and tostring(s.blockValue) or "-") line("Resilience", n(s.resilience))
  elseif view == "melee" then
    line("Attack Power", n(s.ap)) line("Hit", pct(s.hit)) line("Crit", pct(s.crit)) line("Expertise", tostring(s.expertise))
    line("Haste", pct(s.haste)) line("Damage cut", pct(s.armorReduction))
  elseif view == "ranged" then
    if s.hasRanged then
      line("Weapon", s.rangedDmg and (n(s.rangedDmg[1]) .. "-" .. n(s.rangedDmg[2])) or "-") line("Speed", U.fmt(s.rangedSpeed))
    else
      line("Ranged weapon", "none")
    end
    line("Attack Power", n(s.rap)) line("Hit", pct(s.rhit)) line("Crit", pct(s.rcrit))
  elseif view == "spell" then
    line("Bonus Damage", n(s.sp)) line("Bonus Healing", n(s.heal)) line("Hit", pct(s.shit)) line("Crit", pct(s.scrit))
    line("Haste", pct(s.shaste)) line("Mana", n(s.mana)) line("Mana per 5 sec", n(s.mp5))
  end
  for i, l in ipairs(lines) do
    b.k[i]:SetText(l[1])
    b.v[i]:SetText(l[2])
    if l[3] then b.v[i]:SetTextColor(0.12, 1, 0) end
  end
end

--- a small drop-down menu under a button
local menuFrame
function T.menu(anchor, values, label, current, onPick)
  if not menuFrame then
    menuFrame = CreateFrame("Frame", "TBCrushCalcMenu", UIParent, "BackdropTemplate")
    menuFrame:SetBackdrop(K.PANEL)
    menuFrame:SetBackdropColor(0, 0, 0, 0.95)
    menuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    menuFrame:EnableMouse(true)
    menuFrame.items = {}
    tinsert(UISpecialFrames, "TBCrushCalcMenu")
  end
  for _, b in ipairs(menuFrame.items) do b:Hide() end
  menuFrame:ClearAllPoints()
  menuFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  menuFrame:SetWidth(anchor:GetWidth())
  for i, v in ipairs(values) do
    local b = menuFrame.items[i]
    if not b then
      b = CreateFrame("Button", nil, menuFrame)
      b:SetHeight(18)
      b.text = K.fs(b, "GameFontHighlightSmall")
      b.text:SetPoint("LEFT", 8, 0)
      b.text:SetJustifyV("MIDDLE")
      b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
      menuFrame.items[i] = b
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 18)
    b:SetPoint("RIGHT", -4, 0)
    b.text:SetText(label(v))
    if v == current then b.text:SetTextColor(1, 0.82, 0) else b.text:SetTextColor(1, 1, 1) end
    b:SetScript("OnClick", function() menuFrame:Hide() onPick(v) end)
    b:Show()
  end
  menuFrame:SetHeight(8 + #values * 18)
  menuFrame:Show()
end

---------------------------------------------------------------------- gear notes
function T.enchantable(it) return #T.enchantSlotsOf(it) > 0 end

function T.gearNotes(p, s)
  local out = {}
  local g = s.gear
  for _, b in ipairs(g.setBonuses) do out[#out + 1] = { ("%s (%d): %s"):format(b.set, b.count, b.text), K.GREEN } end
  if g.meta and not g.meta.active then out[#out + 1] = { "Meta gem inactive: " .. table.concat(g.meta.req or {}, "; "), K.RED } end
  for _, n in ipairs(g.uniqueClash) do out[#out + 1] = { n .. " is unique: you can only wear one.", K.RED } end
  local emptySockets, noEnchant = 0, {}
  for _, sl in ipairs(T.SLOTS) do
    local piece = p.gear[sl.id]
    local it = piece and T.ITEM_BY_ID[piece.id]
    if it then
      for i in ipairs(it.so or {}) do if not E.on(piece.gems and piece.gems[i]) then emptySockets = emptySockets + 1 end end
      if T.enchantable(it) and not E.on(piece.ench) and sl.item ~= "finger" then noEnchant[#noEnchant + 1] = sl.label end
    end
  end
  if emptySockets > 0 then out[#out + 1] = { ("%d empty socket%s."):format(emptySockets, emptySockets > 1 and "s" or ""), K.GOLD } end
  if #noEnchant > 0 then out[#out + 1] = { "Not enchanted: " .. table.concat(noEnchant, ", ") .. ".", K.GOLD } end
  if p.cls ~= "druid" and not s.canBlock then out[#out + 1] = { "No shield: you can't block, so you can't push crushing blows off the table.", K.RED } end
  if p.cls ~= "druid" and not g.weapon then out[#out + 1] = { "No weapon: you can't parry without one.", K.RED } end
  return out
end

---------------------------------------------------------------------- slot panel
function T.openSlot(slot)
  local p = T.cur()
  if not p.gear[slot] then T.openItemPicker(slot) return end
  T.openSheet(slotLabel(slot), function(f, h)
    local piece = p.gear[slot]
    local it = piece and T.ITEM_BY_ID[piece.id]
    if not it then C_Timer.After(0, h.close) return end
    T.inlineItemTip(f, piece, nil, h.redraw)
    for i, color in ipairs(it.so or {}) do
      local gem = E.on(piece.gems and piece.gems[i]) and T.GEM_BY_ID[piece.gems[i]]
      T.listRow(f, {
        ic = gem and gem.ic or "", icon = not gem and "Interface\\ItemSocketingFrame\\UI-EmptySocket-" .. (color == "meta" and "Meta" or U.ucfirst(color)) or nil,
        name = gem and gem.n or ("Empty %s Socket"):format(U.ucfirst(color)), color = gem and T.QUALITY_COLOR[gem.q + 1] or "#9d9d9d",
        sub = gem and (gem.tx or T.statText(gem.st)) or "Click to choose a gem",
        right = gem and (E.gemFits(color, gem.c) and "matches" or "no bonus") or nil,
        tip = gem and T.gemTip(gem.id) or nil,
        onClick = function() T.openGemPicker(slot, i, function() h.redraw(true) end) end,
      })
    end
    if T.enchantable(it) then
      local e = E.on(piece.ench) and T.ENCHANT_BY_ID[piece.ench]
      T.listRow(f, {
        ic = e and (e.ic or "inv_misc_note_01") or "inv_misc_note_01", name = e and e.n or "Not enchanted", color = e and "#1eff00" or "#9d9d9d",
        sub = e and T.enchantText(e) or "Click to choose an enchant",
        onClick = function() T.openEnchantPicker(slot, function() h.redraw(true) end) end,
      })
    end
    f:gap(6)
    f:buttons({
      { label = "Remove", click = function() p.gear[slot] = nil T.commit() h.close() end },
      { label = "Change item", click = function() T.openItemPicker(slot, function() h.redraw(true) end) end },
      { label = "Wowhead", click = function() T.showUrl(it.n, T.wowheadItemUrl(it.id)) end },
    })
  end)
end

---------------------------------------------------------------------- item picker
--- roughly how much avoidance one item adds for this character (before sockets and enchants)
function T.itemAvoidance(p, s, it)
  local st = it.st
  local R = E.R
  local comps = 2 + (s.canParry and 1 or 0) + (s.canBlock and 1 or 0)
  local kings = E.on(p.buffs.kings) and 1.1 or 1
  return (st.def or 0) / R.defense * 0.04 * comps + (st.dodge or 0) / R.dodge + (st.agi or 0) * kings / E.AGI_PER_DODGE[p.cls]
    + (s.canParry and (st.parry or 0) / R.parry or 0) + ((s.canBlock or it.wt == "shield") and (st.block or 0) / R.block or 0)
end

function T.openItemPicker(slot, after)
  local p = T.cur()
  local s = E.computeSheet(p, "passive")
  local state = { q = "", sort = "avoid", limit = 80 }
  local isArmor = ARMOR_SLOTS[slot] ~= nil
  local pool = {}
  for _, it in ipairs(T.ITEMS) do if T.slotAccepts(slot, it) and T.canUse(p.cls, it, slot) then pool[#pool + 1] = it end end
  local avCache = {}
  local function av(it) local v = avCache[it] if not v then v = T.itemAvoidance(p, s, it) avCache[it] = v end return v end

  local sheet
  local function preview(it)
    T.openSheet("Equip?", function(f, h)
      T.inlineItemTip(f, { id = it.id }, nil, h.redraw)
      f:buttons({
        { label = "Back", click = function() h.close() end },
        { label = "Equip", click = function() if T.equip(p, slot, it) then h.close() sheet.close() if after then after() end end end },
      })
    end)
  end

  sheet = T.openSheet(slotLabel(slot), function(f, h)
    T.searchBox(f, state, "Search items or bosses", function() state.limit = 80 h.redraw() end)
    local function chip(label, on, fn) return { label = label, on = on, click = function() fn() state.limit = 80 T.save() h.redraw(true) end } end
    local c1 = {}
    for n = 1, 5 do c1[#c1 + 1] = chip(n == 5 and "All phases" or ("Up to P" .. n), S.phase == n, function() S.phase = n end) end
    if isArmor then c1[#c1 + 1] = chip((T.BEST_ARMOR[p.cls] == "plate" and "Plate" or "Leather") .. " only", S.armorOnly, function() S.armorOnly = not S.armorOnly end) end
    f:chips(c1, { gap = 4 })
    local c2 = { { label = "Level:", plain = true } }
    for _, lv in ipairs({ { 0, "Any" }, { 60, "60+" }, { 70, "70" } }) do c2[#c2 + 1] = chip(lv[2], S.minLevel == lv[1], function() S.minLevel = lv[1] end) end
    f:chips(c2, { gap = 4 })
    local c3 = { { label = "Sort:", plain = true } }
    for _, so in ipairs({ { "avoid", "Avoidance" }, { "sta", "Stamina" }, { "ilvl", "Item level" }, { "name", "Name" } }) do
      c3[#c3 + 1] = chip(so[2], state.sort == so[1], function() state.sort = so[1] end)
    end
    f:chips(c3)

    local words = {}
    for w in (state.q or ""):lower():gmatch("%S+") do words[#words + 1] = w end
    local items = {}
    for _, it in ipairs(pool) do
      if math.max(1, it.ph) <= S.phase and (it.rl or 1) >= S.minLevel
        and (not isArmor or not S.armorOnly or not it.at or it.at == T.BEST_ARMOR[p.cls]) then
        local ok = true
        if #words > 0 then
          local n, d = it.n:lower(), (it.drop or ""):lower()
          for _, w in ipairs(words) do if not n:find(w, 1, true) and not d:find(w, 1, true) then ok = false break end end
        end
        if ok then items[#items + 1] = it end
      end
    end
    local sort = state.sort
    U.sort(items, function(a, b)
      if sort == "avoid" then
        local d = av(b) - av(a)
        if d ~= 0 then return d end
        d = (b.st.sta or 0) - (a.st.sta or 0)
        if d ~= 0 then return d end
        return b.il - a.il
      elseif sort == "sta" then return (b.st.sta or 0) - (a.st.sta or 0)
      elseif sort == "ilvl" then return b.il - a.il end
      return U.cmp(a.n, b.n)
    end)
    f:text(("%s of %s items for this slot"):format(U.commas(#items), U.commas(#pool)), { font = "GameFontDisableSmall", gap = 4 })
    if #items == 0 then
      f:text('No items match. Try "All phases", "Any" level, or turn off the armor filter.', { color = K.SUB, justify = "CENTER" })
      return
    end
    local curId = p.gear[slot] and p.gear[slot].id
    for i = 1, min(#items, state.limit) do
      local it = items[i]
      local typ = TYPE_NAME[it.at or it.wt or it.rt or ""] or ""
      local parts = {}
      if it.rl then parts[#parts + 1] = "Req. level " .. it.rl end
      parts[#parts + 1] = "ilvl " .. it.il
      if typ ~= "" then parts[#parts + 1] = typ end
      parts[#parts + 1] = "P" .. math.max(1, it.ph)
      if it.so and #it.so > 0 then parts[#parts + 1] = #it.so .. " socket" .. (#it.so > 1 and "s" or "") end
      T.listRow(f, {
        ic = it.ic, quality = it.q, name = it.n, color = T.QUALITY_COLOR[it.q + 1], sub = table.concat(parts, " - "), sub2 = it.drop,
        right = "+" .. U.fmt(av(it)) .. "%", right2 = (it.st.sta or 0) .. " sta", selected = it.id == curId, iconSize = 34,
        tip = T.itemTip({ id = it.id }),
        onClick = function() preview(it) end,
      })
    end
    if #items > state.limit then
      f:buttons({ { label = ("Show more (%d)"):format(#items - state.limit), click = function() state.limit = state.limit + 150 h.redraw(true) end } }, "center")
    end
  end, { full = true })
end

function T.equip(p, slot, it)
  if E.on(it.u) then
    for _, other in ipairs(T.SLOTS) do
      if other.id ~= slot and p.gear[other.id] and p.gear[other.id].id == it.id then T.toast(it.n .. " is unique and already equipped") return false end
    end
  end
  local old = p.gear[slot]
  local oldE = old and E.on(old.ench) and T.ENCHANT_BY_ID[old.ench]
  local keepEnch = oldE and not T.enchantProblem(oldE, it, p.cls) and oldE.k or nil
  if oldE and not keepEnch then T.toast(oldE.n .. " doesn't fit the new item and was taken off") end
  local keepGems = old and old.id == it.id and old.gems or nil
  p.gear[slot] = { id = it.id, gems = keepGems, ench = keepEnch }
  if slot == "mainhand" and it.ht == "2h" and p.gear.offhand then p.gear.offhand = nil T.toast("Off hand removed: two-handed weapon") end
  if slot == "offhand" then
    local mh = p.gear.mainhand and T.ITEM_BY_ID[p.gear.mainhand.id]
    if mh and mh.ht == "2h" then p.gear.mainhand = nil T.toast("Two-handed weapon removed") end
  end
  T.commit()
  return true
end

---------------------------------------------------------------------- gems
local GEM_FILTERS = { { "sta", "Stamina" }, { "def", "Defense" }, { "dodge", "Dodge" }, { "agi", "Agility" }, { "block", "Block" }, { "parry", "Parry" },
  { "bv", "Block value" }, { "res", "Resilience" }, { "str", "Strength" }, { "hit", "Hit" }, { "exp", "Expertise" } }
local COLOR_NAME = { red = "Red", yellow = "Yellow", blue = "Blue", orange = "Orange", purple = "Purple", green = "Green", prismatic = "Prismatic", meta = "Meta" }

function T.openGemPicker(slot, idx, after)
  local p = T.cur()
  local piece = p.gear[slot]
  local it = T.ITEM_BY_ID[piece.id]
  local color = it.so[idx]
  local stat, fitsOnly = "", false
  local rows = {}
  for _, g in ipairs(T.GEMS) do
    if (color == "meta") == (g.c == "meta") then
      local fits = E.gemFits(color, g.c)
      local bits = {}
      if color ~= "meta" then bits[#bits + 1] = COLOR_NAME[g.c] .. (fits and " - matches this socket" or "") end
      if g.req then bits[#bits + 1] = table.concat(g.req, "; ") end
      if g.prof then bits[#bits + 1] = "Requires " .. g.prof end
      if E.on(g.u) then bits[#bits + 1] = "Unique" end
      bits[#bits + 1] = "P" .. math.max(1, g.ph)
      rows[#rows + 1] = {
        key = g.id, name = g.n, ic = g.ic or "", color = T.QUALITY_COLOR[g.q + 1], sub = g.tx or T.statText(g.st), sub2 = table.concat(bits, " - "),
        group = color ~= "meta" and (fits and "Matches the socket (counts for the socket bonus)" or "Other colours (no socket bonus)") or nil,
        search = COLOR_NAME[g.c], info = function(ff) T.gemInfo(ff, g) end, tip = T.gemTip(g.id), gem = g,
      }
    end
  end
  local function sortRows()
    U.sort(rows, function(a, b)
      local ga, gb = a.gem, b.gem
      local d = (E.gemFits(color, gb.c) and 1 or 0) - (E.gemFits(color, ga.c) and 1 or 0)
      if d ~= 0 then return d end
      if stat ~= "" then d = (gb.st[stat] or 0) - (ga.st[stat] or 0) if d ~= 0 then return d end end
      d = gb.q - ga.q
      if d ~= 0 then return d end
      return U.cmp(ga.n, gb.n)
    end)
  end
  sortRows()
  local chips = {}
  if color ~= "meta" then
    chips[#chips + 1] = { label = "Matching colour only", on = function() return fitsOnly end, toggle = function() fitsOnly = not fitsOnly end }
    for _, gf in ipairs(GEM_FILTERS) do
      chips[#chips + 1] = { label = gf[2], on = function() return stat == gf[1] end, toggle = function() stat = stat == gf[1] and "" or gf[1] sortRows() end }
    end
  end
  local cur = piece.gems and piece.gems[idx]
  T.pickFrom({
    title = COLOR_NAME[color] .. " Socket", rows = rows, selected = E.on(cur) and cur or nil, none = E.on(cur) and "Remove gem" or nil,
    placeholder = ("Search %d gems"):format(#rows), chips = chips,
    filter = function(r) return (not fitsOnly or E.gemFits(color, r.gem.c)) and (stat == "" or (r.gem.st[stat] or 0) > 0) end,
    onPick = function(k)
      local g = k and T.GEM_BY_ID[k]
      if g and E.on(g.u) then
        for _, sl in ipairs(T.SLOTS) do
          for i, x in ipairs((p.gear[sl.id] and p.gear[sl.id].gems) or {}) do
            if x == g.id and not (sl.id == slot and i == idx) then T.toast(g.n .. " is unique: you already wear one") return end
          end
        end
      end
      local gems = {}
      for i = 1, #(it.so or {}) do gems[i] = (piece.gems and piece.gems[i]) or 0 end
      gems[idx] = g and g.id or 0
      local any = false
      for _, x in ipairs(gems) do if E.on(x) then any = true end end
      piece.gems = any and gems or nil
      T.commit()
      after()
    end,
  })
end

---------------------------------------------------------------------- enchants
--- survival first, for sorting the enchant list
local function tankish(e)
  local s = e.st
  return (s.def or 0) * 1.2 + (s.dodge or 0) * 1.1 + (s.sta or 0) + (s.agi or 0) + (s.block or 0) * 1.3 + (s.parry or 0)
    + (s.armor or 0) / 20 + (s.hp or 0) / 10 + (s.res or 0) + (s.bv or 0) * 0.5 + (s.hit or 0) * 0.5 + (s.str or 0) * 0.3 + (s.exp or 0) * 0.5
end

function T.openEnchantPicker(slot, after)
  local p = T.cur()
  local piece = p.gear[slot]
  local it = T.ITEM_BY_ID[piece.id]
  -- everything for this kind of slot: two-hander enchants show on one-handers too, greyed with the reason
  local kinds = {}
  for _, k in ipairs(T.enchantSlotsOf(it)) do kinds[k] = true end
  if kinds.weapon then kinds["2h"] = true end
  local rows, usable = {}, 0
  for _, e in ipairs(T.ENCHANTS) do
    local fits = false
    for _, x in ipairs(e.sl) do if kinds[x] then fits = true end end
    if fits then
      local why = T.enchantProblem(e, it, p.cls)
      if not why then usable = usable + 1 end
      local bits = {}
      if e.req and e.req > 0 then bits[#bits + 1] = ("Item level %d+"):format(e.req) end
      if e.prof then bits[#bits + 1] = "Requires " .. e.prof end
      if e.rep then bits[#bits + 1] = e.rep end
      if e.cl then bits[#bits + 1] = U.ucfirst(e.cl) .. "s only" end
      if e.src == "trainer" then bits[#bits + 1] = "Enchanting trainer" end
      rows[#rows + 1] = {
        key = e.k, name = e.n, ic = e.ic or "inv_misc_note_01", color = why and "#9d9d9d" or "#1eff00",
        sub = T.statText(e.st) ~= "" and T.statText(e.st) or e.tx, sub2 = #bits > 0 and table.concat(bits, " - ") or nil,
        disabled = why, search = e.tx, info = function(ff) T.enchantInfo(ff, e) end, e = e,
      }
    end
  end
  U.sort(rows, function(a, b)
    local d = (a.disabled and 1 or 0) - (b.disabled and 1 or 0)
    if d ~= 0 then return d end
    d = tankish(b.e) - tankish(a.e)
    if d ~= 0 then return d end
    return U.cmp(a.name, b.name)
  end)
  T.pickFrom({
    title = "Enchant", rows = rows, selected = E.on(piece.ench) and piece.ench or nil, none = E.on(piece.ench) and "Remove enchant" or nil,
    placeholder = ("Search %d enchants"):format(#rows),
    note = ("%d of %d fit %s (item level %d)."):format(usable, #rows, it.n, it.il) .. (it.s == "finger" and " Ring enchants are for enchanters only." or ""),
    onPick = function(k) piece.ench = k T.commit() after() end,
  })
end

---------------------------------------------------------------------- auto-gear
function T.openAutoGear()
  local p = T.cur()
  T.openSheet("Auto-gear", function(f, h)
    f:text(("Puts the highest-avoidance item from the chosen phase in every slot (no gems or enchants). This replaces what %s is wearing now."):format(p.name))
    local list = {}
    for n = 1, 5 do
      list[#list + 1] = { label = "Phase " .. n, on = false, width = floor((f.width - 16) / 5),
        click = function() p.gear = T.Store.autoGear(p, n) T.commit() h.close() T.toast("Geared from phase " .. n) end }
    end
    f:chips(list)
  end)
end
