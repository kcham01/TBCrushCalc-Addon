-- The window: the open character along the top, the screen in the middle, tabs along the bottom, and
-- pop-up panels ("sheets") over it. Also the slash command, the minimap button and saving.
local ADDON, T = ...
local U, E, K = T.U, T.E, T.K

local floor, max, min = math.floor, math.max, math.min

local WIDTH, HEIGHT = 440, 660
local TOP_H, TAB_H, PAD = 54, 30, 14
T.CONTENT_W = WIDTH - 2 * PAD - 22

---------------------------------------------------------------------- state (the app's ui/state.ts)
local S = {
  list = {}, curId = "", tab = "char", tree = -1, capMode = "cooldown",
  statL = "base", statR = "def", phase = 5, armorOnly = true, minLevel = 0,
}
T.S = S
local db

function T.cur()
  for _, p in ipairs(S.list) do if p.id == S.curId then return p end end
  return S.list[1]
end
function T.classOf(p) return U.find(T.CLASSES, function(c) return c.id == p.cls end) end
function T.describe(p) return ("Level 70 %s %s"):format(T.RACE_NAMES[p.race] or p.race, T.classOf(p).name) end
function T.specText(p) return table.concat(E.treePoints(p), " / ") end

local function save()
  if not db then return end
  db.profiles = S.list
  db.current = S.curId
  db.ui = { tab = S.tab, capMode = S.capMode, statL = S.statL, statR = S.statR, phase = S.phase, armorOnly = S.armorOnly, minLevel = S.minLevel,
    point = db.ui and db.ui.point, minimap = db.ui and db.ui.minimap, hideMinimap = db.ui and db.ui.hideMinimap, effMap = db.ui and db.ui.effMap }
end
T.save = save

--- save after a change and redraw
function T.commit()
  local p = T.cur()
  p.updated = U.now()
  save()
  T.render()
end

function T.select(id)
  S.curId = id
  S.tree = -1
  save()
  T.render()
end

function T.addProfile(p)
  table.insert(S.list, p)
  save()
  T.select(p.id)
end

function T.removeProfile(id)
  local keep = {}
  for _, p in ipairs(S.list) do if p.id ~= id then keep[#keep + 1] = p end end
  S.list = keep
  if #S.list == 0 then S.list = T.Store.examples() end       -- never empty: bring back the examples
  save()
  if S.curId == id then T.select(S.list[1].id) else T.render() end
end

--- the cooldown view each class is usually judged by
function T.mainMode(p) return p.cls == "druid" and "passive" or "cooldown" end

---------------------------------------------------------------------- the window
local win, top, view, tabsBar, toastFrame
local TABS = { { "char", "Character" }, { "talents", "Talents" }, { "buffs", "Buffs" }, { "caps", "Caps" }, { "saved", "Saved" } }

local function classIcon(tex, cls)
  tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
  local c = CLASS_ICON_TCOORDS[cls:upper()]
  tex:SetTexCoord(c[1], c[2], c[3], c[4])
end
T.classIcon = classIcon

-- race portraits. The retail-style atlases (raceicon128-human-male) aren't in the Anniversary client, so
-- use one only if the client has it, else the character-creation race sheet the 2.5 client ships
-- (coordinates from its own CharacterCreate.lua), else the class icon
local RACE_FILE = { human = "HUMAN", dwarf = "DWARF", nightelf = "NIGHTELF", gnome = "GNOME", draenei = "DRAENEI",
  orc = "ORC", undead = "SCOURGE", tauren = "TAUREN", troll = "TROLL", bloodelf = "BLOODELF" }
local RACE_SHEET = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Races"
local RACE_TCOORDS = {
  HUMAN_MALE = { 0, 0.125, 0, 0.25 }, DWARF_MALE = { 0.125, 0.25, 0, 0.25 }, GNOME_MALE = { 0.25, 0.375, 0, 0.25 },
  NIGHTELF_MALE = { 0.375, 0.5, 0, 0.25 }, DRAENEI_MALE = { 0.5, 0.625, 0, 0.25 },
  TAUREN_MALE = { 0, 0.125, 0.25, 0.5 }, SCOURGE_MALE = { 0.125, 0.25, 0.25, 0.5 }, TROLL_MALE = { 0.25, 0.375, 0.25, 0.5 },
  ORC_MALE = { 0.375, 0.5, 0.25, 0.5 }, BLOODELF_MALE = { 0.5, 0.625, 0.25, 0.5 },
  HUMAN_FEMALE = { 0, 0.125, 0.5, 0.75 }, DWARF_FEMALE = { 0.125, 0.25, 0.5, 0.75 }, GNOME_FEMALE = { 0.25, 0.375, 0.5, 0.75 },
  NIGHTELF_FEMALE = { 0.375, 0.5, 0.5, 0.75 }, DRAENEI_FEMALE = { 0.5, 0.625, 0.5, 0.75 },
  TAUREN_FEMALE = { 0, 0.125, 0.75, 1 }, SCOURGE_FEMALE = { 0.125, 0.25, 0.75, 1 }, TROLL_FEMALE = { 0.25, 0.375, 0.75, 1 },
  ORC_FEMALE = { 0.375, 0.5, 0.75, 1 }, BLOODELF_FEMALE = { 0.5, 0.625, 0.75, 1 },
}
local ATLAS_RACE = { undead = "scourge" }
local sheetOk
function T.raceIcon(tex, race, cls)
  race = RACE_FILE[race] and race or "human"
  local a = "raceicon128-" .. (ATLAS_RACE[race] or race) .. "-male"
  if C_Texture.GetAtlasInfo(a) then
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetAtlas(a)
    return
  end
  if sheetOk == nil then sheetOk = GetFileIDFromPath(RACE_SHEET) ~= nil end
  if sheetOk or not cls then
    tex:SetTexture(RACE_SHEET)
    local c = RACE_TCOORDS[RACE_FILE[race] .. "_MALE"]
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
  else
    classIcon(tex, cls)
  end
end

local function build()
  win = CreateFrame("Frame", "TBCrushCalcFrame", UIParent, "BackdropTemplate")
  win:SetSize(WIDTH, HEIGHT)
  win:SetBackdrop(K.ROCK)
  win:SetFrameStrata("HIGH")
  win:SetToplevel(true)
  win:SetClampedToScreen(true)
  win:SetMovable(true)
  win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", function(self) self:StartMoving() end)
  win:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    db.ui.point = { point, relPoint, x, y }
  end)
  local pt = db.ui.point
  if pt then win:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else win:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
  win:Hide()
  win:SetScript("OnShow", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) T.render() end)
  win:SetScript("OnHide", function() T.closeAll() PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE) end)
  -- Escape closes the top panel first, then the window. (No keyboard capture: that would block your keys in
  -- combat. The game's own Escape handling hides "special" frames; while a panel is open, a hidden catcher
  -- frame stands in for the window there and closes one panel at a time.)
  local catcher = CreateFrame("Frame", "TBCrushCalcEscapeCatcher", UIParent)
  catcher:Hide()
  catcher:SetScript("OnHide", function()
    if T.closingAll then return end
    T.closeTop()
  end)
  T.catcher = catcher

  local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() win:Hide() end)

  -- the top bar
  top = CreateFrame("Frame", nil, win, "BackdropTemplate")
  top:SetPoint("TOPLEFT", 12, -12)
  top:SetPoint("TOPRIGHT", -34, -12)
  top:SetHeight(TOP_H - 8)
  top.who = CreateFrame("Button", nil, top)
  top.who:SetSize(40, 40)
  top.who:SetPoint("LEFT", 4, 0)
  top.who.icon = top.who:CreateTexture(nil, "ARTWORK")
  top.who.icon:SetAllPoints()
  top.who:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  top.who:SetScript("OnClick", function() T.go("saved") end)
  top.name = K.fs(top, "GameFontNormalLarge")
  top.name:SetPoint("TOPLEFT", 52, -4)
  top.name:SetPoint("RIGHT", top, "RIGHT", -100, 0)
  top.name:SetWordWrap(false)
  top.sub = K.fs(top, "GameFontHighlightSmall")
  top.sub:SetPoint("TOPLEFT", 52, -24)
  top.sub:SetPoint("RIGHT", top, "RIGHT", -100, 0)
  top.sub:SetWordWrap(false)
  top.verdict = CreateFrame("Button", nil, top, "BackdropTemplate")
  top.verdict:SetBackdrop(K.INSET)
  top.verdict:SetSize(92, 38)
  top.verdict:SetPoint("RIGHT", 0, 0)
  top.verdict.num = K.fs(top.verdict, "GameFontHighlightLarge")
  top.verdict.num:SetJustifyH("CENTER")
  top.verdict.num:SetPoint("TOP", 0, -4)
  top.verdict.word = K.fs(top.verdict, "GameFontNormalSmall")
  top.verdict.word:SetJustifyH("CENTER")
  top.verdict.word:SetPoint("TOP", 0, -23)
  top.verdict:SetScript("OnClick", function() T.go("caps") end)
  top.verdict:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  -- the screen
  view = K.scroller(win)
  view:HookScript("OnVerticalScroll", function(self) if T.clipModel then T.clipModel(self) end end)
  view:SetPoint("TOPLEFT", PAD, -(TOP_H + 8))
  view:SetPoint("BOTTOMRIGHT", -PAD, TAB_H + 16)

  -- the tabs
  tabsBar = CreateFrame("Frame", nil, win)
  tabsBar:SetPoint("BOTTOMLEFT", 12, 12)
  tabsBar:SetPoint("BOTTOMRIGHT", -12, 12)
  tabsBar:SetHeight(TAB_H)
  tabsBar.buttons = {}
  local tw = (WIDTH - 24 - 4 * 4) / #TABS
  for i, t in ipairs(TABS) do
    local b = CreateFrame("Button", nil, tabsBar, "BackdropTemplate")
    b:SetBackdrop(K.INSET)
    b:SetSize(tw, TAB_H)
    b:SetPoint("LEFT", (i - 1) * (tw + 4), 0)
    b.text = K.fs(b, "GameFontNormal")
    b.text:SetJustifyH("CENTER")
    b.text:SetJustifyV("MIDDLE")
    b.text:SetAllPoints()
    b.text:SetText(t[2])
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function() T.go(t[1]) end)
    b.id = t[1]
    tabsBar.buttons[i] = b
  end

  -- the toast
  toastFrame = CreateFrame("Frame", nil, win, "BackdropTemplate")
  toastFrame:SetBackdrop(K.INSET)
  toastFrame:SetBackdropColor(0, 0, 0, 0.92)
  toastFrame:SetBackdropBorderColor(1, 0.82, 0, 1)
  toastFrame:SetFrameStrata("DIALOG")
  toastFrame:SetPoint("BOTTOM", win, "BOTTOM", 0, TAB_H + 26)
  toastFrame.text = K.fs(toastFrame, "GameFontHighlight")
  toastFrame.text:SetJustifyH("CENTER")
  toastFrame.text:SetPoint("CENTER")
  toastFrame:Hide()

  tinsert(UISpecialFrames, "TBCrushCalcFrame")
