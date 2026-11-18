-- Dungeon readiness (Services/Readiness.lua: the Home card and the Grouping topic) and the
-- First steps checklist (Services/FirstSteps.lua and its Guide topic).
local H = ...
local Stub, check = H.Stub, H.check

local function card(T)
	for _, item in ipairs(T.Advisor.Cards(20)) do
		if item.id == "dungeon" then
			return item
		end
	end
	return nil
end

local function step(T, id)
	for _, item in ipairs(T.FirstSteps.List()) do
		if item.id == id then
			return item
		end
	end
	return nil
end

-- A world where the doors and the flight points around them are known: the Orgrimmar and
-- Stormwind flight points are named after the zone around the city, as in the game.
local function sides(T)
	local G = T.Game
	local zones = {
		[1454] = { name = "Orgrimmar", key = "orgrimmar", map = 1454, parent = 1414 },
		[1453] = { name = "Stormwind City", key = "stormwind city", map = 1453, parent = 1415 },
		[1436] = { name = "Westfall", key = "westfall", map = 1436, parent = 1415 },
		[1413] = { name = "The Barrens", key = "barrens", map = 1413, parent = 1414 },
	}
	local function flags()
		local mine = G.Faction()
		zones[1436].friendly, zones[1436].hostile = mine == 2 or nil, mine ~= 2 or nil
		zones[1413].friendly, zones[1413].hostile = true, true
	end
	G.World = function()
		flags()
		return { byMap = zones, zones = {}, raids = {}, dungeons = {
			{ name = "Ragefire Chasm", lo = 13, hi = 18 },
			{ name = "Deadmines", lo = 17, hi = 26 },
			{ name = "Wailing Caverns", lo = 17, hi = 24 },
			{ name = "Stormwind Stockades", lo = 22, hi = 30 },
		} }
	end
	G.TaxiNodes = function(parent)
		if parent == 1414 then
			return { { town = "Orgrimmar", zone = "Durotar", faction = 1 }, { town = "Ratchet", zone = "The Barrens", faction = 0 } }
		end
		return { { town = "Stormwind", zone = "Elwynn", faction = 2 }, { town = "Sentinel Hill", zone = "Westfall", faction = 2 } }
	end
end

H.section("readiness: the best dungeon from the group finder's levels", function()
	local T = H.load(nil, H.checked())
	local R = T.Readiness
	check(R.FirstLevel() == 13, "the first dungeon's level is the group finder's")
	check(R.Best(5) == nil, "nothing fits a level 5 character")
	check(R.Best(14).name == "Ragefire Chasm" and R.Best(14).lo == 13 and R.Best(14).hi == 18, "level 14: Ragefire Chasm, levels 13 to 18")
	check(R.Best(18).name == "Deadmines" and R.Best(18).id == 36, "level 18: the newest fitting one, with its route page")
	check(R.Best(24).name == "The Stockade" and R.Best(24).id == 34, "level 24: The Stockade, found under the game's other name")
	check(R.Best(40) == nil, "nothing past the last range")

	sides(T)
	Stub.world.faction = "Alliance"
	check(R.Side("Ragefire Chasm") == 0 and R.Side("Stormwind Stockades") == 2 and R.Side("Wailing Caverns") == 1,
		"a capital's door belongs to its side, found by the flight point's town")
	check(R.Best(14) == nil, "an Alliance character is not sent into Orgrimmar")
	check(R.Best(18).name == "Deadmines", "Alliance, level 18: the Deadmines, on their own side")
	check(R.Best(23).name == "Stormwind Stockades", "Alliance, level 23: the newest of their own")
	Stub.world.faction = "Horde"
	check(R.Best(14).name == "Ragefire Chasm", "a Horde character gets Ragefire Chasm")
	check(R.Best(23).name == "Wailing Caverns", "Horde, level 23: not the Alliance's Deadmines or Stockade")
	check(R.Best(17).name == "Wailing Caverns", "Horde, level 17: the newer one, open to both, before Ragefire's last levels")
	H.noErrors(T, "best dungeon")
end)

H.section("readiness: what the class can do", function()
	local roles = {}
	for _, class in ipairs({ "WARRIOR", "DRUID", "PRIEST", "MAGE" }) do
		local T = H.load({ class = class, level = 20 }, H.checked())
		roles[class] = T.Readiness.Roles()
	end
	check(roles.WARRIOR == "Tank, Damage", "a warrior can tank or do damage")
	check(roles.DRUID == "Tank, Healer, Damage", "a druid can do all three")
	check(roles.PRIEST == "Healer, Damage", "a priest heals or does damage")
	check(roles.MAGE == "Damage", "a mage does damage")
	local T = H.load({ class = "HORDE_NONE" }, H.checked())
	check(T.Readiness.Roles() == "Damage", "an unknown class falls back to the game's default")
end)

