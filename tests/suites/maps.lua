-- The game's map: Trailhead never opens it from its own code (the map would open tainted, like
-- the talent window that broke the action bars in 0.12). Every map button opens it from the
-- player's click through the secure cover (UI/Secure.lua, QuestLogMicroButton), with the marker
-- placed first; without the cover the click places the marker and says which key opens the map.
-- Also here: greyed-out game buttons, class trainers per class, and the Zones and Find lists.
local H = ...
local check, Stub = H.check, H.Stub

local function chatHas(text)
	for _, line in ipairs(Stub.chat) do
		if line:find(text, 1, true) then
			return true
		end
	end
	return false
end

local function neverOpened(T, what)
	check(#Stub.forbiddenCalls == 0 and T.Compat.errors.OpenWorldMap == nil and Stub.mapOpened == nil,
		what .. ": the game's map code was never called")
end

H.section("maps: every map button opens the map through the game's own button", function()
	local T = H.load(nil, H.checked())
	H.slash("")
	-- a zone in the search: the map opens, nothing is marked
	Stub.type(T.Window.search.edit, "dusk")
	Stub.flush()
	Stub.click("Open map")
	check(Stub.opened.map and WorldMapFrame:IsShown() and Stub.waypoint == nil, "a zone result opens the game's map")
	check(TrailheadSecureOpen:GetAttribute("clickbutton1") == QuestLogMicroButton, "through Forever's Map and Quest Log button")
	check(T.Window:IsBeside() == "WorldMapFrame", "and Trailhead goes beside it")
	-- a flight point: the marker goes on before the click; an open map is not closed again
	Stub.click("Set marker")
	check(Stub.waypoint ~= nil and Stub.waypoint.uiMapID == 13 and WorldMapFrame:IsShown(), "Set marker with the map open marks the place and keeps the map up")
	check(Stub.sees("Remove marker"), "Remove marker shows at once")
	WorldMapFrame:Hide()
	T.Window:DockTick()
	Stub.click("Remove marker")
	Stub.opened.map, Stub.mapMarkerWhenOpened = nil, nil
	Stub.click("Set marker")
	check(Stub.opened.map and Stub.mapMarkerWhenOpened ~= nil and Stub.mapMarkerWhenOpened == Stub.waypoint,
		"with the map closed, the marker is placed first and the map opens showing it")
	check(chatHas("Marker set: Darkshire. Follow the arrow on your screen."), "the chat names the place")
	WorldMapFrame:Hide()
	T.Window:DockTick()

	-- a found place from a category
	Stub.world.npc = "Farmer Saldean"
	Stub.fire("MERCHANT_SHOW")
	T.Window:Select("find", "vendor")
	Stub.waypoint, Stub.opened.map = nil, nil
	Stub.click("Set marker", 1)
	check(Stub.waypoint and Stub.waypoint.uiMapID == 52 and Stub.opened.map, "a found place is marked and the map opens")
	WorldMapFrame:Hide()
	T.Window:DockTick()

	-- Zones: Open map
	T.Window:Select("zones", "fit")
	Stub.opened.map = nil
	Stub.click("Open map", 1)
	check(Stub.opened.map, "Zones' Open map opens the game's map")
	WorldMapFrame:Hide()
	T.Window:DockTick()

	-- a route step has no secure cover: the marker, and the key that opens the map
	Stub.chat = {}
	Stub.opened.map = nil
	check(T.Routes.Mark({ map = 52, x = 0.4, y = 0.4, mark = "Moonbrook" }) == true and Stub.waypoint.uiMapID == 52, "a route step is marked")
	check(not Stub.opened.map and chatHas("Marker set. Press M to open your map."), "and the chat says which key opens the map")
	check(T.Places.ShowMap(52) == false and not WorldMapFrame:IsShown(), "ShowMap opens nothing")
	neverOpened(T, "map buttons")
	H.noErrors(T, "map buttons")
end)

