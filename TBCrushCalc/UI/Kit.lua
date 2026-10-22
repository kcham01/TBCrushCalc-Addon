-- The building blocks of the addon's screens, in the game's own look: framed panels with a gold title
-- plate, red panel buttons, gold "chips", list rows, drop-down rows, icon tiles, item slots, scroll areas
-- and the pop-up panels ("sheets") that slide over the window.
--
-- Screens are redrawn after every change (like the app). So nothing leaks, every widget comes from a pool:
-- K.get(owner, kind, parent) hands out a widget, and K.release(owner) puts back everything that owner had.
local _, T = ...
local U = T.U
local K = {}
T.K = K

local floor, max, min = math.floor, math.max, math.min

K.GOLD = { 1, 0.82, 0 }
K.WHITE = { 1, 1, 1 }
K.GREY = { 0.62, 0.62, 0.62 }
K.GREEN = { 0.12, 1, 0 }
K.RED = { 1, 0.35, 0.3 }
K.TEXT = { 0.91, 0.89, 0.82 }        -- the app's panel text colour
K.SUB = { 0.74, 0.71, 0.64 }

K.WHITE8 = "Interface\\Buttons\\WHITE8X8"
K.ROCK = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
K.PANEL = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
K.INSET = {
  bgFile = K.WHITE8, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = false, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
K.FLAT = { bgFile = K.WHITE8, edgeFile = K.WHITE8, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }

function K.rgb(c) return c[1], c[2], c[3] end

---------------------------------------------------------------------- pools
local pools, live = {}, {}
local makers, resets = {}, {}

function K.define(kind, make, reset) makers[kind] = make resets[kind] = reset end

--- hands out a widget of `kind` for `owner` (a screen or a sheet), parented to `parent` and shown
function K.get(owner, kind, parent)
  pools[kind] = pools[kind] or {}
  local w = table.remove(pools[kind])
  if not w then w = makers[kind]() w._kind = kind end
  w:SetParent(parent)
  if w.SetFrameStrata and parent.GetFrameStrata then w:SetFrameStrata(parent:GetFrameStrata()) end
  w:ClearAllPoints()
  w:SetAlpha(1)
  if w.SetFrameLevel and parent.GetFrameLevel then w:SetFrameLevel(parent:GetFrameLevel() + 1) end
  if resets[kind] then resets[kind](w) end
  w:Show()
  live[owner] = live[owner] or {}
  table.insert(live[owner], w)
  return w
end

--- puts back every widget an owner was given
function K.release(owner)
  local list = live[owner]
  if not list then return end
  for i = #list, 1, -1 do
    local w = list[i]
    w:Hide()
    w:ClearAllPoints()
    if w.SetScript then
      if w.HasScript and w:HasScript("OnClick") then w:SetScript("OnClick", nil) end
      w:SetScript("OnEnter", nil)
      w:SetScript("OnLeave", nil)
    end
    table.insert(pools[w._kind], w)
  end
  live[owner] = nil
end

function K.liveCount() local n = 0 for _, l in pairs(live) do n = n + #l end return n end

local function fs(parent, font, layer)
  local f = parent:CreateFontString(nil, layer or "OVERLAY")
  f:SetFontObject(font or "GameFontHighlight")
  f:SetJustifyH("LEFT")
  f:SetJustifyV("TOP")
  return f
end
K.fs = fs

local function tooltipOn(w, fn)
  w:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    fn(GameTooltip)
    GameTooltip:Show()
  end)
  w:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
K.tooltipOn = tooltipOn

