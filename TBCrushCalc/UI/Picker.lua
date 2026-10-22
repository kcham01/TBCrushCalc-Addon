-- Searchable lists in a panel (consumables, bosses, gems, enchants), list rows, drop-down rows and inline
-- item tooltips: the app's ui/picker.ts.
local _, T = ...
local U, K = T.U, T.K

local max, min = math.max, math.min

--- one list row. o = { ic, name, color, sub, sub2, sub3 (red), right, right2, quality, selected, disabled, onClick, info, tip, iconSize }
function T.listRow(f, o)
  local r = K.get(f.owner, "row", f.parent)
  local iconSize = o.iconSize or 30
  local x = 6
  if o.ic ~= nil then
    r.icon:SetTexture(o.icon or T.icon(o.ic))
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    K.placeIcon(r, 5, -5, iconSize)
    x = iconSize + 12
    if o.quality then
      local c = T.QUALITY_COLOR[o.quality + 1] or "#ffffff"
      r.qual:Show()
      r.qual:ClearAllPoints()
      r.qual:SetPoint("TOPLEFT", r.border, "TOPLEFT", -1, 1)
      r.qual:SetPoint("BOTTOMRIGHT", r.border, "BOTTOMRIGHT", 1, -1)
      r.qual:SetColorTexture(U.hex(c))
    end
  else
    r.icon:Hide() r.border:Hide()
  end
  local rightW = 0
  if o.right then
    r.right:SetText(o.right)
    rightW = max(rightW, r.right:GetStringWidth())
  end
  if o.right2 then r.right2:SetText(o.right2) rightW = max(rightW, r.right2:GetStringWidth()) end
  local infoW = o.info and 26 or 0
  local textW = f.width - x - 8 - (rightW > 0 and rightW + 8 or 0) - infoW
  local y = -5
  local function line(fs, text, color)
    if not text or text == "" then return end
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(textW)
    fs:SetText(text)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    y = y - fs:GetStringHeight() - 1
  end
  line(r.name, o.name, o.color and { U.hex(o.color) } or nil)
  line(r.sub, o.sub)
  line(r.sub2, o.sub2)
  line(r.sub3, o.sub3)
  if o.right then r.right:SetPoint("TOPRIGHT", -(8 + infoW), -6) end
  if o.right2 then r.right2:SetPoint("TOPRIGHT", -(8 + infoW), -20) end
  local h = max(-y + 5, (o.ic ~= nil) and iconSize + 10 or 24)
  if o.selected then
    r:SetBackdropColor(1, 0.82, 0, 0.14) r:SetBackdropBorderColor(1, 0.82, 0, 0.45)
  else
    r:SetBackdropColor(0, 0, 0, 0.28) r:SetBackdropBorderColor(0, 0, 0, 0)
  end
  if o.disabled then
    r.name:SetTextColor(0.62, 0.62, 0.62)
    r.icon:SetDesaturated(true)
  else
    r.icon:SetDesaturated(false)
  end
  if o.info then
    r.info:Show()
    r.info:SetPoint("TOPRIGHT", -5, -5)
    r.info:SetScript("OnClick", o.info)
  end
  r:SetScript("OnClick", o.onClick)
  if o.tip then K.tooltipOn(r, o.tip) end
  f:place(r, h, 0, f.width)
  f:gap(3)
  return r
end

--- a row showing the current choice that opens a picker when clicked
function T.selectRow(f, label, value, onTap, disabled)
  local b = K.get(f.owner, "selrow", f.parent)
  b.label:SetText(label)
  b.label:SetHeight(32)
  if value then
    b.icon:SetTexture(value.icon or T.icon(value.ic))
    b.icon:SetTexCoord(value.coord and value.coord[1] or 0.07, value.coord and value.coord[2] or 0.93, value.coord and value.coord[3] or 0.07, value.coord and value.coord[4] or 0.93)
    b.icon:Show() b.border:Show()
  else
    b.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    b.icon:SetTexCoord(0, 1, 0, 1)
  end
  if disabled then
    b.name:SetText(disabled)
    b.name:SetTextColor(0.62, 0.62, 0.62)
    b.sub:SetText("")
    b:SetAlpha(0.6)
    b:SetScript("OnClick", function() T.toast(disabled) end)
  else
    b.name:SetText(value and value.name or "None")
    if value and value.color then b.name:SetTextColor(U.hex(value.color)) end
    b.sub:SetText(value and value.sub or "")
    b:SetScript("OnClick", onTap)
  end
  local h = (value and value.sub and value.sub ~= "" and not disabled) and 36 or 36
  f:place(b, h, 0, f.width)
  f:gap(4)
  return b
end