H.section("maps: without the game's map button", function()
	local T = H.load(nil, H.checked())
	-- the player bound the map to another key
	_G.GetBindingKey = function(action) return action == "TOGGLEWORLDMAP" and "SHIFT-M" or nil end
	_G.GetBindingText = function(key) return key == "SHIFT-M" and "Shift-M" or key end
	H.slash("")
	Stub.greyed.QuestLogMicroButton = true -- greyed out, as in a pet battle or a vehicle
	check(not T.Secure.Can("map") and T.Secure.Exists("map"), "a greyed-out button cannot be used, though it exists")
	T.Window:Select("find", "flight")
	Stub.chat = {}
	Stub.click("Set marker", 1)
	check(not TrailheadSecureOpen or not TrailheadSecureOpen:IsShown(), "the cover does not take the click")
	check(Stub.waypoint ~= nil and not Stub.opened.map and not WorldMapFrame:IsShown(), "the click marks the place and opens nothing")
	check(chatHas("Marker set. Press Shift-M to open your map.") and not chatHas("Follow the arrow"), "and says which key opens the map, once")
	check(T.Window:IsBeside() == nil, "nothing docks beside a map that did not open")
	-- greyed out after the mouse came on: the cover is up, but the click must not act as if it opened
	Stub.greyed.QuestLogMicroButton = nil
	local button = Stub.click("Remove marker")
	T.Window:Select("find", "flight")
	local setMarker
	for _, text in ipairs(Stub.fontstrings) do
		if text.text == "Set marker" and text.parent and text.parent:IsVisible() then
			setMarker = setMarker or text.parent
		end
	end
	setMarker.rect = { 600, 720, 500, 476 }
	setMarker.scripts.OnEnter(setMarker)
	local cover = TrailheadSecureOpen
	check(cover:IsShown(), "(the cover is over the button)")
	Stub.greyed.QuestLogMicroButton = true
	cover.scripts.PreClick(cover, "LeftButton", false)
	check(cover:GetAttribute("type1") == nil and Stub.waypoint == nil, "greyed out at the click: no press and no marker from the cover")
	cover.scripts.PostClick(cover, "LeftButton", false)
	check(T.Window:IsBeside() == nil and cover:GetAttribute("type1") == "click", "and nothing runs after it")
	cover.scripts.OnLeave(cover)
	_G.GetBindingKey, _G.GetBindingText = nil, nil
	neverOpened(T, "map fallback")
	H.noErrors(T, "map fallback")
	check(button ~= nil, "(remove marker)")
end)

H.section("maps: greyed-out talent and Legacy buttons", function()
	local T = H.load(nil, H.checked())
	H.slash("")
	Stub.greyed.TalentMicroButton = true -- before the first talent point
	check(not T.Secure.Can("talents"), "a greyed-out talent button is not offered as the safe way")
	local button = T.Widgets.Button(T.Window.frame or UIParent, "Probe", "ghost", { onClick = function() end })
	button.rect = { 600, 720, 500, 476 }
	T.Secure.Set(button, "talents")
	check(T.Secure.Cover(button) == false, "the cover is not laid over a button whose game button is greyed out")
	Stub.greyed.TalentMicroButton = nil
	check(T.Secure.Can("talents"), "and is offered again once the game enables it")
	T.Secure.Set(button, nil)

	-- Legacy: before the account's first Legacy Point the game greys its button out
	_G.LegacySystemFrame = nil
	Stub.greyed.LegacyMicroButton = true
	_G.LEGACY_MICRO_BUTTON_LOCKED_TOOLTIP = "Earn a Legacy Point to unlock."
	Stub.click("Skip")
	T.Window:Select("legacy")
	Stub.chat = {}
	Stub.opened.legacy = nil
	Stub.click("Open Legacy window")
	check(not Stub.opened.legacy and chatHas("Earn a Legacy Point to unlock."), "the Legacy button says why it is locked, in the game's words")
	_G.LEGACY_MICRO_BUTTON_LOCKED_TOOLTIP = nil
	Stub.chat = {}
	Stub.click("Open Legacy window")
	check(chatHas("The Legacy window is locked for now. The game opens it with your first Legacy Point."), "or in Trailhead's own")
	Stub.greyed.LegacyMicroButton = nil
	Stub.click("Open Legacy window")
	check(Stub.opened.legacy, "once unlocked it opens the game's Legacy window")
	H.noErrors(T, "greyed-out buttons")
end)