---------------------------------------------------------------------- widgets
-- a framed panel with a gold title plate (the app's "frame rock")
K.define("panel", function()
  local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  f:SetBackdrop(K.PANEL)
  f:SetBackdropBorderColor(0.72, 0.56, 0.24, 1)
  f.plate = f:CreateTexture(nil, "ARTWORK")
  f.plate:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
  f.plate:SetSize(240, 56)
  f.plate:SetPoint("TOP", 0, 15)
  f.title = fs(f, "GameFontNormal")
  f.title:SetJustifyH("CENTER")
  f.title:SetPoint("TOP", f.plate, "TOP", 0, -13)
  return f
end, function(f) f.title:SetText("") f.plate:Show() end)

-- a plain container (no look of its own)
K.define("box", function() return CreateFrame("Frame", nil, UIParent, "BackdropTemplate") end, function(f)
  f:SetBackdrop(nil)
  f:EnableMouse(false)
end)

-- one piece of text
K.define("label", function()
  local f = CreateFrame("Frame", nil, UIParent)
  f.text = fs(f)
  f.text:SetAllPoints()
  return f
end, function(f)
  f.text:SetFontObject("GameFontHighlight")
  f.text:SetTextColor(K.rgb(K.TEXT))
  f.text:SetJustifyH("LEFT")
  f.text:SetJustifyV("TOP")
  f.text:SetText("")
  f:EnableMouse(false)
end)

-- the game's red panel button
K.define("button", function()
  local b = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
  b:SetHeight(24)
  return b
end, function(b) b:Enable() b:SetText("") end)

-- a rounded toggle "chip"
K.define("chip", function()
  local b = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
  b:SetBackdrop(K.INSET)
  b.text = fs(b, "GameFontHighlightSmall")
  b.text:SetJustifyH("CENTER")
  b.text:SetJustifyV("MIDDLE")
  b.text:SetPoint("LEFT", 6, 0)
  b.text:SetPoint("RIGHT", -6, 0)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetHeight(20)
  return b
end, function(b) b:Enable() end)

function K.setChip(b, label, on)
  b.text:SetText(label)
  b:SetWidth(max(28, b.text:GetStringWidth() + 16))
  if on then
    b:SetBackdropColor(0.85, 0.66, 0.13, 1)
    b:SetBackdropBorderColor(0.36, 0.24, 0.06, 1)
    b.text:SetTextColor(0, 0, 0)
  else
    b:SetBackdropColor(0.11, 0.09, 0.07, 1)
    b:SetBackdropBorderColor(0.42, 0.33, 0.19, 1)
    b.text:SetTextColor(0.85, 0.81, 0.74)
  end
end

-- an icon with a thin dark border (and an optional big letter when there is no icon)
local function iconParts(f, size)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  f.border = f:CreateTexture(nil, "BACKGROUND")
  f.border:SetColorTexture(0, 0, 0, 1)
end
function K.placeIcon(f, x, y, size, anchor)
  f.border:ClearAllPoints()
  f.border:SetPoint(anchor or "TOPLEFT", x, y)
  f.border:SetSize(size, size)
  f.icon:ClearAllPoints()
  f.icon:SetPoint("TOPLEFT", f.border, "TOPLEFT", 1, -1)
  f.icon:SetPoint("BOTTOMRIGHT", f.border, "BOTTOMRIGHT", -1, 1)
end
K.iconParts = iconParts

-- a list row ("li"): icon, name, up to three detail lines, a score on the right and an info button
K.define("row", function()
  local b = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
  b:SetBackdrop(K.FLAT)
  iconParts(b)
  b.qual = b:CreateTexture(nil, "BORDER")
  b.name = fs(b, "GameFontHighlight")
  b.sub = fs(b, "GameFontHighlightSmall")
  b.sub2 = fs(b, "GameFontHighlightSmall")
  b.sub3 = fs(b, "GameFontHighlightSmall")
  b.right = fs(b, "GameFontNormalSmall")
  b.right:SetJustifyH("RIGHT")
  b.right2 = fs(b, "GameFontHighlightSmall")
  b.right2:SetJustifyH("RIGHT")
  b.info = CreateFrame("Button", nil, b, "BackdropTemplate")
  b.info:SetSize(20, 20)
  b.info:SetBackdrop(K.INSET)
  b.info:SetBackdropColor(0.15, 0.12, 0.08, 1)
  b.info:SetBackdropBorderColor(0.42, 0.33, 0.19, 1)
  b.info.text = fs(b.info, "GameFontNormal")
  b.info.text:SetText("i")
  b.info.text:SetJustifyH("CENTER")
  b.info.text:SetJustifyV("MIDDLE")
  b.info.text:SetAllPoints()
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  return b
end, function(b)
  for _, f in ipairs({ b.name, b.sub, b.sub2, b.sub3, b.right, b.right2 }) do f:SetText("") f:ClearAllPoints() end
  b.name:SetTextColor(1, 1, 1)
  b.sub:SetTextColor(K.rgb(K.SUB))
  b.sub2:SetTextColor(K.rgb(K.SUB))
  b.sub3:SetTextColor(K.rgb(K.RED))
  b.right:SetTextColor(K.rgb(K.GOLD))
  b.right2:SetTextColor(1, 1, 1)
  b.info:Hide()
  b.info:SetScript("OnClick", nil)
  b.icon:Show() b.border:Show() b.qual:Hide()
  b:SetAlpha(1)
  b:Enable()
end)

-- a drop-down row: label on the left, the current choice (icon, name, detail) and a caret
K.define("selrow", function()
  local b = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
  b:SetBackdrop(K.FLAT)
  b:SetBackdropColor(0, 0, 0, 0.3)
  b:SetBackdropBorderColor(0.42, 0.33, 0.19, 0.7)
  b.label = fs(b, "GameFontNormalSmall")
  b.label:SetPoint("LEFT", 8, 0)
  b.label:SetWidth(84)
  b.label:SetJustifyV("MIDDLE")
  iconParts(b)
  K.placeIcon(b, 96, -5, 26)
  b.name = fs(b, "GameFontHighlight")
  b.name:SetPoint("TOPLEFT", 130, -6)
  b.name:SetPoint("RIGHT", -22, 0)
  b.name:SetWordWrap(false)
  b.sub = fs(b, "GameFontHighlightSmall")
  b.sub:SetPoint("TOPLEFT", 130, -20)
  b.sub:SetPoint("RIGHT", -22, 0)
  b.sub:SetWordWrap(false)
  b.caret = fs(b, "GameFontNormal")
  b.caret:SetText("v")
  b.caret:SetPoint("RIGHT", -8, 0)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b:SetHeight(36)
  return b
end, function(b) b:SetAlpha(1) b.name:SetTextColor(1, 1, 1) b.sub:SetTextColor(K.rgb(K.SUB)) end)

-- a buff / ability tile: icon, state ring, "+" badge and a two-line name
K.define("tile", function()
  local b = CreateFrame("Button", nil, UIParent)
  b:SetSize(66, 66)
  b.ring = b:CreateTexture(nil, "BACKGROUND")
  b.ring:SetPoint("TOP", 0, -2)
  b.ring:SetSize(40, 40)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOP", 0, -4)
  b.icon:SetSize(36, 36)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.badge = b:CreateTexture(nil, "OVERLAY")
  b.badge:SetSize(14, 14)
  b.badge:SetPoint("TOPRIGHT", b.ring, "TOPRIGHT", 5, 5)
  b.badgeText = fs(b, "GameFontHighlightSmall")
  b.badgeText:SetPoint("CENTER", b.badge, "CENTER", 0, 0)
  b.badgeText:SetJustifyH("CENTER")
  b.name = fs(b, "GameFontHighlightSmall")
  b.name:SetPoint("TOP", b.ring, "BOTTOM", 0, -2)
  b.name:SetWidth(64)
  b.name:SetJustifyH("CENTER")
  b.name:SetMaxLines(2)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  return b
end, function(b) b.icon:SetDesaturated(false) b.icon:SetVertexColor(1, 1, 1) b.badge:Hide() b.badgeText:SetText("") end)

-- a paperdoll item slot: icon, quality glow, gem dots, enchant dot, and the empty-slot picture
K.define("slot", function()
  local b = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
  b:SetSize(40, 40)
  b:SetBackdrop({ bgFile = K.WHITE8, edgeFile = K.WHITE8, edgeSize = 2, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.glow = b:CreateTexture(nil, "OVERLAY")
  b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  b.glow:SetBlendMode("ADD")
  b.glow:SetPoint("CENTER")
  b.glow:SetSize(72, 72)
  b.dots = {}
  for i = 1, 4 do
    local d = b:CreateTexture(nil, "OVERLAY", nil, 2)
    d:SetSize(7, 7)
    d:SetPoint("BOTTOMLEFT", 3 + (i - 1) * 8, 3)
    b.dots[i] = d
  end
  b.ench = b:CreateTexture(nil, "OVERLAY", nil, 2)
  b.ench:SetSize(7, 7)
  b.ench:SetPoint("TOPRIGHT", -3, -3)
  b.ench:SetColorTexture(0.12, 1, 0, 1)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  return b
end, function(b)
  b.glow:Hide() b.ench:Hide()
  for i = 1, 4 do b.dots[i]:Hide() end
  b.icon:SetDesaturated(false) b.icon:SetAlpha(1) b.icon:SetTexCoord(0, 1, 0, 1)
end)

-- two texts on one line: a label and a value
K.define("kv", function()
  local f = CreateFrame("Frame", nil, UIParent)
  f.k = fs(f, "GameFontNormal")
  f.k:SetPoint("TOPLEFT")
  f.v = fs(f, "GameFontHighlight")
  f.v:SetJustifyH("RIGHT")
  f.v:SetPoint("TOPRIGHT")
  f:SetHeight(16)
  return f
end, function(f)
  f.k:SetFontObject("GameFontNormal") f.v:SetFontObject("GameFontHighlight")
  f.k:SetTextColor(K.rgb(K.GOLD)) f.v:SetTextColor(1, 1, 1)
  f.k:SetText("") f.v:SetText("")
end)

-- a small card with a heading, a big number and a line under it
K.define("card", function()
  local b = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
  b:SetBackdrop(K.INSET)
  b.l = fs(b, "GameFontNormalSmall") b.l:SetJustifyH("CENTER") b.l:SetPoint("TOP", 0, -6)
  b.n = fs(b, "GameFontHighlightLarge") b.n:SetJustifyH("CENTER") b.n:SetPoint("TOP", 0, -20)
  b.s = fs(b, "GameFontHighlightSmall") b.s:SetJustifyH("CENTER") b.s:SetPoint("TOP", 0, -40)
  b:SetHeight(56)
  return b
end, function(b)
  b:SetBackdropColor(0, 0, 0, 0.45) b:SetBackdropBorderColor(0.42, 0.33, 0.19, 1)
  b.n:SetFontObject("GameFontHighlightLarge")
  b.l:ClearAllPoints() b.l:SetPoint("TOP", 0, -6)
  b.n:ClearAllPoints() b.n:SetPoint("TOP", 0, -20)
  b.s:ClearAllPoints() b.s:SetPoint("TOP", 0, -40)
  b.l:SetText("") b.n:SetText("") b.s:SetText("")
  b.l:SetTextColor(1, 0.82, 0) b.s:SetTextColor(1, 1, 1) b.n:SetTextColor(1, 1, 1)
  b:Enable()
end)

-- a race portrait in a gold ring
K.define("portrait", function()
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(68, 68)
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetPoint("TOPLEFT", 4, -4)
  f.tex:SetPoint("BOTTOMRIGHT", -4, 4)
  f.ring = f:CreateTexture(nil, "OVERLAY")
  f.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  f.ring:SetTexCoord(0, 0.6, 0, 0.6)
  f.ring:SetAllPoints()
  return f
end)

-- the "Uncrushable / Crushable" box
K.define("verdict", function()
  local f = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
  f:SetBackdrop(K.INSET)
  f.big = fs(f, "GameFontNormalLarge") f.big:SetJustifyH("CENTER") f.big:SetPoint("TOPLEFT", 6, -7) f.big:SetPoint("TOPRIGHT", -6, -7)
  f.num = fs(f, "GameFontHighlightLarge") f.num:SetJustifyH("CENTER")
  f.of = fs(f, "GameFontHighlightSmall") f.of:SetJustifyH("CENTER")
  return f
end, function(f) f.num:SetText("") f.of:SetText("") f:Enable() end)

function K.setVerdict(f, ok, big, num, of, width)
  f:SetWidth(width)
  f:SetBackdropColor(ok and 0.05 or 0.25, ok and 0.2 or 0.04, ok and 0.03 or 0.03, 0.85)
  f:SetBackdropBorderColor(ok and 0.12 or 1, ok and 0.7 or 0.25, ok and 0.1 or 0.2, 1)
  f.big:SetText(big)
  f.big:SetTextColor(ok and 0.12 or 1, ok and 1 or 0.35, ok and 0 or 0.3)
  local y = -27
  f.num:ClearAllPoints() f.of:ClearAllPoints()
  if num and num ~= "" then
    f.num:SetText(num)
    f.num:SetPoint("TOPLEFT", 6, y) f.num:SetPoint("TOPRIGHT", -6, y)
    y = y - 20
  else
    f.num:SetText("")
  end
  f.of:SetText(of or "")
  f.of:SetPoint("TOPLEFT", 8, y) f.of:SetPoint("TOPRIGHT", -8, y)
  f.of:SetWidth(width - 16)
  f:SetHeight(-y + f.of:GetStringHeight() + 8)
  return f:GetHeight()
end

-- the attack table bar: one coloured piece per slice
K.define("bar", function()
  local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  f:SetBackdrop(K.FLAT)
  f:SetBackdropColor(0, 0, 0, 1)
  f:SetBackdropBorderColor(0.42, 0.33, 0.19, 1)
  f.parts = {}
  for i = 1, 7 do f.parts[i] = f:CreateTexture(nil, "ARTWORK") end
  f:SetHeight(16)
  return f
end)

-- a text box
K.define("edit", function()
  local e = CreateFrame("EditBox", nil, UIParent, "InputBoxTemplate")
  e:SetAutoFocus(false)
  e:SetHeight(22)
  e:SetFontObject("GameFontHighlight")
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  return e
end, function(e) e:SetScript("OnTextChanged", nil) e:SetScript("OnEnterPressed", nil) e:SetText("") e:SetMaxLetters(0) e:ClearFocus() end)

-- a horizontal slider
K.define("slider", function()
  local s = CreateFrame("Slider", nil, UIParent, "BackdropTemplate")
  s:SetOrientation("HORIZONTAL")
  s:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 } })
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  s:SetHeight(17)
  s:EnableMouse(true)
  s:SetObeyStepOnDrag(true)
  return s
end, function(s) s:SetScript("OnValueChanged", nil) s:SetScript("OnMouseUp", nil) end)