end

--- while panels are open, Escape closes them one at a time instead of the whole window
local function setEscape(panelsOpen)
  local function drop(name) for i = #UISpecialFrames, 1, -1 do if UISpecialFrames[i] == name then table.remove(UISpecialFrames, i) end end end
  drop("TBCrushCalcFrame") drop("TBCrushCalcEscapeCatcher")
  tinsert(UISpecialFrames, panelsOpen and "TBCrushCalcEscapeCatcher" or "TBCrushCalcFrame")
  if panelsOpen then T.catcher:Show() end
end

local toastSeq = 0
function T.toast(text)
  toastSeq = toastSeq + 1
  local mine = toastSeq
  toastFrame.text:SetWidth(0)
  toastFrame.text:SetText(text)
  local w = min(WIDTH - 40, toastFrame.text:GetStringWidth() + 28)
  toastFrame.text:SetWidth(w - 20)
  toastFrame:SetSize(w, toastFrame.text:GetStringHeight() + 16)
  toastFrame:Show()
  C_Timer.After(1.8, function() if toastSeq == mine then toastFrame:Hide() end end)
end

---------------------------------------------------------------------- drawing
local lastTab, lastId

function T.render()
  if not win or not win:IsShown() then return end
  local p = T.cur()
  local keep = lastTab == S.tab and lastId == p.id
  lastTab, lastId = S.tab, p.id

  local cls = T.classOf(p)
  classIcon(top.who.icon, p.cls)
  top.name:SetText(p.name)
  top.name:SetTextColor(U.hex(cls.color))
  top.sub:SetText(T.describe(p) .. " - " .. T.specText(p))
  local v = E.verdict(p, T.mainMode(p))
  top.verdict.num:SetText(U.pct(v.total, 1))
  if v.uncrushable then
    top.verdict:SetBackdropColor(0.05, 0.2, 0.03, 0.9) top.verdict:SetBackdropBorderColor(0.12, 0.7, 0.1, 1)
    top.verdict.word:SetText("UNCRUSHABLE") top.verdict.word:SetTextColor(0.12, 1, 0)
  else
    top.verdict:SetBackdropColor(0.25, 0.04, 0.03, 0.9) top.verdict:SetBackdropBorderColor(1, 0.25, 0.2, 1)
    top.verdict.word:SetText(U.pct(v.short, 1) .. " SHORT") top.verdict.word:SetTextColor(1, 0.35, 0.3)
  end

  for _, b in ipairs(tabsBar.buttons) do
    local on = b.id == S.tab
    b:SetBackdropColor(on and 0.35 or 0.1, on and 0.27 or 0.08, on and 0.07 or 0.06, 1)
    b:SetBackdropBorderColor(on and 1 or 0.42, on and 0.82 or 0.33, on and 0 or 0.19, 1)
    b.text:SetTextColor(on and 1 or 0.8, on and 0.82 or 0.7, on and 0 or 0.5)
  end

  K.release("view")
  if T.hideModel then T.hideModel() end
  local flow = K.flow("view", view.child, 0, 4, T.CONTENT_W)
  local screens = { char = T.characterView, talents = T.talentsView, buffs = T.buffsView, caps = T.capsView, saved = T.savedView }
  local ok, err = pcall(screens[S.tab], flow, p)
  if not ok then
    flow:text("|cffff5a4aSomething went wrong drawing this screen:|r " .. tostring(err), { font = "GameFontHighlightSmall" })
    geterrorhandler()(err)
  end
  view:setContentHeight(flow.y + 8, keep)
  if T.clipModel then T.clipModel(view) end
