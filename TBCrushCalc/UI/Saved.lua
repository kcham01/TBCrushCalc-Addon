-- The Saved screen: your characters (alts), new / copy / rename / delete, sharing a character as a text
-- code (the same codes as the phone app), and loading the character you're playing (the app's ui/saved.ts).
local _, T = ...
local U, E, K = T.U, T.E, T.K
local S = T.S

local floor = math.floor

K.define("prof", function()
  local b = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
  b:SetBackdrop(K.FLAT)
  b.race = b:CreateTexture(nil, "ARTWORK")
  b.race:SetSize(40, 40)
  b.race:SetPoint("LEFT", 8, 0)
  b.cls = b:CreateTexture(nil, "OVERLAY")
  b.cls:SetSize(20, 20)
  b.cls:SetPoint("BOTTOMRIGHT", b.race, "BOTTOMRIGHT", 6, -6)
  b.n = K.fs(b, "GameFontNormal") b.n:SetPoint("TOPLEFT", 58, -7) b.n:SetPoint("RIGHT", -60, 0) b.n:SetWordWrap(false)
  b.d = K.fs(b, "GameFontHighlightSmall") b.d:SetPoint("TOPLEFT", 58, -23) b.d:SetPoint("RIGHT", -60, 0) b.d:SetWordWrap(false)
  b.v = K.fs(b, "GameFontHighlightSmall") b.v:SetPoint("TOPLEFT", 58, -37) b.v:SetPoint("RIGHT", -60, 0)
  b.more = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
  b.more:SetSize(46, 22)
  b.more:SetPoint("RIGHT", -8, 0)
  b.more:SetText("...")
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b:SetHeight(54)
  return b
end)