-- a talent button: icon, gold or green ring, rank badge
K.define("talent", function()
  local b = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
  b:SetSize(38, 38)
  b:SetBackdrop({ bgFile = K.WHITE8, edgeFile = K.WHITE8, edgeSize = 2, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.rankBg = b:CreateTexture(nil, "OVERLAY")
  b.rankBg:SetColorTexture(0, 0, 0, 0.85)
  b.rankBg:SetPoint("BOTTOMRIGHT", 6, -6)
  b.rankBg:SetSize(26, 13)
  b.rank = fs(b, "GameFontHighlightSmall", "OVERLAY")
  b.rank:SetJustifyH("CENTER")
  b.rank:SetPoint("CENTER", b.rankBg, "CENTER", 0, 0)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  return b
end, function(b) b.icon:SetDesaturated(false) b.icon:SetVertexColor(1, 1, 1) b.rank:SetText("") b.rankBg:Hide() end)

-- a talent arrow piece (a line with an arrow head)
K.define("arrow", function()
  local f = CreateFrame("Frame", nil, UIParent)
  f.line = f:CreateTexture(nil, "ARTWORK")
  f.line:SetAllPoints()
  f.head = f:CreateTexture(nil, "OVERLAY")
  f.head:SetTexture("Interface\\TalentFrame\\UI-TalentArrows")
  f.head:SetSize(24, 24)
  return f
end)

-- a statistics box with a drop-down at the top (the character pane's stat panels)
K.define("statbox", function()
  local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  f:SetBackdrop(K.INSET)
  f:SetBackdropColor(0, 0, 0, 0.5)
  f:SetBackdropBorderColor(0.42, 0.33, 0.19, 1)
  f.drop = CreateFrame("Button", nil, f, "BackdropTemplate")
  f.drop:SetBackdrop(K.INSET)
  f.drop:SetBackdropColor(0.11, 0.09, 0.07, 1)
  f.drop:SetBackdropBorderColor(0.42, 0.33, 0.19, 1)
  f.drop:SetPoint("TOPLEFT", 6, -6)
  f.drop:SetPoint("TOPRIGHT", -6, -6)
  f.drop:SetHeight(20)
  f.drop.text = fs(f.drop, "GameFontNormal")
  f.drop.text:SetPoint("LEFT", 8, 0)
  f.drop.text:SetJustifyV("MIDDLE")
  f.drop.caret = fs(f.drop, "GameFontNormal")
  f.drop.caret:SetText("v")
  f.drop.caret:SetPoint("RIGHT", -6, 0)
  f.drop:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  f.k, f.v = {}, {}
  for i = 1, 8 do
    f.k[i] = fs(f, "GameFontNormalSmall")
    f.k[i]:SetPoint("TOPLEFT", 8, -32 - (i - 1) * 14)
    f.v[i] = fs(f, "GameFontHighlightSmall")
    f.v[i]:SetJustifyH("RIGHT")
    f.v[i]:SetPoint("TOPRIGHT", -8, -32 - (i - 1) * 14)
  end
  return f
end, function(f) for i = 1, 8 do f.k[i]:SetText("") f.v[i]:SetText("") f.v[i]:SetTextColor(1, 1, 1) end end)

-- an inline item tooltip (the game's own, drawn inside a panel)
local tipN = 0
K.define("tip", function()
  tipN = tipN + 1
  local t = CreateFrame("GameTooltip", "TBCrushCalcTip" .. tipN, UIParent, "GameTooltipTemplate")
  return t
end, function(t) t:ClearLines() t:SetScript("OnSizeChanged", nil) end)

---------------------------------------------------------------------- vertical flow layout
local Flow = {}
Flow.__index = Flow

--- lays widgets out top to bottom inside `parent`, `width` wide, starting `x`, `y` from its top-left
function K.flow(owner, parent, x, y, width)
  return setmetatable({ owner = owner, parent = parent, x = x, y = y or 0, width = width, top = y or 0 }, Flow)
end

function Flow:place(w, h, dx, width)
  w:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x + (dx or 0), -self.y)
  if width then w:SetWidth(width) end
  if h then w:SetHeight(h) end
  self.y = self.y + (h or w:GetHeight())
  return w
end
function Flow:gap(n) self.y = self.y + (n or 6) return self end
function Flow:height() return self.y - self.top end

--- a paragraph of text; returns the label
function Flow:text(text, opts)
  opts = opts or {}
  local l = K.get(self.owner, "label", self.parent)
  l.text:SetFontObject(opts.font or "GameFontHighlight")
  local c = opts.color or K.TEXT
  l.text:SetTextColor(c[1], c[2], c[3])
  l.text:SetJustifyH(opts.justify or "LEFT")
  l.text:SetWordWrap(true)
  l.text:SetText(text)
  local w = opts.width or self.width
  l:SetWidth(w)
  l.text:SetWidth(w)
  local h = max(l.text:GetStringHeight(), 1) + 2
  self:place(l, h, opts.dx)
  if opts.gap ~= false then self:gap(opts.gap or 4) end
  return l
end
function Flow:note(text, color) return self:text(text, { font = "GameFontHighlightSmall", color = color or K.SUB, gap = 5 }) end

--- a framed panel with a title; `fill(flow)` lays out its contents; returns the panel
function Flow:panel(title, fill)
  local p = K.get(self.owner, "panel", self.parent)
  p.title:SetText(title)
  p.plate:SetShown(title ~= nil and title ~= "")
  p:SetWidth(self.width)
  local inner = K.flow(self.owner, p, 12, (title and title ~= "") and 24 or 12, self.width - 24)
  fill(inner)
  local h = inner.y + 10
  self:gap(title and 14 or 4)
  self:place(p, h)
  self:gap(10)
  return p
end

--- a row of chips (or other fixed-size buttons) that wraps onto more lines
function Flow:chips(list, opts)
  opts = opts or {}
  local x, rowH = 0, 0
  local lineY = self.y
  for _, c in ipairs(list) do
    local b
    if c.plain then
      b = K.get(self.owner, "label", self.parent)
      b.text:SetFontObject("GameFontNormalSmall")
      b.text:SetTextColor(K.rgb(K.GOLD))
      b.text:SetJustifyV("MIDDLE")
      b.text:SetText(c.label)
      b:SetSize(b.text:GetStringWidth() + 4, 20)
    else
      b = K.get(self.owner, "chip", self.parent)
      K.setChip(b, c.label, c.on)
      if c.width then b:SetWidth(c.width) end
    end
    local w = b:GetWidth()
    if x > 0 and x + w > self.width then x = 0 lineY = lineY + rowH + 4 rowH = 0 end
    b:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x + x, -lineY)
    if not c.plain then b:SetScript("OnClick", c.click) end
    if c.tip then tooltipOn(b, function(tt) tt:SetText(c.tip, 1, 1, 1, 1, true) end) end
    x = x + w + 4
    rowH = max(rowH, b:GetHeight())
  end
  self.y = lineY + rowH + (opts.gap or 6)
  return self
end

--- red panel buttons in a row, right-aligned (or centered)
function Flow:buttons(list, align)
  local widths, total = {}, 0
  local made = {}
  for i, c in ipairs(list) do
    local b = K.get(self.owner, "button", self.parent)
    b:SetText(c.label)
    local w = c.width or max(80, b:GetFontString():GetStringWidth() + 28)
    b:SetWidth(w)
    widths[i] = w
    total = total + w + (i > 1 and 6 or 0)
    if c.disabled then b:Disable() end
    b:SetScript("OnClick", c.click)
    made[i] = b
  end
  local x = align == "center" and floor((self.width - total) / 2) or align == "left" and 0 or self.width - total
  for i, b in ipairs(made) do
    b:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x + x, -self.y)
    x = x + widths[i] + 6
  end
  self.y = self.y + 24 + 6
  return made
end

--- label / value lines
function Flow:kv(pairsList, opts)
  for _, pr in ipairs(pairsList) do
    if pr then
      local f = K.get(self.owner, "kv", self.parent)
      if opts and opts.small then f.k:SetFontObject("GameFontNormalSmall") f.v:SetFontObject("GameFontHighlightSmall") end
      f.k:SetText(pr[1])
      f.v:SetText(pr[2])
      if pr[3] then f.v:SetTextColor(pr[3][1], pr[3][2], pr[3][3]) end
      if pr[4] then f.k:SetTextColor(pr[4][1], pr[4][2], pr[4][3]) end
      f:SetWidth(self.width - ((opts and opts.indent) or 0))
      self:place(f, (opts and opts.small) and 14 or 17, opts and opts.indent)
    end
  end
  return self
end

---------------------------------------------------------------------- scroll areas
--- a scroll frame with a child to draw into; the mouse wheel scrolls it and a thin bar shows where you are
function K.scroller(parent)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(10, 10)
  sf:SetScrollChild(child)
  sf:EnableMouseWheel(true)
  local track = sf:CreateTexture(nil, "OVERLAY")
  track:SetColorTexture(1, 1, 1, 0.06)
  track:SetPoint("TOPRIGHT", 0, 0)
  track:SetPoint("BOTTOMRIGHT", 0, 0)
  track:SetWidth(4)
  local thumb = sf:CreateTexture(nil, "OVERLAY", nil, 1)
  thumb:SetColorTexture(1, 0.82, 0, 0.55)
  thumb:SetWidth(4)
  sf.child, sf.track, sf.thumb = child, track, thumb
  local function update()
    local range = sf:GetVerticalScrollRange()
    local hgt = sf:GetHeight()
    if range <= 0 or hgt <= 0 then thumb:Hide() track:Hide() return end
    thumb:Show() track:Show()
    local th = max(20, hgt * hgt / (hgt + range))
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, -(hgt - th) * (sf:GetVerticalScroll() / range))
  end
  sf.updateBar = update
  sf:SetScript("OnMouseWheel", function(self, delta)
    local v = self:GetVerticalScroll() - delta * 48
    v = max(0, min(v, self:GetVerticalScrollRange()))
    self:SetVerticalScroll(v)
    update()
  end)
  sf:SetScript("OnVerticalScroll", function() update() end)
  sf:SetScript("OnSizeChanged", function(self, w) child:SetWidth(w) update() end)
  --- sets the content height, keeps the scroll position when it can
  function sf:setContentHeight(h, keep)
    child:SetHeight(max(h, 1))
    child:SetWidth(self:GetWidth())
    self:UpdateScrollChildRect()
    local v = keep and min(self:GetVerticalScroll(), self:GetVerticalScrollRange()) or 0
    self:SetVerticalScroll(max(0, v))
    update()
  end
  return sf
end