H.section("readiness: the Home card", function()
	local T = H.load({ class = "WARRIOR", level = 18 }, H.checked(), {})
	local item = card(T)
	check(item and item.title == "Ready for Deadmines" and item.tone == "info" and item.icon == "gate",
		"the card names the dungeon")
	check(item.body == "Levels 17 to 26. Dungeons need a group of five.\nRoles your class can fill: Tank, Damage.",
		"it gives the levels and the class's jobs")
	check(item.action == "Open the route", "its button is labelled")
	H.slash("")
	item.run()
	Stub.flush()
	check(T.Window.current == "dungeon" and T.modules.dungeon.shown == 36, "the button opens the Deadmines route")

	-- dismissed: gone for good on this character, until the level brings another dungeon
	T.Advisor.Dismiss(item)
	check(card(T) == nil, "a dismissed card goes away")
	local savedChar = T.cdb
	T = H.load({ class = "WARRIOR", level = 18 }, H.checked(), savedChar)
	check(card(T) == nil, "and stays away after a reload")
	Stub.world.level = 20
	check(card(T) == nil, "a level up with the same dungeon brings nothing new")
	Stub.world.level = 24
	item = card(T)
	check(item and item.title == "Ready for The Stockade", "a new dungeon brings a new card")
	T.Advisor.Reset()
	Stub.world.level = 18
	check(card(T) ~= nil, "Reset brings dismissed cards back")

	-- inside a dungeon the route card speaks instead
	Stub.world.instance = { name = "The Deadmines", kind = "party" }
	_G.GetInstanceInfo = function() return "The Deadmines", "party", 1, "Normal", 5, 0, false, 36 end
	Stub.fire("PLAYER_ENTERING_WORLD")
	Stub.flush()
	check(card(T) == nil and T.Advisor.Cards(1)[1].id == "indungeon", "inside, only the route card")

	-- a dungeon Trailhead has no page for goes to the dungeon list
	T = H.load({ level = 18 }, H.checked())
	T.Dungeons.Find = function() return nil end
	item = card(T)
	check(item and item.action == "See dungeons", "no route page: the button opens the list")
	H.slash("")
	item.run()
	check(T.Window.current == "zones", "and it opens Zones")
	T = H.load({ level = 5 }, H.checked())
	check(card(T) == nil, "no card while nothing fits")
	H.noErrors(T, "readiness card")
end)