function T.savedView(flow, p0)
  local list = {}
  for _, p in ipairs(S.list) do list[#list + 1] = p end
  U.sort(list, function(a, b) return (b.updated or 0) - (a.updated or 0) end)
  flow:panel("Characters", function(f)
    for _, p in ipairs(list) do
      local v = E.verdict(p, T.mainMode(p))
      local b = K.get(f.owner, "prof", f.parent)
      T.raceIcon(b.race, p.race, p.cls)
      T.classIcon(b.cls, p.cls)
      b.n:SetText(p.name)
      b.n:SetTextColor(U.hex(T.classOf(p).color))
      b.d:SetText(T.describe(p) .. " - " .. T.specText(p))
      b.v:SetText(U.pct(v.total) .. " " .. (v.uncrushable and "uncrushable" or ("(" .. U.pct(v.short) .. " short)")))
      if v.uncrushable then b.v:SetTextColor(0.12, 1, 0) else b.v:SetTextColor(1, 0.35, 0.3) end
      if p.id == S.curId then
        b:SetBackdropColor(1, 0.82, 0, 0.12) b:SetBackdropBorderColor(1, 0.82, 0, 0.5)
      else
        b:SetBackdropColor(0, 0, 0, 0.3) b:SetBackdropBorderColor(0, 0, 0, 0)
      end
      b:SetScript("OnClick", function() T.select(p.id) T.toast("Now showing " .. p.name) end)
      b.more:SetScript("OnClick", function() T.openManage(p) end)
      f:place(b, 54, 0, f.width)
      f:gap(4)
    end
    f:gap(6)
    f:buttons({
      { label = "New character", click = function() T.openNew() end },
      { label = "Import code", click = function() T.openImport() end },
    }, "center")
    f:buttons({ { label = "Load the character I'm playing", click = function() T.loadMyCharacter() end } }, "center")
    f:note("Loads your gear, gems, enchants and talents from the game into a character here (warriors, paladins and druids).")
  end)
  flow:panel("About", function(f)
    local version = C_AddOns.GetAddOnMetadata("TBCrushCalc", "Version") or ""
    f:note(("TBCrushCalc %s. A gear planner and crush / crit cap calculator for Burning Crusade tanks, the same as the TBCrushCalc phone app."):format(version))
    f:note("Item, gem, enchant, consumable and talent data from the wowsims/tbc, cmangos and oppahansi/ltc projects; boss data from the cmangos TBC server.")
    f:note("Characters are saved for your whole account. Share codes work in both the addon and the app. /tbcc opens this window; /tbcc minimap hides or shows the minimap button.")
  end)
end

local function raceChips(f, cls, race, pick)
  local races = U.keys(T.BASES[cls])
  table.sort(races, function(a, b) return T.RACE_NAMES[a] < T.RACE_NAMES[b] end)
  f:chips(U.map(races, function(r) return { label = T.RACE_NAMES[r], on = r == race, click = function() pick(r) end } end))
end

function T.openNew()
  local st = { cls = "paladin", race = "human", gear = true, name = "" }
  T.openSheet("New character", function(f, h)
    if not T.BASES[st.cls][st.race] then st.race = U.keys(T.BASES[st.cls])[1] end
    local e = K.get(f.owner, "edit", f.parent)
    f:place(e, 22, 6, f.width - 12)
    e:SetMaxLetters(24)
    e:SetText(st.name)
    e:SetScript("OnTextChanged", function(self) st.name = self:GetText() end)
    f:gap(6)
    f:text("Class", { font = "GameFontNormal", gap = 3 })
    f:chips(U.map(T.CLASSES, function(c) return { label = c.name, on = c.id == st.cls, width = floor((f.width - 8) / 3), click = function() st.cls = c.id h.redraw() end } end))
    f:text("Race", { font = "GameFontNormal", gap = 3 })
    raceChips(f, st.cls, st.race, function(r) st.race = r h.redraw() end)
    f:chips({ { label = (st.gear and "[x] " or "[  ] ") .. "Start in phase 1 gear", on = st.gear, click = function() st.gear = not st.gear h.redraw() end } })
    f:note("Fills every slot with high-avoidance phase 1 items. Change them on the Character screen.")
    f:buttons({
      { label = "Cancel", click = function() h.close() end },
      { label = "Create", click = function()
        local name = U.trim(st.name) ~= "" and U.trim(st.name) or (T.RACE_NAMES[st.race] .. " " .. T.classOf({ cls = st.cls }).name)
        local p = T.Store.newProfile(st.cls, st.race, name)
        if st.gear then p.gear = T.Store.autoGear(p, 1) end
        T.Store.raidSetup(p)
        h.close()
        T.addProfile(p)
        S.tab = "talents"
        T.commit()
        T.toast("Now spend your talent points")
      end },
    })
  end)
end

function T.openManage(p)
  T.openSheet(p.name, function(f, h)
    f:text("Name", { font = "GameFontNormal", gap = 3 })
    local e = K.get(f.owner, "edit", f.parent)
    e:SetMaxLetters(24)
    e:SetText(p.name)
    f:place(e, 22, 6, f.width - 100)
    local save = K.get(f.owner, "button", f.parent)
    save:SetText("Save")
    save:SetWidth(80)
    save:SetPoint("TOPRIGHT", f.parent, "TOPRIGHT", -f.x, -(f.y - 22))
    save:SetScript("OnClick", function()
      local n = U.trim(e:GetText())
      if n ~= "" then p.name = n end
      T.commit() h.setTitle(p.name) T.toast("Renamed")
    end)
    f:gap(8)
    f:text("Race", { font = "GameFontNormal", gap = 3 })
    raceChips(f, p.cls, p.race, function(r) p.race = r T.commit() h.redraw() end)
    f:text("Share code", { font = "GameFontNormal", gap = 3 })
    local code = T.Store.exportCode(p)
    local ce = K.get(f.owner, "edit", f.parent)
    f:place(ce, 22, 6, f.width - 12)
    ce:SetText(code)
    ce:SetScript("OnTextChanged", function(self, user) if user then self:SetText(code) self:HighlightText() end end)
    ce:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    f:note("Click the code and press Ctrl+C to copy it. It opens in the addon and in the TBCrushCalc app.")
    f:buttons({
      { label = "Duplicate", click = function()
        local c = U.copy(p)
        c.id = U.newId() c.name = p.name .. " copy" c.updated = U.now()
        h.close() T.addProfile(c) T.toast("Copied")
      end },
      { label = "Delete", click = function()
        T.confirmSheet("Delete character", ("Delete %s? This can't be undone."):format(p.name), "Delete", function() h.close() T.removeProfile(p.id) end)
      end },
    })
  end)
end

function T.openImport()
  local st = { code = "" }
  T.openSheet("Import", function(f, h)
    f:note("Paste a code shared from TBCrushCalc (the addon or the app) to add that character.")
    local e = K.get(f.owner, "edit", f.parent)
    f:place(e, 22, 6, f.width - 12)
    e:SetText(st.code)
    e:SetScript("OnTextChanged", function(self) st.code = self:GetText() end)
    e:SetFocus()
    f:gap(8)
    f:buttons({
      { label = "Cancel", click = function() h.close() end },
      { label = "Import", click = function()
        local p = T.Store.importCode(st.code)
        if not p then T.toast("That code didn't work") return end
        h.close() T.addProfile(p) T.toast("Imported " .. p.name)
      end },
    })
  end)
end