end

function T.go(tab)
  T.closeAll()
  S.tab = tab
  save()
  T.render()
end

function T.toggle()
  if not T.start() then return end
  if win:IsShown() then win:Hide() else win:Show() end
end
function T.show()
  if not T.start() then return end
  win:Show()
  win:Raise()
end

---------------------------------------------------------------------- sheets (pop-up panels)
local sheets, stack = {}, {}

local function makeSheet(depth)
  local s = CreateFrame("Frame", nil, win, "BackdropTemplate")
  s:SetBackdrop(K.ROCK)
  s:EnableMouse(true)
  s:SetFrameLevel(win:GetFrameLevel() + 30 + depth * 12)
  s.shade = CreateFrame("Frame", nil, win)
  s.shade:SetFrameLevel(s:GetFrameLevel() - 2)
  s.shade:SetPoint("TOPLEFT", 6, -6)
  s.shade:SetPoint("BOTTOMRIGHT", -6, 6)
  s.shade:EnableMouse(true)
  s.shade.tex = s.shade:CreateTexture(nil, "BACKGROUND")
  s.shade.tex:SetAllPoints()
  s.shade.tex:SetColorTexture(0, 0, 0, 0.55)
  s.shade:SetScript("OnMouseUp", function() T.closeTop() end)
  s.title = K.fs(s, "GameFontNormalLarge")
  s.title:SetPoint("TOPLEFT", 18, -18)
  s.title:SetPoint("RIGHT", s, "RIGHT", -40, 0)
  s.title:SetWordWrap(false)
  s.close = CreateFrame("Button", nil, s, "UIPanelCloseButton")
  s.close:SetPoint("TOPRIGHT", -6, -6)
  s.close:SetScript("OnClick", function() T.closeTop() end)
  s.line = s:CreateTexture(nil, "ARTWORK")
  s.line:SetColorTexture(0.72, 0.54, 0.23, 0.45)
  s.line:SetHeight(1)
  s.line:SetPoint("TOPLEFT", 14, -40)
  s.line:SetPoint("TOPRIGHT", -14, -40)
  s.scroll = K.scroller(s)
  s.scroll:SetPoint("TOPLEFT", 16, -46)
  s.scroll:SetPoint("BOTTOMRIGHT", -14, 14)
  s:Hide()
  s.shade:Hide()
  return s
