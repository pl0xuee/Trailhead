-- The page states the layout review looks at. scene(name, stubOptions, saved, savedChar, setup).
local H, scene = ...
local Stub = H.Stub

local CVARS = {
	autoLootDefault = "0", showTargetOfTarget = "0", nameplateShowEnemies = "0",
	statusTextDisplay = "NUMERIC", statusText = "1", lockActionBars = "0", combinedBags = "0",
	displayFreeBagSlots = "0", instantQuestText = "0", questPOI = "0", cameraDistanceMaxZoomFactor = "1.3",
}
local function options(extra)
	local opts = { cvars = {}, bars = { false, false, true, false, false, false, false }, panels = true }
	for key, value in pairs(CVARS) do
		opts.cvars[key] = value
	end
	for key, value in pairs(extra or {}) do
		opts[key] = value
	end
	return opts
end
-- Buttons are in capitals in the Ember look.
local function click(label, nth)
	if not pcall(Stub.click, label, nth) then
		click(label:upper(), nth)
	end
	Stub.flush()
end
local SAVED = H.checked({ welcomeDone = true })

local function open(id, arg, after)
	return function(T)
		T.Window:Open(id, arg)
		Stub.flush()
		T.Window:Select(id, arg) -- again, now that the page has been built once
		Stub.flush()
		if after then
			after(T)
		end
	end
end
local function page(name, id, arg, after, opts)
	scene(name, options(opts), SAVED, nil, open(id, arg, after))
end

-- Home, for characters at different points.
page("home", "home")
page("home-level1", "home", nil, nil, { level = 1 })
page("home-warrior30", "home", nil, nil, { class = "WARRIOR", level = 30 })
page("home-level60", "home", nil, nil, { class = "PRIEST", level = 60 })
-- The dungeon readiness card at the top: the cards above it dismissed.
local function readyFirst(T)
	for _ = 1, 10 do
		local first = T.Advisor.Cards(1)[1]
		if not first or first.id == "dungeon" or first.keep then
			break
		end
		T.Advisor.Dismiss(first)
	end
	T.modules.home:Refresh()
end
page("home-ready", "home", nil, readyFirst, { class = "DRUID", level = 24 })
page("home-ready-long", "home", nil, function(T)
	T.Game.World = function()
		return { zones = {}, byMap = {}, raids = {}, dungeons = { { name = "Upper Blackrock Spire", lo = 55, hi = 60 } } }
	end
	readyFirst(T)
end, { class = "PALADIN", level = 58 })

-- Find it.
page("find", "find")
for _, id in ipairs({ "trainer", "vendor", "repair", "inn", "flight", "mailbox", "bank", "professions", "auction",
	"weapons", "riding", "stable", "other" }) do
	page("find-" .. id, "find", id)
end
for name, query in pairs({ inn = "inn", dusk = "dusk", storm = "storm", none = "zzzzqq", dead = "deadmines", long = "eng" }) do
	page("find-search-" .. name, "find", nil, function(T)
		Stub.type(T.Window.search.edit, query)
	end)
end

-- Spells, before and after a trainer visit.
page("spells", "spells")
page("spells-trained", "spells", nil, function(T)
	H.visit("Jennea Cannon", H.MAGE_TRAINER)
	H.leave()
	T.Window:Select("spells")
end)
page("spells-warrior", "spells", nil, nil, { class = "WARRIOR", level = 30 })

-- Builds: no build chosen, a chosen build, each class, the narrow strip.
page("builds", "builds")
for _, class in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
	page("builds-" .. class:lower(), "builds", nil, function(T)
		local list = T.BuildGuide and T.BuildGuide.List() or {}
		if list[1] then
			T.BuildGuide.Choose(list[1].id)
			T.Window:Select("builds")
		end
	end, { class = class, level = 30 })
