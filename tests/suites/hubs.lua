-- Quest hubs: the shipped list, the service, the Zones page, "How to get there" for a zone.
local H = ...
local check, Stub = H.check, H.Stub

-- A small hub list on the stub's map ids (the real list uses the game's own ids).
-- Row: name, x, y, faction (0 both, 1 Horde, 2 Alliance), lowest, typical, quests, flags
-- (1 inn, 2 flight master, 4 Alliance start, 8 Horde start).
local function testData()
	return {
		[37] = { -- Elwynn Forest: Alliance only
			{ "Northshire Valley", 490, 410, 2, 1, 4, 22, 4 },
			{ "Goldshire", 430, 660, 2, 7, 10, 26, 1 },
		},
		[52] = { -- Westfall: Alliance only
			{ "Sentinel Hill", 560, 480, 2, 12, 17, 15, 2 + 4 },
			{ "Moonbrook", 400, 700, 2, 12, 14, 5, 0 },
		},
		[10] = { -- The Barrens: shared
			{ "The Crossroads", 518, 308, 1, 10, 16, 38, 1 + 2 + 8 },
			{ "Ratchet", 630, 370, 0, 14, 30, 40, 1 + 2 + 4 },
			{ "Camp Taurajo", 447, 590, 1, 19, 20, 23, 3 },
		},
	}
end

local function loaded(faction)
	local T = H.load(nil, H.checked())
	Stub.world.faction = faction -- a load starts a new world, so the side is chosen after it
	T.HubData = testData()
	T.Hubs.Reset()
	return T
end

