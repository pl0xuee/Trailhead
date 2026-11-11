local _, T = ...
local L = T.L
local C = T.Compat
local G = T.Game

-- Places: where things are. Sources:
--   1. the game itself (flight points on every map),
--   2. what the player has found: every service they open is remembered with its spot,
--   3. directions from city guards, which the game marks on the map and Trailhead keeps,
--   4. the built-in list (Data/Known.lua by hand, Data/Seed.lua generated), which a place
--      the player found takes over from.
-- Found places are shared by every character on the account.

local P = {}
T.Places = P

local MAX_PLACES = 1500
local SAME_SPOT = 0.012 -- map units; closer than this is the same place

-- ---------------------------------------------------------------------------
-- Remembering.

local function store()
	local db = T.db
	if type(db.places) ~= "table" then
		db.places = {}
	end
	return db.places
end

local function zoneLabel(mapID)
	return G.MapName(mapID) or C.Plain(C.Call("GetRealZoneText"), nil) or ""
end

-- Adds a place, or refreshes the one already known at that spot. Returns the record.
function P.Remember(categoryId, name, mapID, x, y, source)
	if not T.CategoryById[categoryId] or type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
		return nil
	end
	if type(name) ~= "string" or name == "" then
		name = T.CategoryById[categoryId].label
	end
	local list = store()
	local faction = G.Faction()
	for _, place in ipairs(list) do
		if place.c == categoryId and place.m == mapID
			and math.abs(place.x - x) < SAME_SPOT and math.abs(place.y - y) < SAME_SPOT then
			-- A name read from the person in front of you beats a guard's description.
			if source == "seen" or place.s ~= "seen" then
				place.n, place.s = name, source
				place.x, place.y = x, y
			end
			place.t, place.f = time(), faction
			return place
		end
	end
	local place = { c = categoryId, n = name, m = mapID, x = x, y = y, z = zoneLabel(mapID), f = faction, s = source, t = time() }
	list[#list + 1] = place
	while #list > MAX_PLACES do
		table.remove(list, 1)
	end
	T:Fire("TH_PLACES_CHANGED")
	return place
end

local function npcName()
	local name = C.Plain(C.Call("UnitName", "npc"), nil)
	return type(name) == "string" and name or nil
end

-- Remembers the service the player is standing at.
local function seen(categoryId, name)
	local mapID, x, y = G.PlayerMap()
	if mapID and x and y then
		P.Remember(categoryId, name or npcName(), mapID, x, y, "seen")
	end
end

local function onMerchant()
	seen("vendor")
	if C.Plain(C.Call("CanMerchantRepair"), false) == true then
		seen("repair")
	end
end

local function onTrainer()
	if C.Plain(C.Call("IsTradeskillTrainer"), false) == true then
		seen("professions")
	end
end

-- Forgets a record filed under "other" at this spot once it is known what it really is.
local function dropOther(mapID, x, y)
	local list = store()
	for index = #list, 1, -1 do
		local place = list[index]
		if place.c == "other" and place.m == mapID
			and math.abs(place.x - x) < SAME_SPOT and math.abs(place.y - y) < SAME_SPOT then
			table.remove(list, index)
		end
	end
end

-- The trainer's list arrives a moment after the window opens, so what kind of trainer
-- this is only becomes known once Game.lua has read it.
local function onTrainerRead(class)
	local mapID, x, y = G.PlayerMap()
	if not (mapID and x and y) then
		return
	end
	local name = npcName()
	if not class then
		P.Remember("other", name, mapID, x, y, "seen") -- weapon masters, riding trainers: found by name
		return
	end
	local mine = G.ClassName()
	if name and mine ~= "" then
		name = mine .. ": " .. name
	end
	dropOther(mapID, x, y)
	P.Remember("trainer", name, mapID, x, y, "seen")
	T:Fire("TH_PLACES_CHANGED")
end

local function onBind()
	seen("inn")
end

-- The game announces most services through one event with a type number.
local function onInteraction(kind)
	local types = C.Resolve("Enum.PlayerInteractionType")
	kind = C.Plain(kind, nil)
	if type(types) ~= "table" or kind == nil then
		return
	end
	if kind == types.Banker or kind == types.CharacterBanker then
		seen("bank")
	elseif kind == types.MailInfo then
		seen("mailbox", L["Mailbox"])
	elseif kind == types.Auctioneer then
		seen("auction")
	elseif kind == types.StableMaster then
		seen("stable")
	elseif kind == types.Binder then
		seen("inn")
	end
end

-- ---------------------------------------------------------------------------
-- Guard directions. Asking a guard goes through one or two menus ("Class trainer", then
-- "Mage") and ends with the game putting a flag on the map. The menu choices say what
-- the flag is for, so they are kept until the flag appears.

P.guardLog = {}
local options = {} -- what the open menu offers: id or index -> text
local trail = {} -- what the player picked since the conversation began

local function readOptions()
	options = {}
	local list = C.Call("C_GossipInfo.GetOptions")
	if type(list) ~= "table" then
		return
	end
	for _, option in ipairs(list) do
		local name = C.Plain(option.name, nil)
		if type(name) == "string" then
			local id, index = C.Plain(option.gossipOptionID, nil), C.Plain(option.orderIndex, nil)
			if id ~= nil then
				options["id" .. tostring(id)] = name
			end
			if index ~= nil then
				options["index" .. tostring(index)] = name
			end
		end
	end
end

local function picked(key)
	local name = options[key]
	if name then
		trail[#trail + 1] = name
		while #trail > 4 do
			table.remove(trail, 1)
		end
	end
end

-- Works out which category a guard's flag belongs to, from what the player asked for.
local KEYWORDS = {
	{ "bank", L["bank"] }, { "mailbox", L["mailbox"] }, { "auction", L["auction"] },
	{ "inn", L["inn"] }, { "stable", L["stable"] }, { "weapons", L["weapon master"] }, { "riding", L["riding"] },
	{ "flight", L["flight"] }, { "flight", L["wind rider"] }, { "flight", L["gryphon"] },
	{ "flight", L["bat handler"] }, { "flight", L["hippogryph"] },
	{ "professions", L["profession"] },
}

function P.GuessCategory(asked, flagName)
	local last = (asked[#asked] or ""):lower()
	local all = (table.concat(asked, " ") .. " " .. (flagName or "")):lower()
	local class = G.ClassName():lower()
	if class ~= "" and (last == class or last:find(class, 1, true)) and all:find(L["trainer"], 1, true) then
		return "trainer"
	end
	for _, pair in ipairs(KEYWORDS) do
		-- Whole words only, so "inn" does not match "beginning".
		if (" " .. all:gsub("%p", " ") .. " "):find(" " .. pair[2] .. " ", 1, true) then
			return pair[1]
		end
	end
	if class ~= "" and last == class then
		return "trainer"
	end
	return "other"
end

local function onGuardFlag()
	local mapID = G.PlayerMap()
	if not mapID then
		return
	end
	local flag = C.Plain(C.Call("C_GossipInfo.GetPoiForUiMapID", mapID), nil)
	if flag == nil then
		return
	end
	local info = C.Call("C_GossipInfo.GetPoiInfo", mapID, flag)
	if type(info) ~= "table" or type(info.position) ~= "table" then
		return
	end
	local x, y = C.Plain(info.position.x, nil), C.Plain(info.position.y, nil)
	local name = C.Plain(info.name, nil)
	if type(x) ~= "number" or type(y) ~= "number" then
		return
	end
	local asked = trail[#trail]
	local label = type(name) == "string" and name ~= "" and name or asked
	if asked and label ~= asked and not label:lower():find(asked:lower(), 1, true) then
		label = asked .. ": " .. label
	end
	local category = P.GuessCategory(trail, name)
	-- Kept for the game check, so a wrong guess can be seen and fixed.
	P.guardLog[#P.guardLog + 1] = { asked = table.concat(trail, " > "), flag = name, as = category }
	while #P.guardLog > 8 do
		table.remove(P.guardLog, 1)
	end
	P.Remember(category, label, mapID, x, y, "guard")
end

-- ---------------------------------------------------------------------------
-- Finding.

local function matches(text, words)
	text = text:lower()
	for _, word in ipairs(words) do
		if not text:find(word, 1, true) then
			return false
		end
	end
	return true
end

-- Distance between two spots on one map, in map heights: the game's maps are half as wide
-- again as they are tall, so a step sideways counts for more.
local MAP_ASPECT = 1.5
local function distance(ax, ay, bx, by)
	local dx, dy = (ax - bx) * MAP_ASPECT, ay - by
	return math.sqrt(dx * dx + dy * dy)
end

-- Closest first. A place with a distance comes before one without (another continent); among
-- those without, this zone first, then by name: a total order, so sort never fails.
local function byNearness(a, b)
	if (a.dist == nil) ~= (b.dist == nil) then
		return a.dist ~= nil
	end
	if a.dist and b.dist and a.dist ~= b.dist then
		return a.dist < b.dist
	end
	if a.here ~= b.here then
		return a.here
	end
	if a.where ~= b.where then
		return a.where < b.where
	end
	return a.title < b.title
end

-- Flight points on the player's continent, nearest first, own faction only.
local function flightResults()
	local out = {}
	local continent = G.Continent()
	if not continent then
		return out
	end
	local mine = G.Faction()
	local px, py = G.PositionOn(continent)
	local zone = G.CurrentZone()
	local zoneKey = zone and zone.key
	local _, height = G.MapYards(continent)
	for _, node in ipairs(G.TaxiNodes(continent)) do
		if node.faction == 0 or mine == nil or node.faction == mine then
			local key = G.NormalName(node.zone)
			-- A city's own flight point is named "Orgrimmar, Durotar": match the town too.
			local town = G.NormalName(node.town)
			local here = zoneKey ~= nil and (zoneKey == key or zoneKey:sub(1, #key + 1) == key .. " "
				or zoneKey == town or zoneKey:sub(1, #town + 1) == town .. " ")
			out[#out + 1] = {
				kind = "flight", category = "flight", icon = "wing",
				title = node.town, where = node.zone, here = here or false,
				dist = px and distance(px, py, node.x, node.y) or nil,
				yards = px and height and distance(px, py, node.x, node.y) * height or nil,
				note = L["From the game's flight map"],
				map = continent, x = node.x, y = node.y, node = node.id, zoneKey = key, townKey = town,
			}
		end
	end
	table.sort(out, byNearness)
	return out
end

local seedZones, placeDistance -- see the built-in list below

local function placeResult(place, mapID, px, py)
	local category = T.CategoryById[place.c] or T.CategoryById.other
	local here = place.m == mapID
	local dist, yards = placeDistance(place.m, place.x, place.y, mapID, px, py)
	return {
		kind = "place", category = category.id, icon = category.icon,
		title = place.n, where = place.z or "", here = here,
		dist = dist, yards = yards,
		note = place.s == "guard" and L["A guard pointed here"] or L["You have been here"],
		map = place.m, x = place.x, y = place.y,
	}
end

-- Places from the guides (Data/Known.lua) that this character can use and has not found
-- for themselves: own faction, and for riding the character's own race when it is listed.
local NEAR_KNOWN = 0.03

local function knownPlaces()
	local out = {}
	local list = T.Known and T.Known.places or {}
	local mine, race = G.Faction(), G.RaceFile()
	local raceListed = false
	for _, place in ipairs(list) do
		if place.race and place.race == race then
			raceListed = true
		end
	end
	local found = store()
	for _, place in ipairs(list) do
		local usable = (mine == nil or place.f == mine) and (not place.race or not raceListed or place.race == race)
		if usable then
			for _, own in ipairs(found) do
				if own.c == place.c and own.m == place.m and math.abs(own.x - place.x) < NEAR_KNOWN and math.abs(own.y - place.y) < NEAR_KNOWN then
					usable = false
					break
				end
			end
		end
		if usable then
			out[#out + 1] = place
		end
	end
	return out
end

local function knownResult(place, mapID, px, py)
	local result = placeResult(place, mapID, px, py)
	result.note, result.known = place.note, true
	return result
end

-- The places from the guides for one category, as this character can use them.
function P.Known(categoryId)
	local out = {}
	for _, place in ipairs(knownPlaces()) do
		if place.c == categoryId then
			out[#out + 1] = place
		end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- The built-in list (Data/Seed.lua). One long string, read the first time it is needed and
-- not at login. Each place is hidden while the player has found the same thing themselves.

local SHIPPED_MAX = 25 -- built-in places shown in one list, so it stays readable
local NEAR_SEED = 0.03 -- map units; a place of your own this close hides the built-in one
local CATEGORY_OF = {
	t = "trainer", v = "vendor", r = "repair", i = "inn", f = "flight", m = "mailbox",
	b = "bank", p = "professions", a = "auction", w = "weapons", s = "stable",
}
local seedByCategory -- category id -> list of records
local seedCache = {} -- category/faction/class -> the records this character may use
local zoneLabels = {}
local frame -- the player's spot on its continent for the lookup in progress: cont, x, y

local function loadSeed()
	if seedByCategory then
		return
	end
	seedZones, seedByCategory = {}, {}
	local seed = T.Seed
	if type(seed) ~= "table" then
		return
	end
	for line in tostring(seed.zones or ""):gmatch("[^\n]+") do
		local map, cont, ax, bx, ay, by, name = line:match("^(%d+)|(%d*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
		if map then
			seedZones[tonumber(map)] = {
				cont = tonumber(cont), ax = tonumber(ax), bx = tonumber(bx), ay = tonumber(ay), by = tonumber(by), name = name,
			}
		end
	end
	for line in tostring(seed.places or ""):gmatch("[^\n]+") do
		local code, faction, map, x, y, name, extra = line:match("^(%a)|(%a?)|(%d+)|(%d+)|(%d+)|([^|]*)|(.*)$")
		local category = code and CATEGORY_OF[code]
		map = tonumber(map)
		if category and seedZones[map] then
			local zone = seedZones[map]
			x, y = tonumber(x) / 1000, tonumber(y) / 1000
			local list = seedByCategory[category]
			if not list then
				list = {}
				seedByCategory[category] = list
			end
			list[#list + 1] = {
				c = category, f = faction == "A" and 2 or faction == "H" and 1 or nil, m = map, x = x, y = y,
				n = name, key = name:lower(), e = extra ~= "" and extra or nil,
				cont = zone.cont, cx = zone.cont and (zone.ax * x + zone.bx) or nil, cy = zone.cont and (zone.ay * y + zone.by) or nil,
			}
		end
	end
	seed.zones, seed.places = nil, nil -- the records hold all of it now
end

-- Distance for sorting, and the same in yards when the game says how big the continent is.
-- Everything on the player's continent is measured on the continent's map, so a place just
-- over a zone border counts as near as it is. Nil when the two cannot be compared (another
-- continent); a map the built-in list cannot place is measured on itself.
placeDistance = function(placeMap, x, y, mapID, px, py)
	if not px then
		return nil
	end
	local zone = seedZones[placeMap]
	if frame and zone and zone.cont == frame.cont then
		local dist = distance(frame.x, frame.y, zone.ax * x + zone.bx, zone.ay * y + zone.by)
		return dist, frame.height and dist * frame.height or nil
	end
	if placeMap == mapID then
		-- Smaller than any distance across the continent, so these still come first.
		return distance(px, py, x, y) / 1000
	end
	return nil
end

-- Works out where the player is on the continent, once per lookup.
local function setFrame(mapID, px, py)
	loadSeed()
	frame = nil
	if not mapID then
		return
	end
	local zone = seedZones[mapID]
	local cont = zone and zone.cont or G.ContinentOf(mapID)
	if not cont then
		return
	end
	local cx, cy = G.PositionOn(cont)
	if not cx and zone and zone.cont and px then
		cx, cy = zone.ax * px + zone.bx, zone.ay * py + zone.by
	end
	if cx then
		local _, height = G.MapYards(cont)
		frame = { cont = cont, x = cx, y = cy, height = height }
	end
end

local function zoneName(mapID)
	local name = zoneLabels[mapID]
	if not name then
		name = G.MapName(mapID) or (seedZones[mapID] and seedZones[mapID].name) or ""
		zoneLabels[mapID] = name
	end
	return name
end

-- What this character may use: own faction, and for class trainers their own class.
local function usable(categoryId)
	local mine, class = G.Faction(), G.ClassFile()
	local key = categoryId .. "/" .. tostring(mine) .. "/" .. tostring(class)
	local list = seedCache[key]
	if not list then
		list = {}
		for _, rec in ipairs(seedByCategory[categoryId] or {}) do
			if (rec.f == nil or mine == nil or rec.f == mine) and (categoryId ~= "trainer" or class == nil or rec.e == class) then
				list[#list + 1] = rec
			end
		end
		seedCache[key] = list
	end
	return list
end

-- The kind of place for the list ("Mage trainer", "Mining trainer", a vendor's title), or nil.
local function kindOf(rec)
	if rec.c == "trainer" then
		local class = G.ClassName()
		return L["%s trainer"]:format(class ~= "" and class or L["Class"])
	elseif rec.c == "professions" and rec.e then
		return L["%s trainer"]:format((rec.e:gsub(",", ", ")))
	elseif (rec.c == "vendor" or rec.c == "flight") and rec.e then
		return rec.e
	end
	return nil
end

-- "Mage: Jennea Cannon" (a trainer found in game) is the same person as "Jennea Cannon".
local function plainName(name)
	return ((name or ""):gsub("^[^:]*:%s*", "")):lower()
end

-- True when a place of the player's own (or of the hand-checked guides) is this one.
local function isSame(rec, other, mine)
	if other.c ~= rec.c or not (other.f == nil or mine == nil or other.f == mine) then
		return false
	end
	if other.m == rec.m and math.abs(other.x - rec.x) < NEAR_SEED and math.abs(other.y - rec.y) < NEAR_SEED then
		return true
	end
	-- Every mailbox is called "Mailbox": a name says nothing there.
	return rec.c ~= "mailbox" and plainName(other.n) == rec.key
end

local function covered(rec)
	local mine = G.Faction()
	for _, own in ipairs(store()) do
		if isSame(rec, own, mine) then
			return true
		end
	end
	if rec.c == "weapons" or rec.c == "riding" then
		for _, place in ipairs(T.Known and T.Known.places or {}) do
			if isSame(rec, place, mine) then
				return true
			end
		end
	end
	return false
end

local function seedResult(rec, mapID, px, py)
	local category = T.CategoryById[rec.c]
	-- "Razor Hill, Durotar" when the place stands in a town the hub list knows.
	local where = zoneName(rec.m)
	local town = T.Hubs and T.Hubs.Near and T.Hubs.Near(rec.m, rec.x, rec.y)
	if town and town ~= where then
		where = L["%s, %s"]:format(town, where)
	end
	local dist, yards = placeDistance(rec.m, rec.x, rec.y, mapID, px, py)
	return {
		kind = "place", category = rec.c, icon = category.icon,
		title = rec.n, where = where, here = rec.m == mapID,
		dist = dist, yards = yards,
		note = kindOf(rec) or L["From the built-in list"], known = true, shipped = true,
		map = rec.m, x = rec.x, y = rec.y,
	}
end

-- The built-in places for one category (or, with words, for a search over all of them):
-- the nearest ones, this map first, then the rest of the continent by distance, then
-- the rest by name. `skip` may drop a place the caller already has.
local function shippedFor(categoryId, mapID, px, py, words, skip)
	setFrame(mapID, px, py)
	local ranked = {}
	local ids = { categoryId }
	if not categoryId then
		ids = {}
		for _, category in ipairs(T.Categories) do
			ids[#ids + 1] = category.id
		end
	end
	for _, id in ipairs(ids) do
		for _, rec in ipairs(usable(id)) do
			if not words or matches(rec.n .. " " .. zoneName(rec.m) .. " " .. (kindOf(rec) or ""), words) then
				ranked[#ranked + 1] = {
					rec = rec, here = rec.m == mapID, dist = (placeDistance(rec.m, rec.x, rec.y, mapID, px, py)),
				}
			end
		end
	end
	table.sort(ranked, function(a, b)
		if (a.dist == nil) ~= (b.dist == nil) then
			return a.dist ~= nil
		end
		if a.dist and b.dist and a.dist ~= b.dist then
			return a.dist < b.dist
		end
		if a.here ~= b.here then
			return a.here
		end
		if a.rec.m ~= b.rec.m then
			return zoneName(a.rec.m) < zoneName(b.rec.m)
		end
		if a.rec.n ~= b.rec.n then
			return a.rec.n < b.rec.n
		end
		return a.rec.x < b.rec.x
	end)
	local out = {}
	for _, item in ipairs(ranked) do
		if not covered(item.rec) and not (skip and skip(item.rec)) then
			out[#out + 1] = seedResult(item.rec, mapID, px, py)
			if #out >= SHIPPED_MAX then
				break
			end
		end
	end
	return out
end

-- The game's own flight map already has a point where a built-in flight master stands.
local function flightSkip(nodes)
	return function(rec)
		if rec.c ~= "flight" then
			return false
		end
		for _, node in ipairs(nodes) do
			if rec.cont == node.map and math.abs(node.x - rec.cx) < 0.02 and math.abs(node.y - rec.cy) < 0.02 then
				return true
			end
		end
		return false
	end
end

-- Everything known for one category, nearest first.
function P.Find(categoryId)
	local mapID, px, py = G.PlayerMap()
	local out
	if categoryId == "flight" then
		out = flightResults()
		setFrame(mapID, px, py)
		local skip = flightSkip(out)
		for _, result in ipairs(shippedFor("flight", mapID, px, py, nil, skip)) do
			out[#out + 1] = result
		end
		table.sort(out, byNearness)
		return out
	end
	setFrame(mapID, px, py)
	out = {}
	local mine = G.Faction()
	for _, place in ipairs(store()) do
		if place.c == categoryId and (place.f == nil or mine == nil or place.f == mine) then
			out[#out + 1] = placeResult(place, mapID, px, py)
		end
	end
	for _, place in ipairs(P.Known(categoryId)) do
		out[#out + 1] = knownResult(place, mapID, px, py)
	end
	for _, result in ipairs(shippedFor(categoryId, mapID, px, py)) do
		out[#out + 1] = result
	end
	table.sort(out, byNearness)
	return out
end

-- Searches everything Trailhead knows: categories, found places, flight points, zones
-- and dungeons. Returns a list of results; category matches come first.
function P.Search(query)
	local words = {}
	for word in (query or ""):lower():gmatch("%S+") do
		words[#words + 1] = word
	end
	local out = {}
	if #words == 0 then
		return out
	end
	local level = G.Level()
	for _, category in ipairs(T.Categories) do
		if not category.hidden and matches(category.label .. " " .. category.short .. " " .. category.words, words) then
			out[#out + 1] = {
				kind = "category", category = category.id, icon = category.icon, title = category.label,
				where = L["Everything Trailhead knows about this"], here = true, rank = 1,
			}
		end
	end
	local mapID, px, py = G.PlayerMap()
	local mine = G.Faction()
	setFrame(mapID, px, py)
	for _, place in ipairs(store()) do
		if (place.f == nil or mine == nil or place.f == mine) and matches(place.n .. " " .. (place.z or ""), words) then
			local result = placeResult(place, mapID, px, py)
			result.rank = 2
			out[#out + 1] = result
		end
	end
	for _, place in ipairs(knownPlaces()) do
		if matches(place.n .. " " .. (place.z or "") .. " " .. (place.note or ""), words) then
			local result = knownResult(place, mapID, px, py)
			result.rank = 2
			out[#out + 1] = result
		end
	end
	local nodes = flightResults()
	for _, result in ipairs(shippedFor(nil, mapID, px, py, words, flightSkip(nodes))) do
		result.rank = 2
		out[#out + 1] = result
	end
	for _, result in ipairs(nodes) do
		if matches(result.title .. " " .. result.where, words) then
			result.rank = 3
			out[#out + 1] = result
		end
	end
	-- Quest hubs from the built-in list ("Razor Hill", "Astranaar"), for the player's side.
	if T.Hubs and T.Hubs.Search then
		for _, result in ipairs(T.Hubs.Search(words) or {}) do
			out[#out + 1] = result
		end
	end
	local world = G.World()
	for _, zone in ipairs(world.zones) do
		if matches(zone.name, words) then
			out[#out + 1] = {
				kind = "zone", icon = "mtn", title = zone.name, rank = 4, here = false,
				where = zone.lo and L["Zone, levels %d to %d"]:format(zone.lo, zone.hi) or (zone.continent or L["Zone"]),
				map = zone.map, state = G.RangeState(zone.lo, zone.hi, level),
			}
		end
	end
	for _, dungeon in ipairs(world.dungeons) do
		if matches(dungeon.name, words) then
			out[#out + 1] = {
				kind = "dungeon", icon = "gate", title = dungeon.name, rank = 5, here = false,
				where = L["Dungeon, levels %d to %d"]:format(dungeon.lo, dungeon.hi),
				state = G.RangeState(dungeon.lo, dungeon.hi, level),
			}
		end
	end
	for _, raid in ipairs(world.raids or {}) do
		if matches(raid.name, words) then
			out[#out + 1] = {
				kind = "dungeon", icon = "gate", title = raid.name, rank = 5, here = false,
				where = L["Raid, levels %d to %d"]:format(raid.lo, raid.hi),
				state = G.RangeState(raid.lo, raid.hi, level),
			}
		end
	end
	table.sort(out, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return byNearness(a, b)
	end)
	return out
end

function P.Count()
	return #store()
end

function P.Forget()
	T.db.places = {}
	T:Fire("TH_PLACES_CHANGED")
end

-- ---------------------------------------------------------------------------
-- Map markers.

-- A flight point is listed on the continent map; a marker is easier to follow on the
-- zone map, so look the same point up there when the zone can be worked out.
local function flightOnZone(result)
	local zones = G.World().zones
	-- A city has a map of its own ("Orgrimmar, Durotar"): try the town's map first, where
	-- the marker sits in the middle of things instead of on the edge of the zone around it.
	for _, key in ipairs({ result.townKey or "", result.zoneKey or "" }) do
		if key ~= "" then
			for _, zone in ipairs(zones) do
				if zone.parent == result.map and (zone.key == key or zone.key:sub(1, #key + 1) == key .. " ")
					and C.Plain(C.Call("C_Map.CanSetUserWaypointOnMap", zone.map), false) == true then
					for _, node in ipairs(G.TaxiNodes(zone.map)) do
						if node.id == result.node and node.x >= 0 and node.x <= 1 and node.y >= 0 and node.y <= 1 then
							return zone.map, node.x, node.y
						end
					end
				end
			end
		end
	end
	return result.map, result.x, result.y
end

-- The same for a flight point from the game's list: { id, x, y, zone } on a continent map.
function P.FlightSpot(continent, node)
	return flightOnZone({
		map = continent, x = node.x, y = node.y, node = node.id,
		zoneKey = node.zoneKey or G.NormalName(node.zone or ""),
		townKey = node.townKey or (node.town and G.NormalName(node.town)) or nil,
	})
end

-- Puts the game's own map marker on a spot and points the on-screen arrow at it.
-- Returns true when the marker was placed.
function P.SetMarker(mapID, x, y, title)
	if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
		return false
	end
	if C.Plain(C.Call("C_Map.CanSetUserWaypointOnMap", mapID), false) ~= true then
		T:Print(L["The game does not allow a marker on that map. Open your map to find it instead."])
		return false
	end
	local point = C.Call("UiMapPoint.CreateFromCoordinates", mapID, x, y)
	if not point then
		return false
	end
	C.Call("C_Map.SetUserWaypoint", point)
	if C.Plain(C.Call("C_Map.HasUserWaypoint"), false) ~= true then
		return false
	end
	C.Call("C_SuperTrack.SetSuperTrackedUserWaypoint", true)
	T:Print(L["Marker set: %s. Follow the arrow on your screen."]:format(title or ""))
	T:Fire("TH_MARKER_CHANGED")
	return true
end

-- Marks a search result. Returns true when the marker was placed, and the map it is on.
function P.Go(result)
	if result.kind == "flight" then
		local mapID, x, y = flightOnZone(result)
		return P.SetMarker(mapID, x, y, result.title), mapID
	elseif result.kind == "place" then
		return P.SetMarker(result.map, result.x, result.y, result.title), result.map
	end
	return false
end

function P.ClearMarker()
	C.Call("C_Map.ClearUserWaypoint")
	T:Fire("TH_MARKER_CHANGED")
end

function P.HasMarker()
	return C.Plain(C.Call("C_Map.HasUserWaypoint"), false) == true
end

-- Opens the game's world map on a zone.
function P.ShowMap(mapID)
	if C.InCombat() or type(mapID) ~= "number" then
		return false
	end
	if C.Has("OpenWorldMap") then
		if T.Window and T.Window.Keep then
			T.Window:Keep("OpenWorldMap", mapID)
		else
			C.Call("OpenWorldMap", mapID)
		end
		if T.Window and T.Window.Beside then
			T.Window:Beside("WorldMapFrame")
		end
		return true
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Minimap tracking: the game can show most services on the minimap when they are close.

-- Returns the tracking slot for a category and whether it is on; nil if there is none.
function P.Tracking(categoryId)
	local category = T.CategoryById[categoryId]
	local count = C.Plain(C.Call("C_Minimap.GetNumTrackingTypes"), nil)
	if not category or not category.track or type(count) ~= "number" then
		return nil
	end
	for index = 1, count do
		local info = C.Call("C_Minimap.GetTrackingInfo", index)
		if type(info) == "table" and C.Plain(info.texture, nil) == category.track then
			return index, C.Plain(info.active, false) == true
		end
	end
	return nil
end

function P.SetTracking(categoryId, on)
	local index = P.Tracking(categoryId)
	if not index or not C.Has("C_Minimap.SetTracking") then
		return false
	end
	C.Call("C_Minimap.SetTracking", index, on and true or false)
	T:Fire("TH_TRACKING_CHANGED")
	return true
end

-- ---------------------------------------------------------------------------

T:On("PLAYER_LOGIN", function()
	T:On("MERCHANT_SHOW", onMerchant)
	T:On("TRAINER_SHOW", onTrainer)
	T:On("TH_TRAINER_READ", onTrainerRead)
	T:On("HEARTHSTONE_BOUND", onBind)
	T:On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", onInteraction)
	-- The choices are kept after the menu closes (the flag can arrive a moment later) and
	-- dropped when the next conversation starts.
	local closed = true
	T:On("GOSSIP_SHOW", function()
		if closed then
			trail, closed = {}, false
		end
		readOptions()
	end)
	T:On("GOSSIP_CLOSED", function()
		closed = true
	end)
	T:On("DYNAMIC_GOSSIP_POI_UPDATED", onGuardFlag)
	-- Watch which menu line the player clicks, without changing what the click does.
	if type(hooksecurefunc) == "function" and type(C_GossipInfo) == "table" then
		if type(C_GossipInfo.SelectOption) == "function" then
			pcall(hooksecurefunc, C_GossipInfo, "SelectOption", function(id)
				picked("id" .. tostring(C.Plain(id, "")))
			end)
		end
		if type(C_GossipInfo.SelectOptionByIndex) == "function" then
			pcall(hooksecurefunc, C_GossipInfo, "SelectOptionByIndex", function(index)
				picked("index" .. tostring(C.Plain(index, "")))
			end)
		end
	end
end)
