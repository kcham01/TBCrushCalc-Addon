-- Talent tree rules as in the game: 61 points at level 70, 5 points in a tree per row to unlock the
-- next row, and a talent with an arrow needs the one it points from at full rank. Trees are numbered
-- from 0 in the saved keys ("1.holyShield"), as in the app, so share codes work in both.
local _, T = ...
local TR = {}
T.TR = TR

TR.MAX_POINTS = 61

function TR.key(tree, t) return tree .. "." .. t.f end
local function rank(m, k) return tonumber(m[k]) or 0 end

function TR.spent(m) local n = 0 for _, v in pairs(m) do n = n + (tonumber(v) or 0) end return n end
function TR.treeSpent(cls, m, tree)
  local n = 0
  for _, t in ipairs(T.TALENTS[cls][tree + 1].talents) do n = n + rank(m, TR.key(tree, t)) end
  return n
end
--- points spent in a tree in rows above `row`
local function spentAbove(cls, m, tree, row)
  local n = 0
  for _, t in ipairs(T.TALENTS[cls][tree + 1].talents) do if t.r < row then n = n + rank(m, TR.key(tree, t)) end end
  return n
end
function TR.prereq(cls, tree, t)
  if not t.req then return nil end
  for _, x in ipairs(T.TALENTS[cls][tree + 1].talents) do
    if x.r == t.req[1] and x.c == t.req[2] then return x end
  end
  return nil
end

function TR.unlocked(cls, m, tree, t)
  if spentAbove(cls, m, tree, t.r) < t.r * 5 then return false end
  local pre = TR.prereq(cls, tree, t)
  if pre and rank(m, TR.key(tree, pre)) < pre.max then return false end
  return true
end
function TR.canAdd(cls, m, tree, t)
  return rank(m, TR.key(tree, t)) < t.max and TR.spent(m) < TR.MAX_POINTS and TR.unlocked(cls, m, tree, t)
end

--- every talent with points must still be unlocked
function TR.valid(cls, m)
  if TR.spent(m) > TR.MAX_POINTS then return false end
  for ti, tree in ipairs(T.TALENTS[cls]) do
    for _, t in ipairs(tree.talents) do
      local r = rank(m, TR.key(ti - 1, t))
      if r > t.max then return false end
      if r > 0 and not TR.unlocked(cls, m, ti - 1, t) then return false end
    end
  end
  return true
end
function TR.canRemove(cls, m, tree, t)
  local k = TR.key(tree, t)
  if not (rank(m, k) > 0) then return false end
  local nextM = {}
  for kk, v in pairs(m) do nextM[kk] = v end
  nextM[k] = rank(m, k) - 1
  return TR.valid(cls, nextM)
end