--- a search box that keeps its text and focus when the panel redraws
function T.searchBox(f, state, placeholder, onChange)
  local e = K.get(f.owner, "edit", f.parent)
  f:place(e, 22, 6, f.width - 12)
  e:SetText(state.q or "")
  local hint = K.get(f.owner, "label", f.parent)
  hint.text:SetFontObject("GameFontDisableSmall")
  hint.text:SetText(placeholder or "Search")
  hint:SetPoint("LEFT", e, "LEFT", 4, 0)
  hint:SetSize(f.width - 30, 14)
  hint.text:SetJustifyV("MIDDLE")
  hint:SetShown((state.q or "") == "")
  local seq = 0
  e:SetScript("OnTextChanged", function(self, user)
    hint:SetShown(self:GetText() == "")
    if not user then return end
    state.q = self:GetText()
    state.focus = true
    seq = seq + 1
    local mine = seq
    C_Timer.After(0.15, function() if mine == seq then onChange() end end)
  end)
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() state.focus = false end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() state.focus = false end)
  if state.focus then K.refocus(e) end
  f:gap(6)
  return e
end

--- the searchable picker (the app's pickFrom). o = { title, rows, selected, none, placeholder, note, chips, filter, onPick }
--- rows: { key, name, ic, color, sub, sub2, right, group, disabled, search, info }
function T.pickFrom(o)
  local state = { q = "", limit = 150 }
  return T.openSheet(o.title, function(f, h)
    T.searchBox(f, state, o.placeholder or "Search", function() state.limit = 150 h.redraw() end)
    if o.note then f:note(o.note) end
    if o.chips and #o.chips > 0 then
      local list = {}
      for _, c in ipairs(o.chips) do
        list[#list + 1] = { label = c.label, on = c.on(), click = function() c.toggle() state.limit = 150 h.redraw(true) end }
      end
      f:chips(list)
    end
    if o.none then
      T.listRow(f, { ic = "", icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up", name = o.none, selected = o.selected == nil,
        onClick = function() h.close() o.onPick(nil) end })
    end
    local words = {}
    for w in (state.q or ""):lower():gmatch("%S+") do words[#words + 1] = w end
    local shown = {}
    for _, r in ipairs(o.rows) do
      if not o.filter or o.filter(r) then
        local hay = (r.name .. " " .. (r.sub or "") .. " " .. (r.sub2 or "") .. " " .. (r.group or "") .. " " .. (r.search or "")):lower()
        local ok = true
        for _, w in ipairs(words) do if not hay:find(w, 1, true) then ok = false break end end
        if ok then shown[#shown + 1] = r end
      end
    end
    local group
    for i = 1, min(#shown, state.limit) do
      local r = shown[i]
      if r.group and r.group ~= group then
        group = r.group
        f:gap(4)
        f:text(r.group:upper(), { font = "GameFontNormalSmall", color = K.GOLD, gap = 2 })
      end
      T.listRow(f, {
        ic = r.ic, icon = r.icon, name = r.name, color = r.disabled and "#9d9d9d" or r.color, sub = r.sub, sub2 = r.sub2, sub3 = r.disabled,
        right = r.right, selected = o.selected ~= nil and r.key == o.selected, disabled = r.disabled ~= nil,
        info = r.info and function() T.openSheet(r.name, function(ff) r.info(ff) end) end or nil,
        tip = r.tip,
        onClick = function()
          if r.disabled then T.toast(r.disabled) return end
          h.close()
          o.onPick(r.key)
        end,
      })
    end
    if #shown == 0 then f:text("Nothing matches.", { color = K.SUB, justify = "CENTER" }) end
    if #shown > state.limit then
      f:buttons({ { label = ("Show more (%d)"):format(#shown - state.limit), click = function() state.limit = state.limit + 300 h.redraw(true) end } }, "center")
    end
  end, { full = true })
end

---------------------------------------------------------------------- item tooltips inside a panel
--- the game's own tooltip for an item (with its gems and enchant), drawn in place; returns its height
function T.inlineItemTip(f, piece, extraLines, redraw)
  local tip = K.get(f.owner, "tip", f.parent)
  tip:SetOwner(f.parent, "ANCHOR_NONE")
  tip:ClearAllPoints()
  tip:SetPoint("TOPLEFT", f.parent, "TOPLEFT", f.x, -f.y)
  tip:SetHyperlink(T.itemString(piece))
  local e = piece.ench and T.ENCHANT_BY_ID[piece.ench]
  if e and not e.eff then
    -- the game only knows its own enchant ids; for the rest, show the enchant as the app does
    tip:AddLine("Enchanted: " .. T.enchantText(e), 0.12, 1, 0, true)
  end
  for _, l in ipairs(extraLines or {}) do tip:AddLine(l[1], l[2], l[3], l[4], true) end
  tip:SetMinimumWidth(f.width)
  tip:Show()
  local h = tip:GetHeight()
  if not h or h < 20 then h = 20 + tip:NumLines() * 14 end
  -- the game may still be fetching the item: when its tooltip fills in and grows, lay the panel out again
  tip.usedH = h
  tip:SetScript("OnSizeChanged", function(self, _, newH)
    if redraw and self.usedH and math.abs((newH or 0) - self.usedH) > 2 then
      self.usedH = nil
      C_Timer.After(0, function() redraw(true) end)
    end
  end)
  f.y = f.y + h + 6
  return tip
end

--- tooltips for things shown on hover
function T.itemTip(piece) return function(tt) tt:SetHyperlink(T.itemString(piece)) end end
function T.gemTip(id) return function(tt) tt:SetHyperlink("item:" .. id) end end