H.section("hubs: the shipped list", function()
	local T = H.load(nil, H.checked())
	local data = T.HubData
	check(type(data) == "table" and next(data) ~= nil, "the hub list is shipped")
	local rows, bad, starts = 0, 0, true
	for map, list in pairs(data) do
		local count = { [1] = 0, [2] = 0 }
		for _, row in ipairs(list) do
			rows = rows + 1
			if type(row[1]) ~= "string" or row[1] == "" or row[2] < 0 or row[2] > 1000 or row[3] < 0 or row[3] > 1000
				or row[5] > row[6] or row[7] < 3 or (row[4] ~= 0 and row[4] ~= 1 and row[4] ~= 2) then
				bad = bad + 1
			end
			if row[8] % 8 >= 4 then
				count[2] = count[2] + 1
			end
			if row[8] >= 8 then
				count[1] = count[1] + 1
			end
		end
		starts = starts and count[1] <= 1 and count[2] <= 1
	end
	check(rows > 120 and bad == 0, "every shipped hub row is complete (" .. rows .. " rows)")
	check(starts, "no zone has two start hubs for one side")

	-- What any guide agrees on.
	local function start(map, faction)
		Stub.world.faction = faction
		T.Hubs.Reset()
		local hub = T.Hubs.Start(map)
		return hub and hub.name
	end
	check(start(1429, "Alliance") == "Northshire Valley", "Elwynn Forest starts at Northshire")
	check(start(1429, "Horde") == nil and #T.Hubs.ForZone(1429) == 0 and T.Hubs.Known(1429), "Elwynn Forest is Alliance land: no hub for the Horde")
	local goldshire = false
	Stub.world.faction = "Alliance"
	T.Hubs.Reset()
	for _, hub in ipairs(T.Hubs.ForZone(1429)) do
		goldshire = goldshire or (hub.name == "Goldshire" and hub.inn)
	end
	check(goldshire, "and Goldshire, with its inn, is the next hub")
	check(start(1411, "Horde") == "Valley of Trials", "Durotar starts in the Valley of Trials")
	check(start(1411, "Alliance") == nil, "Durotar has no hub for the Alliance")
	check(start(1413, "Horde") == "The Crossroads", "The Barrens starts at the Crossroads for the Horde")
	check(start(1413, "Alliance") == "Ratchet", "and at Ratchet for the Alliance")
	check(start(1440, "Alliance") == "Astranaar" and start(1440, "Horde") == "Zoram'gar Outpost", "Ashenvale: Astranaar and Zoram'gar")
	check(start(1436, "Alliance") == "Sentinel Hill", "Westfall starts at Sentinel Hill")
	check(start(1412, "Horde") == "Camp Narache", "Mulgore starts at Camp Narache")
	check(start(2521, "Alliance") ~= nil and start(2521, "Horde") ~= nil, "Zephras Isle, new in Forever, has a hub for both sides")
	Stub.world.faction = nil
end)

H.section("hubs: the service", function()
	local T = loaded("Alliance")
	local Hubs = T.Hubs
	local barrens = Hubs.ForZone(10)
	check(#barrens == 1 and barrens[1].name == "Ratchet" and barrens[1].start, "an Alliance character sees only hubs its side can use, the start first")
	check(Hubs.Start(10).name == "Ratchet" and Hubs.Start(37).name == "Northshire Valley", "Start gives the hub to begin at")
	local elwynn = Hubs.ForZone(37)
	check(elwynn[1].name == "Northshire Valley" and elwynn[2].name == "Goldshire" and not elwynn[2].start, "the start hub first, then by level")
	check(elwynn[1].x == 0.49 and elwynn[1].y == 0.41 and elwynn[1].lo == 1 and elwynn[1].typical == 4 and elwynn[1].quests == 22, "a hub carries its place and levels")
	check(elwynn[2].inn and not elwynn[2].flight and Hubs.ForZone(52)[1].flight and not Hubs.ForZone(52)[1].inn, "inn and flight master flags")
	check(Hubs.Levels(elwynn[1]) == "levels 1 to about 4" and Hubs.Levels({ lo = 7, typical = 7 }) == "level 7", "levels in words")
	check(#Hubs.ForZone(999) == 0 and Hubs.Start(999) == nil and not Hubs.Known(999) and #Hubs.ForZone(nil) == 0, "an unknown zone has no hubs")
	Stub.combat = true
	check(#Hubs.ForZone(37) == 0 and #Hubs.Search({ "gold" }) == 0, "nothing is looked up in combat")
	Stub.combat = false
	check(#Hubs.ForZone(37) == 2, "and it works again afterwards")
	H.noErrors(T, "hub service")
	local allianceStart = Hubs.Start(10).name

	T = loaded("Horde")
	barrens = T.Hubs.ForZone(10)
	check(#barrens == 3 and barrens[1].name == "The Crossroads" and barrens[1].start and barrens[2].name == "Camp Taurajo" and barrens[3].name == "Ratchet"
		and not barrens[3].start, "a Horde character sees other hubs in a shared zone, starting at the Crossroads")
	check(T.Hubs.Start(10).name ~= allianceStart, "the two sides start at different hubs in a shared zone")
	check(#T.Hubs.ForZone(37) == 0 and T.Hubs.Start(37) == nil and T.Hubs.Known(37), "a zone of the other side has hubs, but none for this one")

	-- search
	local found = T.Hubs.Search({ "crossroads" })
	check(#found == 1 and found[1].kind == "place" and found[1].title == "The Crossroads" and found[1].where == "Quest hub in The Barrens"
		and found[1].map == 10 and found[1].x == 0.518 and found[1].y == 0.308 and found[1].icon == "pin" and found[1].rank == 2, "a hub is found by name, in the shape of a place")
	check(found[1].note == "Where to start. Quests for levels 10 to about 16", "and says where to start")
	local zone = T.Hubs.Search({ "barrens" })
	check(#zone == 3 and zone[1].title == "The Crossroads" and zone[2].title == "Camp Taurajo", "the zone's name finds its hubs, start first")
	check(#T.Hubs.Search({ "northshire" }) == 0 and #T.Hubs.Search({}) == 0 and #T.Hubs.Search({ "zzz" }) == 0, "nothing for the other side, nothing for no words")
	local target = T.Routes.ForResult(found[1])
	check(target and target.map == 10 and target.x == 0.518 and target.title == "The Crossroads", "a found hub routes to its spot")
	H.noErrors(T, "hub search")
	Stub.world.faction = nil
end)

H.section("hubs: the Zones page", function()
	local T = loaded("Alliance")
	H.slash("")
	T.Window:Select("zones")
	local zones = T.modules.zones
	check(Stub.sees("Start at Sentinel Hill, levels 12 to about 17"), "the Westfall row says where to start")
	check(Stub.sees("Start at Ratchet, levels 14 to about 30"), "and so does a shared zone, for this side")
	check(not Stub.sees("Start at The Crossroads, levels 10 to about 16"), "the other side's start is not shown")
	local items = zones.Items("all", 14)
	local byName = {}
	for _, item in ipairs(items) do
		byName[item.name] = item
	end
	check(byName["Westfall"].hubs and byName["Stormwind City"].hubs == false and byName["Stormwind City"].start == "", "a zone without hub data has no hub button and no start line")

	-- the hub list of a zone
	Stub.click("Quest hubs", 1)
	check(zones.view == 52 or zones.view == 10, "Quest hubs opens the hub list of that zone")
	T.Window:Select("zones", { hubs = 37, name = "Elwynn Forest" })
	check(zones.view == 37 and Stub.sees("Elwynn Forest") and Stub.sees("Northshire Valley") and Stub.sees("Goldshire"), "the hub list shows each hub")
	check(Stub.sees("Levels 1 to about 4  \194\183  22 quests") and Stub.sees("Levels 7 to about 10  \194\183  26 quests  \194\183  Inn"), "with levels, quests, inn and flight master")
	check(Stub.sees("START HERE") and Stub.sees("Start at the first one, Northshire Valley.") == false and
		Stub.sees("Towns and camps where several quests start, for your side. Start at the first one, Northshire Valley."), "the start hub is marked and named")
	Stub.click("Set marker", 1)
	check(Stub.waypoint and Stub.waypoint.uiMapID == 37 and Stub.waypoint.position.x == 0.49 and Stub.waypoint.position.y == 0.41 and Stub.mapOpened == 37,
		"a hub's Set marker puts the marker there and opens the map")
	Stub.click("How to get there", 2)
	local route = T.modules.route
	check(T.Window.current == "route" and route.plan.title == "Goldshire" and route.plan.where == "Quest hub in Elwynn Forest", "How to get there opens the route to that hub")
	Stub.click("Back")
	check(T.Window.current == "zones" and zones.view == 37, "Back returns to the hub list")
	Stub.click("Back")
	check(zones.view == nil and Stub.sees("Zones and the levels they are meant for. You are level 14."), "and Back again returns to the zones")

	-- Open map points at the start hub
	Stub.waypoint, Stub.mapOpened = nil, nil
	T.Window:Select("zones", "all")
	for index, item in ipairs(zones.Items("all", 14)) do
		if item.name == "Westfall" then
			Stub.click("Open map", index)
			break
		end
	end
	check(Stub.waypoint and Stub.waypoint.uiMapID == 52 and Stub.waypoint.position.x == 0.56 and Stub.waypoint.position.y == 0.48 and Stub.mapOpened == 52,
		"Open map puts the marker on the start hub and opens the zone")

	-- the other side
	T = loaded("Horde")
	H.slash("")
	T.Window:Select("zones", "all")
	check(Stub.sees("No quest hub listed for your side"), "a zone of the other side says so plainly")
	check(Stub.sees("Start at The Crossroads, levels 10 to about 16"), "and a shared zone starts at the Horde's hub")
	check(not Stub.sees("Start at Sentinel Hill, levels 12 to about 17"), "not at the Alliance's")
	T.Window:Select("zones", { hubs = 37, name = "Elwynn Forest" })
	check(Stub.sees("No quest hub listed for your side\nTrailhead has no quest hubs listed for your side in this zone."), "its hub list explains itself")
	H.noErrors(T, "zones page hubs")

	-- dungeon rows: a Route button only when the route page knows the dungeon
	T = loaded("Alliance")
	local dungeons = T.Dungeons
	T.Game.Entrance = function() return nil end -- the entrance lookup belongs to the dungeon service
	T.Dungeons = nil
	H.slash("")
	T.Window:Select("zones", "dungeons")
	check(Stub.sees("Deadmines") and not Stub.sees("Route"), "without a dungeon service there is no Route button")
	T.Dungeons = { Has = function(name) return name == "Deadmines" end }
	local picked
	local select = T.Window.Select
	T.Window.Select = function(self, id, arg)
		if id == "dungeon" then
			picked = arg
			return
		end
		return select(self, id, arg)
	end
	T.Window:Select("zones", "dungeons")
	check(Stub.sees("Route"), "a dungeon the service knows gets a Route button")
	for _, item in ipairs(T.modules.zones.DungeonItems(14)) do
		check(item.routed == (item.name == "Deadmines"), item.name .. " is routed only when the service knows it")
	end
	Stub.click("Route", 1)
	check(picked == "Deadmines", "the Route button opens that dungeon's page")
	T.Window.Select = select
	T.Dungeons = dungeons
	Stub.world.faction = nil
end)

H.section("hubs: how to get there", function()
	local T = loaded("Alliance")
	local R = T.Routes
	local target = R.ForZone(52, "Westfall")
	check(target.title == "Sentinel Hill" and target.map == 52 and target.x == 0.56 and target.y == 0.48
		and target.where == "Where to start in Westfall" and target.icon == "pin", "a route to a zone ends at the start hub, named")
	local plan = R.Plan(target)
	local last = plan.steps[#plan.steps]
	check(last.text == "Walk to Sentinel Hill" and last.map == 52 and last.x == 0.56 and last.mark == "Sentinel Hill", "the last step is the hub, with a marker on it")
	check(plan.title == "Sentinel Hill" and plan.where == "Where to start in Westfall", "the page is titled with the hub")
	local hub = T.Hubs.ForZone(37)[2]
	local spot = R.ForHub(hub, "Elwynn Forest")
	check(spot.title == "Goldshire" and spot.where == "Quest hub in Elwynn Forest" and spot.map == 37 and spot.x == 0.43, "a hub that is not the start is a quest hub")

	-- from the Zones page and the page itself
	H.slash("")
	T.Window:Select("zones", "all")
	for index, item in ipairs(T.modules.zones.Items("all", 14)) do
		if item.name == "Westfall" then
			Stub.click("How to get there", index)
			break
		end
	end
	check(T.Window.current == "route" and Stub.sees("Sentinel Hill") and Stub.sees("Where to start in Westfall"), "the zone's How to get there shows the hub")
	Stub.click("Set marker", #T.modules.route.plan.steps)
	check(Stub.waypoint and Stub.waypoint.uiMapID == 52 and Stub.waypoint.position.x == 0.56, "and its marker goes on the hub")

	-- a zone with no hub for this side falls back to the zone's flight point
	local fallback = R.ForZone(47, "Duskwood")
	check(fallback.title == "Duskwood" and fallback.icon == "mtn", "a zone without hubs is routed as before")
	T = loaded("Horde")
	check(T.Routes.ForZone(37, "Elwynn Forest").title == "Elwynn Forest", "so is a zone of the other side")
	check(T.Routes.ForZone(10, "The Barrens").title == "The Crossroads", "a shared zone goes to the Horde's start")
	H.noErrors(T, "route to a zone")
	Stub.world.faction = nil
end)

H.section("hubs: found by the search box", function()
	local Stub, check = H.Stub, H.check
	local T = loaded("Horde")
	local found
	for _, result in ipairs(T.Places.Search("crossroads")) do
		if result.title == "The Crossroads" and result.map == 10 then
			found = result
		end
	end
	check(found ~= nil, "searching for Crossroads finds the quest hub in The Barrens")
	check(found and found.x and found.y and found.kind == "place", "and it can be marked like any place")
	local none = true
	for _, result in ipairs(T.Places.Search("goldshire")) do
		if result.title == "Goldshire" then
			none = false
		end
	end
	check(none, "a Horde character is not sent to an Alliance hub")
	H.noErrors(T, "hub search")
end)

H.section("hubs: built-in places say which town they are in", function()
	local T = H.load({ seed = true }, H.checked())
	check(T.Hubs.Near(1411, 0.52, 0.42) == "Razor Hill", "a spot in Razor Hill is named")
	check(T.Hubs.Near(1411, 0.20, 0.90) == nil and T.Hubs.Near(999999, 0.5, 0.5) == nil, "open country and unknown maps have no town")
	Stub.world.faction = "Horde"
	local named, total = 0, 0
	for _, result in ipairs(T.Places.Find("vendor")) do
		if result.shipped then
			total = total + 1
			if result.where:find(", ") then
				named = named + 1
			end
		end
	end
	check(total > 0 and named > 0, "built-in vendors carry a town name where one is known (" .. named .. " of " .. total .. ")")
	H.noErrors(T, "town names")
end)

-- The shipped list after the noise was removed (tools/gen_hubs.py): no endgame clusters in low
-- zones, no lone camps of the wrong side, one town per place, each side starting at its own town.
H.section("hubs: the shipped list is free of noise", function()
	local T = H.load(nil, H.checked())
	local data = T.HubData

	-- Rows that break the rules: a hub of level 55 or more in a zone whose lowest hub is 40 or less,
	-- or a name used twice in one zone.
	local function noise(list)
		local bad = {}
		for map, rows in pairs(list) do
			local floor, names = 999, {}
			for _, row in ipairs(rows) do
				if row[7] >= 6 then
					floor = math.min(floor, row[6])
				end
			end
			for _, row in ipairs(rows) do
				if floor <= 40 and row[6] >= 55 then
					bad[#bad + 1] = map .. ":" .. row[1] .. " is endgame in a low zone"
				end
				if names[row[1] .. "/" .. row[4]] then
					bad[#bad + 1] = map .. ":" .. row[1] .. " twice"
				end
				names[row[1] .. "/" .. row[4]] = true
			end
		end
		return bad
	end
	check(#noise(data) == 0, "no endgame hubs in low zones and no repeated names: " .. table.concat(noise(data), "; "))

	-- Mutation: put a level 60 cluster into Tirisfal and a repeat of Brill; the rules must see both.
	local copy = {}
	for map, rows in pairs(data) do
		copy[map] = { unpack(rows) }
	end
	copy[1420][#copy[1420] + 1] = { "The Bulwark", 830, 700, 1, 55, 56, 24, 0 }
	copy[1420][#copy[1420] + 1] = copy[1420][2]
	check(#noise(copy) >= 2, "the noise check catches a level 56 cluster in Tirisfal and a repeated name")

	local function find(map, name)
		for _, row in ipairs(data[map] or {}) do
			if row[1] == name then
				return row
			end
		end
	end
	check(not find(1436, "Westfall Lighthouse"), "Westfall has no lighthouse hub of mixed levels")
	check(not find(1420, "The Bulwark") and not find(1434, "Stranglethorn Vale"), "no level 60 cluster in Tirisfal or Stranglethorn")
	check(not find(1416, "Gavin's Naze"), "no Alterac Valley battleground hub in Alterac Mountains")
	local duskwood = data[1431] or {}
	local horde = false
	for _, row in ipairs(duskwood) do
		horde = horde or row[4] == 1
	end
	check(not horde, "Duskwood, an Alliance zone, has no lone Horde hub")
	local lake = 0
	for _, row in ipairs(data[1433] or {}) do
		lake = lake + (row[1]:find("Lakeshire", 1, true) and 1 or 0)
	end
	check(lake == 1, "Redridge has one Lakeshire (the old map extent had split it in two)")
	local lakeshire = find(1433, "Lakeshire")
	check(lakeshire and lakeshire[8] % 2 == 1, "and the inn is in it")

	-- Start hubs per side in contested zones.
	local function startName(map, faction)
		Stub.world.faction = faction
		T.Hubs.Reset()
		local hub = T.Hubs.Start(map)
		return hub and hub.name
	end
	check(startName(1434, "Alliance") == "Rebel Camp" and startName(1434, "Horde") == "Grom'gol Base Camp", "Stranglethorn: Rebel Camp and Grom'gol")
	check(startName(1417, "Alliance") == "Refuge Pointe" and startName(1417, "Horde") == "Hammerfall", "Arathi: Refuge Pointe and Hammerfall")
	check(startName(1424, "Alliance") == "Southshore" and startName(1424, "Horde") == "Tarren Mill", "Hillsbrad: Southshore and Tarren Mill")
	check(startName(1443, "Horde") == "Shadowprey Village" or startName(1443, "Horde") == "Ghost Walker Post", "Desolace has a Horde start hub")
	check(startName(2521, "Alliance") == "Thendal Village" and startName(2521, "Horde") == "Thendal Village", "Zephras Isle: both Skyborne start at Thendal Village")
	local shendar = find(2521, "Shen'dar Village")
	check(shendar ~= nil and not find(2521, "Falaath Village"), "Shen'dar Village is named for Constable Aonda's cluster, not a quest name")
	check(find(1446, "Steamwheedle Port") ~= nil, "Steamwheedle Port is named on Tanaris's east coast")
	Stub.world.faction = nil
end)
