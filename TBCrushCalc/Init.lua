-- TBCrushCalc: the namespace every file shares. Loaded first (see TBCrushCalc.toc).
-- The game data lives in a second addon, TBCrushCalc_Data, loaded the first time the window opens (it holds
-- every TBC item, so there's no reason to keep it in memory before then); it finds this namespace through
-- the TBCrushCalcNS global.
local ADDON, T = ...
T.NAME = ADDON
-- if the game happened to run TBCrushCalc_Data first, its tables are already waiting in TBCrushCalcNS
if type(TBCrushCalcNS) == "table" and TBCrushCalcNS ~= T then
  for k, v in pairs(TBCrushCalcNS) do if T[k] == nil then T[k] = v end end
end
T.ITEMS = T.ITEMS or {} -- filled by TBCrushCalc_Data/Items*.lua
TBCrushCalcNS = T