H.section("places: class trainers belong to their class", function()
	local saved = H.checked({ places = {
		-- found before 0.14: the class only in the name
		{ c = "trainer", n = "Warrior: Wu Shen", m = 84, x = 0.78, y = 0.45, z = "Stormwind City", f = 2, s = "seen", t = 1 },
		{ c = "trainer", n = "Odd Name", m = 84, x = 0.10, y = 0.10, z = "Stormwind City", f = 2, s = "seen", t = 1 },
	} })
	local T = H.load({ class = "MAGE" }, saved)
	local P = T.Places
	check(T.db.places[1].e == "WARRIOR" and T.db.places[2].e == nil and T.db.placesClassed, "old trainer records get their class back from the name, once")
	local function titles(list)
		local out = {}
		for _, item in ipairs(list) do
			out[#out + 1] = item.title
		end
		table.sort(out)
		return table.concat(out, " | ")
	end
	check(titles(P.Find("trainer")) == "Odd Name", "a Mage is not offered the Warrior's trainer")
	check(titles(P.Search("wu shen")) == "", "nor finds it in the search")

	-- two classes at one spot are two places
	P.Remember("trainer", "Mage: Jennea Cannon", 84, 0.40, 0.80, "seen", "MAGE")
	P.Remember("trainer", "Warrior: Ilsa Corbin", 84, 0.401, 0.801, "seen", "WARRIOR")
	check(#T.db.places == 4, "a trainer of another class next to it does not overwrite it")
	P.Remember("trainer", "Mage: Jennea Cannon", 84, 0.402, 0.802, "seen", "MAGE")
	check(#T.db.places == 4, "the same class at the same spot is the same place")
	check(titles(P.Find("trainer")) == "Mage: Jennea Cannon | Odd Name", "the Mage sees the Mage trainer")

	-- read at the trainer: the class comes from the character
	Stub.world.npc = "Elsharin"
	Stub.world.map, Stub.world.x, Stub.world.y = 52, 0.30, 0.30
	T:Fire("TH_TRAINER_READ", "Mage")
	local last = T.db.places[#T.db.places]
	check(last.c == "trainer" and last.e == "MAGE" and last.n == "Mage: Elsharin", "a trainer read in game is filed under the character's class")

	-- the Warrior alt on the same account
	local mage = _G.UnitClass
	_G.UnitClass = function() return "Warrior", "WARRIOR", 1 end
	check(titles(P.Find("trainer")) == "Odd Name | Warrior: Ilsa Corbin | Warrior: Wu Shen", "the Warrior sees only Warrior trainers")
	check(titles(P.Search("jennea")) == "", "and not the Mage's in the search")
	_G.UnitClass = mage
	H.noErrors(T, "trainer classes")
end)

H.section("zones: for my level and dungeons", function()
	local T = H.load(nil, H.checked())
	T.HubData = { [10] = { { "Ratchet", 630, 370, 0, 14, 30, 40, 1 + 2 + 4 } } }
	T.Hubs.Reset()
	local zones = T.modules.zones
	local items = zones.Items("fit", 14)
	check(items[1].name == "Westfall" and items[1].here, "the zone you are in comes first")
	check(items[2].name == "The Barrens", "then a zone with a place for your side to start")
	H.slash("")
	T.Window:Select("zones", "fit")
	check(not Stub.sees("RIGHT FOR YOU") and Stub.sees("ALMOST"), "For my level tags only the zones that stand out")
	T.Window:Select("zones", "all")
	check(Stub.sees("RIGHT FOR YOU") and Stub.sees("TOO DANGEROUS"), "All zones still says how each fits")

	-- dungeons: a door in the other side's capital
	local G = T.Game
	local byMap = { [1454] = { name = "Orgrimmar", key = "orgrimmar", map = 1454, parent = 1414 } }
	local world = G.World
	G.World = function()
		return { byMap = byMap, zones = {}, raids = {}, dungeons = {
			{ name = "Ragefire Chasm", lo = 13, hi = 18 }, { name = "Deadmines", lo = 17, hi = 26 },
		} }
	end
	local taxi = G.TaxiNodes
	G.TaxiNodes = function() return { { town = "Orgrimmar", zone = "Durotar", faction = 1 } } end
	local list = zones.DungeonItems(14)
	check(list[1].name == "Deadmines" and list[2].name == "Ragefire Chasm" and list[2].enemy and not list[1].enemy,
		"a dungeon in enemy territory comes last")
	check(list[2].detail:find("Enemy territory", 1, true) ~= nil and not list[1].detail:find("Enemy territory", 1, true), "and says so")
	G.World, G.TaxiNodes = world, taxi
	H.noErrors(T, "zones lists")
end)

H.section("find: distances read as plain words", function()
	local T = H.load(nil, H.checked())
	H.slash("")
	T.Window:Select("find", "flight")
	check(Stub.sees("500 yards") and not Stub.sees("500 YARDS"), "a distance is written in plain case")
	H.noErrors(T, "find distances")
end)
