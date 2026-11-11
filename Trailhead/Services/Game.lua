local _, T = ...
local L = T.L
local C = T.Compat

-- Game: everything Trailhead reads about the character and the world, in one place.
-- Every reader is guarded: if the game will not answer, the result is empty and the
-- feature that wanted it shows nothing instead of failing.

local G = {}
T.Game = G

local ATTACK = 6603 -- the basic Attack; nobody needs to be told it is not on a bar
local MISSING_FROM_BARS = 2 -- ActionButtonUtil.ActionBarActionStatus.MissingFromAllBars
local RETRY = 20 -- seconds before asking again for data the game did not have yet

-- ---------------------------------------------------------------------------
-- The player.

local levelSeen = 0 -- the level the last level-up announced; the game's own answer lags it

function G.Level()
	return math.max(C.Plain(UnitLevel("player"), 0) or 0, levelSeen)
end

function G.MaxLevel()
	return C.Plain(C.Call("GetMaxPlayerLevel"), nil) or 60
end

-- The class as the game's files name it ("ROGUE"), the same in every language.
function G.ClassFile()
	local _, file = UnitClass("player")
	file = C.Plain(file, nil)
	return type(file) == "string" and file or nil
end

-- The race's file name ("Orc", "NightElf", "Scourge" for the undead), the same in every language.
function G.RaceFile()
	local _, file = C.Call("UnitRace", "player")
	file = C.Plain(file, nil)
	return type(file) == "string" and file or nil
end

function G.Money()
	local copper = C.Plain(C.Call("GetMoney"), nil)
	return type(copper) == "number" and copper or nil
end

-- How many mounts the character has, or nil when the game will not say.
function G.MountsOwned()
	local ids = C.Call("C_MountJournal.GetMountIDs")
	if type(ids) ~= "table" or not C.Has("C_MountJournal.GetMountInfoByID") then
		return nil
	end
	local owned = 0
	for _, id in ipairs(ids) do
		local collected = select(11, C.Call("C_MountJournal.GetMountInfoByID", id))
		if C.Plain(collected, false) == true then
			owned = owned + 1
		end
	end
	return owned
end

-- "ghost" after releasing, "dead" before, nil when alive or unknown.
function G.Dead()
	if C.Plain(C.Call("UnitIsGhost", "player"), false) == true then
		return "ghost"
	elseif C.Plain(C.Call("UnitIsDeadOrGhost", "player"), false) == true then
		return "dead"
	end
	return nil
end

