-- Loads the whole addon into the WoW API stand-in (tests/wow/mock.lua), logs in, opens the window and
-- clicks through every screen and panel like a player would. Checks what appears, that nothing errors,
-- that frames are reused (no leaks), and writes each screen as build/shots/NN-name.json for
-- tools/render.mjs to draw.     lua5.1 tests/ui.lua
package.path = "./tests/?.lua;./tests/wow/?.lua;" .. package.path
local L = require("load")
local M = require("mock")

local failed, passed = 0, 0
local function check(name, ok, detail)
  if ok then passed = passed + 1 else failed = failed + 1 end
  print((ok and "ok   " or "FAIL ") .. name .. (detail and detail ~= "" and ("  " .. detail) or ""))
end

local player = {
  name = "Tankadin", class = "paladin", race = "bloodelf",
  links = {},
  trees = {},
}
local G = M.env(player)
local T = L.load(".", nil, G)
local dataLoads = 0
M.loadAddOn = function(name)
  if name ~= "TBCrushCalc_Data" then return false, "MISSING" end
  dataLoads = dataLoads + 1
  L.loadData(".", G)
  return true
end
local U = T.U

-- what the game's tooltips would show for a link: name in its quality colour, item level, stats
M.describeLink = function(link)
  local id, eff, g1, g2, g3 = link:match("item:(%d+):?(%d*):?(%d*):?(%d*):?(%d*)")
  id = tonumber(id)
  local it = T.ITEM_BY_ID[id] or T.GEM_BY_ID[id] or T.CONSUMABLE_BY_ID[id]
  if not it then return nil end
  local r, g, b = U.hex(T.QUALITY_COLOR[(it.q or 1) + 1] or "#ffffff")
  local out = { { it.n, r, g, b } }
  if it.il then out[#out + 1] = { "Item Level " .. it.il, 1, 0.82, 0 } end
  if it.st and next(it.st) then out[#out + 1] = { T.statText(it.st), 1, 1, 1 } end
  for i, gid in ipairs({ g1, g2, g3 }) do
    local gem = T.GEM_BY_ID[tonumber(gid) or 0]
    if gem then out[#out + 1] = { gem.tx or gem.n, 1, 1, 1 } end
  end
  local e = T.ENCHANT_BY_EFF[tonumber(eff) or 0]
  if e then out[#out + 1] = { T.enchantText(e), 0.12, 1, 0 } end
  if it.drop then out[#out + 1] = { "Dropped by: " .. it.drop, 0.6, 0.6, 0.6 } end
  return out
end

-- the talents of the character being played, as the game lists them (from a separate copy of the data:
-- the addon itself only loads its data when the window opens)
local REF = L.load(".", function(f) return not f:match("^UI") end, nil, true)
for tab, tree in ipairs(REF.TALENTS.paladin) do
  local list = {}
  for _, t in ipairs(tree.talents) do list[#list + 1] = { name = t.n, tier = t.r + 1, column = t.c + 1, rank = 0, max = t.max } end
  player.trees[tab] = { name = tree.name, talents = list, background = ({ "PaladinHoly", "PaladinProtection", "PaladinCombat" })[tab] }
end
for _, t in ipairs(player.trees[2].talents) do
  if t.name == "Redoubt" or t.name == "Toughness" or t.name == "Anticipation" or t.name == "Improved Righteous Fury" then t.rank = math.min(t.max, 5) end
end
-- gear, with links written the way the Anniversary client writes them (empty fields blank, from /dump
-- GetInventoryItemLink in game): Warbringer Greathelm with two gems and Glyph of the Defender, Bastion of
-- Light, and The Horseman's Blade under the new id the Anniversary realms gave it, with Battlemaster (an
-- enchant the data has no game id for, so it's read off the tooltip)
player.links[1] = "|cffa335ee|Hitem:29011:2999:25896:24033:::::70::::::::::|h[Warbringer Greathelm]|h|r"
player.links[17] = "|cffa335ee|Hitem:30882::::::::70::::::::::|h[Bastion of Light]|h|r"
player.links[16] = "|cffa335ee|Hitem:281923:2675:::::::70::::::::::|h[The Horseman's Blade]|h|r"
M.inventoryLines = function(_, slot)
  if slot == 16 then
    return { { "The Horseman's Blade", 0.64, 0.21, 0.93 }, { "Binds when picked up", 1, 1, 1 }, { "Battlemaster", 0, 1, 0 },
      { "+16 Stamina", 1, 1, 1 }, { "Equip: Increases attack power by 46.", 0, 1, 0 } }
  end
  return { { "inventory", 1, 1, 1 } }
end

-- json for the renderer
local function json(v)
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "boolean" then return v and "true" or "false" end
  if t == "number" then if v ~= v or v == math.huge or v == -math.huge then return "0" end return string.format("%.4f", v):gsub("%.?0+$", "") end
  if t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"' end
  if #v > 0 or next(v) == nil then
    local out = {}
    for i = 1, #v do out[i] = json(v[i]) end
    return "[" .. table.concat(out, ",") .. "]"
  end
  local out = {}
  for k, x in pairs(v) do out[#out + 1] = json(tostring(k)) .. ":" .. json(x) end
  return "{" .. table.concat(out, ",") .. "}"
end

os.execute("rm -rf build/shots && mkdir -p build/shots")
local shotN = 0
local function shot(name)
  M.tick(0.2)
  shotN = shotN + 1
  local f = assert(io.open(("build/shots/%02d-%s.json"):format(shotN, name), "w"))
  f:write(json({ w = M.SCREEN_W, h = M.SCREEN_H, ops = M.render() }))
  f:close()
end

local function run(name, fn)
  local ok, err = pcall(fn)
  if not ok then check(name, false, tostring(err)) end
end
--- text on screen: in the panel on top if one is open, else in the window
local function find(text)
  local root = T.topSheet and T.topSheet() or nil
  return M.findText(text, true, root)
end
local function clickText(text, nth)
  local hits = find(text)
  -- prefer things whose whole text is what we asked for (a tab called "Caps" over a note mentioning Caps)
  local exact = {}
  for _, x in ipairs(hits) do if M.plain(x.fs._text) == text and x.clickable then exact[#exact + 1] = x end end
  if #exact > 0 then hits = exact end
  local h = hits[nth or 1]
  if not h or not h.clickable then error("nothing clickable shows '" .. text .. "' (" .. #hits .. " matches)", 2) end
  M.click(h.clickable)
  M.tick(0.2)
  return h
end
local function visibleText(text) return #find(text) > 0 end
local win

run("log in", function()
  M.fire("ADDON_LOADED", "TBCrushCalc")
  M.fire("PLAYER_LOGIN")
  check("game data not loaded at log in", dataLoads == 0 and T.GEMS == nil)
  check("slash command registered", G.SlashCmdList.TBCRUSHCALC ~= nil and G.SLASH_TBCRUSHCALC1 == "/tbcc")
  check("minimap button", G.TBCrushCalcMinimapButton ~= nil)
  G.SlashCmdList.TBCRUSHCALC("")
  win = G.TBCrushCalcFrame
  check("window opens", win:IsShown())
  check("data loaded once, on opening", dataLoads == 1 and #T.ITEMS > 14000)
  check("saved variables created", type(G.TBCrushCalcDB) == "table" and #G.TBCrushCalcDB.profiles == 3)
end)

run("character screen", function()
  check("example character on top", visibleText("Example Paladin"))
  check("verdict in the top bar", visibleText("UNCRUSHABLE") or visibleText("SHORT"))
  check("paperdoll verdict", visibleText("Uncrushable") or visibleText("Crushable"))
  check("stat panels", visibleText("Base Stats") and visibleText("Defenses"))
  shot("character")
  -- scroll down to the stat panels
  local view
  for _, c in ipairs(win._children) do if c._type == "ScrollFrame" then view = c end end
  view._scripts.OnMouseWheel(view, -6)
  shot("character-stats")
  view._scripts.OnMouseWheel(view, 20)
end)

run("slot panel and item picker", function()
  -- click the head slot
  local slots = {}
  local function walk(f) for _, c in ipairs(f._children) do if c._kind == "slot" and c:IsVisible() then slots[#slots + 1] = c end walk(c) end end
  walk(win)
  check("17 + 2 slots on the paperdoll", #slots == 19, tostring(#slots))
  M.click(slots[1])
  M.tick()
  check("slot panel opens with the item", visibleText("Change item"))
  shot("slot")
  clickText("Change item")
  check("item picker lists items", visibleText("items for this slot"))
  shot("picker")
  -- typing in the search box, a key at a time with the list redrawing in between, as in game
  local function searchBox()
    local found
    local function walk(f) for _, c in ipairs(f._children) do if c._type == "EditBox" and c:IsVisible() then found = c end walk(c) end end
    walk(T.topSheet())
    return found
  end
  M.click(searchBox())
  M.type("warbringer", function() M.tick(0.2) end)
  check("search box keeps every key typed", searchBox():GetText() == "warbringer", searchBox():GetText())
  check("and keeps focus", M.focus == searchBox())
  local names = {}
  for _, r in ipairs(find("Req. level")) do names[#names + 1] = r.text end
  check("and the list filters", visibleText("Warbringer") and #find("Req. level") <= 3, table.concat(names, " / "))
  M.type(" g", function() M.tick(0.2) end)
  check("typing on after a pause", searchBox():GetText() == "warbringer g", searchBox():GetText())
  local box = searchBox()
  box:SetText("")
  box._scripts.OnTextChanged(box, true)     -- as if the text was deleted
  box._scripts.OnEnterPressed(box)
  M.tick(0.2)
  clickText("Avoidance")
  clickText("All phases")
  local before = #find("ilvl")
  check("item rows shown", before > 10, tostring(before))
  -- open the first item and equip it
  local rows = find("Req. level")
  M.click(rows[1].clickable)
  M.tick()
  check("equip preview", visibleText("Equip?"))
  shot("preview")
  clickText("Equip")
  check("back on the slot panel", visibleText("Change item"))
  G.TBCrushCalcEscapeCatcher:Hide()     -- what the game's Escape handling does
  M.tick()
  check("Escape closes the panel", not visibleText("Change item"))
end)

run("gems and enchants", function()
  local p = T.cur()
  p.gear.head = { id = 29011 }
  T.commit()
  local slots = {}
  local function walk(f) for _, c in ipairs(f._children) do if c._kind == "slot" and c:IsVisible() then slots[#slots + 1] = c end walk(c) end end
  walk(win)
  M.click(slots[1])
  M.tick()
  check("sockets listed", visibleText("Empty Meta Socket") and visibleText("Empty Yellow Socket"))
  clickText("Empty Yellow Socket")
  check("gem picker", visibleText("Yellow Socket") and visibleText("MATCHES THE SOCKET"))
  shot("gems")
  clickText("Matching colour only")
  clickText("Stamina")
  local g = find("Stamina")
  check("gem filter works", #g > 1)
  local rows = find("matches this socket")
  M.click(rows[1].clickable)
  M.tick()
  check("gem goes in", (T.cur().gear.head.gems or {})[2] ~= nil and T.cur().gear.head.gems[2] > 0)
  clickText("Not enchanted")
  check("enchant picker", visibleText("Glyph of the Defender"))
  shot("enchants")
  clickText("Glyph of the Defender")
  check("enchant on", T.ENCHANT_BY_ID[T.cur().gear.head.ench].n == "Glyph of the Defender")
  T.closeAll()
  -- a low-level item can't take a level 35 enchant, and says why
  local low = U.find(T.ITEMS, function(i) return i.s == "chest" and i.il < 20 and T.canUse("paladin", i) end)
  p.gear.chest = { id = low.id }
  T.commit()
  slots = {}
  walk(win)
  M.click(slots[5])
  M.tick()
  clickText("Not enchanted")
  check("too-high enchant explains itself", visibleText("Requires a level 35 or higher item"))
  shot("enchant-low-level")
  local hit = find("Exceptional Health")[1]
  M.click(hit.clickable)
  M.tick()
  check("and refuses", T.cur().gear.chest.ench == nil)
  T.closeAll()
end)

run("talents", function()
  clickText("Talents")
  check("talent tree", visibleText("Points left"))
  local art
  local function findArt(f) for _, c in ipairs(f._children) do if c._kind == "treeart" and c:IsVisible() then art = c end findArt(c) end end
  findArt(win)
  check("tree painting, named by the game", art and art.tl:GetTexture() == "Interface\\TalentFrame\\PaladinProtection-TopLeft", art and art.tl:GetTexture())
  check("cut like the game's talent frame", art and art.tr._coord[2] == 0.6875 and art.br._coord[4] == 0.5859375 and art.bl._coord[4] == 0.5859375)
  shot("talents")
  local tal
  local function walk(f) for _, c in ipairs(f._children) do if c._kind == "talent" and c:IsVisible() and not tal then tal = c end walk(c) end end
  walk(win)
  M.click(tal)
  M.tick()
  check("talent panel", visibleText("Add point") or visibleText("Remove point"))
  shot("talent")
  T.closeAll()
end)

run("buffs", function()
  clickText("Buffs")
  check("consumables", visibleText("Flask of Fortification") and visibleText("Flask active"))
  shot("buffs")
  clickText("Fisherman's Feast")
  check("food list", visibleText("Spicy Crawdad"))
  shot("food")
  clickText("Spicy Crawdad")
  check("food picked", T.CONSUMABLE_BY_ID[T.cur().cons.food].n == "Spicy Crawdad")
  -- a raid buff: on, improved, off
  local function tile(name)
    local h = find(name)
    for _, x in ipairs(h) do if x.clickable and x.clickable._kind == "tile" then return x.clickable end end
  end
  local might = tile("Blessing of Might")
  M.click(might) M.tick()
  check("buff on", T.cur().buffs.might == 1)
  M.click(tile("Blessing of Might")) M.tick()
  check("buff improved", T.cur().buffs.might == 2)
  M.click(tile("Blessing of Might")) M.tick()
  check("buff off", T.cur().buffs.might == nil)
  M.click(tile("Blessing of Sanctuary"), "RightButton") M.tick()
  check("buff details", visibleText("80 less damage"))
  shot("buff-detail")
  T.closeAll()
  local view
  for _, c in ipairs(win._children) do if c._type == "ScrollFrame" then view = c end end
  view._scripts.OnMouseWheel(view, -12)
  shot("buffs-grid")
  view._scripts.OnMouseWheel(view, -60)
  clickText("Any level 73 boss")
  check("boss list", visibleText("Brutallus") and visibleText("KARAZHAN"))
  shot("bosses")
  clickText("Gruul the Dragonkiller")
  check("boss picked", T.BOSS_BY_ID[T.cur().opts.boss].n == "Gruul the Dragonkiller")
  view._scripts.OnMouseWheel(view, -60)
  shot("fight")
end)

run("caps", function()
  clickText("Caps")
  check("boss on the caps screen", visibleText("Gruul the Dragonkiller"))
  check("damage taken", visibleText("Normal hit on you"))
  shot("caps")
  local view
  for _, c in ipairs(win._children) do if c._type == "ScrollFrame" then view = c end end
  view._scripts.OnMouseWheel(view, -12)
  shot("caps-2")
  view._scripts.OnMouseWheel(view, -12)
  shot("caps-3")
end)

run("saved, share codes and loading your character", function()
  clickText("Saved")
  check("characters listed", visibleText("Example Warrior") and visibleText("Example Bear"))
  shot("saved")
  clickText("Load the character I'm playing")
  local me = T.cur()
  check("loaded the character being played", me.name == "Tankadin" and me.cls == "paladin" and me.race == "bloodelf")
  check("with its gear, gems and enchant", me.gear.head and me.gear.head.id == 29011 and T.ENCHANT_BY_ID[me.gear.head.ench].n == "Glyph of the Defender"
    and me.gear.head.gems and me.gear.head.gems[1] == 25896)
  check("and its talents", T.TR.spent(me.talents) > 10, tostring(T.TR.spent(me.talents)))
  check("reissued item found by name", me.gear.mainhand and me.gear.mainhand.id == 38175, me.gear.mainhand and tostring(me.gear.mainhand.id))
  check("its enchant read off the tooltip", me.gear.mainhand and me.gear.mainhand.ench and T.ENCHANT_BY_ID[me.gear.mainhand.ench].n == "Enchant Weapon - Battlemaster")
  check("and remembered", T.db.ui.effMap and T.db.ui.effMap[2675] == me.gear.mainhand.ench, tostring(T.db.ui.effMap and T.db.ui.effMap[2675]) .. " " .. tostring(me.gear.mainhand.ench))
  check("links written like the client's", T.itemString(me.gear.head) == "item:29011:2999:25896:24033::" and T.itemString(me.gear.offhand) == "item:30882:::::",
    T.itemString(me.gear.head) .. " " .. T.itemString(me.gear.offhand))
  shot("loaded")
  clickText("Saved")
  local more = find("...")
  M.click(more[1].clickable)
  M.tick()
  check("manage panel with share code", visibleText("Share code"))
  shot("manage")
  T.closeAll()
  clickText("New character")
  shot("new")
  local nameBox
  local function walk(f) for _, c in ipairs(f._children) do if c._type == "EditBox" and c:IsVisible() then nameBox = c end walk(c) end end
  walk(T.topSheet())
  M.click(nameBox)
  M.type("Moonkin Tank", function() M.tick(0.2) end)
  clickText("Druid")
  clickText("Tauren")
  clickText("Create")
  check("new character", T.cur().cls == "druid" and T.cur().race == "tauren")
  check("with the name typed", T.cur().name == "Moonkin Tank", T.cur().name)
  check("goes to talents", visibleText("Points left"))
end)

run("no leaks", function()
  local before = M.frameCount()
  for _ = 1, 20 do
    for _, tab in ipairs({ "Character", "Talents", "Buffs", "Caps", "Saved" }) do clickText(tab) end
  end
  local after = M.frameCount()
  check("redrawing reuses frames", after - before < 5, ("%d frames before, %d after 100 redraws"):format(before, after))
end)

run("race portraits", function()
  local f = M.CreateFrame("Frame", nil, G.UIParent)
  local tex = f:CreateTexture()
  T.raceIcon(tex, "undead", "warrior")
  check("no race atlas in the client: the race sheet", tex:GetTexture() == "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Races"
    and tex._coord[1] == 0.125 and tex._coord[3] == 0.25, tostring(tex:GetTexture()))
  M.atlases = { ["raceicon128-tauren-male"] = { width = 128, height = 128 } }
  T.raceIcon(tex, "tauren", "druid")
  check("an atlas when the client has one", tex:GetAtlas() == "raceicon128-tauren-male")
  M.atlases = nil
end)

run("item data that won't load", function()
  local errorsBefore = #M.errors
  local keep = M.loadAddOn
  local function fresh()
    local G2 = M.env({ name = "Alt", class = "warrior", race = "orc", links = {}, trees = {} })
    return L.load(".", nil, G2), G2
  end
  local T2 = fresh()
  M.loadAddOn = function() return nil, nil end
  check("no reason from the game", not T2.loadData() and T2.dataError:find("didn't say why"), T2.dataError)
  T2 = fresh()
  M.loadAddOn = function() return false, "DISABLED" end
  check("switched off", not T2.loadData() and T2.dataError:find("switched off"), T2.dataError)
  T2 = fresh()
  M.loadAddOn = function() return false, "INTERFACE_VERSION" end
  check("out of date", not T2.loadData() and T2.dataError:find("out of date"), T2.dataError)
  local G2
  T2, G2 = fresh()
  M.loadAddOn = function() G2.geterrorhandler()("Interface/AddOns/TBCrushCalc_Data/Gems.lua:5: boom") return true end
  check("a data file's error is shown", not T2.loadData() and T2.dataError:find("Gems.lua:5: boom", 1, true), T2.dataError)
  check("and the game's error handler put back", G2.geterrorhandler() ~= nil and #M.errors == errorsBefore + 1)
  -- the game ran TBCrushCalc_Data before TBCrushCalc: the tables are picked up, nothing else to load
  local G3 = M.env({ name = "Alt", class = "warrior", race = "orc", links = {}, trees = {} })
  L.loadData(".", G3)
  local calls = 0
  M.loadAddOn = function() calls = calls + 1 return false, "MISSING" end
  local T3 = L.load(".", nil, G3)
  check("data loaded first still works", T3.loadData() and calls == 0 and #T3.ITEMS > 14000 and T3.ITEM_BY_ID[29011] ~= nil, T3.dataError)
  M.loadAddOn = keep
  for i = #M.errors, errorsBefore + 1, -1 do table.remove(M.errors, i) end
end)

local clashes = M.layerClashes()
check("nothing drawn level with a backdrop (the game may draw the backdrop over it)", #clashes == 0, table.concat(clashes, ", "))
check("no Lua errors", #M.errors == 0, table.concat(M.errors, " | "))
print(("passed %d"):format(passed))
print(("errors %d"):format(failed))
if failed > 0 then os.exit(1) end
