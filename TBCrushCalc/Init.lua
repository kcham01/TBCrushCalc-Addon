-- TBCrushCalc: the namespace every file shares. Loaded first (see TBCrushCalc.toc).
-- The game data lives in a second addon, TBCrushCalc_Data, loaded the first time the window opens (it holds
-- every TBC item, so there's no reason to keep it in memory before then); it finds this namespace through
-- the TBCrushCalcNS global.
local ADDON, T = ...
T.NAME = ADDON
T.ITEMS = {}            -- filled by TBCrushCalc_Data/Items*.lua
TBCrushCalcNS = T