H.section("readiness: the Grouping topic", function()
	local T = H.load({ class = "PRIEST", level = 18 }, H.checked())
	local info = T.modules.guide.Read("grouping")
	local row = info.rows[2]
	check(row.name == "Ready for" and row.text == "Deadmines, levels 17 to 26" and row.tag == "Route" and row.run ~= nil,
		"Grouping names the dungeon that fits, with its route")
	check(info.action and info.action.label == "Open the route", "and a button to the route")
	check(info.next:find("Your class can be: healer, damage.", 1, true) ~= nil, "the jobs still follow")
	check(#info.rows <= 9, "the rows fit the panel")
	H.slash("")
	info.action.run()
	check(T.Window.current == "dungeon", "the button opens the route page")
	T = H.load({ level = 5 }, H.checked())
	info = T.modules.guide.Read("grouping")
	check(info.rows[2].text == "No dungeon yet: the first opens at level 13" and info.action == nil, "too low: when the first opens")
	T = H.load({ level = 40 }, H.checked())
	info = T.modules.guide.Read("grouping")
	check(info.rows[2].name ~= "Ready for", "past the last range: no row")
	H.noErrors(T, "grouping topic")
end)

H.section("first steps: each milestone from the game", function()
	local T = H.load({ level = 1, bars = { false, false, false, false, false, false, false } }, H.checked(), {})
	local F = T.FirstSteps
	local world = Stub.world
	world.bagSlots = { 0, 0, 0, 0 }
	T.Game.Talents = function() return { spent = 0, unspent = 0, trees = {}, nodes = {} } end
	local list = F.List()
	local ids = {}
	for index, item in ipairs(list) do
		ids[index] = item.id
	end
	check(table.concat(ids, ",") == "trainer,hearth,rest,bar2,talent,profession,bag,group,dungeon,mount", "ten milestones, in the order they come")
	check(select(1, F.Counts()) == 0 and select(2, F.Counts()) == 10, "a new character has done none")
	check(step(T, "talent").text == "Spend your first talent point (level 10)", "the talent point says when it comes")
	check(step(T, "mount").text == "Ride a mount (from level 40)", "riding says when it opens")
	check(F.AllDone() == false, "not all done")

	-- one by one
	H.visit("Jennea Cannon", H.MAGE_TRAINER)
	H.leave()
	check(step(T, "trainer").done, "a visit to the class trainer counts")
	check(not step(T, "hearth").done, "the stone where the game started it does not count")
	world.bind = "Sentinel Hill"
	Stub.fire("ZONE_CHANGED")
	Stub.fire("PLAYER_ENTERING_WORLD")
	check(step(T, "hearth").done, "a new home inn counts")
	world.resting = true
	Stub.fire("PLAYER_UPDATE_RESTING")
	world.resting = false
	Stub.fire("PLAYER_UPDATE_RESTING")
	check(step(T, "rest").done, "resting once is remembered")
	Stub.bars[1] = true
	check(step(T, "bar2").done, "Action Bar 2 on counts")
	T.Game.Talents = function() return { spent = 1, unspent = 0, trees = {}, nodes = {} } end
	check(step(T, "talent").done, "a talent point spent counts")
	world.secondary = { { "Horse Riding", 148, 75, 75 } }
	check(not step(T, "profession").done and step(T, "mount").done, "riding is not a profession, but it counts as riding")
	world.secondary = { { "Cooking", 185, 1, 75 } }
	check(step(T, "profession").done, "Cooking counts as a profession")
	world.secondary = nil
	world.professions = { { "Herbalism", 182, 1, 75 } }
	check(step(T, "profession").done, "a main profession counts")
	world.bagSlots = { 0, 6, 0, 0 }
	check(step(T, "bag").done, "a bag in a bag slot counts")
	Stub.combat = true
	world.group = 2
	Stub.fire("GROUP_ROSTER_UPDATE")
	check(not step(T, "group").done, "nothing is read in combat")
	Stub.combat = false
	Stub.fire("PLAYER_REGEN_ENABLED")
	world.group = nil
	check(step(T, "group").done, "a group is remembered, read once combat ends")
	world.mounted = true
	Stub.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
	world.mounted = false
	check(step(T, "mount").done, "riding once is remembered")
	check(not step(T, "dungeon").done, "no dungeon yet")
	world.instance = { name = "Wailing Caverns", kind = "party" }
	_G.GetInstanceInfo = function() return "Wailing Caverns", "party", 1, "Normal", 5, 0, false, 43 end
	Stub.fire("PLAYER_ENTERING_WORLD")
	check(not step(T, "dungeon").done, "walking in is not enough")
	Stub.fire("BOSS_KILL", 585, "Lady Anacondra")
	check(step(T, "dungeon").done, "a dungeon boss down counts")
	world.instance = nil
	Stub.fire("PLAYER_ENTERING_WORLD")
	check(F.AllDone(), "all ten done")

	-- remembered per character
	local savedChar = T.cdb
	T = H.load({ level = 1 }, H.checked(), savedChar)
	check(step(T, "rest").done and step(T, "group").done and step(T, "dungeon").done and step(T, "hearth").done,
		"what was seen is kept for the character")
	T = H.load({ level = 1 }, H.checked(), {})
	check(not step(T, "rest").done and not step(T, "group").done, "another character starts again")
	T.FirstSteps.Scan()
	Stub.fire("HEARTHSTONE_BOUND")
	check(step(T, "hearth").done, "the game's own word that the stone was set counts")
	check(step(T, "bar2") == nil, "a client that cannot read the bars leaves that one out")
	H.noErrors(T, "first steps")
end)

H.section("first steps: the Guide topic", function()
	local T = H.load({ level = 1, bars = { false, false, false, false, false, false, false } }, H.checked(), {})
	local guide = T.modules.guide
	T.Game.Talents = function() return { spent = 0, unspent = 0, trees = {}, nodes = {} } end
	Stub.world.bagSlots = { 0, 0, 0, 0 }
	H.visit("Jennea Cannon", H.MAGE_TRAINER)
	H.leave()
	local info = guide.Read("firststeps")
	check(info.heading == "1 of 10 done" and not info.hidden, "the topic counts what is done")
	check(info.rows[1].name == "Hearthstone" and info.rows[1].tag == "Find" and info.rows[#info.rows].name == "Class trainer"
		and info.rows[#info.rows].tag == "Done", "the ones still to do come first, done ones last")
	check(info.next:find("Next: Make an inn your home at its innkeeper.", 1, true) == 1 and info.action.label == "Find an inn",
		"the next step and its button")
	local bad = {}
	for _, row in ipairs(info.rows) do
		if #row.name > 14 or #row.text > 54 then
			bad[#bad + 1] = row.name
		end
		if not row.tag then
			bad[#bad + 1] = row.name .. " has no tag"
		end
	end
	check(#bad == 0, "every row is short enough for its tag (" .. table.concat(bad, ", ") .. ")")
	check(#info.what <= 250, "the words above fit")

	-- each link goes where it says
	H.slash("")
	local where = {}
	for _, item in ipairs(T.FirstSteps.List()) do
		item.link.run()
		Stub.flush()
		where[item.id] = T.Window.current .. ":" .. tostring(T.modules.find.category or "") .. ":" .. tostring(guide.topic)
	end
	check(where.hearth:find("^find:inn") and where.profession:find("^find:professions") and where.bag:find("^find:auction"),
		"Find links open the right category")
	check(where.rest:find("^guide:.*:rest$") and where.talent:find("^guide:.*:talents$") and where.mount:find("^guide:.*:mount$")
		and where.group:find("^guide:.*:grouping$"), "Guide links open the right topic")
	check(where.bar2:find("^setup:"), "Action Bar 2 opens Screen setup")

	-- on the page
	T.Window:Select("guide", "firststeps")
	Stub.flush()
	check(guide.group == "world" and Stub.sees("First steps") and Stub.sees("1 OF 10 DONE"), "the topic opens in The world")
	T.Window:Select("guide", "firststeps")
	Stub.flush()
	Stub.click("Find an inn")
	check(T.Window.current == "find" and T.modules.find.category == "inn", "its button opens Find it")

	-- all done: the topic goes away and leaves no gap
	T.FirstSteps.AllDone = function() return true end
	T.FirstSteps.List = function() return { { id = "x", name = "Done", text = "Done", done = true, link = {} } } end
	T.Window:Select("guide", "firststeps")
	Stub.flush()
	check(guide.Read("firststeps").hidden and guide.topic == "rest" and not Stub.sees("First steps"),
		"once all are done the topic is hidden and the next one opens")
	H.noErrors(T, "first steps topic")
end)

H.section("readiness: the first dungeon is on the character's side", function()
	local T = H.load({ level = 11 }, H.checked())
	local R = T.Readiness
	check(R.First().name == "Ragefire Chasm" and R.FirstLevel() == 13, "with no side known, the group finder's first")
	sides(T)
	Stub.world.faction = "Alliance"
	check(R.First().name == "Deadmines" and R.FirstLevel() == 17, "Alliance: not Ragefire Chasm in Orgrimmar, the Deadmines at 17")
	H.slash("")
	check(Stub.sees("Level 17: first dungeon") and Stub.sees("6 levels to go. Deadmines. Dungeons need a group of five.")
		and not Stub.sees("Level 13: first dungeon"), "Home's milestone names the Alliance's first dungeon")
	local info = T.modules.guide.Read("grouping")
	check(info.rows[2].text == "No dungeon yet: the first opens at level 17", "the Grouping topic agrees")
	Stub.world.faction = "Horde"
	check(R.First().name == "Ragefire Chasm" and R.FirstLevel() == 13, "Horde: Ragefire Chasm at 13")
	T.Window:Select("guide")
	T.Window:Select("home")
	Stub.flush()
	check(Stub.sees("Level 13: first dungeon"), "and Home follows")
	Stub.world.faction = nil
	H.noErrors(T, "first dungeon by side")
end)

H.section("first steps: a character first seen later has already chosen an inn", function()
	local T = H.load({ level = 20 }, H.checked(), {})
	local hearth = step(T, "hearth")
	check(hearth and hearth.done == true, "level 20, bound before Trailhead: the hearthstone step is done")
	T = H.load({ level = 3 }, H.checked(), {})
	check(step(T, "hearth").done == false, "level 3: the stone where the game started it is the start")
	T = H.load({ level = 3 }, H.checked(), { trainer = { at = 1 } })
	check(step(T, "hearth").done == true, "a character that has seen its trainer before: done")
	H.noErrors(T, "hearth first seen")
end)
