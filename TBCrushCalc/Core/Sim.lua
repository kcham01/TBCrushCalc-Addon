-- How well Holy Shield or Shield Block actually cover you: they only block a limited number of hits,
-- so a fast boss (or adds, or a second weapon) can use up the charges and land crushing blows. A small,
-- repeatable simulation of an hour of swings against the passive sheet plus the cooldown. Uses the same
-- random number generator (mulberry32) as the app, so both give the same numbers.
local _, T = ...
local E, U = T.E, T.U
local floor = math.floor
local TWO32 = 4294967296

-- 32-bit integer helpers with JavaScript's semantics, on whole numbers kept in 0 .. 2^32 - 1
local bxor, bor, rshift
if bit and bit.bxor then
  local b = bit
  bxor = function(x, y) return b.bxor(x, y) % TWO32 end
  bor = function(x, y) return b.bor(x, y) % TWO32 end
  rshift = function(x, n) return b.rshift(x, n) % TWO32 end
else
  local function op(x, y, fn)
    local r, p = 0, 1
    for _ = 1, 32 do
      local xa, ya = x % 2, y % 2
      if fn(xa, ya) then r = r + p end
      x, y, p = (x - xa) / 2, (y - ya) / 2, p * 2
    end
    return r
  end
  bxor = function(x, y) return op(x, y, function(a, b) return a ~= b end) end
  bor = function(x, y) return op(x, y, function(a, b) return a == 1 or b == 1 end) end
  rshift = function(x, n) return floor(x / 2 ^ n) end
end
--- Math.imul, as an unsigned result
local function imul(a, b)
  local al, ah = a % 65536, floor(a / 65536)
  local bl, bh = b % 65536, floor(b / 65536)
  return ((ah * bl + al * bh) % 65536 * 65536 + al * bl) % TWO32
end

local function rng(seed)
  local s = seed % TWO32
  return function()
    s = (s + 0x6D2B79F5) % TWO32
    local t = s
    t = imul(bxor(t, rshift(t, 15)), bor(t, 1))
    t = bxor(t, (t + imul(bxor(t, rshift(t, 7)), bor(t, 61))) % TWO32)
    return bxor(t, rshift(t, 14)) / TWO32
  end
end
T.rng = rng

--- `minutes` of the boss (and any extra attackers) hitting the tank while the cooldown is used whenever it is ready
function T.coverage(p, minutes)
  minutes = minutes or 60
  local passive = E.computeSheet(p, "passive")
  if not passive.canBlock then return nil end
  local ability, charges, duration, cooldown, bonus = "", 0, 0, 0, 0
  if p.cls == "paladin" and E.talentRank(p, "holyShield") > 0 then
    ability, charges, duration, cooldown, bonus = "Holy Shield", 4 + 2 * E.talentRank(p, "improvedHolyShield"), 10, 10, 30
    if passive.gear.libramOfRepentance then bonus = bonus + 42 / 7.8846 end
  elseif p.cls == "warrior" then
    local isb = E.talentRank(p, "improvedShieldBlock")
    ability, charges, duration, cooldown, bonus = "Shield Block", 1 + isb, 5 + isb, 5, 75
  else
    return nil
  end
  local bc = E.bossCtx(p)
  local swing = bc.swing
  local attackers = bc.attackers
  local d = bc.deficit
  local avoid = (passive.miss - d + bc.hitRed) + (passive.dodge - d) + (passive.canParry and passive.parry - d or 0)
  local blockBase = passive.block - d
  local critSlice = math.max(0, bc.critBase - passive.critReduction)
  local rand = rng(1234)
  local nextCast, castAt, left = 0, -999, 0
  local bossSwings, crushes, crits, blocksInCasts, casts = 0, 0, 0, 0, 0
  local stop = minutes * 60
  local events = {}
  for a = 0, attackers - 1 do
    local x = a * swing / attackers
    while x < stop do events[#events + 1] = { t = x, boss = a == 0 } x = x + swing end
  end
  U.sort(events, function(a, b) return U.cmp(a.t, b.t) end)
  for _, e in ipairs(events) do
    while nextCast <= e.t do castAt = nextCast left = charges nextCast = nextCast + cooldown casts = casts + 1 end
    local active = e.t - castAt < duration and left > 0
    local blk = blockBase + (active and bonus or 0)
    local r = rand() * 100
    local outcome = "hit"
    if r < avoid then outcome = "avoid"
    elseif r < avoid + blk then outcome = "block"
    elseif r < avoid + blk + critSlice then outcome = "crit"
    elseif r < avoid + blk + critSlice + bc.crush then outcome = "crush" end
    if outcome == "block" and active then left = left - 1 blocksInCasts = blocksInCasts + 1 end
    if e.boss then
      bossSwings = bossSwings + 1
      if outcome == "crush" then crushes = crushes + 1 end
      if outcome == "crit" then crits = crits + 1 end
    end
  end
  local withoutTotal = avoid + blockBase + critSlice
  local crushPctWithout = math.max(0, math.min(bc.crush, 100 - withoutTotal))
  local blocksPerCast = blocksInCasts / math.max(1, casts)
  local hitsPerCast = (duration / swing) * attackers
  local note
  if charges >= hitsPerCast then
    note = ("%s has more charges (%d) than the swings it meets in %d seconds (%s)."):format(ability, charges, duration, U.fixed(hitsPerCast, 1))
  else
    note = ("%s meets about %s swings per use but only has %d charge%s: once they are used up, later swings in the window are not covered.")
      :format(ability, U.fixed(hitsPerCast, 1), charges, charges == 1 and "" or "s")
  end
  return {
    ability = ability, charges = charges, duration = duration, cooldown = cooldown, swing = swing, attackers = attackers,
    crushPct = crushes / math.max(1, bossSwings) * 100, critPct = crits / math.max(1, bossSwings) * 100,
    crushPctWithout = crushPctWithout, blocksPerCast = blocksPerCast, hitsPerCast = hitsPerCast, note = note,
  }
end