end
page("builds-rogue60", "builds", nil, function(T)
	local list = T.BuildGuide.List()
	T.BuildGuide.Choose(list[#list].id)
	T.Window:Select("builds")
end, { class = "ROGUE", level = 60 })
-- The narrow strip (no room beside the game window for the full one): next to the talents with
-- a build followed and without, and next to the spellbook.
page("strip-talents", "builds", nil, function(T)
	T.BuildGuide.Choose("levelling")
	click("Open talents")
	PlayerSpellsFrame.rect = { 400, 2600, 1084, 201 }
	T.Window:DockTick()
end, { class = "ROGUE", level = 21 })
page("strip-talents-summary", "builds", nil, function(T)
	click("Open talents")
	PlayerSpellsFrame.rect = { 400, 2600, 1084, 201 }
	T.Window:DockTick()
end, { class = "ROGUE", level = 21 })
page("strip-spellbook", "spells", nil, function(T)
	PlayerSpellsFrame.rect = { 400, 2600, 1084, 201 }
	click("Open spellbook")
end)
page("strip-spellbook-done", "spells", nil, function(T)
	Stub.world.onBars[2139], Stub.world.onBars[1953] = true, true
	Stub.fire("ACTIONBAR_SLOT_CHANGED")
	PlayerSpellsFrame.rect = { 400, 2600, 1084, 201 }
	click("Open spellbook")
end)

-- Zones: each filter and the hubs of a few zones.
for _, id in ipairs({ "fit", "all", "dungeons", "raids" }) do
	page("zones-" .. id, "zones", id)
end
page("zones-fit-level60", "zones", "fit", nil, { level = 60 })
page("zones-fit-level1", "zones", "fit", nil, { level = 1 })
page("zones-hubs-elwynn", "zones", { hubs = 1429, name = "Elwynn Forest" })
page("zones-hubs-barrens", "zones", { hubs = 1413, name = "The Barrens" })
page("zones-hubs-barrens-horde", "zones", { hubs = 1413, name = "The Barrens" }, nil, { horde = true })
page("zones-all-horde", "zones", "all", nil, { horde = true, level = 32 })
page("zones-hubs-stranglethorn", "zones", { hubs = 1434, name = "Stranglethorn Vale" })

-- Guide: every topic, for a low mage and for a warrior further on.
page("guide", "guide")
for _, id in ipairs({ "class", "talents", "levels", "gear", "weapons", "professions", "screen", "firststeps", "rest", "services",
	"supplies", "travel", "mount", "dying", "grouping", "danger", "words", "money", "reputation", "forever", "week",
	"fighting", "quests", "pet", "camping", "choosing" }) do
	page("guide-" .. id, "guide", id)
	page("guide-" .. id .. "-warrior", "guide", id, nil, { class = "WARRIOR", level = 38 })
end
page("guide-pet-hunter", "guide", "pet", nil, { class = "HUNTER", level = 12 })

page("guide-firststeps-some", "guide", "firststeps", function(T)
	H.visit("Jennea Cannon", H.MAGE_TRAINER)
	H.leave()
	Stub.world.group = 2
	Stub.fire("GROUP_ROSTER_UPDATE")
	T.Window:Select("guide", "firststeps")
end)

page("legacy", "legacy")

for _, section in ipairs({ { "window" }, { "vendors", "At vendors" }, { "items", "Items" }, { "help", "Help and data" } }) do
	page("settings-" .. section[1], "settings", nil, function()
		if section[2] then
			click(section[2])
		end
	end)
end

page("setup", "setup")
page("setup-some-set", "setup", nil, function()
	click("Turn on", 1)
	click("Turn on", 3)
end)
scene("setup-bare", { bare = true }, SAVED, nil, open("setup"))

-- This week: before raids open, with lockouts and a rank cap, and on a client without the functions.
local function day(year, month, dayOfMonth)
	Stub.skew = os.time({ year = year, month = month, day = dayOfMonth, hour = 12 }) - os.time()
end
local function weekly(data, date)
	local opts = options({ weekly = data })
	scene(data.scene, opts, SAVED, nil, function(T)
		day(date[1], date[2], date[3])
		open("weekly")(T)
	end)
end
weekly({ scene = "weekly", reset = 3 * 86400 + 5 * 3600, saved = {} }, { 2026, 11, 15 })
weekly({ scene = "weekly-lockouts", reset = 2 * 86400 + 4 * 3600, rank = { level = 3, earned = 500, capLevel = 5, lastLevel = 4 }, saved = {
	{ name = "Hyjal Summit", reset = 2 * 86400 + 4 * 3600, done = 3, total = 8 },
	{ name = "Onyxia's Lair", reset = 2 * 86400 + 4 * 3600, done = 1, total = 1 },
	{ name = "Barrow Deeps", reset = 2 * 86400 + 4 * 3600, done = 0, total = 6 },
} }, { 2026, 12, 12 })
weekly({ scene = "weekly-none", reset = 40 * 60, rank = { level = 5, earned = 0, capLevel = 5, lastLevel = 5 }, saved = {} }, { 2026, 12, 12 })
scene("weekly-bare", { bare = true }, SAVED, nil, function(T)
	day(2026, 12, 12)
	open("weekly")(T)
end)

-- Dungeon routes: outside, inside, long ones, raids.
for _, name in ipairs({ "Wailing Caverns", "The Deadmines", "Blackrock Depths", "Molten Core", "Scarlet Monastery",
	"Dire Maul", "Stratholme", "Ragefire Chasm" }) do
	page("dungeon-" .. name:lower():gsub("%W", ""), "home", nil, function(T)
		T.Window:Select("dungeon", name)
	end)
end
page("dungeon-inside", "home", nil, function(T)
	Stub.world.instance = { name = "Wailing Caverns", kind = "party" }
	_G.GetInstanceInfo = function()
		return "Wailing Caverns", "party", 1, "Normal", 5, 0, false, 43
	end
	Stub.fire("PLAYER_ENTERING_WORLD")
	Stub.flush()
	T.Window:Select("dungeon", "Wailing Caverns")
end)

-- How to get there.
page("route-flight", "find", "flight", function()
	click("How to get there", 4)
end)
page("route-zone", "zones", "all", function()
	click("How to get there", 6)
end)
page("route-dungeon", "zones", "dungeons", function()
	click("How to get there", 3)
end)

-- The welcome, on a first open.
scene("welcome", options(), { firstRun = false }, nil, open())

-- Your characters: a full account, a single character, and Home's "since you last played" card.
local ALTS = {
	["TestRealm-Thrallgarnok"] = { name = "Thrallgarnok", realm = "Test Realm", class = "SHAMAN", className = "Shaman",
		race = "Orc", level = 38, xp = 41000, xpMax = 77000, rested = 52000, bind = "Thousand Needles", money = 4815162,
		durability = 0.18, zone = "Stranglethorn Vale", talents = 3, train = 4, at = time() - 2 * 86400,
		profs = { { name = "Leatherworking", rank = 187, max = 225 }, { name = "Skinning", rank = 201, max = 225 },
			{ name = "Cooking", rank = 150, max = 225 }, { name = "First Aid", rank = 225, max = 225 }, { name = "Fishing", rank = 98, max = 150 } } },
	["OtherRealm-Mira"] = { name = "Mira", realm = "Other Realm", className = "Priest", race = "Night Elf", level = 60,
		bind = "Light's Hope Chapel", money = 251234567, durability = 1, zone = "Eastern Plaguelands", talents = 0,
		at = time() - 26 * 86400, profs = { { name = "Tailoring", rank = 300, max = 300 } } },
	["TestRealm-Bankalt"] = { name = "Bankalt", level = 1, at = time() - 5 * 3600 },
	["TestRealm-Old"] = { name = "Old", level = 12, at = "long ago" },
}
local function withAlts(extra)
	local saved = H.checked({ welcomeDone = true, chars = {} })
	for key, rec in pairs(ALTS) do
		saved.chars[key] = rec
	end
	for key, rec in pairs(extra or {}) do
		saved.chars[key] = rec
	end
	return saved
end
scene("characters", options(), withAlts(), nil, open("characters"))
scene("characters-one", options(), SAVED, nil, open("characters"))
scene("characters-forget", options(), withAlts(), nil, open("characters", nil, function()
	click("Forget", 1)
end))
scene("home-since", options(), withAlts({
	["TestRealm-Aeloria"] = { name = "Aeloria", level = 14, xp = 6200, xpMax = 10000, rested = 0, at = time() - 3 * 86400 },
}), nil, open("home", nil, function(T)
	H.visit("Jennea Cannon", H.MAGE_TRAINER)
	H.leave()
	Stub.world.durability[1] = { 3, 40 }
	T.Window:Select("home")
end))