end

--- opens a panel over the window. build(flow, handle) draws its contents (again after handle.redraw()).
--- opts.full: as tall as the window allows. Returns the handle: { close, redraw, setTitle, frame }.
function T.openSheet(title, buildFn, opts)
  opts = opts or {}
  local depth = #stack + 1
  sheets[depth] = sheets[depth] or makeSheet(depth)
  local s = sheets[depth]
  local owner = "sheet" .. depth
  local handle = { frame = s, owner = owner }
  local entry = { s = s, owner = owner, onClose = opts.onClose, handle = handle }
  table.insert(stack, entry)
  s.title:SetText(title)
  local maxH = HEIGHT - 70
  function handle.setTitle(t) s.title:SetText(t) end
  function handle.close()
    for i, e in ipairs(stack) do
      if e == entry then
        for j = #stack, i, -1 do
          local x = table.remove(stack, j)
          K.release(x.owner)
          x.s:Hide() x.s.shade:Hide()
          if x.onClose then x.onClose() end
        end
        break
      end
    end
    if #stack == 0 then
      T.closingAll = true
      T.catcher:Hide()
      T.closingAll = false
      setEscape(false)
    elseif not T.catcher:IsShown() then
      C_Timer.After(0, function() if #stack > 0 then T.catcher:Show() end end)
    end
  end
  function handle.redraw(keep)
    K.release(owner)
    local flow = K.flow(owner, s.scroll.child, 0, 2, WIDTH - 64)
    buildFn(flow, handle)
    local contentH = flow.y + 6
    local h = opts.full and maxH or min(maxH, contentH + 62)
    s:SetHeight(h)
    s.scroll:setContentHeight(contentH, keep)
  end
  s:ClearAllPoints()
  s:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 8, 8)
  s:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -8, 8)
  s.shade:Show()
  s:Show()
  handle.redraw()
  setEscape(true)
  return handle
