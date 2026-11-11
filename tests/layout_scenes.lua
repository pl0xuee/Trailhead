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
page("builds-strip", "builds", nil, function(T)
	T.BuildGuide.Choose("levelling")
	click("Open talents")
	PlayerSpellsFrame.rect = { 400, 2600, 1084, 201 }
	T.Window:DockTick()
end, { class = "ROGUE", level = 21 })

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
for _, id in ipairs({ "class", "talents", "levels", "gear", "weapons", "professions", "screen", "rest", "services",
	"supplies", "travel", "mount", "dying", "grouping", "danger", "words", "money", "reputation", "forever" }) do
	page("guide-" .. id, "guide", id)
	page("guide-" .. id .. "-warrior", "guide", id, nil, { class = "WARRIOR", level = 38 })
end

page("legacy", "legacy")

for _, section in ipairs({ { "window" }, { "vendors", "At vendors" }, { "help", "Help and data" } }) do
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
