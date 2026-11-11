-- Offline tests: loads the whole addon under Lua 5.1 against tests/wowstub.lua and drives
-- it the way a player would. Run from the repository root:  lua5.1 tests/run.lua

local Stub = dofile("tests/wowstub.lua")
local ADDON_DIR = "Trailhead/"
local passed, failed = 0, 0
local inSuites = false

local function check(condition, what)
	if condition then
		passed = passed + 1
	else
		failed = failed + 1
		print("  FAIL: " .. what)
	end
end

local function tocFiles()
	local files = {}
	for line in io.lines(ADDON_DIR .. "Trailhead.toc") do
		line = line:gsub("\r", "")
		if line:match("%.lua$") and not line:match("^#") then
			files[#files + 1] = line:gsub("\\", "/")
		end
	end
	return files
end

-- Loads the addon like the game does: every file gets the addon name and one shared table.
local function load(opts, saved, savedChar)
	Stub.uninstall()
	Stub.install(opts)
	TrailheadDB, TrailheadCharDB = saved, savedChar
	local savedLook = saved and saved.theme
	local T = {}
	for _, file in ipairs(tocFiles()) do
		local chunk = assert(loadfile(ADDON_DIR .. file))
		chunk("Trailhead", T)
	end
	-- The older suites count places one by one: they run without the built-in list unless
	-- the test asks for it (opts.seed = true).
	if not (opts and opts.seed) then
		T.Seed = nil
	end
	-- Likewise their searches expect exact result lists: quest hubs join the search only in
	-- the suites under tests/suites.
	if not inSuites and T.Hubs then
		T.Hubs.Search = nil
	end
	Stub.fire("ADDON_LOADED", "SomeOtherAddon")
	Stub.fire("ADDON_LOADED", "Trailhead")
	Stub.fire("PLAYER_LOGIN")
	Stub.fire("PLAYER_ENTERING_WORLD")
	Stub.flush()
	-- The tests read plain-case text, so they run in the Night look unless they ask for
	-- the look a new player gets (opts.look = "default") or bring a saved one.
	if not (opts and opts.look == "default") and not savedLook then
		T.db.theme = "night"
		T.Theme:Set("night", true)
	end
	return T
end

local function noErrors(T, what)
	local list = (TrailheadDB and TrailheadDB.errors) or {}
	check(#list == 0 and #Stub.errors == 0, what .. ": no errors logged")
	for _, entry in ipairs(list) do
		print("    " .. entry.where .. ": " .. entry.err)
	end
end

local function slash(text)
	SlashCmdList.TRAILHEAD(text)
	Stub.flush()
end

local function section(name, fn)
	print(name)
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then
		failed = failed + 1
		print("  FAIL (error): " .. tostring(err))
	end
end

section("startup and defaults", function()
	local T = load({ look = "default" })
	check(T.db.theme == "ember" and T.Theme.current.id == "ember", "a new player gets the Ember look")
	T = load()
	check(T.db.scale == 1 and T.db.minimap.show == true, "defaults filled in")
	check(T.db.firstRun == false, "first-run welcome shown once")
	check(#Stub.chat == 1, "one welcome line in chat")
	check(TrailheadMinimapButton ~= nil and TrailheadMinimapButton:IsShown(), "minimap button shown")
	check(TrailheadWindow == nil, "window is not built until opened")
	check(T.version == "0.12.0", "version read from the TOC")
	noErrors(T, "startup")
end)

section("window, tabs and settings", function()
	local T = load()
	slash("")
	check(T.Window:IsOpen(), "/th opens the window")
	check(T.Window.current == "home", "opens on Home")
	for _, id in ipairs({ "find", "spells", "zones", "guide", "settings", "home" }) do
		T.Window:Select(id)
		check(T.Window.current == id and T.modules[id].page:IsVisible(), "page " .. id .. " shows")
	end
	check(T.cdb.tab == "home", "last tab remembered per character")
	T.Window:Select("nonsense")
	check(T.Window.current == "home", "unknown page falls back to Home")
	slash("")
	check(not T.Window:IsOpen(), "/th closes the window")
	slash("settings")
	check(T.Window:IsOpen() and T.Window.current == "settings", "/th settings opens Settings")
	Trailhead_OnAddonCompartmentClick("Trailhead", "LeftButton")
	check(not T.Window:IsOpen(), "addon compartment click toggles")
	Trailhead:ToggleWindow()
	check(T.Window:IsOpen(), "key binding toggles")
	check(UISpecialFrames[1] == "TrailheadWindow", "Escape closes the window")
	noErrors(T, "window")
end)

section("themes", function()
	local T = load()
	slash("")
	local title
	for _, id in ipairs({ "journal", "ember", "night" }) do
		slash("theme " .. id)
		check(T.Theme.current.id == id and T.db.theme == id, "theme " .. id .. " applies and is saved")
		T.Window:Select("settings")
		T.Window:Select("home")
	end
	slash("theme ember")
	local found = false
	for _, text in ipairs(Stub.chat) do
		found = found or text:find("Themes:", 1, true)
	end
	slash("theme bogus")
	check(T.Theme.current.id == "ember", "an unknown theme changes nothing")
	-- capitals follow the theme
	local W = T.Widgets
	local label = W.Text(UIParent, "head", 12, "ink")
	label:SetLabel("What now?")
	check(label:GetText() == "WHAT NOW?", "Ember shows headings in capitals")
	slash("theme night")
	check(label:GetText() == "What now?", "Night restores normal case")
	local button = W.Button(UIParent, "Go", "primary")
	local narrow = button:GetWidth()
	button:SetLabel("Take me there right now")
	check(button:GetWidth() > narrow, "buttons grow with their label")
	for role in pairs(T.Theme.defs.night.c) do
		for _, id in ipairs(T.Theme.order) do
			local def = T.Theme.defs[id]
			check(def.c[role] ~= nil or role == "tabOnTop" or role == "cardTop", id .. " defines colour " .. role)
		end
	end
	noErrors(T, "themes")
end)

section("every texture the addon asks for exists", function()
	local T = load()
	slash("")
	for _, id in ipairs({ "journal", "ember", "night" }) do
		T.Theme:Set(id)
		for _, page in ipairs({ "find", "spells", "zones", "guide", "settings", "home" }) do
			T.Window:Select(page)
		end
	end
	local count = 0
	for path in pairs(Stub.textures) do
		local name = path:match("^Interface\\AddOns\\Trailhead\\Media\\(.+)$")
		check(name ~= nil, "texture path is inside the addon: " .. path)
		if name then
			local file = io.open(ADDON_DIR .. "Media/" .. name .. ".tga", "rb")
			check(file ~= nil, "Media/" .. name .. ".tga exists")
			if file then
				file:close()
			end
			count = count + 1
		end
	end
	check(count > 20, "saw " .. count .. " textures")
	local toc = io.open(ADDON_DIR .. "Media/logo.tga", "rb")
	check(toc ~= nil, "TOC icon exists")
	if toc then toc:close() end
end)

-- A saved game check from this version, so the check card stays out of the way.
local function checked(extra)
	local saved = { firstRun = false, probe = { at = 1700000000, v = 8, failed = 0, report = {} } }
	for key, value in pairs(extra or {}) do
		saved[key] = value
	end
	return saved
end

local function titles(list)
	local out = {}
	for index, item in ipairs(list) do
		out[index] = item.title or item.name
	end
	return table.concat(out, " | ")
end

local function cardIds(T, most)
	local out = {}
	for index, card in ipairs(T.Advisor.Cards(most or 20)) do
		out[index] = card.id
	end
	return table.concat(out, ",")
end

local MAGE_TRAINER = {
	services = {
		{ name = "Frostbolt", sub = "Rank 4", state = "used", level = 14, cost = 900 },
		{ name = "Cone of Cold", sub = "Rank 1", state = "available", level = 14, cost = 1800 },
		{ name = "Arcane Missiles", sub = "Rank 2", state = "available", level = 14, cost = 1200 },
		{ name = "Flamestrike", sub = "Rank 1", state = "unavailable", level = 16, cost = 3000 },
		{ name = "Evocation", state = "unavailable", level = 20, cost = 5000 },
		{ name = "Frost Ward", sub = "Rank 1", state = "unavailable", level = 22, cost = 6000 },
		{ name = "Not a spell", state = "header", level = 0, cost = 0 },
	},
}

MAGE_TRAINER.group = "Frost"

-- Opens a trainer's window the way the game does: the window first, the list a moment later.
local function visit(npc, trainer)
	local world = Stub.world
	world.npc, world.trainer = npc, trainer
	Stub.fire("TRAINER_SHOW")
	Stub.fire("TRAINER_UPDATE")
	Stub.flush()
end

local function leave()
	Stub.world.trainer = nil
	Stub.fire("TRAINER_CLOSED")
	Stub.flush()
end

section("home banner", function()
	local T = load()
	slash("")
	for _, wanted in ipairs({ "Aeloria", "14", "MAGE", "Sentinel Hill, Westfall  \194\183  levels 10-20",
		"62% to level 15", "Rested: double experience from kills", "34g 12s", "Goldshire", "9 free",
		"What now?", "3 things worth doing", "Find nearby", "Trainer", "Crafting",
		"NEXT MILESTONE", "Level 40: first mount", "26 levels to go. Riding is expensive. Start saving gold now.",
		"DID YOU KNOW?" }) do
		check(Stub.sees(wanted), "home shows: " .. wanted)
	end
	check(not Stub.sees("Choose your look"), "the look picker is no longer on Home")
	-- tips rotate
	local first = T.db.tip
	Stub.click("Next tip")
	check(T.db.tip == first + 1, "Next tip moves to the next tip")
	for _, event in ipairs({ "PLAYER_MONEY", "PLAYER_XP_UPDATE", "ZONE_CHANGED", "UPDATE_INVENTORY_DURABILITY", "TRAIT_CONFIG_UPDATED" }) do
		Stub.fire(event)
	end
	Stub.flush()
	-- a Find nearby tile opens that category
	Stub.click("Mailbox")
	check(T.Window.current == "find" and T.modules.find.category == "mailbox", "a Find nearby tile opens Find it on that category")
	noErrors(T, "home banner")

	T = load({ level = 9 }, checked())
	slash("")
	check(Stub.sees("Level 10: first talent point") and Stub.sees("1 level to go. Talents let you shape your class."), "milestone counts down to talents")
	T = load({ level = 11 }, checked())
	slash("")
	check(Stub.sees("Level 13: first dungeon"), "the first dungeon milestone comes from the game's list")
	T = load({ level = 60 }, checked())
	slash("")
	check(Stub.sees("You reached the top"), "milestones end at the top level")
	noErrors(T, "milestones")
end)

section("advice cards", function()
	local T = load()
	slash("")
	check(cardIds(T, 3) == "check,talents,train", "a new player sees the check, talents and training first")
	check(Stub.sees("Teach Trailhead about your game") and Stub.sees("You have talent points to spend")
		and Stub.sees("Visit your class trainer"), "the three cards are on Home")
	Stub.click("Run check")
	Stub.flush()
	check(T.db.probe ~= nil and T.db.probe.v == T.Probe.VERSION, "Run check runs the game check")
	check(Stub.sees("Check complete") and Stub.sees("Reload now"), "the card then asks for a reload")
	Stub.click("Reload now")
	check(Stub.reloaded == true, "Reload now reloads the interface")
	Stub.reloaded = nil

	T = load(nil, { firstRun = false, probe = { at = 1700000000, failed = 0, report = {} } })
	slash("")
	check(Stub.sees("Trailhead has new questions"), "a check from an older version is asked again")

	T = load(nil, checked())
	slash("")
	check(cardIds(T) == "talents,train,bars,dungeon", "with the check done: talents, training, bars, dungeon")
	check(Stub.sees("2 spells are not on your action bars"), "off-bar spells are counted")
	local cards = T.Advisor.Cards(20)
	check(cards[2].title == "Visit your class trainer" and cards[2].key == "train:first"
		and cards[2].body == "Trainers sell your new spells as you level.\nAfter one visit Trailhead lists them here with prices.", "before the first visit the training card sends you to the trainer")
	check(cards[3].body == "Counterspell, Blink\nDrag them from your spellbook to a bar.", "bars card names the spells")
	check(cards[4].body == "Ragefire Chasm, levels 13 to 18.\nDungeons need a group of five.", "dungeon card names the dungeon")
	Stub.click("Open talents")
	check(Stub.opened.talents == true, "Open talents opens the game's talent window")
	Stub.click("Find trainer")
	check(T.Window.current == "find" and T.modules.find.category == "trainer", "Find trainer opens Find it on class trainers")
	T.Window:Select("home")

	-- dismissing
	local before = cardIds(T)
	T.Advisor.Dismiss(T.Advisor.Cards(1)[1])
	Stub.flush()
	check(cardIds(T) == "train,bars,dungeon" and not Stub.sees("You have talent points to spend"), "a dismissed card goes away")
	T.Advisor.Reset()
	check(cardIds(T) == before, "restoring brings it back")
	T.db.cardsOff.dungeon = true
	check(cardIds(T) == "talents,train,bars", "a card can be switched off for good")
	T.db.cardsOff = {}

	-- each rule reacts to the game
	local world = Stub.world
	world.talents = false
	Stub.fire("TRAIT_CONFIG_UPDATED")
	Stub.flush()
	check(cardIds(T) == "train,bars,dungeon", "spending the points removes the talents card")
	world.durability[5] = { 4, 40 }
	check(cardIds(T) == "train,bars,repair,dungeon" and T.Advisor.Cards(20)[3].title == "Your gear is nearly broken", "worn gear asks for a repair")
	world.durability[5] = { 0, 40 }
	check(T.Advisor.Cards(20)[3].title == "Some of your gear is broken", "broken gear says so")
	world.durability[5] = { 30, 40 }
	world.free = { [0] = 2, 0, 1, 0, 0 }
	check(cardIds(T) == "train,bars,bags,dungeon" and T.Advisor.Cards(20)[3].title == "Your bags are nearly full", "nearly full bags")
	world.free = { [0] = 0, 0, 0, 0, 0 }
	check(T.Advisor.Cards(20)[3].title == "Your bags are full", "full bags")
	world.free = { [0] = 5, 1, 1, 1, 1 }
	world.bind = nil
	check(cardIds(T) == "train,bars,dungeon,home", "no hearthstone home")
	world.bind = "Goldshire"
	world.onBars[2139], world.onBars[1953] = true, true
	Stub.fire("SPELLS_CHANGED")
	Stub.flush()
	check(cardIds(T) == "train,dungeon", "placing the spells clears the bars card")
	visit("Jennea Cannon", { group = "Frost", services = {
		{ name = "Frostbolt", sub = "Rank 4", state = "used", level = 14, cost = 900 },
		{ name = "Flamestrike", sub = "Rank 1", state = "unavailable", level = 16, cost = 3000 },
	} })
	leave()
	check(cardIds(T) == "dungeon", "a trainer with nothing new to teach clears the training card")
	check(T.Game.Training().source == "trainer" and titles(T.Game.Training().later) == "Flamestrike", "and what comes later is known")
	T.db.cardsOff.dungeon = true
	check(cardIds(T) == "clear", "with nothing to say, one card says so")
	T.modules.home:Refresh()
	check(Stub.sees("You are all set") and Stub.sees("Nothing urgent"), "Home shows the all-clear")
	noErrors(T, "advice")

	T = load({ level = 5 }, checked())
	local zoneCard
	for _, card in ipairs(T.Advisor.Cards(20)) do
		zoneCard = card.id == "zone" and card or zoneCard
	end
	check(zoneCard and zoneCard.title == "Westfall is above your level" and zoneCard.tone == "warn", "a zone that is too hard is called out")
	T = load({ level = 30 }, checked())
	zoneCard = nil
	for _, card in ipairs(T.Advisor.Cards(20)) do
		zoneCard = card.id == "zone" and card or zoneCard
	end
	check(zoneCard and zoneCard.title == "You have outgrown Westfall", "an outgrown zone is called out")
	T = load({ level = 18 }, checked())
	local dungeon
	for _, card in ipairs(T.Advisor.Cards(20)) do
		dungeon = card.id == "dungeon" and card or dungeon
	end
	check(dungeon and dungeon.body:find("Deadmines", 1, true), "the newest fitting dungeon is suggested")
	noErrors(T, "advice by level")
end)

section("finding places", function()
	local T = load(nil, checked())
	local P, world = T.Places, Stub.world
	slash("")
	T.Window:Select("find")
	check(Stub.sees("Class trainer") and Stub.sees("None found yet"), "an empty category explains itself")
	check(Stub.sees("Show on the minimap"), "and offers minimap tracking")

	-- places are learned when the player uses them
	world.npc, world.repair = "Farmer Saldean", true
	Stub.fire("MERCHANT_SHOW")
	check(titles(P.Find("vendor")) == "Farmer Saldean" and titles(P.Find("repair")) == "Farmer Saldean", "a repairing vendor is remembered twice")
	Stub.fire("MERCHANT_SHOW")
	check(P.Count() == 2, "the same spot is not added again")
	local place = P.Find("vendor")[1]
	check(place.where == "Westfall" and place.here == true and place.note == "You have been here", "a place knows its zone")
	world.x, world.y = 0.30, 0.30
	world.npc, world.repair = "Innkeeper Heather", false
	Stub.fire("MERCHANT_SHOW")
	check(titles(P.Find("vendor")) == "Innkeeper Heather | Farmer Saldean", "the nearest place comes first")
	check(#P.Find("repair") == 1, "a vendor who cannot repair is not a repair place")

	-- the window opens empty; the list arrives a moment later
	world.npc, world.trainer, world.trainerLate = "Jennea Cannon", MAGE_TRAINER, true
	Stub.fire("TRAINER_SHOW")
	Stub.flush()
	check(#P.Find("trainer") == 0 and #P.Find("other") == 0 and world.filterSets == 0, "an empty trainer window is not judged yet")
	world.trainerLate = nil
	Stub.fire("TRAINER_UPDATE")
	Stub.flush()
	check(titles(P.Find("trainer")) == "Mage: Jennea Cannon" and #P.Find("other") == 0, "a class trainer is remembered, with the class in its name")
	check(T.cdb.trainer and #T.cdb.trainer.list == 5 and T.cdb.trainer.full == true, "and their list of spells is kept, later levels included")
	check(world.filter.unavailable == false and world.shown.unavailable == false and world.filterSets == 2, "the trainer window's filter is put back as it was")
	local log = T.Game.trainerLog
	check(#log == 1 and log[1].how == "at once" and log[1].class == true and log[1].groups.Frost == 5, "how the list was read is noted for the game check")
	leave()
	visit("Woo Ping", { services = {
		{ name = "Swords", state = "available", level = 1, cost = 1000 },
		{ name = "Staves", state = "unavailable", level = 1, cost = 1000 },
	} })
	check(#P.Find("trainer") == 1 and titles(P.Find("other")) == "Woo Ping", "a weapon master is not a class trainer")
	check(#T.cdb.trainer.list == 5 and world.filter.unavailable == false, "and does not replace the class trainer's list")
	leave()
	local before = world.filterSets
	visit("Tomas", { tradeskill = true, services = { { name = "Cooking", state = "available", level = 1, cost = 100 } } })
	check(titles(P.Find("professions")) == "Tomas", "a profession trainer is remembered")
	check(world.filterSets == before and #T.cdb.trainer.list == 5, "and its window is left alone")
	leave()
	visit("Hesuwa", { kind = 3, services = { { name = "Growl", sub = "Rank 2", state = "available", level = 10, cost = 100 } } })
	check(world.filterSets == before and #P.Find("trainer") == 1 and #T.cdb.trainer.list == 5, "a pet trainer is not the class trainer")
	leave()

	world.x, world.y = 0.10, 0.10
	world.npc = "Olivia Burnside"
	for kind, category in pairs({ [8] = "bank", [67] = "bank", [17] = "mailbox", [21] = "auction", [22] = "stable", [20] = "inn" }) do
		Stub.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", kind)
		check(#P.Find(category) == 1, "interaction " .. kind .. " is remembered as " .. category)
	end
	check(P.Find("mailbox")[1].title == "Mailbox", "a mailbox is called Mailbox, not the last person spoken to")
	Stub.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 999)
	Stub.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Stub.SECRET)
	Stub.fire("HEARTHSTONE_BOUND")
	check(#P.Find("inn") == 1, "binding at the same innkeeper adds nothing")
	local known = P.Count()

	-- guard directions
	world.map, world.x, world.y = 84, 0.5, 0.5
	world.gossip = { { gossipOptionID = 101, name = "Class Trainer", orderIndex = 0 }, { gossipOptionID = 102, name = "Bank", orderIndex = 1 } }
	Stub.fire("GOSSIP_SHOW")
	C_GossipInfo.SelectOption(101)
	check(world.selected == 101, "watching the menu does not change what a click does")
	world.gossip = { { gossipOptionID = 201, name = "Mage", orderIndex = 0 }, { gossipOptionID = 202, name = "Warrior", orderIndex = 1 } }
	Stub.fire("GOSSIP_SHOW")
	C_GossipInfo.SelectOptionByIndex(0)
	Stub.fire("GOSSIP_CLOSED")
	world.poi = { id = 9, name = "Wizard's Sanctum", x = 0.39, y = 0.80 }
	Stub.fire("DYNAMIC_GOSSIP_POI_UPDATED")
	local found = P.Find("trainer")
	check(#found == 2 and found[1].title == "Mage: Wizard's Sanctum" and found[1].note == "A guard pointed here", "a guard's directions to the class trainer are kept")
	check(found[1].where == "Stormwind City" and found[1].x == 0.39, "with the place the guard marked")
	world.gossip = { { gossipOptionID = 101, name = "Class Trainer", orderIndex = 0 }, { gossipOptionID = 102, name = "Bank", orderIndex = 1 } }
	Stub.fire("GOSSIP_SHOW")
	C_GossipInfo.SelectOption(102)
	world.poi = { id = 10, name = "Stormwind Counting House", x = 0.57, y = 0.72 }
	Stub.fire("DYNAMIC_GOSSIP_POI_UPDATED")
	check(titles(P.Find("bank")) == "Bank: Stormwind Counting House | Olivia Burnside", "a second question starts fresh and lands in Bank")
	world.gossip = { { gossipOptionID = 301, name = "The Beginning of the End", orderIndex = 0 } }
	Stub.fire("GOSSIP_CLOSED")
	Stub.fire("GOSSIP_SHOW")
	C_GossipInfo.SelectOption(301)
	world.poi = { id = 11, name = Stub.SECRET, x = 0.2, y = 0.2 }
	Stub.fire("DYNAMIC_GOSSIP_POI_UPDATED")
	check(#P.Find("inn") == 1 and titles(P.Find("other")):find("The Beginning of the End", 1, true), "unknown directions are kept under their own name, not guessed")
	check(P.Count() == known + 3 and #P.guardLog == 3, "three guard answers recorded")
	check(P.GuessCategory({ "Inn" }, "The Gilded Rose") == "inn" and P.GuessCategory({ "Gryphon Master" }, nil) == "flight"
		and P.GuessCategory({ "Profession Trainer", "Mining" }, nil) == "professions"
		and P.GuessCategory({ "Class Trainer", "Warrior" }, nil) == "other", "guard answers are sorted by what was asked")
	-- standing at a guard's spot replaces the guard's description with the real name
	world.x, world.y = 0.39, 0.80
	visit("Jennea Cannon", MAGE_TRAINER)
	check(P.Find("trainer")[1].title == "Mage: Jennea Cannon" and P.Find("trainer")[1].note == "You have been here", "visiting replaces the guard's description")
	leave()

	-- markers
	check(P.Go(P.Find("trainer")[1]) == false and Stub.waypoint == nil, "a map that refuses markers is reported, not forced")
	world.map, world.x, world.y = 52, 0.56, 0.47
	local vendor = P.Find("vendor")[1]
	check(P.Go(vendor) == true and Stub.waypoint.uiMapID == 52 and Stub.waypoint.position.x == vendor.x, "Set marker places the game's marker")
	check(P.HasMarker(), "the marker is known")
	P.ClearMarker()
	check(Stub.waypoint == nil, "and can be removed")

	-- other faction's places are hidden
	T.db.places[#T.db.places + 1] = { c = "inn", n = "Horde Inn", m = 52, x = 0.5, y = 0.5, z = "Westfall", f = 1, s = "seen", t = 1 }
	check(#P.Find("inn") == 1, "the other side's places are not offered")
	check(#P.Search("horde inn") == 0, "nor found by search")
	noErrors(T, "finding places")

	-- kept across logins, for every character
	local saved = TrailheadDB
	T = load(nil, saved)
	check(T.Places.Count() == known + 4 and titles(T.Places.Find("professions")) == "Tomas", "places survive a reload")
	T.Places.Forget()
	check(T.Places.Count() == 0, "Forget empties the list")
	for index = 1, 1510 do
		T.Places.Remember("vendor", "Vendor " .. index, 52, (index % 40) / 40, math.floor(index / 40) / 40, "seen")
	end
	check(T.Places.Count() == 1500, "the list is capped")
	check(T.Places.Remember("nonsense", "x", 52, 0.5, 0.5, "seen") == nil and T.Places.Remember("vendor", "x", 52, nil, 0.5, "seen") == nil, "bad input is refused")
	noErrors(T, "saved places")
end)

section("flight points and search", function()
	local T = load(nil, checked())
	local P, world = T.Places, Stub.world
	local flights = P.Find("flight")
	check(titles(flights) == "Sentinel Hill | Stormwind | Darkshire | Booty Bay", "own and neutral flight points, this zone first then nearest")
	check(flights[1].here == true and flights[1].where == "Westfall" and flights[2].here == false, "the one in this zone is marked")
	world.map = 84
	local inCity = P.Find("flight")
	local cityOnly = true
	for _, item in ipairs(inCity) do
		cityOnly = cityOnly and (item.here == (item.title == "Stormwind"))
	end
	check(cityOnly and #inCity > 1, "inside a city its own flight point is the one here")
	world.map = 52
	check(P.Go(flights[1]) and Stub.waypoint.uiMapID == 52 and Stub.waypoint.position.y == 0.52, "a marker goes on the zone map when the zone is known")
	check(P.Go(flights[2]) and Stub.waypoint.uiMapID == 37 and Stub.waypoint.position.y == 0.02, "a city that takes no marker falls back to the zone around it")
	world.cityMarkers = true
	check(P.Go(flights[2]) and Stub.waypoint.uiMapID == 84 and Stub.waypoint.position.x == 0.71, "a city's flight point is marked on the city's own map")
	world.cityMarkers = nil
	check(P.Go(flights[4]) and Stub.waypoint.uiMapID == 13 and Stub.waypoint.position.y == 0.97, "otherwise on the continent map")
	check(P.Go(flights[3]) and Stub.waypoint.uiMapID == 13, "a position that falls off the zone map is not used")
	P.ClearMarker()

	check(titles(P.Search("bank")) == "Bank", "searching a service finds its category")
	check(titles(P.Search("fly")) == "Flight master", "by any of its other names")
	check(titles(P.Search("dusk")) == "Darkshire | Duskwood", "a zone name finds its flight point and the zone")
	check(P.Search("hinterlands")[1].where == "Zone, levels 40 to 50" and P.Search("hinterlands")[1].state == "hard", "zones carry their levels")
	local dead = P.Search("dead")
	check(#dead == 1 and dead[1].kind == "dungeon" and dead[1].where == "Dungeon, levels 17 to 26" and dead[1].state == "soon", "dungeons are found with their levels")
	check(#P.Search("zzz") == 0 and #P.Search("") == 0 and #P.Search("   ") == 0, "nothing matches nothing")
	check(#P.Search("storm duskwood") == 0 and titles(P.Search("city storm")) == "Stormwind City", "every word must match")
	world.npc = "Farmer Saldean"
	Stub.fire("MERCHANT_SHOW")
	check(titles(P.Search("saldean")) == "Farmer Saldean" and titles(P.Search("westfall")) == "Farmer Saldean | Sentinel Hill | Westfall", "found places are searched by name and zone")

	-- the search box
	slash("")
	Stub.type(T.Window.search.edit, "dusk")
	check(T.Window.current == "find" and Stub.sees("Search results") and Stub.sees("2 matches"), "typing opens Find it with the results")
	check(Stub.sees("Darkshire") and Stub.sees("Duskwood") and Stub.sees("TOO DANGEROUS"), "results are listed with how they fit")
	Stub.click("Open map")
	check(Stub.mapOpened == 47, "a zone result opens the map on that zone")
	Stub.click("Set marker")
	check(Stub.waypoint ~= nil and Stub.sees("Remove marker"), "a flight result sets the marker")
	check(Stub.mapOpened == 13 and Stub.waypoint.uiMapID == 13, "and opens the game's map where the marker is")
	Stub.click("Remove marker")
	Stub.flush()
	check(Stub.waypoint == nil and not Stub.sees("Remove marker"), "Remove marker clears it")
	Stub.type(T.Window.search.edit, "bank")
	Stub.click("Show")
	check(T.modules.find.category == "bank" and T.Window.search:GetQuery() == "" and Stub.sees("None found yet"), "a category result opens that category and ends the search")
	Stub.type(T.Window.search.edit, "qqq")
	check(Stub.sees("Nothing found"), "no results says so")
	T.Window.search.clear.scripts.OnClick(T.Window.search.clear)
	check(not Stub.sees("Nothing found") and Stub.sees("Bank"), "clearing the box returns to the category")
	Stub.type(T.Window.search.edit, "dusk")
	T.Window:Select("home")
	check(T.Window.search:GetQuery() == "" and T.modules.find.query == "", "leaving Find it ends the search")
	T.Window:Select("find")
	check(Stub.sees("None found yet"), "and coming back shows the category again")
	local edit = T.Window.search.edit
	edit:SetFocus()
	Stub.mouseOver = T.Window.search
	Stub.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
	check(edit:HasFocus(), "clicking inside the search box keeps the keyboard there")
	Stub.mouseOver = nil
	Stub.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
	check(not edit:HasFocus(), "clicking anywhere else gives the keyboard back")
	edit:SetFocus()
	T.db.hideInCombat = false
	Stub.fire("PLAYER_REGEN_DISABLED")
	check(not edit:HasFocus() and T.Window:IsOpen(), "a fight gives the keyboard back even when the window stays")
	Stub.fire("PLAYER_REGEN_ENABLED")
	T.db.hideInCombat = true
	edit:SetFocus()
	T.Window:Close()
	check(not edit:HasFocus(), "closing the window lets go of the keyboard")
	slash("find saldean")
	check(T.Window:IsOpen() and Stub.sees("Farmer Saldean") and Stub.sees("1 match"), "/th find searches")
	slash("find")
	check(T.Window.current == "find", "/th find alone opens Find it")

	-- pills and tracking
	Stub.click("Vendor")
	check(T.modules.find.category == "vendor" and Stub.sees("1 place known") and not Stub.sees("Show on the minimap"), "vendors have no minimap tracking to offer")
	Stub.click("Flight master")
	check(Stub.sees("Sentinel Hill") and Stub.sees("500 YARDS") and not Stub.sees("Show on the minimap"), "flight points list with how far each is; the stub has no flight tracking")
	check(T.modules.find.YardsText(1949) == "1,900 yards" and T.modules.find.YardsText(44) == "40 yards", "distances are rounded")
	Stub.world.noYards = true
	T.Window:Select("find", "flight")
	check(Stub.sees("IN THIS ZONE") and not Stub.sees("500 YARDS"), "without the size of the continent the row says In this zone")
	Stub.world.noYards = nil
	Stub.click("Repair")
	Stub.click("Show on the minimap")
	check(world.tracking[1].active == true and Stub.sees("Shown on the minimap"), "tracking can be switched on")
	Stub.click("Shown on the minimap")
	check(world.tracking[1].active == false and Stub.sees("Show on the minimap"), "and off again")
	Stub.click("Mailbox")
	check(Stub.sees("Shown on the minimap"), "tracking that is already on shows as on")
	Stub.fire("ZONE_CHANGED_NEW_AREA")
	Stub.fire("MINIMAP_UPDATE_TRACKING")
	Stub.flush()
	slash("clear")
	noErrors(T, "search")

	-- far from any map position (inside a building the game gives no position for)
	world.x, world.y = nil, nil
	check(#P.Find("flight") == 4 and #P.Find("vendor") == 1, "lists still work without a position")
	Stub.fire("MERCHANT_SHOW")
	check(P.Count() == 1, "nothing is remembered without a position")
	noErrors(T, "no position")
end)

section("trainer windows", function()
	local T = load(nil, checked())
	local P, G, world = T.Places, T.Game, Stub.world

	-- the game applies the filter a moment later and says so
	world.filterLag = true
	visit("Jennea Cannon", MAGE_TRAINER)
	check(#T.cdb.trainer.list == 5 and T.cdb.trainer.full == true and G.trainerLog[1].how == "waited", "a filter that answers late is waited for")
	check(world.filter.unavailable == false and world.shown.unavailable == false, "and still put back")
	check(titles(G.Training().later) == "Flamestrike | Evocation | Frost Ward", "later levels are read")
	leave()

	-- the game applies it late and says nothing
	T = load(nil, checked())
	P, G, world = T.Places, T.Game, Stub.world
	world.filterLag = "silent"
	world.npc, world.trainer = "Jennea Cannon", MAGE_TRAINER
	Stub.fire("TRAINER_SHOW")
	check(T.cdb.trainer == nil and world.filter.unavailable == true, "while waiting nothing is saved")
	Stub.flush()
	check(#T.cdb.trainer.list == 5 and world.filter.unavailable == false, "a silent filter is read after a short wait and put back")
	leave()

	-- the window closes while Trailhead is waiting
	T = load(nil, checked())
	P, G, world = T.Places, T.Game, Stub.world
	world.filterLag = "silent"
	world.npc, world.trainer = "Jennea Cannon", MAGE_TRAINER
	Stub.fire("TRAINER_SHOW")
	world.trainer = nil
	Stub.fire("TRAINER_CLOSED")
	check(world.filter.unavailable == false, "closing the window mid-read puts the filter back at once")
	Stub.flush()
	check(T.cdb.trainer == nil and #P.Find("trainer") == 0 and world.filter.unavailable == false, "and nothing half-read is kept")

	-- the player already shows later levels: nothing is touched
	T = load(nil, checked())
	P, G, world = T.Places, T.Game, Stub.world
	world.filter.unavailable, world.shown.unavailable = true, true
	visit("Jennea Cannon", MAGE_TRAINER)
	check(world.filterSets == 0 and #T.cdb.trainer.list == 5 and G.trainerLog[1].how == "as shown"
		and world.filter.unavailable == true, "a window that already shows later levels is left alone")
	leave()

	-- only what can be learned now, and the filter cannot be changed
	T = load(nil, checked())
	P, G, world = T.Places, T.Game, Stub.world
	SetTrainerServiceTypeFilter = nil
	visit("Jennea Cannon", MAGE_TRAINER)
	check(#T.cdb.trainer.list == 2 and T.cdb.trainer.full == nil and titles(P.Find("trainer")) == "Mage: Jennea Cannon", "without a filter to change, what is shown is kept")
	slash("")
	T.Window:Select("spells")
	check(Stub.sees("As of your last visit to the trainer. Learning everything ready now costs about 30s 0c. To see later levels here, tick Unavailable in the trainer window's filter."), "and the page says how to see later levels")
	leave()

	-- every spell already learned: an empty list is still a visit
	T = load(nil, checked())
	P, G, world = T.Places, T.Game, Stub.world
	visit("Jennea Cannon", { group = "Frost", services = { { name = "Frostbolt", sub = "Rank 4", state = "used", level = 14, cost = 900 } } })
	check(world.filter.unavailable == false and world.filterSets <= 6, "an empty list stops trying after a few goes")
	check(T.cdb.trainer == nil and titles(P.Find("other")) == "Jennea Cannon", "and without a list the trainer is kept by name")
	leave()

	-- a trainer filed under "other" is moved once it turns out to teach the class
	visit("Jennea Cannon", MAGE_TRAINER)
	check(#P.Find("other") == 0 and titles(P.Find("trainer")) == "Mage: Jennea Cannon", "a mistaken record is moved, not doubled")
	leave()

	-- few services, no ranks: told apart by the spell school
	T = load(nil, checked())
	P, G, world = T.Places, T.Game, Stub.world
	visit("Jennea Cannon", { group = "Frost", services = { { name = "Blink", state = "available", level = 20, cost = 100 } } })
	check(titles(P.Find("trainer")) == "Mage: Jennea Cannon" and #T.cdb.trainer.list == 1, "a short list in the class's own school is a class trainer")
	leave()
	-- the real game's trainer: ranks, and a school name Trailhead does not know
	T = load(nil, checked())
	P, G, world = T.Places, T.Game, Stub.world
	local rogue = { group = "Something else", services = {
		{ name = "Backstab", sub = "Rank 1", state = "available", level = 4, cost = 100 },
		{ name = "Sap", sub = "Rank 1", state = "available", level = 10, cost = 300 },
		{ name = "Garrote", sub = "Rank 1", state = "available", level = 14, cost = 1100 },
		{ name = "Feint", sub = "Rank 1", state = "available", level = 16, cost = 1500 },
		{ name = "Kick", sub = "Rank 2", state = "unavailable", level = 22, cost = 3000 },
		{ name = "Garrote", state = "available", level = 22, cost = 1100 },
		{ name = "Garrote", state = "available", level = 30, cost = 1100 },
		{ name = "Garrote", state = "available", level = 38, cost = 1100 },
	} }
	visit("Shenthul", rogue)
	check(titles(P.Find("trainer")) == "Mage: Shenthul" and #T.cdb.trainer.list == 8, "spells that come in ranks mark a class trainer")
	-- the game calls Feint "available" although it needs level 16 and the mage is 14
	check(titles(G.Training().now) == "Backstab | Sap | Garrote" and titles(G.Training().later) == "Feint | Garrote | Kick | Garrote | Garrote"
		and G.Training().cost == 1500, "a spell above your level is coming up, whatever the game calls it")
	-- three spells vanishing at once is the list changing, not the player buying them
	rogue.services[1].state, rogue.services[2].state, rogue.services[3].state = "used", "used", "used"
	Stub.fire("TRAINER_UPDATE")
	Stub.flush()
	check(#G.Training().now == 3, "a list that shrinks in one go is not read as spells bought")
	rogue.services[2].state, rogue.services[3].state = "available", "available"
	Stub.fire("TRAINER_UPDATE")
	Stub.flush()
	check(titles(G.Training().now) == "Sap | Garrote", "one spell bought is")
	leave()
	Stub.fire("PLAYER_LEVEL_UP", 16)
	Stub.flush()
	check(titles(G.Training().now) == "Sap | Garrote | Feint" and titles(G.Training().later) == "Garrote | Kick | Garrote | Garrote", "and it becomes ready at its level")
	noErrors(T, "trainer windows")
end)

section("spells", function()
	local T = load(nil, checked())
	local G, world = T.Game, Stub.world
	check(titles(G.SpellsOffBars()) == "Counterspell | Blink", "off-bar spells skip Attack, passives, low ranks and unlearned spells")
	local training = G.Training()
	check(training.source == nil and #training.now == 0 and #training.later == 0, "before a trainer visit nothing is guessed")
	slash("")
	T.Window:Select("spells")
	for _, wanted in ipairs({ "Not on your action bars", "Counterspell", "Blink", "From your class trainer",
		"Visit your class trainer once. From then on Trailhead lists what you can learn, what it costs and what is coming at later levels.",
		"New spells and new ranks are bought from your class trainer." }) do
		check(Stub.sees(wanted), "spells page shows: " .. wanted)
	end
	check(not Stub.sees("Fireball") and not Stub.sees("Attack") and not Stub.sees("Mage Armor")
		and not Stub.sees("READY TO LEARN NOW"), "and nothing it should not")
	Stub.click("Open spellbook")
	check(Stub.opened.spellbook == true, "Open spellbook opens the game's spellbook")
	world.onBars[2139] = true
	Stub.fire("ACTIONBAR_SLOT_CHANGED", 5)
	Stub.flush()
	check(not Stub.sees("Counterspell") and Stub.sees("Blink"), "putting a spell on a bar removes it from the list")
	world.onBars[1953] = true
	Stub.fire("ACTIONBAR_SLOT_CHANGED", 6)
	Stub.flush()
	check(Stub.sees("Every class spell you know is on a bar. Nothing to do here."), "an empty list says all is well")

	-- the trainer's list
	visit("Jennea Cannon", MAGE_TRAINER)
	training = G.Training()
	check(training.source == "trainer" and titles(training.now) == "Cone of Cold | Arcane Missiles" and training.cost == 3000, "the trainer's list gives what is ready and the cost")
	check(titles(training.later) == "Flamestrike | Evocation | Frost Ward", "and what comes later, in level order")
	check(training.full == true and Stub.sees("READY TO LEARN NOW") and Stub.sees("COMING UP"), "with both headings")
	check(Stub.sees("Cone of Cold  (Rank 1)") and Stub.sees("18s 0c") and Stub.sees("level 22"), "the page shows ranks, prices and levels")
	check(Stub.sees("As of your last visit to the trainer. Learning everything ready now costs about 30s 0c."), "and the total")
	local card
	for _, advice in ipairs(T.Advisor.Cards(20)) do
		card = advice.id == "train" and advice or card
	end
	check(card and card.title == "2 new spells to train" and card.body == "Cone of Cold, Arcane Missiles\nCost: about 30s 0c.", "the advice card uses the trainer's list")
	-- learning one at the trainer
	MAGE_TRAINER.services[2].state = "used"
	Stub.fire("TRAINER_UPDATE")
	Stub.flush()
	check(titles(G.Training().now) == "Arcane Missiles", "learning a spell updates the list")
	-- the window closing empties the list, which must not look like learning the rest
	world.trainer = nil
	Stub.fire("TRAINER_UPDATE")
	Stub.fire("TRAINER_CLOSED")
	Stub.flush()
	check(titles(G.Training().now) == "Arcane Missiles" and world.filter.unavailable == false, "closing the window learns nothing")
	MAGE_TRAINER.services[2].state = "available"
	-- a level-up makes the next ones ready without a new visit
	Stub.fire("PLAYER_LEVEL_UP", 16)
	Stub.flush()
	check(G.Level() == 16, "the new level is known at once, before the game reports it")
	check(titles(G.Training().now) == "Arcane Missiles | Flamestrike", "spells for the new level become ready")
	Stub.click("Find my trainer")
	check(T.Window.current == "find" and T.modules.find.category == "trainer" and Stub.sees("Mage: Jennea Cannon"), "Find my trainer lists the trainer just visited")
	noErrors(T, "spells")

	local savedChar = TrailheadCharDB
	T = load(nil, checked(), savedChar)
	check(T.Game.Training().source == "trainer", "the trainer's list is kept per character across logins")
	T = load(nil, checked(), { trainer = { list = "broken" } })
	check(T.Game.Training().source == nil, "a damaged saved list is ignored")
	noErrors(T, "saved trainer list")
end)

section("zones", function()
	local T = load(nil, checked())
	local G, world = T.Game, Stub.world
	local zones = G.World().zones
	check(#zones == 7 and #G.World().dungeons == 3 and G.World().complete, "zones and dungeons are read from the game")
	local byName = {}
	for _, zone in ipairs(zones) do
		byName[zone.name] = zone
	end
	check(byName["The Hinterlands"].lo == 40 and byName["The Hinterlands"].hi == 50, "a name with The matches the group finder's name without it")
	check(byName["Stormwind City"].lo == 1 and byName["Stormwind City"].hi == 60, "the map's own levels are the fallback")
	check(byName["Westfall"].friendly and not byName["Westfall"].hostile, "a zone with our flight point is friendly")
	check(byName["The Hinterlands"].hostile and not byName["The Hinterlands"].friendly, "a zone with only the other side's is not")
	check(byName["Stranglethorn Vale"].friendly and byName["Stranglethorn Vale"].hostile, "a shared zone is both")
	check(byName["Westfall"].continent == "Eastern Kingdoms" and byName["The Barrens"].continent == "Kalimdor", "zones know their continent")
	check(G.CurrentZone() == byName["Westfall"], "the current zone is found")
	check(G.RangeState(10, 20, 14) == "fit" and G.RangeState(15, 30, 14) == "soon" and G.RangeState(18, 30, 14) == "hard"
		and G.RangeState(1, 10, 14) == "done" and G.RangeState(nil, nil, 14) == nil, "level ranges are judged against the player")

	slash("")
	T.Window:Select("zones")
	local list = T.modules.zones
	check(list.filter == "fit" and Stub.sees("Zones and the levels they are meant for. You are level 14."), "opens on zones for my level")
	for _, wanted in ipairs({ "Westfall", "10-20", "You are here", "RIGHT FOR YOU", "Stormwind City", "The Barrens", "15-30", "ALMOST",
		"Kalimdor  \194\183  No flight point for your side" }) do
		check(Stub.sees(wanted), "zones for my level shows: " .. wanted)
	end
	check(not Stub.sees("Duskwood") and not Stub.sees("Elwynn Forest"), "zones that do not fit are left out")
	check(titles(list.Items("fit", 14)) == "Westfall | Stormwind City | The Barrens", "reachable zones first, then by how well they fit")
	local strict = true
	for _, item in ipairs(list.Items("all", 14)) do
		strict = strict and type(item.away) == "boolean"
	end
	check(strict, "every zone says plainly whether it is out of reach (the list is sorted on it)")
	check(titles(list.Items("all", 14)) == "Elwynn Forest | Stormwind City | Westfall | The Barrens | Duskwood | Stranglethorn Vale | The Hinterlands", "All zones runs from low to high")
	Stub.click("All zones")
	check(list.filter == "all" and Stub.sees("Elwynn Forest") and Stub.sees("OUTGROWN") and Stub.sees("Duskwood") and Stub.sees("TOO DANGEROUS"), "All zones lists everything")
	Stub.click("Open map", 1)
	check(Stub.mapOpened == 37, "Open map opens the game's map on that zone")
	Stub.click("Dungeons")
	check(list.filter == "dungeons" and Stub.sees("Ragefire Chasm") and Stub.sees("13-18") and Stub.sees("Deadmines") and Stub.sees("The Stockade")
		and not Stub.sees("Broken Entry") and not Stub.sees("Warsong Gulch"), "Dungeons lists the dungeons only")
	check(not Stub.sees("Open map"), "dungeons have no map button (the game does not say where they are)")
	T.Window:Open("zones", "nonsense")
	check(list.filter == "dungeons", "an unknown filter changes nothing")
	T.Window:Open("zones", "fit")
	Stub.fire("PLAYER_LEVEL_UP", 15)
	Stub.flush()
	check(Stub.sees("Zones and the levels they are meant for. You are level 15."), "the page follows a level-up")
	Stub.combat = true
	check(T.Places.ShowMap(47) == false, "the map is not opened in combat")
	Stub.combat = false
	noErrors(T, "zones")

	-- the game sometimes has no group finder list yet at login
	T = load({ noActivities = true }, checked())
	slash("")
	T.Window:Select("zones")
	check(not T.Game.World().complete and Stub.sees("Stormwind City"), "without the list, what is known still shows")
	T.Window:Select("zones", "dungeons")
	check(Stub.sees("The game has not listed any dungeons yet. Try again in a moment."), "an empty dungeon list explains itself")
	Stub.world.noActivities = false
	Stub.skew = 30
	check(T.Game.World().complete and #T.Game.World().dungeons == 3, "and the list is read again a little later")
	Stub.skew = 0
	noErrors(T, "late group finder list")
end)

section("how to get there", function()
	local T = load(nil, checked())
	T.DungeonIndex = {} -- these tests are about doors learned by walking in, not the shipped ones
	local G, P, R, world = T.Game, T.Places, T.Routes, Stub.world
	local function texts(plan)
		local out = {}
		for _, step in ipairs(plan.steps) do
			out[#out + 1] = step.text
		end
		return table.concat(out, " | ")
	end
	local function flight(name)
		for _, result in ipairs(P.Find("flight")) do
			if result.title == name then
				return R.ForResult(result)
			end
		end
	end
	local DOT = "  \194\183  "

	-- positions and sizes
	local continent, cx, cy = G.OnContinent(47, 0.5, 0.5)
	check(continent == 13 and math.abs(cx - 0.48) < 1e-9 and math.abs(cy - 0.81) < 1e-9, "a spot on a zone map is placed on its continent")
	check(select("#", G.OnContinent(13, 0.2, 0.3)) == 3 and select(2, G.OnContinent(13, 0.2, 0.3)) == 0.2, "a spot on a continent map stays as it is")
	check(G.ContinentOf(52) == 13 and G.ContinentOf(10) == 12 and G.ContinentOf(nil) == nil and G.ZoneOf(55) == 52, "maps know their continent and zone")
	check(G.MapYards(13) == 30000 and G.MapYards(52) == nil, "continents have a size in yards")
	check(R.Compass(0, -1) == "north" and R.Compass(1, -1) == "north-east" and R.Compass(1, 0) == "east" and R.Compass(1, 1) == "south-east"
		and R.Compass(0, 1) == "south" and R.Compass(-1, 1) == "south-west" and R.Compass(-1, 0) == "west" and R.Compass(-1, -1) == "north-west",
		"eight compass directions")

	-- before any flight master has been visited
	check(G.KnownFlights(13) == nil, "no flight points are known before a flight master is visited")
	local plan = R.Plan(flight("Booty Bay"))
	check(texts(plan) == "Go to the flight master in Sentinel Hill | Fly to Booty Bay", "a far flight point: walk to the nearest flight master, then fly")
	check(plan.steps[1].detail == "Westfall" .. DOT .. "To the south-east" .. DOT .. "About 2 minutes on foot", "the walk says where, which way and how long")
	check(plan.steps[1].map == 52 and plan.steps[1].y == 0.52 and plan.steps[1].mark == "Sentinel Hill", "the flight master step carries a marker on the zone map")
	check(plan.steps[2].map == nil and plan.steps[2].detail:find("Stranglethorn", 1, true) and plan.steps[2].detail:find("you have not found it yet", 1, true),
		"the flight step warns that the point may not be found yet")
	check(plan.note:find("Talk to any flight master once", 1, true), "and says how Trailhead learns them")
	check(plan.title == "Booty Bay" and plan.icon == "wing", "the plan is titled")

	-- a flight master's map teaches which points the character has
	world.taxiAll = {
		{ nodeID = 4, name = "Sentinel Hill, Westfall", state = 0 }, { nodeID = 2, name = "Stormwind, Elwynn", state = 1 },
		{ nodeID = 12, name = "Darkshire, Duskwood", state = 1 }, { nodeID = 19, name = "Booty Bay, Stranglethorn", state = 2 },
	}
	Stub.fire("TAXIMAP_OPENED")
	local known = G.KnownFlights(13)
	check(known and known["Sentinel Hill, Westfall"] and known["Darkshire, Duskwood"] and not known["Booty Bay, Stranglethorn"],
		"the flight master's list is remembered, without the points out of reach")
	check(G.KnownFlights(12) == nil and G.taxiLog.how == "map" and G.taxiLog.count == 3 and G.taxiLog.states["2"] == 1, "for that continent only, and logged")
	plan = R.Plan(flight("Booty Bay"))
	check(texts(plan) == "Walk to the flight master in Booty Bay", "a flight point not found yet has to be walked to")
	check(plan.steps[1].detail == "Stranglethorn" .. DOT .. "To the south" .. DOT .. "12 minutes or more on foot" and plan.steps[1].map == 13, "with the way, and a long walk's time given as a lower figure")
	check(plan.note:find("You have not found this flight point yet", 1, true), "and the note says why")

	-- a found place in another zone
	P.Remember("vendor", "Abercrombie", 47, 0.5, 0.5, "visit")
	local shop = R.ForResult(P.Find("vendor")[1])
	plan = R.Plan(shop)
	check(texts(plan) == "Go to the flight master in Sentinel Hill | Fly to Darkshire | Walk to Abercrombie", "a place far away: walk, fly, walk")
	check(plan.steps[2].detail == "Duskwood", "a flight point the character has is named plainly")
	check(plan.steps[3].detail == "Duskwood" .. DOT .. "To the south-west" .. DOT .. "About a minute on foot", "the last stretch starts at the landing")
	check(plan.steps[3].map == 47 and plan.steps[3].x == 0.5 and plan.note == nil, "and its marker is the place itself")

	-- standing at the flight master
	world.cx, world.cy = 0.41, 0.80
	plan = R.Plan(shop)
	check(plan.steps[1].text == "Talk to the flight master in Sentinel Hill" and plan.steps[1].detail == "You are standing next to them.", "next to the flight master it says to talk to them")
	world.cx, world.cy = nil, nil

	-- a closer flight point the character lacks
	T.cdb.taxi[13]["Darkshire, Duskwood"] = nil
	plan = R.Plan(shop)
	check(texts(plan) == "Walk to Abercrombie" and plan.note:find("Darkshire has a flight point closer to it", 1, true), "a closer point not found yet is named in the note")
	T.cdb.taxi[13]["Darkshire, Duskwood"] = true

	-- close by: just walk
	P.Remember("repair", "Smith Argus", 52, 0.5, 0.5, "visit")
	plan = R.Plan(R.ForResult(P.Find("repair")[1]))
	check(texts(plan) == "Walk to Smith Argus" and plan.steps[1].detail == "Westfall" .. DOT .. "To the south" .. DOT .. "Under a minute on foot" and plan.note == nil,
		"a place close by is one walk")

	-- zones
	local dusk = R.ForZone(47, "Duskwood")
	check(dusk.node == 12 and dusk.where == "Flight point: Darkshire" and dusk.map == 13, "a zone is reached at its flight point")
	plan = R.Plan(dusk)
	check(texts(plan) == "Go to the flight master in Sentinel Hill | Fly to Darkshire", "and the route ends when you land there")
	local barrens = R.ForZone(10, "The Barrens")
	check(barrens.node == nil and barrens.map == 10 and barrens.x == 0.5, "a zone without a flight point for your side is reached at its middle")
	plan = R.Plan(barrens)
	check(texts(plan) == "Cross the sea to Kalimdor | Walk to The Barrens" and plan.steps[1].map == nil and plan.steps[2].map == 10, "another continent starts with the crossing")
	check(plan.steps[1].detail:find("Ask a city guard which one goes to Kalimdor", 1, true) and plan.note:find("does not know the sea crossings yet", 1, true), "and is honest about not knowing the boats")

	-- when the game will not say enough
	world.noYards = true
	plan = R.Plan(shop)
	check(texts(plan) == "Go to the flight master in Sentinel Hill | Fly to Darkshire | Walk to Abercrombie"
		and plan.steps[3].detail == "Duskwood" .. DOT .. "To the south-west", "without map sizes the steps stay and the times go")
	world.noYards = nil
	world.noRects = true
	plan = R.Plan(shop)
	check(texts(plan) == "Follow the marker to Abercrombie" and plan.steps[1].map == 47 and plan.note:find("cannot tell where you are standing", 1, true),
		"without zone positions there is still a marker")
	world.noRects = nil
	local x = world.x
	world.x = nil
	plan = R.Plan(shop)
	check(texts(plan) == "Follow the marker to Abercrombie", "indoors, with no position, the same")
	world.x = x
	check(R.ForResult({ kind = "category" }) == nil and R.Mark(nil) == false and R.Mark({ text = "Fly" }) == false, "nothing to route to, nothing done")

	-- the old flight window
	world.taxiAll = nil
	world.taxiFrame = { { "Sentinel Hill, Westfall", "CURRENT" }, { "Stormwind, Elwynn", "REACHABLE" }, { "Darkshire, Duskwood", "DISTANT" }, { "Booty Bay, Stranglethorn", "NONE" } }
	T.cdb.taxi = nil
	Stub.fire("TAXIMAP_OPENED")
	known = G.KnownFlights(13)
	check(known and known["Darkshire, Duskwood"] and not known["Booty Bay, Stranglethorn"] and G.taxiLog.how == "frame", "the old flight window is read too")
	world.taxiFrame = {}
	Stub.fire("TAXIMAP_OPENED")
	check(G.KnownFlights(13) == known, "an empty list changes nothing")

	-- dungeon entrances are learned by walking in
	local dead = R.ForDungeon("Deadmines")
	plan = R.Plan(dead)
	check(plan.unknown and #plan.steps == 0 and plan.note:find("does not know where Deadmines is entered yet", 1, true)
		and plan.note:find("the first time one of your characters walks in", 1, true), "an entrance nobody has used is admitted")
	check(#Stub.tickers == 1, "one ticker watches for doors")
	local tick = Stub.tickers[1]
	tick()
	world.instance = { name = "The Deadmines", kind = "party" }
	Stub.fire("PLAYER_ENTERING_WORLD")
	world.instance = nil
	local door = G.Entrance("Deadmines")
	check(door and door.map == 52 and door.x == 0.56 and door.y == 0.47 and door.zone == "Westfall", "walking in records where you stood, under either name")
	plan = R.Plan(R.ForDungeon("Deadmines"))
	check(texts(plan) == "Walk to Deadmines" and plan.where == "Entrance in Westfall" and plan.steps[1].map == 52, "and the dungeon now has a route")
	tick()
	tick()
	check(#TrailheadDB.entrances.deadmines.spots == 1 and TrailheadDB.entrances.deadmines.spots[1].c == 1, "standing outside records nothing more")

	-- a cave's own map: the spot on the zone map is kept
	world.map = 55
	tick()
	world.instance = { name = "The Deadmines", kind = "party" }
	tick()
	world.instance = nil
	world.map = 52
	local spots = TrailheadDB.entrances.deadmines.spots
	check(#spots == 2 and spots[2].m == 52 and spots[2].x == 0.40, "from a cave, the spot on the zone map is kept")
	tick()
	world.instance = { name = "The Deadmines", kind = "party" }
	tick()
	tick()
	world.instance = nil
	check(#spots == 2 and spots[1].c == 2 and G.Entrance("Deadmines").x == 0.56, "the door used most wins, and one visit counts once")

	-- arrivals that are not walking in
	tick()
	Stub.fire("CONFIRM_SUMMON")
	world.instance = { name = "The Stockade", kind = "party" }
	tick()
	world.instance = nil
	check(G.Entrance("The Stockade") == nil, "a summon is not an entrance")
	tick()
	world.instance = { name = "Warsong Gulch", kind = "pvp" }
	tick()
	world.instance = nil
	check(G.Entrance("Warsong Gulch") == nil, "nor is a battleground")
	world.instance = { name = "Ragefire Chasm", kind = "party" }
	tick()
	world.instance = nil
	check(G.Entrance("Ragefire Chasm") == nil, "nor logging in inside one")
	Stub.combat = true
	world.x = 0.9
	tick()
	Stub.combat = false
	world.x = x
	world.instance = { name = "Ragefire Chasm", kind = "party" }
	tick()
	world.instance = nil
	check(G.Entrance("Ragefire Chasm") == nil, "nothing is sampled in combat")

	-- the page
	slash("")
	T.Window:Select("find", "flight")
	Stub.click("How to get there", 4)
	check(T.Window.current == "route" and Stub.sees("Booty Bay") and Stub.sees("HOW TO GET THERE") and Stub.sees("Walk to the flight master in Booty Bay"),
		"the button on a row opens its route")
	check(Stub.sees("1") and not Stub.sees("2") and Stub.sees("Stranglethorn"), "one step, numbered, with where it is")
	Stub.click("Set marker", 1)
	check(Stub.waypoint and Stub.waypoint.uiMapID == 13 and Stub.mapOpened == 13, "a step's marker goes on the map and the map opens")
	Stub.click("Back")
	check(T.Window.current == "find" and T.modules.find.category == "flight", "Back returns to the list it came from")
	Stub.type(T.Window.search.edit, "dusk")
	Stub.click("How to get there", 2)
	check(T.Window.current == "route" and Stub.sees("Darkshire") and Stub.sees("Fly to Darkshire") and Stub.sees("2"), "a search result has a route too")
	Stub.click("Back")
	check(T.Window.current == "find" and Stub.sees("Search results") and Stub.sees("3 matches"), "and Back keeps the search")
	Stub.click("How to get there", 3)
	check(Stub.sees("Duskwood") and Stub.sees("Flight point: Darkshire"), "a zone in the search is routed to its flight point")
	T.Window:Select("zones", "dungeons")
	check(Stub.sees("Dungeon for a group of five  \194\183  Entrance in Westfall"), "a learned entrance shows in the dungeon list")
	Stub.click("How to get there", 1)
	check(T.Window.current == "route" and Stub.sees("Ragefire Chasm") and Stub.sees(T.modules.route.plan.note) and T.modules.route.plan.note:find("does not know where Ragefire Chasm is entered yet", 1, true), "a dungeon without one says so")
	Stub.click("Back")
	check(T.Window.current == "zones" and T.modules.zones.filter == "dungeons", "Back returns to the dungeons")
	T.Window:Select("zones", "fit")
	Stub.click("How to get there", 1)
	check(T.Window.current == "route" and Stub.sees("Westfall"), "zones have routes")
	world.cx = 0.47
	Stub.fire("ZONE_CHANGED_NEW_AREA")
	Stub.flush()
	check(T.modules.route.plan and T.Window.current == "route", "the steps are worked out again as you travel")
	world.cx = nil
	T.modules.route.target = nil
	T.Window:Select("route")
	check(T.Window.current ~= "route", "with nothing to route to the page is not shown")
	noErrors(T, "routes")

	-- raids
	T.Window:Select("zones", "raids")
	check(Stub.sees("The game lists no raids for your character yet.\nRaids are for large groups at the highest levels. They will appear here, with how to get to each, as soon as the game lists them."), "no raids yet is explained")
	T = load(nil, checked())
	Stub.world.raids = true
	check(#T.Game.World().raids == 2 and #T.Game.World().dungeons == 3, "raids are told apart from dungeons by number or by name")
	slash("")
	T.Window:Select("zones", "raids")
	check(Stub.sees("Molten Core") and Stub.sees("Onyxia's Lair") and Stub.sees("Raid for a large group") and Stub.sees("60-60"), "and listed with their levels")
	local found = T.Places.Search("molten")
	check(#found == 1 and found[1].where == "Raid, levels 60 to 60" and found[1].kind == "dungeon", "and found by the search")
	noErrors(T, "raids")
end)

section("beside game windows", function()
	local T = load(nil, checked())
	local window = T.Window
	slash("")
	local frame = TrailheadWindow
	local function at()
		local point = frame.points[#frame.points]
		return point[1], point[2], point[3], point[4], point[5]
	end
	local homePoint, _, _, homeX, homeY = at()
	check(window:IsBeside() == nil and window:Beside("NoSuchFrame") == false, "nothing to sit beside, nothing happens")

	-- the spellbook: room on its right
	window:Select("spells")
	Stub.click("Open spellbook")
	local point, parent, relPoint, x, y = at()
	check(window:IsBeside() == "PlayerSpellsFrame" and point == "TOPLEFT" and parent == UIParent and relPoint == "BOTTOMLEFT"
		and x == 1182 and y == 1084, "Open spellbook puts Trailhead to the right of the spellbook, tops lined up")
	check(frame:IsShown() and frame:GetScale() == 1, "at its normal size")
	-- the game window changes size (another tab): Trailhead follows
	PlayerSpellsFrame.rect = { 16, 1628, 1084, 228 }
	window:DockTick()
	check(select(4, at()) == 1640, "it follows when the game window grows")
	-- it grows so far that only a smaller Trailhead fits
	PlayerSpellsFrame.rect = { 16, 2200, 1084, 228 }
	window:DockTick()
	point, parent, relPoint, x, y = at()
	check(frame:GetScale() == 0.8 and math.abs(x * 0.8 - 2212) < 0.01 and math.abs(y * 0.8 - 1084) < 0.01, "with little room it shrinks to fit")
	-- no room on the right, plenty on the left
	PlayerSpellsFrame.rect = { 1700, 2854, 1084, 201 }
	window:DockTick()
	point, parent, relPoint, x, y = at()
	check(frame:GetScale() == 1 and x == 1700 - 12 - 920 and y == 1084, "it takes the left side when that is where the room is")
	-- a game window low on the screen: Trailhead's bottom stays on screen
	PlayerSpellsFrame.rect = { 16, 1170, 500, 100 }
	window:DockTick()
	check(select(5, at()) == 600, "its bottom edge is kept on the screen")
	-- no room at all: Trailhead stays where the player keeps it
	PlayerSpellsFrame.rect = { 400, 2600, 1084, 201 }
	window:DockTick()
	point, parent, relPoint, x, y = at()
	check(point == homePoint and x == homeX and y == homeY and frame:GetScale() == 1 and frame:IsShown(), "with no room either side it stays at home")
	-- closing the game window sends Trailhead home
	PlayerSpellsFrame.rect = { 16, 1170, 1084, 201 }
	window:DockTick()
	check(select(4, at()) == 1182, "(beside again)")
	PlayerSpellsFrame:Hide()
	window:DockTick()
	point, parent, relPoint, x, y = at()
	check(window:IsBeside() == nil and point == homePoint and x == homeX and y == homeY, "closing the game window sends Trailhead back to its place")
	check(T.db.window.x == nil, "and none of this is saved as the window's own position")

	-- talents
	window:Select("home")
	Stub.click("Open talents")
	check(Stub.opened.talents and window:IsBeside() == "PlayerSpellsFrame" and select(4, at()) == 1182, "Open talents does the same")
	-- closing Trailhead lets go
	window:Close()
	window:DockTick()
	check(window:IsBeside() == nil, "closing Trailhead lets go of the game window")
	PlayerSpellsFrame:Hide()
	slash("")
	point, parent, relPoint, x, y = at()
	check(point == homePoint and x == homeX, "and it opens at home next time")

	-- the map, windowed and then full-screen
	T.Places.ShowMap(52)
	check(window:IsBeside() == "WorldMapFrame" and select(4, at()) == 1052, "the map gets Trailhead beside it too")
	WorldMapFrame.rect = { 0, 2968, 1200, 0 }
	window:DockTick()
	check(not frame:IsShown() and window:IsBeside() == "WorldMapFrame", "a map that fills the screen sends Trailhead out of the way")
	WorldMapFrame:Hide()
	window:DockTick()
	point, parent, relPoint, x, y = at()
	check(frame:IsShown() and window:IsBeside() == nil and point == homePoint and x == homeX, "and it comes back when the map closes")
	WorldMapFrame.rect = { 16, 1040, 1084, 316 }

	-- moved by hand while beside: it stays where the player drops it
	T.Places.ShowMap(52)
	window:Undock(true)
	check(window:IsBeside() == nil and select(4, at()) == 1052, "moved by hand, it stays put")
	WorldMapFrame:Hide()

	-- a fight
	window:ResetPosition()
	T.Places.ShowMap(52)
	Stub.combat = true
	Stub.fire("PLAYER_REGEN_DISABLED")
	check(window:IsBeside() == nil and not frame:IsShown(), "a fight ends it and hides Trailhead as usual")
	Stub.combat = false
	Stub.fire("PLAYER_REGEN_ENABLED")
	point, parent, relPoint, x, y = at()
	check(frame:IsShown() and point == "CENTER", "and afterwards Trailhead is back at home")
	WorldMapFrame:Hide()

	-- a fight while a full-screen map has Trailhead tucked away
	T.Places.ShowMap(52)
	WorldMapFrame.rect = { 0, 2968, 1200, 0 }
	window:DockTick()
	Stub.combat = true
	Stub.fire("PLAYER_REGEN_DISABLED")
	Stub.combat = false
	Stub.fire("PLAYER_REGEN_ENABLED")
	check(frame:IsShown() and window:IsBeside() == nil, "tucked away when a fight starts, it still comes back afterwards")
	WorldMapFrame.rect = { 16, 1040, 1084, 316 }
	WorldMapFrame:Hide()

	-- a game window drawn at another scale than the screen
	WorldMapFrame.effective, WorldMapFrame.rect = 0.5, { 32, 2080, 2168, 632 }
	T.Places.ShowMap(52)
	check(select(4, at()) == 1052 and select(5, at()) == 1084, "a game window at its own scale is measured in the screen's units")
	WorldMapFrame.effective, WorldMapFrame.rect = nil, { 16, 1040, 1084, 316 }
	WorldMapFrame:Hide()
	window:DockTick()

	-- switched off in Settings
	window:Select("settings")
	check(Stub.sees("Beside game windows"), "Settings has the switch")
	T.db.dock = false
	T.Places.ShowMap(52)
	check(window:IsBeside() == nil and Stub.mapOpened == 52, "switched off, the map opens and Trailhead stays put")
	T.db.dock = true
	WorldMapFrame:Hide()

	check(#window.dockLog > 0 and window.dockLog[#window.dockLog].name == "WorldMapFrame" and window.dockLog[#window.dockLog].side == "right", "placements are noted for the game check")
	noErrors(T, "beside game windows")
end)

section("settings: advice and found places", function()
	local T = load(nil, checked())
	Stub.fire("MERCHANT_SHOW")
	slash("settings")
	check(not Stub.sees("Forget all") and Stub.sees("Window position"), "Settings opens on the Window section")
	Stub.click("Help and data")
	check(Stub.sees("Trailhead remembers 1 place you have found.") and not Stub.sees("Window position"), "settings count the found places")
	Stub.click("Forget all")
	check(T.Places.Count() == 1 and Stub.sees("Really forget?"), "forgetting asks once more")
	Stub.click("Really forget?")
	check(T.Places.Count() == 0 and Stub.sees("Trailhead remembers 0 places you have found."), "the second click forgets")
	T.Advisor.Dismiss(T.Advisor.Cards(1)[1])
	local fewer = cardIds(T)
	Stub.click("Bring back")
	check(cardIds(T) ~= fewer, "Bring back restores dismissed advice")
	Stub.click("Run check")
	check(T.db.probe.v == T.Probe.VERSION, "the check can be run from Settings")
	noErrors(T, "settings")
end)

section("guide: weapon skills and professions", function()
	local T = load(nil, checked())
	local G = T.Game
	local skills = G.Skills()
	check(skills.complete and #skills.weapons == 3 and skills.defense.rank == 66 and #skills.professions == 0,
		"weapon skills are read from the game's list, with Defense kept apart")
	check(skills.byId[136].rank == 61 and skills.byId[136].max == 70 and skills.byId[98] == nil, "ranks and limits are kept; languages are not")
	local hands = G.Hands(skills)
	check(#hands == 1 and hands[1].slot == 16 and hands[1].skill.name == "Staves" and hands[1].name == "Gnarled Staff",
		"the weapon in hand is matched to its skill")
	check(#G.WeaponsBehind() == 0 and not cardIds(T):find("weapon"), "a skill close to its limit raises nothing")

	slash("")
	Stub.click("Guide")
	Stub.flush()
	check(T.Window.current == "guide" and T.modules.guide.topic == "talents" and Stub.sees("WHERE YOU STAND"), "the Guide opens on its first topic")
	Stub.click("Weapon skills")
	Stub.flush()
	check(T.Window.current == "guide" and T.modules.guide.topic == "weapons" and Stub.sees("Weapon skills") and Stub.sees("WHAT IT IS") and Stub.sees("WHERE YOU STAND")
		and Stub.sees("WHAT TO DO NEXT"), "the Guide opens on weapon skills")
	check(Stub.sees("Staves") and Stub.sees("61 of 70") and Stub.sees("IN HAND") and Stub.sees("Defense") and Stub.sees("66 of 70") and Stub.sees("MAKES YOU HARDER TO HIT"), "each skill shows where it stands, the one in hand marked")
	local info = T.modules.guide.Read("weapons")
	check(info.rows[1].name == "Staves" and info.rows[2].name == "Unarmed" and info.rows[3].name == "Wands" and info.rows[4].name == "Defense"
		and info.attention == 0, "the weapon in hand comes first, then the rest by rank")
	check(info.next:find("in good shape", 1, true) ~= nil, "with nothing behind it says so")

	-- a new kind of weapon with no skill
	Stub.world.hands = { [16] = { 2092, 10, "Gnarled Staff" }, [18] = { 5069, 19, "Fire Wand" } }
	Stub.fire("PLAYER_EQUIPMENT_CHANGED", 18)
	Stub.flush()
	info = T.modules.guide.Read("weapons")
	check(info.attention == 1 and info.rows[1].name == "Staves" and info.rows[2].name == "Wands" and info.rows[2].tag == "In hand, low"
		and info.rows[2].tone == "warn", "a weapon in hand with a low skill is flagged")
	check(info.next:find("Your Wands skill is behind: 1 of 70. By the game's own figures that costs about 2.8% of your chance to hit and to crit an enemy of your level. Keep using it on enemies you beat easily until it catches up.", 1, true) == 1,
		"and the next step names it, with what it costs")
	check(info.next:find("is taught by a weapon master in a city, for about 10s 0c (polearms: level 20, 1g 0s).", 1, true) ~= nil
		and info.action.label == "Find a weapon master", "and it says where a new kind of weapon is learned")
	check(math.abs(G.SkillCost({ rank = 1, max = 70 }) - 2.76) < 0.001 and G.SkillCost({ rank = 61, max = 70, bonus = 9 }) == 0
		and G.SkillCost({ rank = 75, max = 70 }) == 0, "the cost is the game's own sum: 0.04% for each point under 5 a level")
	check(Stub.sees("1 of 70") and Stub.sees("IN HAND, LOW"), "the page follows a change of weapon")
	local cards = T.Advisor.Cards(20)
	local card
	for _, item in ipairs(cards) do
		if item.id == "weapon" then card = item end
	end
	check(card ~= nil and card.title == "Your Wands skill is low" and card.key == "weapon:228"
		and card.body == "1 of 70: about 2.8% less chance to hit and to crit.\nIt rises as you fight with that kind of weapon.",
		"Home gets a card for it")
	check(cardIds(T) == "talents,train,bars,weapon,dungeon", "it ranks after talents, training and bars")
	Stub.world.talents = false
	Stub.fire("TRAIT_CONFIG_UPDATED")
	T.Window:Select("home")
	Stub.flush()
	check(Stub.sees("Your Wands skill is low") and Stub.sees("Open guide"), "the card is on Home")
	card.run()
	Stub.flush()
	check(T.Window.current == "guide" and T.modules.guide.topic == "weapons" and Stub.sees("1 of 70"), "the card opens the Guide on weapon skills")

	-- a weapon whose skill the game does not list is left alone
	Stub.world.hands = { [16] = { 7005, 1, "Big Axe" } }
	check(#G.Hands() == 0 and #G.WeaponsBehind(1) == 0, "a weapon with no matching skill is not guessed at")
	Stub.world.hands = { [16] = { 7006, 13, "Brass Knuckles" } }
	check(#G.Hands() == 1 and G.Hands()[1].skill.name == "Unarmed", "fist weapons use the Unarmed skill, as in the game's own window")
	-- a small gap is marked on the page but does not reach Home
	Stub.world.hands = nil
	Stub.world.weapons = { { "Defense", 95, 66 }, { "Staves", 136, 40 } }
	check(T.modules.guide.Read("weapons").rows[1].tag == "In hand, low" and not cardIds(T):find("weapon"), "a skill 30 behind is marked low without a Home card")
	-- more skills than the page has room for
	Stub.world.weapons = { { "Defense", 95, 66 }, { "Staves", 136, 61 }, { "Axes", 44, 9 }, { "Bows", 45, 8 }, { "Guns", 46, 7 }, { "Maces", 54, 6 },
		{ "Swords", 43, 5 }, { "Daggers", 173, 4 }, { "Thrown", 176, 3 }, { "Polearms", 229, 2 }, { "Unarmed", 162, 1 } }
	info = T.modules.guide.Read("weapons")
	check(#info.rows == 9 and info.total == 11 and info.rows[1].name == "Staves" and info.rows[9].name == "Defense",
		"with many weapon skills the best ones and Defense are kept")
	T.modules.guide:Refresh()
	-- The page shows as many as fit above the advice, and Defense keeps its row.
	local fits
	for count = 2, 9 do
		fits = fits or (Stub.sees(("showing %d of 11"):format(count)) and count)
	end
	check(fits and Stub.sees("Defense") and Stub.sees("Staves") and not Stub.sees("Unarmed"),
		"and the page says it is not showing all of them, with Defense still on it")
	Stub.world.weapons = nil
	T.modules.guide:Refresh()
	check(not Stub.sees("showing 9 of 11"), "which goes away when they all fit")

	-- professions
	info = T.modules.guide.Read("professions")
	check(#info.rows == 0 and info.next == "You have no professions yet. Profession trainers in towns and cities teach them."
		and info.action.label == "Find a profession trainer", "with no professions it points at the trainers")
	Stub.world.professions = { { "Mining", 186, 40, 75 }, { "Herbalism", 182, 70, 75 } }
	Stub.world.secondary = { { "First Aid", 129, 66, 150 } }
	Stub.fire("SKILL_LINES_CHANGED")
	Stub.flush()
	info = T.modules.guide.Read("professions")
	check(#info.rows == 3 and info.rows[1].name == "Mining" and info.rows[2].tag == "Near its limit" and info.rows[3].name == "First Aid"
		and info.attention == 1, "each profession is listed once, the one near its limit flagged")
	check(info.next == "Herbalism is close to its limit: 70 of 75. A skill stops rising at its limit, so see its trainer for the next step.", "and the next step names it")
	Stub.world.secondary = { { "First Aid", 129, 66, 150 }, { "Lockpicking", 633, 69, 70 } }
	check(T.modules.guide.Read("professions").attention == 1 and T.modules.guide.Read("professions").rows[4].tag == nil,
		"lockpicking, whose limit follows your level, is not sent to a trainer")
	Stub.world.secondary = { { "First Aid", 129, 66, 150 } }
	Stub.click("Professions")
	Stub.flush()
	check(T.modules.guide.topic == "professions" and Stub.sees("Mining") and Stub.sees("40 of 75") and Stub.sees("NEAR ITS LIMIT"),
		"the Professions topic shows them")
	Stub.click("Find a profession trainer")
	Stub.flush()
	check(T.Window.current == "find" and T.modules.find.category == "professions", "its button opens Find it on profession trainers")

	-- the list not ready, or folded shut
	Stub.world.weaponsFolded = true
	info = T.modules.guide.Read("weapons")
	check(#info.rows == 0 and info.next:find("has not listed your skills yet", 1, true) ~= nil, "a folded list is not read as having no skills")
	Stub.world.weaponsFolded = nil
	Stub.world.noSkills = true
	check(G.Skills().complete == false and #G.WeaponsBehind() == 0, "no list at all raises nothing")
	Stub.world.noSkills = nil
	noErrors(T, "guide")

	-- the look a new player gets
	T = load({ look = "default" }, checked())
	slash("")
	T.Window:Select("guide", "weapons")
	Stub.flush()
	check(Stub.sees("WEAPON SKILLS") and Stub.sees("61 of 70") and Stub.sees("TALENTS"), "the Guide reads well in the default look")
	noErrors(T, "guide in the default look")
end)

section("guide: talents", function()
	local T = load(nil, checked())
	local G = T.Game
	local info = G.Talents()
	check(info ~= nil and #info.trees == 2 and info.trees[1].name == "Fire" and info.trees[2].name == "Frost", "the trees are read in the talent window's order")
	check(info.trees[2].spent == 2 and info.trees[2].total == 10 and info.trees[1].spent == 0 and info.spent == 2 and info.unspent == 1,
		"with the points in each and the points left to spend")
	local topic = T.modules.guide.Read("talents")
	check(#topic.rows == 2 and topic.rows[2].name == "Frost" and topic.rows[2].value == "2 points" and topic.rows[2].frac == 1
		and topic.rows[1].value == "0 points" and topic.rows[1].frac == 0, "each tree shows its points")
	check(topic.attention == 1 and topic.next == "You have 1 talent point to spend. Unspent points do nothing." and topic.action.label == "Open talents",
		"a point to spend is the next step")
	slash("")
	T.Window:Select("guide")
	Stub.flush()
	check(Stub.sees("Talents") and Stub.sees("Frost") and Stub.sees("2 points") and Stub.sees("You have 1 talent point to spend. Unspent points do nothing."),
		"the Talents topic is the first thing the Guide shows")
	Stub.click("Open talents")
	check(Stub.opened.talents == true, "its button opens the game's talent window")
	Stub.world.talentPoints = 3
	check(T.modules.guide.Read("talents").next == "You have 3 talent points to spend. Unspent points do nothing.", "several points are counted")
	Stub.world.talentPoints = nil

	-- all spent: the next point is only promised when this character's own count fits
	Stub.world.talents = false
	Stub.fire("TRAIT_CONFIG_UPDATED")
	Stub.flush()
	topic = T.modules.guide.Read("talents")
	check(topic.attention == 0 and topic.next == "All your talent points are spent.", "with everything spent it says so, and promises nothing it cannot check")
	Stub.world.level = 11
	topic = T.modules.guide.Read("talents")
	check(topic.next == "All 2 of your points are spent. You have had one for every level since 10, so the next comes at level 12.",
		"when the count fits one point a level it names the next level")
	Stub.world.level = 14

	-- the game says there are points but not how many
	Stub.world.talents = true
	Stub.world.noCurrency = true
	topic = T.modules.guide.Read("talents")
	check(topic.attention == 1 and topic.next == "You have talent points to spend. Unspent points do nothing.", "an unknown number of points is not counted")
	Stub.world.noCurrency = nil
	noErrors(T, "guide talents")

	T = load({ bare = true }, checked())
	check(T.Game.Talents() == nil and T.modules.guide.Read("talents").next == "The game has not listed your talents yet. Try again in a moment.",
		"a client without the talent APIs says so")
	noErrors(T, "guide talents on a bare client")
end)

section("builds: the rogue build and the talent helper", function()
	local ROGUE = { class = "ROGUE", level = 21 }
	local T = load(ROGUE, checked())
	local G, B = T.Game, T.BuildGuide
	local build = B.List()[1]
	check(#B.List() == 1 and build.id == "levelling" and B.Get("levelling") == build and B.Chosen() == nil, "a rogue has a build to choose, and none chosen yet")

	-- the shipped build, spent point by point on an empty copy of the real tree
	local steps, final = B.Steps(build)
	local recorded = {}
	for id, ranks in pairs(Stub.world.ranks) do
		recorded[id] = ranks
		Stub.world.ranks[id] = 0
	end
	Stub.world.talents, Stub.world.talentPoints = true, 1
	local broken
	for index, step in ipairs(steps) do
		local node = G.Talents().nodes[step.node]
		if not node or not node.available or node.rank + 1 ~= step.rank or step.rank > node.max then
			broken = broken or ("step " .. index .. " (" .. tostring(Stub.rogue.nodes[step.node] and Stub.rogue.nodes[step.node].name) .. ")")
			break
		end
		Stub.world.ranks[step.node] = step.rank
	end
	check(#steps == 51 and broken == nil, "the build is 51 points and the game would take every one in order" .. (broken and (": " .. broken) or ""))
	local info = G.Talents()
	check(info.trees[1].name == "Assassination" and info.trees[1].spent == 17 and info.trees[2].spent == 34 and info.trees[3].spent == 0,
		"it ends with 34 points in Combat and 17 in Assassination")
	local whole = true
	for nodeID, talent in pairs(build.talents) do
		local node = Stub.rogue.nodes[nodeID]
		whole = whole and node ~= nil and node.spell == talent.spell and type(talent.why) == "string" and #talent.why > 10 and final[nodeID] ~= nil
	end
	check(whole, "every talent in it is a real one with its reason written down")
	local progress = B.Progress(build)
	check(progress.finished and progress.next == nil and progress.done == 51 and #progress.after == 0 and #progress.fight == 5,
		"with every point placed the build is finished")
	slash("")
	T.Window:Select("builds")
	Stub.flush()
	check(Stub.sees("Build complete") and Stub.sees("51 of 51 points placed"), "and the page says so")

	-- the character game check 6 recorded: 12 points at level 21, one of them outside the build
	for id, ranks in pairs(recorded) do
		Stub.world.ranks[id] = ranks
	end
	Stub.world.talents, Stub.world.talentPoints = false, nil
	progress = B.Progress(build)
	check(progress.done == 11 and progress.total == 51 and progress.unspent == 0 and progress.nextLevel == 22, "the recorded character has 11 of its points in the build")
	check(progress.next.name == "Efficient Strikes" and progress.next.rank == 2 and progress.next.max == 2 and progress.next.locked == false
		and progress.next.why == build.talents[105741].why and progress.next.text == "Entry 1105741 at rank 2",
		"the next point is named with its rank, its reason and the game's own words for that rank")
	local tree = G.Talents()
	check(progress.next.tree == "Combat" and progress.next.row == 1 and G.TalentRow(tree, tree.nodes[105735]) == 3
		and G.TalentRow(tree, tree.nodes[105724]) == 7, "and with where it sits in the talent window: its tree and its row from the top")
	check(progress.after[1].name == "Coup de Grace" and progress.after[1].from == 2 and progress.after[1].to == 3 and progress.after[2].name == "Riposte"
		and progress.after[3].name == "Endurance", "the points after it follow, a run in one talent as one line")
	check(#progress.outside == 1 and progress.outside[1].name == "Composure" and progress.outsidePoints == 1, "a point outside the build is counted, not hidden")
	check(#progress.fight == 2, "fight advice only mentions abilities the character has")
	check(B.Following() == nil and cardIds(T):find("build", 1, true) ~= nil, "until a build is chosen Home offers one")

	Stub.fire("TRAIT_CONFIG_UPDATED")
	Stub.flush()
	check(Stub.sees("Easy levelling") and Stub.sees("11 of 51 points placed") and Stub.sees("Efficient Strikes") and Stub.sees("2 of 2")
		and Stub.sees("comes at level 22") and Stub.sees("The game says: Entry 1105741 at rank 2") and Stub.sees("Combat, row 1 from the top"), "the Builds page shows the next point")
	check(Stub.sees("Coup de Grace") and Stub.sees("2 to 3 of 3") and Stub.sees("Riposte") and Stub.sees("1 of 1"), "and what comes after")
	check(Stub.sees("1 point outside this build (Composure). Nothing is lost: carry on from here.") and Stub.sees("DRAFT"),
		"with the point outside it and the draft mark")
	Stub.click("Follow this build")
	Stub.flush()
	check(TrailheadCharDB.build == "levelling" and B.Chosen() == build and Stub.sees("Stop following") and Stub.sees("FOLLOWING"), "the build can be followed")
	check(B.Following() ~= nil and not cardIds(T):find("build", 1, true), "and Home stops offering one")
	local topic = T.modules.guide.Read("talents")
	check(topic.next:find("Next in your build: Efficient Strikes (2 of 2).", 1, true) ~= nil, "the Guide's Talents topic names the next point too")
	Stub.click("Open talents")
	check(Stub.opened.talents == true, "Open talents opens the game's talent window")
	check(TrailheadWindow:IsShown() and PlayerSpellsFrame:IsShown() and T.Window:IsBeside() == "PlayerSpellsFrame" and Stub.sees("Efficient Strikes"),
		"and Trailhead stays up beside it, though the game closes other windows for the talents")
	local listed = 0
	for _, name in ipairs(UISpecialFrames) do
		listed = listed + (name == "TrailheadWindow" and 1 or 0)
	end
	Stub.closeSpecial()
	check(listed == 1 and not TrailheadWindow:IsShown(), "Escape still closes Trailhead afterwards")
	slash("")
	T.Window:Select("builds")
	Stub.flush()
	Stub.click("Open talents")
	check(PlayerSpellsFrame:IsShown() and TrailheadWindow:IsShown(), "pressing Open talents with the talents already open leaves them open")
	PlayerSpellsFrame:Hide()
	Stub.flush()

	-- a new level brings a point
	Stub.world.level, Stub.world.talents, Stub.world.talentPoints = 22, true, 1
	Stub.fire("PLAYER_LEVEL_UP", 22)
	Stub.flush()
	check(Stub.sees("you have 1 point to spend"), "a point to spend is announced on the page")
	local card
	for _, item in ipairs(T.Advisor.Cards(20)) do
		card = item.id == "talents" and item or card
	end
	check(card and card.body == "Next in your build: Efficient Strikes (2 of 2).\nUnspent points do nothing.", "and the Home card says where it goes")
	Stub.world.ranks[105741], Stub.world.talents, Stub.world.talentPoints = 2, false, nil
	Stub.fire("TRAIT_CONFIG_UPDATED")
	Stub.flush()
	check(Stub.sees("12 of 51 points placed") and Stub.sees("2 of 3") and Stub.sees("comes at level 23") and not Stub.sees("2 of 2"),
		"spending it moves the page on to the next point")

	-- in combat nothing is read
	Stub.combat = true
	check(B.Following() == nil, "in combat the build is left alone")
	Stub.combat = false

	-- the game changes a talent the build uses
	Stub.world.spellChanged = 105741
	check(B.Progress(build).problem == "changed" and B.Following() == nil, "a talent that no longer matches stops every suggestion")
	Stub.fire("TRAIT_CONFIG_UPDATED")
	Stub.flush()
	check(Stub.sees("The game's talents have changed since this build was written, so Trailhead will not suggest points from it. An update will bring it back."),
		"and the page says why")
	Stub.world.spellChanged = nil
	Stub.fire("TRAIT_CONFIG_UPDATED")
	Stub.flush()
	Stub.click("Stop following")
	Stub.flush()
	check(TrailheadCharDB.build == nil and Stub.sees("Follow this build"), "the build can be dropped again")
	noErrors(T, "builds")

	-- the look a new player gets
	T = load({ class = "ROGUE", level = 21, look = "default" }, checked())
	slash("")
	T.Window:Select("builds")
	Stub.flush()
	check(Stub.sees("EASY LEVELLING") and Stub.sees("FOLLOW THIS BUILD") and Stub.sees("NEXT POINT") and Stub.sees("IN A FIGHT"), "the page reads the same in the default look")
	noErrors(T, "builds in the default look")

	-- a class that has no builds written (none left today, so take the mage's away)
	T = load({ class = "MAGE" }, checked())
	T.Builds.MAGE = nil
	check(#T.BuildGuide.List() == 0 and T.BuildGuide.Following() == nil and not T.BuildGuide.Usable() and not cardIds(T):find("build", 1, true),
		"a class without a build is offered none")
	slash("")
	T.Window:Select("builds")
	Stub.flush()
	check(Stub.sees("No build for your class yet") and not Stub.sees("Follow this build"), "and the Builds page says so")
	T.BuildGuide.Choose("levelling")
	check(TrailheadCharDB.build == nil, "a build that is not in the class's list cannot be chosen")
	noErrors(T, "builds for a class without one")

	-- the made-up talent tree of the default character matches no build: nothing is offered
	-- and nothing is suggested, rather than a point that might be wrong
	T = load(nil, checked())
	check(#T.BuildGuide.List() == 1 and T.BuildGuide.Progress(T.BuildGuide.List()[1]).problem == "changed" and not T.BuildGuide.Usable()
		and not cardIds(T):find("build", 1, true), "a tree that does not match the build is not offered on Home")
	slash("")
	T.Window:Select("builds")
	Stub.flush()
	check(Stub.sees("The game's talents have changed since this build was written, so Trailhead will not suggest points from it. An update will bring it back.")
		and not Stub.sees("Follow this build"),
		"and the Builds page says it cannot suggest points")
	T.BuildGuide.Open()
	check(Stub.opened.talents == true and T.Window.current == "builds", "Open talents still opens the game's window")
	noErrors(T, "builds with a talent tree that does not match")

	T = load({ bare = true }, checked())
	slash("")
	T.Window:Select("builds")
	Stub.flush()
	noErrors(T, "builds on a bare client")
end)

section("guide: coming up", function()
	local list = {}
	for _, service in ipairs({
		{ "Frostbolt", "Rank 4", "used", 14, 900 }, { "Cone of Cold", "Rank 1", "available", 14, 1800 },
		{ "Flamestrike", "Rank 1", "unavailable", 16, 3000 }, { "Evocation", nil, "unavailable", 20, 5000 },
		{ "Frost Ward", "Rank 1", "unavailable", 22, 6000 }, { "Blink", nil, "unavailable", 22, 400000 },
		{ "Mana Shield", "Rank 1", "available", 22, 100 }, { "Scorch", "Rank 1", "unavailable", 22, 100 },
	}) do
		list[#list + 1] = { n = service[1], s = service[2], t = service[3], l = service[4], c = service[5] }
	end
	local T = load(nil, checked(), { trainer = { at = 1, level = 14, full = true, list = list } })
	local info = T.modules.guide.Read("levels")
	check(info.attention == 0 and info.rows[1].name == "Level 16" and info.rows[1].text == "Trainer: Flamestrike", "the next level with something new comes first")
	check(info.rows[2].name == "Level 17" and info.rows[2].text == "Dungeon: Deadmines", "a dungeon appears at the level the group finder gives it")
	local byName = {}
	for _, item in ipairs(info.rows) do
		byName[item.name] = item.text
	end
	check(byName["Level 22"] == "Trainer: Blink, Frost Ward and 2 more. Dungeon: The Stockade", "abilities, dungeons and zones of one level share a line")
	check(byName["Level 18"] ~= nil and byName["Level 18"]:find("Zone: Duskwood", 1, true) ~= nil and byName["Level 14"] == nil and byName["Level 13"] == nil,
		"zones are listed too, and nothing at or under your own level")
	check(info.next == "You are 62% of the way to level 15. At level 16 your trainer has Flamestrike for you, 30s 0c in all. You have enough for that already.",
		"the next step says how far the next level is, what the trainer will have and what it costs")
	slash("")
	T.Window:Select("guide", "levels")
	Stub.flush()
	check(Stub.sees("Coming up") and Stub.sees("Level 16") and Stub.sees("Trainer: Flamestrike") and Stub.sees("Dungeon: Deadmines"), "the page shows the levels as plain lines")
	Stub.world.level = 21
	T.Game.SpellsChanged()
	info = T.modules.guide.Read("levels")
	check(info.rows[1].name == "Level 22" and info.next:find("At level 22 your trainer has Blink, Frost Ward, Mana Shield and 1 more for you, 40g 62s in all. You have 34g 12s, so keep some aside.", 1, true) ~= nil,
		"a level that costs more than you carry says so")
	Stub.world.level = 60
	check(#T.modules.guide.Read("levels").rows == 0 and T.modules.guide.Read("levels").next == "You are at the top level. Nothing more unlocks by levelling.",
		"at the top level there is nothing to list")
	noErrors(T, "guide coming up")

	T = load(nil, checked())
	info = T.modules.guide.Read("levels")
	local deadmines
	for _, row in ipairs(info.rows) do
		deadmines = deadmines or (row.text == "Dungeon: Deadmines" and row)
	end
	check(info.next:find("Visit your class trainer once", 1, true) ~= nil and info.action.label == "Find your trainer" and deadmines ~= nil,
		"before the first trainer visit it asks for one, and still lists dungeons")
	noErrors(T, "guide coming up without a trainer visit")
	T = load({ bare = true }, checked())
	check(type(T.modules.guide.Read("levels").next) == "string", "a bare client still gets an answer")
	noErrors(T, "guide coming up on a bare client")
end)

section("guide: inns and rest", function()
	local T = load(nil, checked())
	local guide = T.modules.guide
	local function rows(info)
		local by = {}
		for _, item in ipairs(info.rows) do
			by[item.name] = item.text
		end
		return by
	end
	local info = guide.Read("rest")
	local by = rows(info)
	check(by["Home"] == "Goldshire" and by["Hearthstone"] == "Ready", "it names your home and says the hearthstone is ready")
	check(by["Rest"] == "Rested: 200% of normal experience from monsters" and by["Bonus left"] == "2100 more experience from monsters at that rate",
		"the rest state and the bonus left are the game's own figures")
	check(by["Right now"] == "Out in the world" and info.attention == 0 and info.action.label == "Find an inn"
		and info.next:find("You are rested", 1, true) == 1, "out in the world and rested: it says to log out in an inn")

	Stub.world.stoneCooldown = { 900, 1900 }
	check(rows(guide.Read("rest"))["Hearthstone"] == "Ready in 30 minutes", "a hearthstone on cooldown says how long is left")
	Stub.world.stoneCooldown = { 900, 130 }
	check(rows(guide.Read("rest"))["Hearthstone"] == "Ready in 1 minute", "the last minute reads as one minute")
	Stub.world.stoneCooldown = { 100, 600 }
	check(rows(guide.Read("rest"))["Hearthstone"] == "Ready", "a cooldown that has run out is ready")
	Stub.world.stoneCooldown = nil
	Stub.world.stones = 0
	check(rows(guide.Read("rest"))["Hearthstone"] == "Not in your bags", "a missing hearthstone is said so")
	Stub.world.stones = nil

	Stub.world.rest, Stub.world.rested = { 2, "Normal", 1 }, 0
	info = guide.Read("rest")
	by = rows(info)
	check(by["Rest"] == "Normal: 100% of normal experience from monsters" and by["Bonus left"] == nil and info.next:find("You are not rested", 1, true) == 1,
		"not rested: no bonus line, and the advice is to log out in an inn or city")
	Stub.world.resting = true
	info = guide.Read("rest")
	check(rows(info)["Right now"] == "In an inn or a city: your rest is building up" and info.action == nil
		and info.next:find("Log out here", 1, true) ~= nil, "in an inn it says rest is building and to log out here")
	Stub.world.resting = nil

	Stub.world.bind = nil
	info = guide.Read("rest")
	check(rows(info)["Home"] == "None yet" and info.attention == 1 and info.action.label == "Find an inn"
		and info.next == "Your hearthstone has no home. Ask an innkeeper to make their inn your home.", "no home: it sends you to an innkeeper")
	slash("")
	T.Window:Select("guide", "rest")
	Stub.flush()
	check(Stub.sees("Inns and rest") and Stub.sees("Hearthstone") and Stub.sees("None yet"), "the page shows the topic")
	Stub.click("Find an inn")
	Stub.flush()
	check(T.Window.current == "find" and T.modules.find.category == "inn", "Find an inn opens Find it on inns")
	noErrors(T, "guide inns and rest")

	T = load({ bare = true }, checked())
	info = T.modules.guide.Read("rest")
	check(type(info.next) == "string" and info.attention == 0, "a bare client still gets an answer, with no false alarm about a home")
	noErrors(T, "guide inns and rest on a bare client")
end)

section("guide: supplies", function()
	local T = load(nil, checked())
	local guide = T.modules.guide
	local info = guide.Read("supplies")
	check(info.attention == 1 and info.rows[1].name == "Food and drink" and info.rows[1].text == "None" and info.rows[1].tone == "warn"
		and info.next == "You carry no food or drink. Buy some before you leave town." and info.action.label == "Find a vendor",
		"empty bags: it warns about food and offers a vendor")
	Stub.world.carried = {
		{ 4540, 5, "Tough Hunk of Bread", 0, 5, "Food & Drink" },
		{ 13754, 4, "Snapvine Watermelon", 0, 5, "Food & Drink", "Use: Restores 874 health over 27 sec.  Must remain seated while eating." },
		{ 13754, 8, "Snapvine Watermelon", 0, 5, "Food & Drink", "Use: Restores 874 health over 27 sec.  Must remain seated while eating." },
		{ 2581, 21, "Heavy Linen Bandage", 0, 7, "Bandages" },
		{ 5060, 1, "Thieves' Tools", 15, 1, "Reagent" },
	}
	info = guide.Read("supplies")
	check(info.attention == 0 and info.rows[1].name == "Food & Drink" and info.rows[1].text == "17, mostly Snapvine Watermelon",
		"food is counted across stacks, named by the game's own word and by the item there is most of")
	check(info.rows[2].name == "Bandages" and info.rows[2].text == "21, mostly Heavy Linen Bandage" and info.rows[3].name == "Potions"
		and info.rows[3].text == "None", "bandages and potions are counted, and other items are left out")
	check(info.next:find("Snapvine Watermelon, in the game's words: Use: Restores 874 health over 27 sec. Must remain seated while eating.", 1, true) ~= nil
		and info.action == nil, "what the food does is quoted from its own tooltip")
	slash("")
	T.Window:Select("guide", "supplies")
	Stub.flush()
	check(Stub.sees("Supplies") and Stub.sees("17, mostly Snapvine Watermelon") and Stub.sees("Bandages"), "the page shows the counts")
	Stub.world.carried = nil
	Stub.fire("BAG_UPDATE_DELAYED")
	Stub.flush()
	check(Stub.sees("You carry no food or drink. Buy some before you leave town."), "the page follows the bags as they change")
	Stub.click("Find a vendor")
	Stub.flush()
	check(T.Window.current == "find" and T.modules.find.category == "vendor", "Find a vendor opens Find it on vendors")
	noErrors(T, "guide supplies")

	T = load({ bare = true }, checked())
	info = T.modules.guide.Read("supplies")
	check(info.attention == 0 and #info.rows == 0 and info.next:find("has not listed your bags", 1, true) ~= nil, "a bare client raises no false alarm")
	noErrors(T, "guide supplies on a bare client")
end)

section("known places: weapon masters and riding trainers", function()
	local T = load({ class = "ROGUE", level = 21 }, checked())
	local world, P = Stub.world, T.Places
	world.race, world.faction = { "Orc", "Orc" }, "Horde"
	world.map, world.x, world.y = 1454, 0.5, 0.5
	local function names(list)
		local out = {}
		for _, item in ipairs(list) do
			out[#out + 1] = item.title
		end
		return table.concat(out, ",")
	end
	local found = P.Find("weapons")
	check(names(found) == "Hanashi,Sayoc,Ansekhwa,Archibald", "a Horde character sees the Horde weapon masters, the ones in this city first")
	check(found[1].here == true and found[1].where == "Orgrimmar" and found[1].note == "axes, bows, staves, thrown" and found[1].map == 1454
		and found[1].x == 0.815, "each says where it is and what it teaches")
	check(names(P.Find("riding")) == "Kildar,Ogunaro Wolfrunner", "riding shows the character's own race only")
	world.race = { "Goblin", "Goblin" }
	check(#P.Find("riding") == 9, "a race that is not listed sees every trainer of its side")
	world.race, world.faction = { "Human", "Human" }, "Alliance"
	check(names(P.Find("riding")) == "Katie Hunter,Randal Hunter" and names(P.Find("weapons")):find("Woo Ping", 1, true) ~= nil
		and names(P.Find("weapons")):find("Sayoc", 1, true) == nil, "the Alliance sees its own")
	world.race, world.faction = { "Orc", "Orc" }, "Horde"
	check(names(P.Search("sayoc")) == "Sayoc" and names(P.Search("weapon master")):find("Weapon master", 1, true) == 1
		and names(P.Search("polearms")) == "Archibald", "they are found by name, by kind and by what they teach")
	P.Remember("weapons", "Sayoc", 1454, 0.812, 0.199, "seen")
	found = P.Find("weapons")
	check(names(found) == "Sayoc,Ansekhwa,Archibald" and found[1].note == "You have been here", "a place you have seen yourself replaces the guide's entry at that spot")
	check(P.GuessCategory({ "The weapon master" }) == "weapons", "a guard's weapon master goes under weapon masters")
	slash("")
	T.Window:Select("find", "weapons")
	Stub.flush()
	check(Stub.sees("Weapon master") and Stub.sees("Ansekhwa") and Stub.sees("Thunder Bluff  \194\183  guns, maces, staves"), "Find it lists them")
	Stub.click("Riding trainer")
	Stub.flush()
	check(T.modules.find.category == "riding" and Stub.sees("Kildar") and Stub.sees("Orgrimmar  \194\183  Riding trainer"), "and the riding trainer has its own button")
	local pillRows, pills = T.modules.find.Layout()
	local shown = 0
	for _, category in ipairs(T.Categories) do
		shown = shown + (category.hidden and 0 or 1)
	end
	check(pills == shown and pillRows >= 2 and pillRows <= 3, "every kind has a button, wrapped onto further rows")
	noErrors(T, "known places")
	T = load({ bare = true }, checked())
	check(type(T.Places.Find("weapons")) == "table" and type(T.Places.Find("riding")) == "table", "a bare client still answers")
	noErrors(T, "known places on a bare client")
end)

section("guide: mount and dying", function()
	local T = load({ class = "ROGUE", level = 21 }, checked())
	local world, guide = Stub.world, T.modules.guide
	world.race, world.faction, world.money = { "Orc", "Orc" }, "Horde", 38747
	world.mounts = { { 14, "Timber Wolf", 580, false, "" } }
	local function rows(info)
		local by = {}
		for _, item in ipairs(info.rows) do
			by[item.name] = item
		end
		return by
	end
	local info = guide.Read("mount")
	local by = rows(info)
	check(info.what:find("From level 40 you can learn to ride.", 1, true) == 1 and info.what:find("for 100g 0s", 1, true) ~= nil
		and info.what:find("60% faster", 1, true) ~= nil, "it says when riding comes and what it costs")
	check(by["You can ride"].text == "At level 40: 19 levels to go" and by["Riding costs"].text == "100g 0s" and by["You have"].text == "3g 87s"
		and by["You have"].tone == nil, "your level and your money are set against it")
	check(by["Your trainer"].text == "Kildar, Orgrimmar" and by["Mount vendor"].text == "Ogunaro Wolfrunner, Orgrimmar" and by["Your mounts"].text == "None yet",
		"your own race's trainer and vendor are named")
	check(info.attention == 0 and info.next:find("Riding is the big cost of levelling: 100g 0s at level 40. You have 3g 87s so far.", 1, true) == 1
		and info.action.label == "Find the riding trainer", "under level 40 it says to save")
	world.money = 1500000
	check(guide.Read("mount").next == "You already have the 100g 0s for riding. Keep it aside until level 40.", "with the money in hand it says to keep it")
	world.level, world.money = 40, 600000
	T.Game.SpellsChanged()
	info = guide.Read("mount")
	check(info.attention == 1 and rows(info)["You can ride"].text == "Now" and rows(info)["You have"].tone == "warn"
		and info.next == "You can learn to ride now. Go to Kildar in Orgrimmar. You are 40g 0s short of the fee.", "at level 40 it sends you to the trainer and says what is missing")
	world.mounts[1][6] = true
	info = guide.Read("mount")
	check(info.attention == 0 and rows(info)["Your mounts"].text == "1" and info.next == "You have a mount. The faster lesson comes at level 60, for 1000g 0s.",
		"with a mount it looks ahead to the faster lesson")
	slash("")
	T.Window:Select("guide", "mount")
	Stub.flush()
	check(Stub.sees("Mount") and Stub.sees("Kildar, Orgrimmar"), "the page shows the topic")

	world.dead, world.durability = nil, { [5] = { 65, 65 } }
	info = guide.Read("dying")
	check(info.attention == 0 and rows(info)["Right now"].text == "Alive" and rows(info)["Your gear"].text == "At full durability"
		and info.next:find("If you die: release, run back to your body", 1, true) == 1 and info.action == nil, "alive and well: it says what to do if it happens")
	world.dead = "dead"
	check(guide.Read("dying").attention == 1 and guide.Read("dying").next:find("Release your spirit", 1, true) == 1, "dead: release")
	world.dead = "ghost"
	info = guide.Read("dying")
	check(info.attention == 1 and rows(info)["Right now"].text == "You are a ghost" and info.next:find("Your body is marked on the minimap", 1, true) == 1,
		"a ghost is told to run to the body")
	Stub.fire("PLAYER_UNGHOST")
	world.dead, world.sick, world.durability[5] = nil, true, { 10, 65 }
	info = guide.Read("dying")
	check(info.attention == 1 and rows(info)["Right now"].text == "Alive, with Resurrection Sickness" and rows(info)["Your gear"].tone == "warn"
		and info.next:find("You have Resurrection Sickness.", 1, true) == 1 and info.action.label == "Find repair", "after the Spirit Healer it says to wait and repair")
	T.Window:Select("guide", "dying")
	Stub.flush()
	check(Stub.sees("Dying") and Stub.sees("Alive, with Resurrection Sickness"), "the page shows the topic")
	noErrors(T, "guide mount and dying")

	T = load({ class = "PALADIN" }, checked())
	noErrors(T, "paladin load")
	T = load({ bare = true }, checked())
	check(type(T.modules.guide.Read("mount").next) == "string" and T.modules.guide.Read("mount").attention == 0
		and T.modules.guide.Read("dying").attention == 0, "a bare client still gets an answer")
	noErrors(T, "guide mount and dying on a bare client")
end)

section("guide: gear", function()
	local T = load({ class = "ROGUE", level = 21 }, checked())
	local guide = T.modules.guide
	local world = Stub.world
	local function rows(info)
		local by = {}
		for _, item in ipairs(info.rows) do
			by[item.name] = item
		end
		return by
	end
	world.armor = { "Cloth", "Leather" }
	world.worn = {
		[3] = { 1793, "Patched Leather Shoulderpads", 4, 2, "Leather" }, [5] = { 9757, "Nomad Tunic", 4, 2, "Leather" },
		[7] = { 15117, "Rigid Leggings", 4, 2, "Leather" }, [8] = { 4788, "Agile Boots", 4, 1, "Cloth" },
		[11] = { 5351, "Bounty Hunter's Ring", 4, 0, "Miscellaneous" }, [15] = { 2316, "Dark Leather Cloak", 4, 1, "Cloth" },
		[4] = { 5107, "Deckhand's Shirt", 4, 0, "Miscellaneous" }, [10] = { 777, "Festive Mittens", 4, 0, "Miscellaneous" },
	}
	world.durability = { [3] = { 40, 40 }, [5] = { 65, 65 }, [7] = { 60, 60 }, [8] = { 35, 35 } }
	local info = guide.Read("gear")
	local by = rows(info)
	check(by["You can wear"].text == "Cloth, Leather", "the kinds of armor come from the game's skill list")
	check(by["You wear"].text == "3 Leather, 1 Cloth", "worn armor is counted by the game's own label; cloak, shirt, rings and pieces of no armor kind aside")
	check(by["Empty slots"].text == "Head, Neck, Wrist, Waist, Finger, Trinket", "empty slots are named once each, in the game's words")
	check(by["Condition"].text == "Everything is at full durability" and info.attention == 0 and info.action == nil
		and info.next == "Everything you wear is at full durability. Nothing to repair.", "full durability asks for nothing")
	world.durability[7] = { 30, 60 }
	info = guide.Read("gear")
	check(rows(info)["Condition"].text == "Lowest: Rigid Leggings, at 50%" and rows(info)["Condition"].tone == nil and info.attention == 0
		and info.next == "Nothing needs repair yet. Rigid Leggings is the most worn, at 50% durability." and info.action.label == "Find repair",
		"some wear names the most worn piece without alarm")
	world.durability[7] = { 12, 60 }
	info = guide.Read("gear")
	check(rows(info)["Condition"].tone == "warn" and info.attention == 1
		and info.next == "Rigid Leggings is down to 20% durability. Have it repaired before it breaks.", "a nearly broken piece is flagged")
	world.durability[7] = { 0, 60 }
	info = guide.Read("gear")
	check(info.attention == 1 and info.next == "Rigid Leggings is broken. A vendor who does repairs can fix it.", "a broken piece says so")
	slash("")
	T.Window:Select("guide", "gear")
	Stub.flush()
	check(Stub.sees("Gear") and Stub.sees("3 Leather, 1 Cloth") and Stub.sees("Lowest: Rigid Leggings, at 0%"), "the page shows the topic")
	world.durability[7] = { 60, 60 }
	Stub.fire("UPDATE_INVENTORY_DURABILITY")
	Stub.flush()
	check(Stub.sees("Everything is at full durability"), "the page follows a repair")
	world.durability[7] = { 0, 60 }
	Stub.fire("UPDATE_INVENTORY_DURABILITY")
	Stub.flush()
	Stub.click("Find repair")
	Stub.flush()
	check(T.Window.current == "find" and T.modules.find.category == "repair", "Find repair opens Find it on repairs")

	world.armorFolded = true
	check(rows(guide.Read("gear"))["You can wear"].text:find("Armor Proficiencies", 1, true) ~= nil, "a folded heading is not read as no armor")
	world.armorFolded, world.worn, world.durability = nil, nil, { [1] = { Stub.SECRET, Stub.SECRET }, [2] = { 0, 0 }, [3] = { 0, 0 } }
	info = guide.Read("gear")
	check(rows(info)["You wear"] == nil and rows(info)["Condition"].text == "Nothing you wear can break" and info.attention == 0,
		"nothing readable raises no alarm")
	noErrors(T, "guide gear")

	T = load({ bare = true }, checked())
	info = T.modules.guide.Read("gear")
	check(info.attention == 0 and #info.rows == 0 and type(info.next) == "string", "a bare client raises no false alarm")
	noErrors(T, "guide gear on a bare client")
end)

section("game check: words, mounts, ability tooltips and guard menus", function()
	local T = load()
	local world = Stub.world
	world.mounts = { { 14, "Timber Wolf", 580, false, "|cffffd200Vendor:|r Ogunaro Wolfrunner\n|cffffd200Zone:|r Orgrimmar" } }
	world.spellTips = { [116] = { "Frostbolt", "25 Mana / Reagents: Rune of Frost" } }
	world.npc = "Orgrimmar Grunt"
	world.said = "What are you looking for?"
	world.gossip = {}
	for index, name in ipairs({ "Bank", "Wind Rider Master", "Weapon Master", "Stable Master", "Class Trainer" }) do
		world.gossip[index] = { gossipOptionID = 300 + index, name = name, orderIndex = index - 1, icon = 132060 }
	end
	Stub.fire("GOSSIP_SHOW")
	check(#T.db.visits == 1 and T.db.visits[1].kind == "menu" and T.db.visits[1].npc == "Orgrimmar Grunt" and T.db.visits[1].count == 5
		and T.db.visits[1].rows[3] == "Weapon Master|132060" and T.db.visits[1].said == "What are you looking for?",
		"a guard's menu is written down choice by choice")
	world.gossip = { { name = "Mage", gossipOptionID = 1 }, { name = "Rogue", gossipOptionID = 2 }, { name = "Hunter", gossipOptionID = 3 }, { name = "Warrior", gossipOptionID = 4 } }
	Stub.fire("GOSSIP_SHOW")
	Stub.fire("GOSSIP_SHOW")
	check(#T.db.visits == 2 and T.db.visits[2].rows[2] == "Rogue|" and T.db.visits[1].rows[1] == "Bank|132060", "a second menu is kept beside the first, once")
	world.gossip = { { name = "Make this inn your home.", gossipOptionID = 9 }, { name = "Let me browse your goods.", gossipOptionID = 10 } }
	Stub.fire("GOSSIP_SHOW")
	check(#T.db.visits == 2, "a short menu is not written down")
	slash("check")
	local r = T.db.probe.report
	check(T.db.probe.failed == 0 and r.words.list.TUTORIAL1 == "Quest givers have an exclamation mark over their heads."
		and r.words.list.NEWBIE_TOOLTIP_XPBAR ~= nil and r.words.list.REPAIR_COST == "Repair Cost:" and r.words.list.HEADSLOT == nil
		and r.words.cut == false, "the game's own tutorial and help texts are recorded, and only those")
	check(r.mounts.count == 1 and r.mounts.rows[1] == "14|Timber Wolf|580|false|2|true|0|false|false|230|/cffffd200Vendor:/r Ogunaro Wolfrunner /cffffd200Zone:/r Orgrimmar|A sturdy wolf.",
		"each mount is recorded with where the game says it comes from")
	local tips = {}
	for _, line in ipairs(r.spelltips.rows) do
		tips[#tips + 1] = line
	end
	check(table.concat(tips, ";"):find("Frostbolt|116|Frostbolt / 25 Mana / Reagents: Rune of Frost", 1, true) ~= nil, "the top of each ability's tooltip is recorded")
	check(#r.visits == 2 and r.visits[1].kind == "menu", "and the menus are in the report")
	noErrors(T, "game check 8")
	T = load({ bare = true })
	Stub.fire("GOSSIP_SHOW")
	slash("check")
	r = T.db.probe.report
	check(T.db.probe.failed == 0 and T.db.visits == nil and #r.mounts.rows == 0 and #r.spelltips.rows == 0, "a bare client records nothing and fails nothing")
	noErrors(T, "game check 8 on a bare client")
end)

section("game check: rest, bags and visits", function()
	local T = load()
	Stub.world.carried = { { 4540, 5, "Tough Hunk of Bread", 0, 5 } }
	Stub.world.npc = "Ogunaro Wolfrunner"
	Stub.world.merchant = { { "Horn of the Dire Wolf", 800000, 1, 5665, "Requires Level 40" }, { "Horn of the Timber Wolf", 800000, 1, 1132, "Requires Level 40" } }
	Stub.fire("MERCHANT_SHOW")
	Stub.flush()
	check(#T.db.visits == 1 and T.db.visits[1].kind == "vendor" and T.db.visits[1].npc == "Ogunaro Wolfrunner"
		and T.db.visits[1].rows[1] == "Horn of the Dire Wolf|800000|1|5665|15|5|Miscellaneous|Mount|true|Horn of the Dire Wolf / Requires Level 40",
		"a vendor's list is written down with prices and what the game says each item needs")
	Stub.fire("MERCHANT_SHOW")
	Stub.flush()
	check(#T.db.visits == 1, "the same vendor twice is kept once")
	Stub.world.merchant = nil
	visit("Jennea Cannon", MAGE_TRAINER)
	leave()
	check(#T.db.visits == 2 and T.db.visits[2].kind == "trainer" and T.db.visits[2].rows[2] == "Arcane Missiles|Rank 2|available|14|1200|Frost",
		"a trainer's list is written down with levels and prices")
	for index = 1, 20 do
		Stub.world.npc, Stub.world.merchant = "Vendor " .. index, { { "Bread", 25, 5, 4540 } }
		Stub.fire("MERCHANT_SHOW")
		Stub.flush()
	end
	check(#T.db.visits == 16 and T.db.visits[16].npc == "Vendor 20", "only the last few visits are kept")
	slash("check")
	local r = T.db.probe.report
	check(T.db.probe.failed == 0 and r.rest.state[2] == "Rested" and r.rest.state[3] == 2 and r.rest.rested == 2100 and r.rest.bind == "Goldshire"
		and r.rest.stone.count == 1 and r.rest.stone.text == "Hearthstone / Use: Returns you to your inn.", "rest and the hearthstone are recorded")
	check(r.bags.count == 1 and r.bags.items[1] == "0|1|4540|5|Tough Hunk of Bread|0|5|Consumable|Food & Drink|" and #r.bags.worn == 1
		and r.bags.worn[1]:find("^16|2092|Gnarled Staff|2|10|") ~= nil, "what is carried and worn is recorded the way the game files it")
	check(#r.visits == 16 and r.visits[16].npc == "Vendor 20", "and the visits are in the report")
	noErrors(T, "game check 7")
	T = load({ bare = true })
	Stub.fire("MERCHANT_SHOW")
	Stub.fire("TRAINER_SHOW")
	Stub.flush()
	slash("check")
	check(T.db.probe.failed == 0 and T.db.visits == nil, "a bare client records nothing and fails nothing")
	noErrors(T, "game check 7 on a bare client")
end)

section("game check", function()
	local T = load()
	visit("Jennea Cannon", MAGE_TRAINER)
	leave()
	check(not T.Probe:IsCurrent(), "not current before it has run")
	slash("check")
	local probe = T.db.probe
	check(type(probe) == "table" and probe.failed == 0 and probe.v == T.Probe.VERSION and T.Probe:IsCurrent(), "check ran with no failed sections")
	local r = probe.report
	for _, name in ipairs({ "build", "player", "apis", "character", "map", "zones", "taxi", "dungeons",
		"tracking", "spellbook", "talents", "skills", "rest", "bags", "visits", "words", "mounts", "spelltips", "routes", "groupFinder", "learned" }) do
		check(type(r[name]) == "table" and r[name].error == nil, "section " .. name)
	end
	check(r.build.toc == 16001 and r.player.class == "MAGE", "build and class recorded")
	check(r.talents.config == 77 and r.talents.tree == 900 and r.talents.nodeCount == 2 and r.talents.groups[1].displayName == "Frost",
		"the talent tree is found the way the game's window finds it")
	check(r.talents.nodes[1] == "1|600|1200|5|2|31|116|Frostbolt|true|true|0|2||1" and r.talents.nodes[2] == "2|1200|1200|5|0|31||Ice / Shards|false|true|0||9001|1",
		"one packed row per talent, with its spell, ranks, links and cost")
	check(r.talents.gates[1] == "2|9001|5|3820|false|1|" and r.talents.treeInfo.ID == 900, "the points each row of the tree needs are recorded")
	check(r.talents.descriptions[116] == "Launches a bolt of frost." and r.talents.descriptionsMissing == 0, "with each talent's own text")
	check(r.talents.texts[1].first == "Entry 501 at rank 1" and r.talents.texts[1].full == "Entry 501 at rank 5" and r.talents.texts[2].first == "Entry 502 at rank 1",
		"and its tooltip text at the first and the last rank, read the way the game's talent button reads it")
	check(#r.talents.conditions == 1 and r.talents.conditions[1] == "9001|5|3820|false|true|1||", "what each row of the tree asks for is recorded once")
	Stub.world.slowText = true
	Stub.world.textReady = nil
	T.Probe:Run()
	check(T.db.probe.report.talents.descriptions[116] == nil and T.db.probe.report.talents.texts[1].first == nil
		and T.db.probe.report.talents.descriptionsMissing == 3, "text the game has not loaded yet is asked for")
	Stub.flush()
	check(T.db.probe.report.talents.descriptions[116] == "Launches a bolt of frost." and T.db.probe.report.talents.texts[2].full == "Entry 502 at rank 5"
		and T.db.probe.report.talents.descriptionsMissing == 0, "and filled in a moment later")
	-- a reload straight after the check still gets the texts that have arrived
	Stub.world.textReady = nil
	T.Probe:Run()
	Stub.timers = {}
	Stub.world.textReady = true
	check(T.db.probe.report.talents.descriptionsMissing == 3, "a reload before the timers run")
	Stub.fire("PLAYER_LOGOUT")
	check(T.db.probe.report.talents.descriptionsMissing == 0 and T.db.probe.report.talents.texts[1].first == "Entry 501 at rank 1",
		"reads them once more as the interface goes down")
	Stub.world.slowText = nil
	check(r.talents.can.purchase == true and r.talents.can.commit == false and r.talents.firstNode.maxRanks == 5, "and what the game allows is recorded")
	check(r.skills.descriptions[136] == "Skill with staves." and r.skills.descriptions[95] == nil and type(r.skills.words) == "table",
		"with the game's own text for each skill")
	check(#r.skills.rows == 13 and r.skills.rows[6] == "Defense|95|66|70|0|false|false|6|0" and r.skills.rows[7] == "Staves|136|61|70|0|false|false|6|0"
		and r.skills.hands[1] == "16|2092|2|10",
		"skills are listed with their ranks, and what is in each hand")
	check(r.routes.continent == 13 and r.routes.sizes[13][1] == 30000 and r.routes.rects[1] == "52|Westfall|0.36|0.44|0.74|0.84",
		"zone rectangles and continent sizes are recorded")
	check(r.routes.pois[52].count == 1 and r.routes.pois[52][1] == "7001|The Deadmines|Dungeon|0.42|0.71" and r.routes.positions[13][1] == 0.40,
		"with the map's points of interest and the player's spot on each map")
	check(r.map.id == 52 and #r.map.chain == 3 and r.map.top == 947, "map chain walked to the top")
	check(r.zones.count == 7 and r.zones.withLevels == 1, "zone level ranges counted")
	check(r.dungeons.zonesWithEntrances == 1 and r.dungeons.list[1].name == "The Deadmines", "dungeon entrances found")
	check(#r.spellbook.future == 1 and r.spellbook.future[1].name == "Frost Nova", "trainable spell found")
	check(#r.spellbook.missing == 4, "spells missing from bars found")
	check(r.character.bagsFree == 9 and r.character.bind == "Goldshire", "character facts recorded")
	check(r.apis["C_Map.GetMapLevels"] == true and r.apis["TomTom.AddWaypoint"] == false, "API list recorded")
	check(type(r.compatErrors["C_GameRules.GetForeverExperiencePreset"]) == "string", "a failing API is noted, not fatal")
	check(r.levelSpells == nil, "the useless spells-by-level list is no longer read")
	check(r.learned.places == 1 and r.learned.byCategory.trainer == 1 and r.learned.trainer.count == 5
		and r.learned.trainer.states.available == 2 and r.learned.trainer.states.unavailable == 3
		and r.learned.trainer.full == true, "what Trailhead has learned is recorded")
	check(#r.learned.trainerLog == 1 and r.learned.trainerLog[1].how == "at once" and r.learned.trainerLog[1].count == 5
		and r.learned.trainerLog[1].before.u == false and r.learned.trainerLog[1].shown == 2, "and how the trainer's list was read")
	check(Stub.waypoint == nil, "the check no longer places a marker")
	Stub.combat = true
	T.db.probe.at = 1
	slash("check")
	check(T.db.probe.at == 1, "the check refuses to run in combat")
	Stub.combat = false
	noErrors(T, "game check")
end)

section("a client without the optional APIs", function()
	local T = load({ bare = true })
	slash("")
	for _, id in ipairs({ "find", "spells", "zones", "guide", "settings", "home" }) do
		T.Window:Select(id)
	end
	for _, id in ipairs({ "journal", "ember", "night" }) do
		T.Theme:Set(id)
	end
	for _, event in ipairs({ "MERCHANT_SHOW", "TRAINER_SHOW", "TRAINER_UPDATE", "GOSSIP_SHOW", "GOSSIP_CLOSED",
		"DYNAMIC_GOSSIP_POI_UPDATED", "SPELLS_CHANGED", "ACTIONBAR_SLOT_CHANGED", "ZONE_CHANGED_NEW_AREA" }) do
		Stub.fire(event)
	end
	Stub.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
	Stub.fire("PLAYER_LEVEL_UP", 15)
	Stub.flush()
	local P, G = T.Places, T.Game
	check(P.Count() == 0 and #P.Find("flight") == 0 and #P.Find("vendor") == 0, "nothing is found, and nothing breaks")
	check(titles(P.Search("bank")) == "Bank" and #P.Search("westfall") == 0, "search still knows the categories")
	check(#G.SpellsOffBars() == 0 and G.Training().source == nil and #G.World().zones == 0, "spell and zone readers come back empty")
	check(P.SetMarker(52, 0.5, 0.5, "x") == false and P.ShowMap(52) == false and P.Tracking("repair") == nil
		and P.SetTracking("repair", true) == false, "markers, maps and tracking decline politely")
	Stub.type(T.Window.search.edit, "dead")
	check(Stub.sees("Nothing found"), "the search box works")
	for _, id in ipairs({ "find", "spells", "zones" }) do
		T.Window:Select(id)
	end
	check(Stub.sees("The game has not listed its zones yet. Try again in a moment."), "the zones page explains the empty list")
	Stub.click("All zones")
	Stub.click("Dungeons")
	T.Window:Select("spells")
	Stub.click("Open spellbook")
	check(cardIds(T) == "check", "only the check card is offered")
	slash("check")
	check(T.db.probe and T.db.probe.failed == 0, "check still completes")
	check(T.missingEvents.HEARTHSTONE_BOUND == true, "an unknown event is noted, not fatal")
	slash("find bank")
	slash("clear")
	noErrors(T, "bare client")
end)

section("secret values and maximum level", function()
	local T = load({ secretName = true }, checked())
	local world, SECRET = Stub.world, Stub.SECRET
	slash("")
	T.modules.home:Refresh()
	world.npc = SECRET
	Stub.fire("MERCHANT_SHOW")
	check(T.Places.Find("vendor")[1].title == "Vendor", "a secret name falls back to the category's name")
	world.level, world.bind, world.talents, world.map = SECRET, SECRET, SECRET, SECRET
	world.free = { [0] = SECRET, SECRET, SECRET, SECRET, SECRET }
	world.durability[1] = { SECRET, SECRET }
	world.tracking[1] = { name = SECRET, texture = SECRET, active = SECRET }
	Stub.fire("SPELLS_CHANGED")
	Stub.fire("PLAYER_LEVEL_UP", SECRET)
	Stub.fire("MERCHANT_SHOW")
	Stub.fire("DYNAMIC_GOSSIP_POI_UPDATED")
	Stub.flush()
	check(T.Game.Level() == 0 and T.Game.PlayerMap() == nil, "secret level and map read as unknown")
	T.Advisor.Cards(20)
	for _, id in ipairs({ "home", "find", "spells", "zones", "settings" }) do
		T.Window:Select(id)
	end
	T.Places.Search("west")
	T.Places.Find("flight")
	T.Places.Tracking("repair")
	slash("check")
	noErrors(T, "secret values")
	T = load({ level = 60 }, checked())
	slash("")
	T.modules.home:Refresh()
	for _, id in ipairs({ "find", "spells", "zones" }) do
		T.Window:Select(id)
	end
	check(not cardIds(T):find("zone", 1, true), "no zone advice at the top level")
	noErrors(T, "maximum level")
end)

section("combat, scale and saved settings", function()
	local T = load()
	slash("")
	Stub.combat = true
	Stub.fire("PLAYER_REGEN_DISABLED")
	check(not T.Window:IsOpen(), "window hides when combat starts")
	Stub.combat = false
	Stub.fire("PLAYER_REGEN_ENABLED")
	check(T.Window:IsOpen(), "and returns afterwards")
	T.Window:Close()
	Stub.fire("PLAYER_REGEN_DISABLED")
	Stub.fire("PLAYER_REGEN_ENABLED")
	check(not T.Window:IsOpen(), "a closed window stays closed")
	T.db.hideInCombat = false
	slash("")
	Stub.fire("PLAYER_REGEN_DISABLED")
	check(T.Window:IsOpen(), "setting off: window stays in combat")
	check(T.Window:SetScale(5) == T.SCALE_MAX and T.Window:SetScale(0) == T.SCALE_MIN, "scale is clamped")
	T.db.minimap.show = false
	T:UpdateMinimapButton()
	check(not TrailheadMinimapButton:IsShown(), "minimap button can be hidden")
	slash("reset")
	slash("help")
	slash("errors")
	noErrors(T, "combat and settings")

	T = load(nil, { theme = "does-not-exist", scale = 99, minimap = "broken", tip = "x", firstRun = false }, { tab = 7 })
	check(T.db.theme == "ember" and T.Theme.current.id == "ember" and T.db.scale == 1, "bad saved values are repaired")
	check(type(T.db.minimap) == "table" and T.db.minimap.show == true, "bad saved tables are rebuilt")
	check(#Stub.chat == 0, "no welcome on later logins")
	slash("")
	check(T.Window.current == "home", "bad saved tab falls back to Home")
	noErrors(T, "repaired settings")
end)

section("errors are contained", function()
	local T = load()
	T:On("TH_TEST", function() error("boom") end)
	local reached = false
	T:On("TH_TEST", function() reached = true end)
	T:Fire("TH_TEST")
	check(reached, "one failing handler does not stop the next")
	check(#T.db.errors == 1 and T.db.errors[1].err:find("boom"), "the failure is recorded")
	T:Fire("TH_TEST")
	check(#T.db.errors == 1 and T.db.errors[1].count == 2, "repeats are counted, not stacked")
	check(T.Compat.Call("No.Such.Function") == nil, "a missing API returns nil")
end)

-- More suites live in tests/suites/*.lua. Each file is called with the harness:
-- local H = ...; H.section("name", function() local T = H.load() H.check(ok, "what") end)
local harness = {
	Stub = Stub, check = check, load = load, noErrors = noErrors, slash = slash, section = section,
	checked = checked, titles = titles, cardIds = cardIds, visit = visit, leave = leave, MAGE_TRAINER = MAGE_TRAINER,
}
inSuites = true
local listing = io.popen("ls tests/suites/*.lua 2>/dev/null | sort")
for file in listing:lines() do
	assert(loadfile(file))(harness)
end
listing:close()

-- The layout review (tools/layout_review.py) asks for every page to be written out.
if os.getenv("TH_LAYOUT") then
	assert(loadfile("tests/layout.lua"))(harness)
end

print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