end

--- the frame of the panel on top (or nil)
function T.topSheet() local e = stack[#stack] return e and e.s end

--- closes the top panel; false when there was none
function T.closeTop()
  local e = stack[#stack]
  if not e then return false end
  e.handle.close()
  return true
end
function T.closeAll() while T.closeTop() do end end

--- a confirmation panel
function T.confirmSheet(title, text, yes, onYes)
  T.openSheet(title, function(f, h)
    f:text(text)
    f:gap(6)
    f:buttons({ { label = "Cancel", click = function() h.close() end }, { label = yes, click = function() h.close() onYes() end } })
  end)
end

--- a box with a web address to copy (addons can't open a browser)
function T.showUrl(title, url)
  T.openSheet(title, function(f)
    f:note("Press Ctrl+C to copy the address, then paste it into your browser.")
    local e = K.get(f.owner, "edit", f.parent)
    f:place(e, 22, 6, f.width - 12)
    e:SetText(url)
    e:SetScript("OnTextChanged", function(self, user) if user then self:SetText(url) self:HighlightText() end end)
    e:SetFocus()
    e:HighlightText()
    f:gap(8)
  end)
end

---------------------------------------------------------------------- minimap button
local function minimapButton()
  local b = CreateFrame("Button", "TBCrushCalcMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\INV_Shield_06")
  icon:SetSize(20, 20)
  icon:SetPoint("TOPLEFT", 7, -5)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  local function place()
    local a = math.rad(db.ui.minimap or 210)
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
  end
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      db.ui.minimap = math.deg(math.atan2(py / scale - my, px / scale - mx)) % 360
      place()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnClick", function() T.toggle() end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("TBCrushCalc")
    GameTooltip:AddLine("Click to open the crush cap calculator.", 1, 1, 1)
    GameTooltip:AddLine("Drag to move this button. /tbcc also opens it.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  place()
  if db.ui.hideMinimap then b:Hide() end
  T.minimap = b
end

---------------------------------------------------------------------- start up
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    TBCrushCalcDB = TBCrushCalcDB or {}
    TBCrushCalcDB.ui = TBCrushCalcDB.ui or {}
    db = TBCrushCalcDB
    T.db = db
  elseif event == "PLAYER_LOGIN" then
    minimapButton()
  end
end)

--- the first time the window is wanted: load the game data, the saved characters and build the window
local started = false
function T.start()
  if started then return true end
  if not T.loadData() then
    print(("|cffffd100TBCrushCalc|r: couldn't load its item data: %s. Both the TBCrushCalc and TBCrushCalc_Data folders need to be in Interface\\AddOns and ticked in the AddOns list."):format(tostring(T.dataError)))
    return false
  end
  db = T.Store.load(TBCrushCalcDB)
  T.db = db
  S.list = db.profiles
  local ui = db.ui
  for _, k in ipairs({ "tab", "capMode", "statL", "statR", "phase", "minLevel" }) do if ui[k] ~= nil then S[k] = ui[k] end end
  if ui.armorOnly ~= nil then S.armorOnly = ui.armorOnly end
  S.curId = (db.current and U.find(S.list, function(p) return p.id == db.current end)) and db.current or S.list[1].id
  build()
  started = true
  return true
end

SLASH_TBCRUSHCALC1 = "/tbcc"
SLASH_TBCRUSHCALC2 = "/tbcrushcalc"
SlashCmdList.TBCRUSHCALC = function(msg)
  msg = U.trim(msg or ""):lower()
  if msg == "load" or msg == "me" then
    T.show()
    T.loadMyCharacter()
  elseif msg == "minimap" then
    db.ui.hideMinimap = not db.ui.hideMinimap
    if T.minimap then T.minimap:SetShown(not db.ui.hideMinimap) end
    print("|cffffd100TBCrushCalc|r: minimap button " .. (db.ui.hideMinimap and "hidden" or "shown") .. ".")
  else
    T.toggle()
  end
end