-- True while Resurrection Sickness (the Spirit Healer's price) is on the character.
local RESURRECTION_SICKNESS = 15007
function G.Sick()
	if C.InCombat() then
		return false
	end
	return type(C.Call("C_UnitAuras.GetPlayerAuraBySpellID", RESURRECTION_SICKNESS)) == "table"
end

function G.ClassName()
	return C.Plain((UnitClass("player")), "") or ""
end

-- 1 for Horde, 2 for Alliance (the numbers flight points use), nil if unknown.
function G.Faction()
	local name = C.Plain(C.Call("UnitFactionGroup", "player"), nil)
	if name == "Horde" then
		return 1
	elseif name == "Alliance" then
		return 2
	end
	return nil
end

function G.MoneyText(copper)
	copper = C.Plain(copper, 0) or 0
	local gold = math.floor(copper / 10000)
	local silver = math.floor(copper % 10000 / 100)
	local g, s, c = GOLD_AMOUNT_SYMBOL or "g", SILVER_AMOUNT_SYMBOL or "s", COPPER_AMOUNT_SYMBOL or "c"
	if gold > 0 then
		return ("%d%s %d%s"):format(gold, g, silver, s)
	elseif silver > 0 then
		return ("%d%s %d%s"):format(silver, s, copper % 100, c)
	end
	return ("%d%s"):format(copper % 100, c)
end

function G.FreeBagSlots()
	local free = 0
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		free = free + (C.Plain(C.Call("C_Container.GetContainerNumFreeSlots", bag), 0) or 0)
	end
	return free
end

-- The condition of the most worn piece of equipped gear, from 0 to 1; nil if nothing
-- the character wears can break.
function G.LowestDurability()
	local lowest
	for slot = 1, 18 do
		local now, most = C.Call("GetInventoryItemDurability", slot)
		now, most = C.Plain(now), C.Plain(most)
		if type(now) == "number" and type(most) == "number" and most > 0 then
			local part = now / most
			if not lowest or part < lowest then
				lowest = part
			end
		end
	end
	return lowest
end

-- Rest and the hearthstone, as the game's own experience bar and the stone's tooltip give
-- them (game check 7): { name = "Rested", multiplier = 2, rested = bonus experience left,
-- resting = in an inn or city now, home = "Camp Taurajo",
-- stone = { carried = true, left = seconds until it is ready (0 when ready) } or nil }
local HEARTHSTONE = 6948

function G.Rest()
	local _, name, multiplier = C.Call("GetRestState")
	name, multiplier = C.Plain(name, nil), C.Plain(multiplier, nil)
	local rested = C.Plain(C.Call("GetXPExhaustion"), 0)
	local out = {
		name = type(name) == "string" and name ~= "" and name or nil,
		multiplier = type(multiplier) == "number" and multiplier or nil,
		rested = type(rested) == "number" and rested or 0,
		resting = C.Plain(C.Call("IsResting"), false) == true,
		home = G.BindLocation(),
	}
	local count = C.Plain(C.Call("C_Item.GetItemCount", HEARTHSTONE), nil)
	if type(count) == "number" then
		out.stone = { carried = count > 0, left = 0 }
		local start, duration = C.Call("C_Container.GetItemCooldown", HEARTHSTONE)
		start, duration = C.Plain(start, 0), C.Plain(duration, 0)
		if type(start) == "number" and type(duration) == "number" and start > 0 and duration > 0 and GetTime then
			out.stone.left = math.max(0, start + duration - GetTime())
		end
	end
	return out
end

-- The line of an item's tooltip that says what using it does ("Use: Restores ..."), in the
-- game's own words, or nil while the game has not loaded it.
function G.ItemUse(itemID)
	local data = type(itemID) == "number" and C.Call("C_TooltipInfo.GetItemByID", itemID) or nil
	if type(data) ~= "table" or type(data.lines) ~= "table" then
		return nil
	end
	local prefix = type(ITEM_SPELL_TRIGGER_ONUSE) == "string" and ITEM_SPELL_TRIGGER_ONUSE or "Use:"
	for _, line in ipairs(data.lines) do
		local text = type(line) == "table" and C.Plain(line.leftText, nil) or nil
		if type(text) == "string" and text:sub(1, #prefix) == prefix then
			return (text:gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rR]", ""):gsub("%s+", " "))
		end
	end
	return nil
end

-- The things in the bags that get used up, by the class and subclass the game files them
-- under (game check 7: consumables are class 0; food and drink 5, bandages 7, potions 1).
-- Returns { food = {count, name, item, label}, bandages = {...}, potions = {...}, read = true }
-- or { read = false } when the game will not list the bags.
local CONSUMABLE = 0
local SUPPLY = { [5] = "food", [7] = "bandages", [1] = "potions" }

function G.Supplies()
	local out = { read = false }
	for _, key in pairs(SUPPLY) do
		out[key] = { count = 0 }
	end
	if not C.Has("C_Container.GetContainerItemInfo") or not C.Has("C_Item.GetItemInfoInstant") then
		return out
	end
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		local slots = C.Plain(C.Call("C_Container.GetContainerNumSlots", bag), 0)
		if type(slots) == "number" and slots > 0 then
			out.read = true
		end
		for slot = 1, type(slots) == "number" and slots or 0 do
			local info = C.Call("C_Container.GetContainerItemInfo", bag, slot)
			local itemID = type(info) == "table" and C.Plain(info.itemID, nil) or nil
			if type(itemID) == "number" then
				local _, _, label, _, _, classID, subClassID = C.Call("C_Item.GetItemInfoInstant", itemID)
				local key = C.Plain(classID, nil) == CONSUMABLE and SUPPLY[C.Plain(subClassID, -1)] or nil
				if key then
					local group = out[key]
					local count = C.Plain(info.stackCount, 1)
					count = type(count) == "number" and count or 1
					group.count = group.count + count
					label = C.Plain(label, nil)
					group.label = type(label) == "string" and label ~= "" and label or group.label
					-- The one there is most of names the group.
					group.stacks = group.stacks or {}
					group.stacks[itemID] = (group.stacks[itemID] or 0) + count
					if not group.item or group.stacks[itemID] > group.stacks[group.item] then
						local name = C.Plain(info.itemName, nil)
						if type(name) ~= "string" or name == "" then
							name = C.Plain(C.Call("C_Item.GetItemNameByID", itemID), nil)
						end
						group.item, group.name = itemID, type(name) == "string" and name or nil
					end
				end
			end
		end
	end
	return out
end

function G.BindLocation()
	local bind = C.Plain(C.Call("GetBindLocation"), nil)
	if type(bind) == "string" and bind ~= "" then
		return bind
	end
	return nil
end

function G.HasTalentPoints()
	return C.Plain(C.Call("C_ClassTalents.HasUnspentTalentPoints"), false) == true
end

-- The talent trees as the game's own talent window reads them, or nil when the game gives
-- no tree: { trees = { {id, name, spent, total} ... } (in the window's order), spent, unspent }.
function G.Talents()
	local group = C.Plain(C.Call("C_SpecializationInfo.GetActiveSpecGroup"), 1)
	local configID = C.Plain(C.Call("C_SpecializationInfo.GetCombatConfigIDForSpecGroup", type(group) == "number" and group or 1), nil)
	if type(configID) ~= "number" then
		configID = C.Plain(C.Call("C_ClassTalents.GetActiveConfigID"), nil)
	end
	if type(configID) ~= "number" then
		return nil
	end
	local config = C.Call("C_Traits.GetConfigInfo", configID)
	local treeID = type(config) == "table" and type(config.treeIDs) == "table" and C.Plain(config.treeIDs[1], nil) or nil
	local groups = type(treeID) == "number" and C.Call("C_Traits.GetGroupDisplayInfoByTreeID", treeID) or nil
	local nodeIDs = type(treeID) == "number" and C.Call("C_Traits.GetTreeNodes", treeID) or nil
	if type(groups) ~= "table" or type(nodeIDs) ~= "table" then
		return nil
	end
	local out = { config = configID, tree = treeID, trees = {}, nodes = {}, spent = 0, unspent = 0 }
	local byGroup = {}
	for index, info in ipairs(groups) do
		local id, name = type(info) == "table" and C.Plain(info.groupID, nil), type(info) == "table" and C.Plain(info.displayName, nil)
		if type(id) == "number" and type(name) == "string" then
			local order = C.Plain(info.orderIndex, index)
			local tree = { id = id, name = name, spent = 0, total = 0, order = type(order) == "number" and order or index }
			byGroup[id] = tree
			out.trees[#out.trees + 1] = tree
		end
	end
	if #out.trees == 0 then
		return nil
	end
	table.sort(out.trees, function(a, b)
		return a.order < b.order
	end)
	for _, nodeID in ipairs(nodeIDs) do
		local node = C.Call("C_Traits.GetNodeInfo", configID, nodeID)
		if type(node) == "table" and C.Plain(node.isVisible, true) ~= false then
			local ranks, max = C.Plain(node.ranksPurchased, 0), C.Plain(node.maxRanks, 0)
			for _, groupID in ipairs(type(node.groupIDs) == "table" and node.groupIDs or {}) do
				local tree = byGroup[C.Plain(groupID, 0)]
				if tree and type(ranks) == "number" and type(max) == "number" then
					tree.spent = tree.spent + ranks
					tree.total = tree.total + max
					out.spent = out.spent + ranks
					out.nodes[nodeID] = {
						id = nodeID, rank = ranks, max = max, tree = tree, y = C.Plain(node.posY, nil),
						available = C.Plain(node.isAvailable, false) == true,
						entry = type(node.entryIDs) == "table" and C.Plain(node.entryIDs[1], nil) or nil,
					}
					break
				end
			end
		end
	end
	local currencies = C.Call("C_Traits.GetTreeCurrencyInfo", configID, treeID, false)
	local currency = type(currencies) == "table" and currencies[1] or nil
	local left = type(currency) == "table" and C.Plain(currency.quantity, nil) or nil
	if type(left) == "number" then
		out.unspent = left
	elseif G.HasTalentPoints() then
		out.unspent = 1
		out.unspentUnknown = true -- the game says there are points but not how many
	end
	return out
end

-- Opens the game's talent window with Trailhead beside it. False when it cannot.
function G.OpenTalents()
	if C.InCombat() then
		return false
	end
	-- "Open" must open: the game's toggle would close a talent window that is already up.
	local open = C.Has("PlayerSpellsUtil.OpenToClassTalentsTab") and "PlayerSpellsUtil.OpenToClassTalentsTab"
		or C.Has("PlayerSpellsUtil.ToggleClassTalentFrame") and "PlayerSpellsUtil.ToggleClassTalentFrame"
	if not open then
		T:Print(L["Open your talents from the game's menu bar."])
		return false
	end
	T.Window:Keep(open)
	T.Window:Beside("PlayerSpellsFrame")
	return true
end

-- ---------------------------------------------------------------------------
-- Maps.

local function mapInfo(mapID)
	local info = C.Call("C_Map.GetMapInfo", mapID)
	if type(info) ~= "table" then
		return nil
	end
	return info
end

function G.MapName(mapID)
	local info = mapID and mapInfo(mapID)
	local name = info and C.Plain(info.name, nil)
	return type(name) == "string" and name or nil
end

-- Where the player stands on a map: x, y from 0 to 1, or nil (inside a dungeon, say).
function G.PositionOn(mapID)
	local position = C.Call("C_Map.GetPlayerMapPosition", mapID, "player")
	if type(position) == "table" and type(position.GetXY) == "function" then
		local ok, x, y = pcall(position.GetXY, position)
		if ok and type(C.Plain(x)) == "number" and type(C.Plain(y)) == "number" then
			return x, y
		end
	end
	return nil
end

-- The map the player is on and the position on it.
function G.PlayerMap()
	local mapID = C.Plain(C.Call("C_Map.GetBestMapForUnit", "player"), nil)
	if type(mapID) ~= "number" then
		return nil
	end
	return mapID, G.PositionOn(mapID)
end

-- Walks up from a map and returns the first ancestor (or the map itself) of a map type,
-- and the topmost map reached.
local function ancestor(mapID, wantType)
	local found, top = nil, mapID
	for _ = 1, 12 do
		local info = mapID and mapInfo(mapID)
		if not info then
			break
		end
		top = mapID
		if wantType and not found and C.Plain(info.mapType) == wantType then
			found = mapID
		end
		local parent = C.Plain(info.parentMapID, 0)
		if type(parent) ~= "number" or parent == 0 then
			break
		end
		mapID = parent
	end
	return found, top
end

-- The continent the player is on (a map id), or nil.
function G.Continent()
	local mapID = G.PlayerMap()
	local continentType = C.Resolve("Enum.UIMapType.Continent")
	if not mapID or not continentType then
		return nil
	end
	return (ancestor(mapID, continentType))
end

-- The continent a map belongs to (a map id), or nil.
function G.ContinentOf(mapID)
	local continentType = C.Resolve("Enum.UIMapType.Continent")
	if type(mapID) ~= "number" or not continentType then
		return nil
	end
	return (ancestor(mapID, continentType))
end

-- The zone a map belongs to (a cave or a city district sits inside one), or nil.
function G.ZoneOf(mapID)
	local zoneType = C.Resolve("Enum.UIMapType.Zone")
	if type(mapID) ~= "number" or not zoneType then
		return nil
	end
	return (ancestor(mapID, zoneType))
end

-- A spot on a zone's map as a spot on its continent's map: continent, x, y. Nil when the
-- game will not say where the zone sits.
function G.OnContinent(mapID, x, y)
	local continent = G.ContinentOf(mapID)
	if not continent or type(x) ~= "number" or type(y) ~= "number" then
		return nil
	end
	if continent == mapID then
		return continent, x, y
	end
	local minX, maxX, minY, maxY = C.Call("C_Map.GetMapRectOnMap", mapID, continent)
	minX, maxX, minY, maxY = C.Plain(minX, nil), C.Plain(maxX, nil), C.Plain(minY, nil), C.Plain(maxY, nil)
	if type(minX) ~= "number" or type(maxX) ~= "number" or type(minY) ~= "number" or type(maxY) ~= "number"
		or maxX <= minX or maxY <= minY then
		return nil
	end
	return continent, minX + x * (maxX - minX), minY + y * (maxY - minY)
end

-- How many yards a map is across and down, or nil.
function G.MapYards(mapID)
	local width, height = C.Call("C_Map.GetMapWorldSize", mapID)
	width, height = C.Plain(width, nil), C.Plain(height, nil)
	if type(width) == "number" and type(height) == "number" and width > 0 and height > 0 then
		return width, height
	end
	return nil
end

local function normal(name)
	return (name:lower():gsub("^the ", ""))
end
G.NormalName = normal

-- ---------------------------------------------------------------------------
-- Flight points. The game lists every one on a map with its position and faction.

local taxiCache = {}

function G.TaxiNodes(mapID)
	if not mapID then
		return {}
	end
	if taxiCache[mapID] then
		return taxiCache[mapID]
	end
	local nodes = C.Call("C_TaxiMap.GetTaxiNodesForMap", mapID)
	local out = {}
	if type(nodes) ~= "table" then
		return out
	end
	for _, node in ipairs(nodes) do
		local name = C.Plain(node.name, nil)
		local position = node.position
		local x = type(position) == "table" and C.Plain(position.x, nil)
		local y = type(position) == "table" and C.Plain(position.y, nil)
		-- Names starting zzOLD are leftovers the game still lists.
		if type(name) == "string" and not name:find("^zz") and type(x) == "number" and type(y) == "number" then
			local town, zone = name:match("^(.-), (.+)$")
			out[#out + 1] = {
				id = C.Plain(node.nodeID, nil), name = name, town = town or name, zone = zone or name,
				faction = C.Plain(node.faction, 0) or 0, x = x, y = y,
			}
		end
	end
	if #out > 0 then
		taxiCache[mapID] = out
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Zones and dungeons with their level ranges. The ranges come from the game's own group
-- finder list, which names every zone and dungeon with the levels it suggests.

local DUNGEON_CATEGORY = GROUP_FINDER_CATEGORY_ID_DUNGEONS or 2
local RAID_CATEGORY = 114 -- the old game's number for raids; Forever lists none yet, so the name is checked too
local raidCategory = {}

-- Whether a group finder category is the raid list.
local function isRaid(category)
	if category == nil then
		return false
	end
	if raidCategory[category] == nil then
		local info = C.Call("C_LFGList.GetLfgCategoryInfo", category)
		local name = type(info) == "table" and C.Plain(info.name, nil) or nil
		raidCategory[category] = category == RAID_CATEGORY or (type(name) == "string" and name == RAIDS)
	end
	return raidCategory[category]
end
local world, worldAt

local function readActivities()
	local ranges, dungeons, raids = {}, {}, {}
	local ids = C.Call("C_LFGList.GetAvailableActivities")
	if type(ids) ~= "table" then
		return ranges, dungeons, raids
	end
	for _, id in ipairs(ids) do
		local info = C.Call("C_LFGList.GetActivityInfoTable", id)
		if type(info) == "table" then
			local name = C.Plain(info.fullName, nil)
			local lo = C.Plain(info.minLevelSuggestion, 0)
			local hi = C.Plain(info.maxLevelSuggestion, 0)
			if type(name) == "string" and type(lo) == "number" and type(hi) == "number" and lo > 0 and hi >= lo then
				local category = C.Plain(info.categoryID, nil)
				if category == DUNGEON_CATEGORY then
					dungeons[#dungeons + 1] = { name = name, lo = lo, hi = hi }
				elseif isRaid(category) then
					raids[#raids + 1] = { name = name, lo = lo, hi = hi, raid = true }
				else
					ranges[normal(name)] = { lo, hi }
				end
			end
		end
	end
	local function byLevel(a, b)
		if a.lo ~= b.lo then
			return a.lo < b.lo
		end
		return a.name < b.name
	end
	table.sort(dungeons, byLevel)
	table.sort(raids, byLevel)
	return ranges, dungeons, raids
end

local function buildWorld()
	local out = { zones = {}, byMap = {}, dungeons = {}, raids = {}, complete = false }
	local mapID = G.PlayerMap()
	local zoneType = C.Resolve("Enum.UIMapType.Zone")
	if not mapID or not zoneType then
		return out
	end
	local _, top = ancestor(mapID)
	local children = C.Call("C_Map.GetMapChildrenInfo", top, zoneType, true)
	if type(children) ~= "table" then
		return out
	end
	local ranges, dungeons, raids = readActivities()
	out.dungeons, out.raids = dungeons, raids
	local mine = G.Faction()
	local parents = {}
	for _, info in ipairs(children) do
		local name, id = C.Plain(info.name, nil), C.Plain(info.mapID, nil)
		if type(name) == "string" and type(id) == "number" and not out.byMap[id] then
			local parent = C.Plain(info.parentMapID, nil)
			local zone = { name = name, map = id, parent = parent, key = normal(name) }
			local range = ranges[zone.key]
			if range then
				zone.lo, zone.hi = range[1], range[2]
			else
				local lo, hi = C.Call("C_Map.GetMapLevels", id)
				lo, hi = C.Plain(lo, 0), C.Plain(hi, 0)
				if type(lo) == "number" and type(hi) == "number" and lo > 0 and hi >= lo then
					zone.lo, zone.hi = lo, hi
				end
			end
			if parent and parents[parent] == nil then
				parents[parent] = G.MapName(parent) or false
			end
			zone.continent = parent and parents[parent] or nil
			out.zones[#out.zones + 1] = zone
			out.byMap[id] = zone
		end
	end
	-- Which side has a flight point in each zone: the best hint the game gives about
	-- whose territory it is.
	for parent in pairs(parents) do
		for _, node in ipairs(G.TaxiNodes(parent)) do
			local key = normal(node.zone)
			for _, zone in ipairs(out.zones) do
				if zone.parent == parent and (zone.key == key or zone.key:sub(1, #key + 1) == key .. " ") then
					if node.faction == 0 or node.faction == mine then
						zone.friendly = true
					else
						zone.hostile = true
					end
				end
			end
		end
	end
	table.sort(out.zones, function(a, b)
		local la, lb = a.lo or 999, b.lo or 999
		if la ~= lb then
			return la < lb
		end
		return a.name < b.name
	end)
	out.complete = #out.zones > 0 and next(ranges) ~= nil
	return out
end

-- { zones = { {name, map, lo, hi, continent, friendly, hostile} ... }, byMap, dungeons }
function G.World()
	if world and (world.complete or time() - worldAt < RETRY) then
		return world
	end
	world, worldAt = buildWorld(), time()
	return world
end

-- The zone the player is in (a zone record), or nil in a place that is not a zone.
function G.CurrentZone()
	local mapID = G.PlayerMap()
	local byMap = G.World().byMap
	for _ = 1, 6 do
		if not mapID then
			return nil
		end
		if byMap[mapID] then
			return byMap[mapID]
		end
		local info = mapInfo(mapID)
		mapID = info and C.Plain(info.parentMapID, nil)
		if mapID == 0 then
			return nil
		end
	end
	return nil
end

-- How a level range sits against the player's level:
-- "fit", "soon" (a few levels away), "hard", "done" (outgrown) or nil when unknown.
function G.RangeState(lo, hi, level)
	if not lo or not hi then
		return nil
	end
	level = level or G.Level()
	if level > hi then
		return "done"
	elseif level >= lo then
		return "fit"
	elseif lo - level <= 3 then
		return "soon"
	end
	return "hard"
end

-- ---------------------------------------------------------------------------
-- Spells.

local function spellName(spellID)
	local name = C.Plain(C.Call("C_Spell.GetSpellName", spellID), nil)
	return type(name) == "string" and name or nil
end

local function spellIcon(spellID)
	local icon = C.Plain(C.Call("C_Spell.GetSpellTexture", spellID), nil)
	return (type(icon) == "number" or type(icon) == "string") and icon or nil
end

-- Fills in a talent's spell, name and icon (node is one of G.Talents().nodes). Done only
-- for the talents a page shows, since each costs two more questions to the game.
function G.TalentSpell(info, node)
	if node.resolved then
		return node
	end
	node.resolved = true
	local entry = type(node.entry) == "number" and C.Call("C_Traits.GetEntryInfo", info.config, node.entry) or nil
	local definitionID = type(entry) == "table" and C.Plain(entry.definitionID, nil) or nil
	local definition = type(definitionID) == "number" and C.Call("C_Traits.GetDefinitionInfo", definitionID) or nil
	if type(definition) == "table" then
		local spellID, name = C.Plain(definition.spellID, nil), C.Plain(definition.overrideName, nil)
		node.spell = type(spellID) == "number" and spellID or nil
		node.name = type(name) == "string" and name ~= "" and name or (node.spell and spellName(node.spell)) or nil
		node.icon = node.spell and spellIcon(node.spell) or nil
	end
	return node
end

-- Which row of its tree a talent sits in, counted from the top as the talent window draws
-- it (1 is the top row), or nil when the game gave no position.
-- Rows are 600 apart from 2130 down in every class's tree. A few talents in the game's
-- data sit a little off that grid, or far off it by a slip; near ones are snapped to their
-- row and far ones get no row rather than a wrong one.
local ROW_TOP, ROW_STEP, ROW_SLACK, ROW_MAX = 2130, 600, 60, 11

function G.TalentRow(info, node)
	if type(node.y) ~= "number" then
		return nil
	end
	local row = math.floor((node.y - ROW_TOP) / ROW_STEP + 0.5)
	if row < 0 or row >= ROW_MAX or math.abs(node.y - (ROW_TOP + row * ROW_STEP)) > ROW_SLACK then
		return nil
	end
	return row + 1
end

-- A talent's own words at one rank, as the game's talent tooltip gives them (its last
-- line, which is the description), or nil while the game has not loaded them.
function G.TalentText(entryID, rank)
	if type(entryID) ~= "number" then
		return nil
	end
	local data = C.Call("C_TooltipInfo.GetTraitEntry", entryID, rank)
	if type(data) ~= "table" or type(data.lines) ~= "table" then
		return nil
	end
	local last
	for _, line in ipairs(data.lines) do
		local text = type(line) == "table" and C.Plain(line.leftText, nil) or nil
		if type(text) == "string" and text ~= "" then
			last = text
		end
	end
	if not last then
		return nil
	end
	last = last:gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rR]", ""):gsub("%s*[\r\n]+%s*", " ")
	return last
end

-- The level the next talent point comes at. Only answered when this character's own count
-- fits one point a level since level 10; otherwise nil rather than a guess.
local FIRST_TALENT_LEVEL = 10
G.FIRST_TALENT_LEVEL = FIRST_TALENT_LEVEL

function G.NextTalentLevel(info)
	local level = G.Level()
	if info.unspentUnknown or level >= G.MaxLevel() or info.spent + info.unspent ~= level - FIRST_TALENT_LEVEL + 1 then
		return nil
	end
	return level + 1
end

local offBars, training -- caches, dropped by G.SpellsChanged()

-- Class spells the character knows that are on no action bar: { {name, spellID, icon} }.
function G.SpellsOffBars()
	if offBars then
		return offBars
	end
	local out = {}
	local bank = C.Resolve("Enum.SpellBookSpellBank.Player")
	local spellType = C.Resolve("Enum.SpellBookItemType.Spell")
	local lines = C.Plain(C.Call("C_SpellBook.GetNumSpellBookSkillLines"), nil)
	if bank == nil or spellType == nil or type(lines) ~= "number" or not C.Has("ActionButtonUtil.GetActionBarStatusForSpell") then
		return out
	end
	local seen = {}
	-- The first line is "General" (professions, racials, Attack); class spells follow.
	for line = math.min(2, lines), lines do
		local info = C.Call("C_SpellBook.GetSpellBookSkillLineInfo", line)
		if type(info) == "table" and C.Plain(info.shouldHide, false) ~= true then
			local first = C.Plain(info.itemIndexOffset, 0) or 0
			local total = C.Plain(info.numSpellBookItems, 0) or 0
			for slot = first + 1, first + total do
				local item = C.Call("C_SpellBook.GetSpellBookItemInfo", slot, bank)
				if type(item) == "table" and C.Plain(item.itemType, nil) == spellType
					and C.Plain(item.isPassive, true) == false and C.Plain(item.isOffSpec, false) ~= true then
					local id, name = C.Plain(item.spellID, nil), C.Plain(item.name, nil)
					if type(id) == "number" and type(name) == "string" and id ~= ATTACK and not seen[name] then
						local status = C.Plain(C.Call("ActionButtonUtil.GetActionBarStatusForSpell", item.actionID, true, false), nil)
						if status == MISSING_FROM_BARS
							and C.Plain(C.Call("C_SpellBook.IsSpellBookItemLowRank", slot, bank), false) ~= true then
							seen[name] = true
							out[#out + 1] = { name = name, spellID = id, icon = C.Plain(item.iconID, nil) or spellIcon(id) }
						end
					end
				end
			end
		end
	end
	offBars = out
	return out
end

function G.SpellsChanged()
	offBars, training = nil, nil
end

-- ---------------------------------------------------------------------------
-- The class trainer's list, remembered from the last visit, so Trailhead can say what
-- there is to learn and what it costs without the player standing at the trainer.
--
-- Three things the game does that shape this code:
--  * the list is not there yet when the window opens; it arrives with TRAINER_UPDATE;
--  * the window's filter usually hides spells for later levels, so the filter is switched
--    on for a moment to read them and then put back exactly as it was;
--  * buying a spell just makes it vanish from the filtered list.

local CLASS_TRAINER_MIN = 12 -- weapon masters and riding trainers teach far fewer things
local MAX_TRIES = 3
local visit -- the open trainer window: { tries, read, waiting, busy }, nil when closed
G.trainerLog = {} -- what happened at the last few trainers, for the game check

local function note(entry)
	G.trainerLog[#G.trainerLog + 1] = entry
	while #G.trainerLog > 6 do
		table.remove(G.trainerLog, 1)
	end
end

local function filterOn(kind)
	local on = C.Call("GetTrainerServiceTypeFilter", kind)
	if C.IsSecret(on) then
		return nil
	end
	return on
end

-- The services in the open trainer window as it is filtered right now, or nil when the
-- window belongs to a profession or pet trainer.
local function readServices()
	if C.Plain(C.Call("IsTradeskillTrainer"), false) == true then
		return nil
	end
	local kind = C.Plain(C.Call("C_Trainer.GetTrainerType"), nil)
	local pet = C.Resolve("Enum.TrainerType.Pet")
	if kind ~= nil and pet ~= nil and kind == pet then
		return nil
	end
	local list = {}
	local count = C.Plain(C.Call("GetNumTrainerServices"), 0)
	if type(count) ~= "number" then
		return list
	end
	for index = 1, math.min(count, 300) do
		local name, state, icon, level, sub, group = C.Call("GetTrainerServiceInfo", index)
		name, state = C.Plain(name, nil), C.Plain(state, nil)
		if type(name) == "string" and (state == "available" or state == "unavailable" or state == "used") then
			sub, group = C.Plain(sub, nil), C.Plain(group, nil)
			list[#list + 1] = {
				n = name, s = type(sub) == "string" and sub or nil, t = state,
				l = tonumber(C.Plain(level, 0)) or 0, i = C.Plain(icon, nil),
				c = tonumber(C.Plain(C.Call("GetTrainerServiceCost", index), 0)) or 0,
				g = type(group) == "string" and group or nil,
			}
		end
	end
	return list
end

-- The names of the character's own spell schools ("Combat", "Subtlety"); a class
-- trainer files what it teaches under the same names.
local function classLines()
	local names = {}
	local lines = C.Plain(C.Call("C_SpellBook.GetNumSpellBookSkillLines"), 0)
	if type(lines) == "number" then
		for line = 2, lines do
			local info = C.Call("C_SpellBook.GetSpellBookSkillLineInfo", line)
			local name = type(info) == "table" and C.Plain(info.name, nil)
			if type(name) == "string" then
				names[name] = true
			end
		end
	end
	return names
end

-- Class spells come in ranks ("Rank 2") and belong to the character's spell schools;
-- weapon skills and riding do neither.
local function isClassTrainer(list)
	if #list >= CLASS_TRAINER_MIN then
		return true
	end
	local rank = C.Plain(C.Resolve("RANK"), nil)
	rank = type(rank) == "string" and rank ~= "" and rank or "Rank"
	local lines = classLines()
	for _, entry in ipairs(list) do
		if (entry.s and entry.s:find(rank, 1, true)) or (entry.g and lines[entry.g]) then
			return true
		end
	end
	return false
end

-- Reads the open trainer window. Returns the list, or nil if it is not a class trainer.
function G.ReadTrainer()
	local list = readServices()
	if not list or not isClassTrainer(list) then
		return nil
	end
	return list
end

-- A spell's ranks share a name; the level each is learned at tells them apart. (The rank
-- text cannot be used: the game often has not loaded it yet when the list is read.)
local function key(entry)
	return entry.n .. "|" .. (entry.l or 0)
end

-- Stores what was read and tells the rest of Trailhead what kind of trainer this is.
local function conclude(list, full, how)
	visit.read, visit.waiting, visit.busy = true, false, false
	local class = isClassTrainer(list)
	local groups = {}
	for _, entry in ipairs(list) do
		if entry.g then
			groups[entry.g] = (groups[entry.g] or 0) + 1
		end
	end
	note({
		how = how, count = #list, full = full, class = class, groups = groups,
		before = visit.before, shown = visit.shown, tries = visit.tries,
		kind = C.Plain(C.Call("C_Trainer.GetTrainerType"), nil),
		filters = { a = filterOn("available"), u = filterOn("unavailable"), d = filterOn("used") },
	})
	if class and T.cdb then
		for _, entry in ipairs(list) do
			entry.g = nil
		end
		T.cdb.trainer = { at = time(), level = G.Level(), list = list, full = full or nil }
		training = nil
		T:Fire("TH_SPELLS_CHANGED")
	end
	T:Fire("TH_TRAINER_READ", class)
end

-- Second half of a read that had to wait for the game to apply the filter. Updates
-- that bring nothing new are not the answer yet; when time is up, what is there is kept.
local function finish(timeUp)
	if not visit or not visit.waiting then
		return
	end
	local list = readServices() or {}
	local grew = #list > (visit.shown or 0)
	if not grew and not timeUp then
		return
	end
	visit.waiting = false
	if #list == 0 and visit.tries < MAX_TRIES then
		-- Still nothing: the trainer's list has not arrived. Put the filter back and let
		-- the next update try again.
		visit.busy = false
		C.Call("SetTrainerServiceTypeFilter", "unavailable", false)
		return
	end
	conclude(list, grew, grew and "waited" or "no more")
	C.Call("SetTrainerServiceTypeFilter", "unavailable", false)
end

local function tryRead()
	if visit.read or visit.busy or visit.tries >= MAX_TRIES then
		return
	end
	local list = readServices()
	if not list then
		visit.read = true -- a profession or pet trainer: nothing to keep
		return
	end
	if not visit.before or #list > (visit.shown or 0) then
		-- Kept for the game check: the filter as the player had it, and how much it showed.
		visit.before = { a = filterOn("available"), u = filterOn("unavailable"), d = filterOn("used") }
		visit.shown = #list
	end
	local hidden = filterOn("unavailable") == false and C.Has("SetTrainerServiceTypeFilter")
	if not hidden then
		if #list > 0 then
			conclude(list, filterOn("unavailable") == true, "as shown")
		end
		return
	end
	if #list == 0 and visit.tries == 0 and not visit.updated then
		return -- the window has only just opened; wait for the list to arrive
	end
	-- Later levels are filtered out. Show them, read, and put the filter back.
	visit.tries = visit.tries + 1
	visit.busy = true
	C.Call("SetTrainerServiceTypeFilter", "unavailable", true)
	local full = readServices() or {}
	if #full > #list then
		conclude(full, true, "at once")
		C.Call("SetTrainerServiceTypeFilter", "unavailable", false)
		return
	end
	-- Either there is nothing more to see or the game applies the filter a moment
	-- later. Wait for its update, but never leave the filter changed for long.
	visit.waiting = true
	local mine = visit
	C_Timer.After(0.4, function()
		if visit == mine then
			finish(true)
		end
	end)
end

-- After a spell is bought it disappears from the filtered list: mark it learned.
local function merge(later)
	local saved = T.cdb and T.cdb.trainer
	local list = readServices()
	if not list or type(saved) ~= "table" or type(saved.list) ~= "table" or filterOn("available") == false then
		return
	end
	if #list == 0 and not later then
		-- Empty means either the last spell was just bought or the window is closing.
		-- Look again in a moment: by then a closing window has said so.
		local mine = visit
		C_Timer.After(0.3, function()
			if visit == mine then
				merge(true)
			end
		end)
		return
	end
	local now = {}
	for _, entry in ipairs(list) do
		now[key(entry)] = entry
	end
	local gone = {}
	local level = G.Level()
	for _, entry in ipairs(saved.list) do
		local current = now[key(entry)]
		if current then
			entry.t, entry.c = current.t, current.c
			entry.s = current.s or entry.s
		elseif entry.t == "available" and (entry.l or 0) <= level then
			-- Only what the window would be showing can go missing from it.
			gone[#gone + 1] = entry
		end
	end
	-- One or two at a time is the player buying spells. More than that is the list
	-- going away (the window closing), which says nothing about what was learned.
	if #gone > 0 and #gone <= 2 then
		for _, entry in ipairs(gone) do
			entry.t = "used"
		end
	end
	training = nil
	T:Fire("TH_SPELLS_CHANGED")
end

local function onTrainerShow()
	visit = { tries = 0 }
	tryRead()
end

local function onTrainerUpdate()
	if not visit then
		visit = { tries = 0 }
	end
	visit.updated = true
	if visit.waiting then
		finish()
	elseif visit.busy then
		return -- our own filter change echoing back
	elseif visit.read then
		merge()
	else
		tryRead()
	end
end

local function onTrainerClosed()
	if visit and visit.waiting then
		visit.waiting = false
		C.Call("SetTrainerServiceTypeFilter", "unavailable", false)
	end
	visit = nil
end

-- What can be trained now and what comes later.
-- Returns { now = {...}, later = {...}, cost = copper for everything in `now`,
--           source = "trainer" or nil (never visited) }. Entries: {name, sub, level, cost, icon}.
function G.Training()
	if training then
		return training
	end
	local level = G.Level()
	local out = { now = {}, later = {}, cost = 0 }
	local saved = T.cdb and T.cdb.trainer
	if type(saved) == "table" and type(saved.list) == "table" then
		out.source = "trainer"
		out.full = saved.full == true
		for _, entry in ipairs(saved.list) do
			if type(entry) == "table" and type(entry.n) == "string" and entry.t ~= "used" then
				local need = type(entry.l) == "number" and entry.l or 0
				local item = { name = entry.n, sub = entry.s, level = need, cost = entry.c or 0, icon = entry.i }
				-- The game calls later ranks of a spell you have not bought "available" even
				-- when they need a higher level, so the level always has the last word.
				if need > level then
					out.later[#out.later + 1] = item
				elseif entry.t == "available" or (need > 0 and need > (saved.level or 0)) then
					out.now[#out.now + 1] = item
					out.cost = out.cost + item.cost
				end
			end
		end
	end
	table.sort(out.later, function(a, b)
		if a.level ~= b.level then
			return a.level < b.level
		end
		return a.name < b.name
	end)
	training = out
	return out
end

-- Joins up to `most` names: "Sprint, Vanish and 2 more".
function G.NameList(items, most)
	most = most or 3
	local names = {}
	for index = 1, math.min(#items, most) do
		names[index] = items[index].name
	end
	local text = table.concat(names, ", ")
	if #items > most then
		text = L["%s and %d more"]:format(text, #items - most)
	end
	return text
end

-- ---------------------------------------------------------------------------
-- Which flight points this character has. The game's maps do not say, so Trailhead reads
-- the list whenever a flight master's map opens. Kept per continent, by name.

local function onTaxiOpened()
	local known, count, states, how = {}, 0, {}, "map"
	local mapID = C.Plain(C.Call("GetTaxiMapID"), nil)
	if type(mapID) ~= "number" then
		mapID = G.Continent() -- the old flight window has no map of its own
	end
	local nodes = type(mapID) == "number" and C.Call("C_TaxiMap.GetAllTaxiNodes", mapID) or nil
	if type(nodes) == "table" and #nodes > 0 then
		local unreachable = C.Resolve("Enum.FlightPathState.Unreachable")
		for _, node in ipairs(nodes) do
			local name, state = C.Plain(node.name, nil), C.Plain(node.state, nil)
			if type(name) == "string" then
				states[tostring(state)] = (states[tostring(state)] or 0) + 1
				if state ~= nil and state ~= unreachable then
					known[name] = true
					count = count + 1
				end
			end
		end
	else
		how = "frame"
		local total = C.Plain(C.Call("NumTaxiNodes"), 0)
		for index = 1, type(total) == "number" and total or 0 do
			local name = C.Plain(C.Call("TaxiNodeName", index), nil)
			local kind = C.Plain(C.Call("TaxiNodeGetType", index), nil)
			if type(name) == "string" and type(kind) == "string" then
				states[kind] = (states[kind] or 0) + 1
				if kind ~= "NONE" then
					known[name] = true
					count = count + 1
				end
			end
		end
	end
	local continent = G.Continent()
	G.taxiLog = { how = how, count = count, states = states, map = mapID, continent = continent }
	if count > 0 and continent then
		T.cdb.taxi = type(T.cdb.taxi) == "table" and T.cdb.taxi or {}
		T.cdb.taxi[continent] = known
		T:Fire("TH_TAXI_CHANGED")
	end
end

-- The flight points this character has on a continent, as a set of names; nil when no
-- flight master's map has been opened there yet.
function G.KnownFlights(continent)
	local saved = T.cdb and T.cdb.taxi
	local known = type(saved) == "table" and continent and saved[continent]
	return type(known) == "table" and known or nil
end

-- ---------------------------------------------------------------------------
-- Dungeon and raid entrances. The game lists none, so Trailhead remembers where the
-- player stood just before walking into one. Shared by every character on the account.

local ENTRANCE_AGE = 120 -- seconds a remembered spot stays good across a loading screen
local SUMMON_AGE = 90 -- a summon lands you inside without passing the door
local SAME_DOOR = 0.03 -- map units; closer than this is the same entrance
local outside, summonedAt

local function entranceKey(name)
	return normal(name)
end

local function rememberEntrance(name, kind, spot)
	T.db.entrances = type(T.db.entrances) == "table" and T.db.entrances or {}
	local key = entranceKey(name)
	local entry = T.db.entrances[key] or { n = name, k = kind, spots = {} }
	T.db.entrances[key] = entry
	for _, known in ipairs(entry.spots) do
		if known.m == spot.map and math.abs(known.x - spot.x) < SAME_DOOR and math.abs(known.y - spot.y) < SAME_DOOR then
			known.c = (known.c or 1) + 1
			T:Fire("TH_PLACES_CHANGED")
			return
		end
	end
	if #entry.spots < 6 then
		entry.spots[#entry.spots + 1] = { m = spot.map, x = spot.x, y = spot.y, c = 1 }
	end
	T:Fire("TH_PLACES_CHANGED")
end

-- Called every couple of seconds and on every loading screen.
local function watchDoor()
	local inside, kind = C.Call("IsInInstance")
	inside, kind = C.Plain(inside, false), C.Plain(kind, nil)
	if inside == true then
		local spot = outside
		outside = nil
		if spot and (kind == "party" or kind == "raid") and time() - spot.at <= ENTRANCE_AGE
			and not (summonedAt and time() - summonedAt <= SUMMON_AGE) then
			local name = C.Plain(C.Call("GetInstanceInfo"), nil)
			if type(name) == "string" and name ~= "" then
				rememberEntrance(name, kind, spot)
			end
		end
		return
	end
	if C.InCombat() then
		return
	end
	local mapID, x, y = G.PlayerMap()
	-- An entrance cave has a map of its own; the spot on the zone's map is the useful one.
	local zone = mapID and G.ZoneOf(mapID)
	if zone and zone ~= mapID then
		local zx, zy = G.PositionOn(zone)
		if zx then
			mapID, x, y = zone, zx, zy
		end
	end
	if mapID and x then
		outside = outside or {}
		outside.map, outside.x, outside.y, outside.at = mapID, x, y, time()
	end
end
G.WatchDoor = watchDoor

-- Where a dungeon or raid is entered: { map, x, y, zone } for the spot used most, or nil.
function G.Entrance(name)
	if type(name) ~= "string" then
		return nil
	end
	local saved = T.db and T.db.entrances
	if type(saved) ~= "table" then
		saved = {}
	end
	local key = entranceKey(name)
	local entry = saved[key]
	if not entry then
		-- "Scarlet Monastery: Library" in one list, "Scarlet Monastery" in the other.
		for other, candidate in pairs(saved) do
			if key:sub(1, #other) == other or other:sub(1, #key) == key then
				entry = candidate
				break
			end
		end
	end
	local best
	for _, spot in ipairs(entry and entry.spots or {}) do
		if not best or (spot.c or 1) > (best.c or 1) then
			best = spot
		end
	end
	if not best then
		-- No character has walked in yet: the door the game's tables ship, if they have one.
		return T.Dungeons and T.Dungeons.Shipped(name) or nil
	end
	return { map = best.m, x = best.x, y = best.y, zone = G.MapName(best.m) }
end

-- ---------------------------------------------------------------------------
-- Skills: weapon skills and professions, from the character sheet's skill list.

local SKILL_WEAPONS, SKILL_PROFESSIONS, SKILL_SECONDARY = 6, 11, 9 -- the list's own headings
local SKILL_ARMOR = 8 -- the "Armor Proficiencies" heading
local SKILL_DEFENSE = 95
local SKILL_LOCKPICKING = 633 -- its limit follows your level, not a trainer
local SKILL_PER_LEVEL = 5 -- a weapon skill's limit is 5 for each level
-- The game's own skills window: each point of weapon skill under 5 x level takes this much
-- (in percent) off the chance to hit and off the chance to crit an enemy of your level.
local PERCENT_PER_POINT = 0.04
G.SKILL_BEHIND = 25 -- points under the limit before a weapon skill is marked low (1%)
G.SKILL_FAR_BEHIND = 50 -- and before Home says so (2%)
G.SKILL_NEAR = 10 -- points under the limit before a profession counts as nearly full
-- The kind of weapon (the game's item subclass) and the skill it uses, as the game's own
-- character window maps them. Fist weapons use Unarmed.
local WEAPON_SKILL = {
	[0] = 44, [1] = 172, [2] = 45, [3] = 46, [4] = 54, [5] = 160, [6] = 229, [7] = 43, [8] = 55,
	[10] = 136, [13] = 162, [15] = 173, [16] = 176, [18] = 226, [19] = 228,
}

-- { weapons, professions, secondary = { {id, name, rank, max} ... }, defense, byId, complete }
-- complete is false when the game gave no list or one of the headings is folded shut.
function G.Skills()
	local out = { weapons = {}, professions = {}, secondary = {}, armor = {}, byId = {}, complete = true }
	local total = C.Plain(C.Call("C_SkillInfo.GetNumSkillLines"), 0)
	if type(total) ~= "number" or total == 0 then
		out.complete = false
		return out
	end
	local lists = { [SKILL_WEAPONS] = out.weapons, [SKILL_PROFESSIONS] = out.professions, [SKILL_SECONDARY] = out.secondary }
	for index = 1, total do
		local info = C.Call("C_SkillInfo.GetSkillLineInfo", index)
		if type(info) == "table" then
			local name, id = C.Plain(info.name, nil), C.Plain(info.skillID, nil)
			if C.Plain(info.isHeader, false) == true then
				if lists[id] and C.Plain(info.isCollapsed, false) == true then
					out.complete = false
				elseif id == SKILL_ARMOR and C.Plain(info.isCollapsed, false) == true then
					out.armorFolded = true
				end
			elseif type(name) == "string" and type(id) == "number" and C.Plain(info.parentSkillLineID, 0) == 0 then
				local rank, max = C.Plain(info.rank, nil), C.Plain(info.maxRank, nil)
				local list = lists[C.Plain(info.skillLineCategoryID, nil)]
				if C.Plain(info.skillLineCategoryID, nil) == SKILL_ARMOR then
					out.armor[#out.armor + 1] = name
				end
				if list and type(rank) == "number" and type(max) == "number" and max > 0 then
					local bonus = C.Plain(info.modifier, 0)
					local entry = { id = id, name = name, rank = rank, max = max, bonus = type(bonus) == "number" and bonus or 0,
						levelBound = id == SKILL_LOCKPICKING }
					out.byId[id] = entry
					if id == SKILL_DEFENSE then
						out.defense = entry
					else
						list[#list + 1] = entry
					end
				end
			end
		end
	end
	return out
end

-- What the character wears (game check 7): the kinds of armor the skill list says it can
-- wear, the kinds it does wear (the game's own words for each piece), the slots with
-- nothing in them, and the most worn piece.
-- { read, can = { "Cloth", "Leather" }, canFolded, worn = { { label, count } ... },
--   empty = { "Head", ... }, breakable = pieces that have a durability,
--   lowest = { name, part = 0 to 1 } or nil }
local ARMOR_CLASS = 4
local ARMOR_SLOT = { [1] = true, [3] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true }
local GEAR_SLOTS = {
	{ 1, "HEADSLOT", L["Head"] }, { 2, "NECKSLOT", L["Neck"] }, { 3, "SHOULDERSLOT", L["Shoulders"] }, { 15, "BACKSLOT", L["Back"] },
	{ 5, "CHESTSLOT", L["Chest"] }, { 9, "WRISTSLOT", L["Wrist"] }, { 10, "HANDSSLOT", L["Hands"] }, { 6, "WAISTSLOT", L["Waist"] },
	{ 7, "LEGSSLOT", L["Legs"] }, { 8, "FEETSLOT", L["Feet"] }, { 11, "FINGER0SLOT", L["Finger"] }, { 12, "FINGER1SLOT", L["Finger"] },
	{ 13, "TRINKET0SLOT", L["Trinket"] }, { 14, "TRINKET1SLOT", L["Trinket"] }, { 16, "MAINHANDSLOT", L["Main Hand"] },
}

function G.Gear(skills)
	skills = skills or G.Skills()
	local out = { read = C.Has("GetInventoryItemID"), can = skills.armor or {}, canFolded = skills.armorFolded == true, worn = {}, empty = {}, breakable = 0 }
	if not out.read then
		return out
	end
	local tally, listed = {}, {}
	for _, slot in ipairs(GEAR_SLOTS) do
		local itemID = C.Plain(C.Call("GetInventoryItemID", "player", slot[1]), nil)
		if type(itemID) ~= "number" then
			local name = type(_G[slot[2]]) == "string" and _G[slot[2]] or slot[3]
			if not listed[name] then
				listed[name] = true
				out.empty[#out.empty + 1] = name
			end
		elseif ARMOR_SLOT[slot[1]] then
			local _, _, label, _, _, classID, subClassID = C.Call("C_Item.GetItemInfoInstant", itemID)
			label, subClassID = C.Plain(label, nil), C.Plain(subClassID, 0)
			if C.Plain(classID, nil) == ARMOR_CLASS and type(subClassID) == "number" and subClassID > 0 and type(label) == "string" and label ~= "" then
				if not tally[label] then
					tally[label] = { label = label, count = 0 }
					out.worn[#out.worn + 1] = tally[label]
				end
				tally[label].count = tally[label].count + 1
			end
		end
	end
	table.sort(out.worn, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.label < b.label
	end)
	for slot = 1, 18 do
		local now, most = C.Call("GetInventoryItemDurability", slot)
		now, most = C.Plain(now), C.Plain(most)
		if type(now) == "number" and type(most) == "number" and most > 0 then
			out.breakable = out.breakable + 1
			local part = now / most
			if not out.lowest or part < out.lowest.part then
				local itemID = C.Plain(C.Call("GetInventoryItemID", "player", slot), nil)
				local name = type(itemID) == "number" and C.Plain(C.Call("C_Item.GetItemNameByID", itemID), nil) or nil
				out.lowest = { part = part, name = type(name) == "string" and name ~= "" and name or nil }
			end
		end
	end
	return out
end

-- The weapons in hand, each with the skill it uses: { {slot, name, skill} ... }. A weapon
-- whose skill cannot be matched is left out rather than guessed at.
function G.Hands(skills)
	local out = {}
	skills = skills or G.Skills()
	for _, slot in ipairs({ 16, 17, 18 }) do
		local itemID = C.Plain(C.Call("GetInventoryItemID", "player", slot), nil)
		if type(itemID) == "number" then
			local _, _, _, _, _, classID, subClassID = C.Call("C_Item.GetItemInfoInstant", itemID)
			local skill = C.Plain(classID, nil) == 2 and skills.byId[WEAPON_SKILL[C.Plain(subClassID, -1)] or 0] or nil
			if skill then
				skill.inHand = true
				out[#out + 1] = { slot = slot, name = C.Plain(C.Call("C_Item.GetItemNameByID", itemID), nil), skill = skill }
			end
		end
	end
	return out
end

-- How much a weapon skill under its limit costs, in percent of the chance to hit and to
-- crit an enemy of your level (the same sum the game's skills window does).
function G.SkillCost(skill)
	local level = G.Level()
	local full = type(level) == "number" and level > 0 and level * SKILL_PER_LEVEL or skill.max
	return math.max(0, (full - (skill.rank + (skill.bonus or 0))) * PERCENT_PER_POINT)
end

-- Weapon skills in hand that are at least `points` under their limit, worst first.
function G.WeaponsBehind(points, skills)
	local out, seen = {}, {}
	for _, hand in ipairs(G.Hands(skills)) do
		local skill = hand.skill
		if not seen[skill.id] and skill.max - skill.rank >= (points or G.SKILL_BEHIND) then
			seen[skill.id] = true
			out[#out + 1] = skill
		end
	end
	table.sort(out, function(a, b)
		return a.max - a.rank > b.max - b.rank
	end)
	return out
end

local function onLogin()
	local function spells()
		G.SpellsChanged()
		T:Fire("TH_SPELLS_CHANGED")
	end
	for _, event in ipairs({ "SPELLS_CHANGED", "ACTIONBAR_SLOT_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_LEVEL_CHANGED" }) do
		T:On(event, spells)
	end
	T:On("PLAYER_LEVEL_UP", function(level)
		level = C.Plain(level, nil)
		if type(level) == "number" then
			levelSeen = level
		end
		spells()
	end)
	T:On("TRAINER_SHOW", onTrainerShow)
	T:On("TRAINER_UPDATE", onTrainerUpdate)
	T:On("TRAINER_CLOSED", onTrainerClosed)
	T:On("TAXIMAP_OPENED", onTaxiOpened)
	local function skillsChanged()
		T:Fire("TH_SKILLS_CHANGED")
	end
	T:On("SKILL_LINES_CHANGED", skillsChanged)
	T:On("TRAIT_CONFIG_UPDATED", skillsChanged)
	T:On("PLAYER_EQUIPMENT_CHANGED", skillsChanged)
	T:On("PLAYER_ENTERING_WORLD", watchDoor)
	T:On("CONFIRM_SUMMON", function()
		summonedAt = time()
	end)
	if C.Has("C_Timer.NewTicker") then
		C_Timer.NewTicker(2, function()
			T.SafeCall("Game.WatchDoor", watchDoor)
		end)
	end
end

T:On("PLAYER_LOGIN", onLogin)
