-- The Talents screen, like the game's talent frame: one tree at a time, 4 columns, arrows for
-- prerequisites, rank badges, and the tree tabs along the bottom (the app's ui/talents.ts).
local _, T = ...
local U, E, K, TR = T.U, T.E, T.K, T.TR
local S = T.S

local floor, max = math.floor, math.max

local PITCH_Y = 48
local ICON = 38
local BACKGROUND = {
  Arms = "WarriorArms", Fury = "WarriorFury", Protection = { warrior = "WarriorProtection", paladin = "PaladinProtection" },
  Holy = "PaladinHoly", Retribution = "PaladinCombat", Balance = "DruidBalance", ["Feral Combat"] = "DruidFeralCombat", Restoration = "DruidRestoration",
}

K.define("treeart", function()
  local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  f:SetBackdrop(K.INSET)
  f.tl = f:CreateTexture(nil, "BACKGROUND")
  f.tr = f:CreateTexture(nil, "BACKGROUND")
  f.bl = f:CreateTexture(nil, "BACKGROUND")
  f.br = f:CreateTexture(nil, "BACKGROUND")
  f.shade = f:CreateTexture(nil, "BORDER")
  f.shade:SetAllPoints()
  f.shade:SetColorTexture(0, 0, 0, 0.35)
  return f
end)

--- the talent's text for a tooltip: rank, requirements, this rank and the next
local function talentLines(t, rank, req)
  local out = { { t.n, 1, 1, 1 }, { ("Rank %d/%d"):format(rank, t.max), 1, 1, 1 } }
  for _, r in ipairs(req) do out[#out + 1] = { r, 1, 0.13, 0.13 } end
  if rank > 0 then out[#out + 1] = { t.d[rank] or "", 1, 0.82, 0 } end
  if rank < t.max then
    if rank > 0 then out[#out + 1] = { " ", 1, 1, 1 } out[#out + 1] = { "Next rank:", 1, 1, 1 } end
    out[#out + 1] = { t.d[rank + 1] or t.d[1] or "", 1, 0.82, 0 }
  end
  return out
end

local function requirements(p, ti, tree, t)
  local req = {}
  local above = 0
  for _, x in ipairs(tree.talents) do if x.r < t.r then above = above + (tonumber(p.talents[TR.key(ti, x)]) or 0) end end
  if above < t.r * 5 then req[#req + 1] = ("Requires %d points in %s Talents"):format(t.r * 5, tree.name) end
  local pre = TR.prereq(p.cls, ti, t)
  if pre and (tonumber(p.talents[TR.key(ti, pre)]) or 0) < pre.max then
    req[#req + 1] = ("Requires %d point%s in %s"):format(pre.max, pre.max > 1 and "s" or "", pre.n)
  end
  return req
end

function T.talentsView(flow, p)
  local trees = T.TALENTS[p.cls]
  local pts = E.treePoints(p)
  if S.tree < 0 or S.tree >= #trees then
    local best, bi = -1, 0
    for i, n in ipairs(pts) do if n > best then best, bi = n, i - 1 end end
    S.tree = bi
  end
  local ti = S.tree
  local tree = trees[ti + 1]
  local left = TR.MAX_POINTS - TR.spent(p.talents)

  flow:panel("Talents", function(f)
    local head = K.get(f.owner, "kv", f.parent)
    head.k:SetText(("%s: %d"):format(tree.name, pts[ti + 1]))
    head.v:SetText("Points left: " .. left)
    if left > 0 then head.v:SetTextColor(0.12, 1, 0) else head.v:SetTextColor(1, 0.82, 0) end
    head:SetWidth(f.width)
    f:place(head, 18)
    f:gap(4)

    local rows = 0
    for _, t in ipairs(tree.talents) do rows = max(rows, t.r + 1) end
    rows = max(rows, 9)
    local gridH = rows * PITCH_Y + 10
    local art = K.get(f.owner, "treeart", f.parent)
    art:SetPoint("TOPLEFT", f.parent, "TOPLEFT", f.x, -f.y)
    art:SetSize(f.width, gridH)
    local bg = BACKGROUND[tree.name]
    if type(bg) == "table" then bg = bg[p.cls] end
    local base = "Interface\\TalentFrame\\" .. (bg or "WarriorArms")
    local wA, hA = f.width * 0.8, gridH * 0.66
    art.tl:SetTexture(base .. "-TopLeft") art.tl:SetPoint("TOPLEFT", 3, -3) art.tl:SetSize(wA, hA)
    art.tr:SetTexture(base .. "-TopRight") art.tr:SetPoint("TOPLEFT", art.tl, "TOPRIGHT") art.tr:SetSize(f.width - 6 - wA, hA)
    art.tr:SetTexCoord(0, 1, 0, 1)
    art.bl:SetTexture(base .. "-BottomLeft") art.bl:SetPoint("TOPLEFT", art.tl, "BOTTOMLEFT") art.bl:SetSize(wA, gridH - 6 - hA)
    art.br:SetTexture(base .. "-BottomRight") art.br:SetPoint("TOPLEFT", art.tl, "BOTTOMRIGHT") art.br:SetSize(f.width - 6 - wA, gridH - 6 - hA)
    art.tl:SetTexCoord(0, 1, 0, 1) art.bl:SetTexCoord(0, 1, 0, 1) art.br:SetTexCoord(0, 1, 0, 1)

    local colW = f.width / 4
    local function cx(c) return floor(colW * (c + 0.5)) end
    local function cy(r) return 8 + r * PITCH_Y + ICON / 2 end
    -- arrows first so the icons sit on top of them
    for _, t in ipairs(tree.talents) do
      if t.req then
        local pre = TR.prereq(p.cls, ti, t)
        local on = pre and (tonumber(p.talents[TR.key(ti, pre)]) or 0) >= pre.max
        local a = K.get(f.owner, "arrow", art)
        a.line:SetColorTexture(on and 1 or 0.45, on and 0.82 or 0.45, on and 0 or 0.45, 0.9)
        if pre.c == t.c then
          local top, bottom = cy(pre.r) + ICON / 2 + 2, cy(t.r) - ICON / 2 - 2
          a:SetPoint("TOPLEFT", art, "TOPLEFT", cx(t.c) - 2, -top)
          a:SetSize(4, max(2, bottom - top))
          a.head:ClearAllPoints()
          a.head:SetPoint("CENTER", a, "BOTTOM", 0, 2)
          local c = TALENT_ARROW_TEXTURECOORDS.top[on and 1 or -1]
          a.head:SetTexCoord(c[1], c[2], c[3], c[4])
        else
          local l, r = math.min(pre.c, t.c), math.max(pre.c, t.c)
          local x1, x2 = cx(l) + ICON / 2 + 2, cx(r) - ICON / 2 - 2
          a:SetPoint("TOPLEFT", art, "TOPLEFT", x1, -(cy(t.r) - 2))
          a:SetSize(max(2, x2 - x1), 4)
          a.head:ClearAllPoints()
          if t.c > pre.c then
            a.head:SetPoint("CENTER", a, "RIGHT", -2, 0)
            local c = TALENT_ARROW_TEXTURECOORDS.right[on and 1 or -1]
            a.head:SetTexCoord(c[1], c[2], c[3], c[4])
          else
            a.head:SetPoint("CENTER", a, "LEFT", 2, 0)
            local c = TALENT_ARROW_TEXTURECOORDS.left[on and 1 or -1]
            a.head:SetTexCoord(c[1], c[2], c[3], c[4])
          end
        end
      end
    end
    for _, t in ipairs(tree.talents) do
      local rank = tonumber(p.talents[TR.key(ti, t)]) or 0
      local open = TR.unlocked(p.cls, p.talents, ti, t)
      local state = rank >= t.max and "maxed" or ((open and left > 0) and "avail" or (rank > 0 and "avail" or "locked"))
      local b = K.get(f.owner, "talent", art)
      b:SetFrameLevel(art:GetFrameLevel() + 3)
      b:SetPoint("TOPLEFT", art, "TOPLEFT", cx(t.c) - ICON / 2, -(8 + t.r * PITCH_Y))
      b.icon:SetTexture(T.icon(t.ic))
      b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      if state == "maxed" then
        b:SetBackdropBorderColor(1, 0.82, 0, 1)
      elseif state == "avail" then
        b:SetBackdropBorderColor(0.12, 1, 0, 1)
      else
        b:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
        b.icon:SetDesaturated(true)
      end
      b:SetBackdropColor(0, 0, 0, 1)
      if rank > 0 or open then
        b.rankBg:Show()
        b.rank:SetText(rank .. "/" .. t.max)
        if state == "maxed" then b.rank:SetTextColor(1, 0.82, 0) elseif state == "avail" then b.rank:SetTextColor(0.12, 1, 0) else b.rank:SetTextColor(0.6, 0.6, 0.6) end
      end
      b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
          if TR.canRemove(p.cls, p.talents, ti, t) then
            local k = TR.key(ti, t)
            p.talents[k] = rank - 1
            if p.talents[k] == 0 then p.talents[k] = nil end
            T.commit()
          end
          return
        end
        T.openTalent(ti, t)
      end)
      K.tooltipOn(b, function(tt)
        local lines = talentLines(t, rank, requirements(p, ti, tree, t))
        tt:SetText(lines[1][1], 1, 1, 1)
        for i = 2, #lines do tt:AddLine(lines[i][1], lines[i][2], lines[i][3], lines[i][4], true) end
        tt:AddLine("Click for details. Right-click removes a point.", 0.5, 0.5, 0.5, true)
      end)
    end
    f.y = f.y + gridH + 8

    -- the tree tabs
    local tabs = {}
    local tw = floor((f.width - 8) / 3)
    for i, tr in ipairs(trees) do
      tabs[#tabs + 1] = { label = ("%s  %d"):format(tr.name, pts[i]), on = i - 1 == ti, width = tw, click = function() S.tree = i - 1 T.commit() end }
    end
    f:chips(tabs)
    f:buttons({
      { label = "Reset tree", click = function() T.confirmSheet("Reset tree", ("Remove all points from %s?"):format(tree.name), "Reset", function() T.resetTree(ti) end) end },
      { label = "Reset all", click = function() T.confirmSheet("Reset talents", "Remove every talent point?", "Reset", function() p.talents = {} T.commit() end) end },
    }, "center")
  end)
  flow:text(("%s: %s. Click a talent to see it and add or remove points."):format(p.name, table.concat(pts, " / ")), { font = "GameFontHighlightSmall", color = K.SUB, justify = "CENTER" })
end

function T.resetTree(ti)
  local p = T.cur()
  for k in pairs(p.talents) do if k:sub(1, #tostring(ti) + 1) == ti .. "." then p.talents[k] = nil end end
  T.commit()
end

function T.openTalent(ti, t)
  local p = T.cur()
  local tree = T.TALENTS[p.cls][ti + 1]
  T.openSheet(t.n, function(f, h)
    local k = TR.key(ti, t)
    local rank = tonumber(p.talents[k]) or 0
    local req = requirements(p, ti, tree, t)
    local ic = K.get(f.owner, "talent", f.parent)
    ic:SetPoint("TOPLEFT", f.parent, "TOPLEFT", f.x, -f.y)
    ic:SetSize(44, 44)
    ic.icon:SetTexture(T.icon(t.ic))
    ic.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    ic:SetBackdropBorderColor(0.48, 0.42, 0.32, 1)
    ic:SetScript("OnClick", nil)
    local inner = T.K.flow(f.owner, f.parent, f.x + 54, f.y, f.width - 54)
    for i, l in ipairs(talentLines(t, rank, req)) do
      inner:text(l[1], { font = i == 1 and "GameFontHighlightLarge" or "GameFontHighlight", color = { l[2], l[3], l[4] }, gap = 2 })
    end
    local spell = t.spells[math.max(1, math.min(#t.spells, rank))]
    if spell then
      inner:text(tree.name .. " - spell " .. spell, { font = "GameFontDisableSmall", gap = 2 })
    end
    f.y = math.max(f.y + 48, inner.y) + 8
    f:buttons({
      { label = "- Remove point", disabled = not TR.canRemove(p.cls, p.talents, ti, t), click = function()
        if not TR.canRemove(p.cls, p.talents, ti, t) then return end
        p.talents[k] = rank - 1
        if p.talents[k] == 0 then p.talents[k] = nil end
        T.commit() h.redraw()
      end },
      { label = "+ Add point", disabled = not TR.canAdd(p.cls, p.talents, ti, t), click = function()
        if not TR.canAdd(p.cls, p.talents, ti, t) then return end
        p.talents[k] = rank + 1
        T.commit() h.redraw()
      end },
    })
    if rank > 0 and not TR.canRemove(p.cls, p.talents, ti, t) then f:note("Other talents depend on this one, so its points can't come out yet.") end
    if TR.spent(p.talents) >= TR.MAX_POINTS and rank < t.max then f:note("All 61 points are spent.") end
    if spell then f:buttons({ { label = "Wowhead link", click = function() T.showUrl(t.n, T.wowheadSpellUrl(spell)) end } }, "left") end
  end)
end
