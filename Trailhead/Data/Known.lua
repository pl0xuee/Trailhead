local _, T = ...
local L = T.L

-- Things the game itself has no list of, taken from published guides to World of Warcraft:
-- Forever (Blizzard's new player starter guide, Warcraft Tavern's weapon trainer and riding
-- guides, Icy Veins; see "Sources" in docs/PLAN.md). The map numbers are the game's own
-- (its zone list, game check 8). A place the player has seen for themselves replaces the
-- entry here. f: 1 Horde, 2 Alliance. race: the race file name (riding is taught by your
-- own race's trainer). x and y are map fractions.

local function weapons(faction, name, map, x, y, city, teaches)
	return { c = "weapons", f = faction, n = name, m = map, x = x, y = y, z = city, note = teaches }
end

local function riding(faction, race, name, map, x, y, zone, vendor)
	return { c = "riding", f = faction, race = race, n = name, m = map, x = x, y = y, z = zone,
		note = vendor and L["Mount vendor"] or L["Riding trainer"], vendor = vendor or nil }
end

T.Known = {
	places = {
		weapons(1, "Sayoc", 1454, 0.815, 0.196, L["Orgrimmar"], L["axes, bows, daggers, fist, staves, thrown"]),
		weapons(1, "Hanashi", 1454, 0.815, 0.196, L["Orgrimmar"], L["axes, bows, staves, thrown"]),
		weapons(1, "Ansekhwa", 1456, 0.409, 0.627, L["Thunder Bluff"], L["guns, maces, staves"]),
		weapons(1, "Archibald", 1458, 0.573, 0.328, L["Undercity"], L["crossbows, daggers, polearms, swords"]),
		weapons(2, "Woo Ping", 1453, 0.638, 0.690, L["Stormwind"], L["crossbows, daggers, polearms, staves, swords"]),
		weapons(2, "Buliwyf Stonehand", 1455, 0.622, 0.896, L["Ironforge"], L["axes, fist, guns, maces"]),
		weapons(2, "Bixi Wobblebonk", 1455, 0.622, 0.896, L["Ironforge"], L["crossbows, daggers, thrown"]),
		weapons(2, "Ilyenia Moonfire", 1457, 0.576, 0.467, L["Darnassus"], L["bows, daggers, fist, staves, thrown"]),

		riding(1, "Orc", "Kildar", 1454, 0.694, 0.131, L["Orgrimmar"]),
		riding(1, "Orc", "Ogunaro Wolfrunner", 1454, 0.694, 0.122, L["Orgrimmar"], true),
		riding(1, "Troll", "Xar'Ti", 1411, 0.553, 0.755, L["Sen'jin Village, Durotar"]),
		riding(1, "Troll", "Zjolnir", 1411, 0.552, 0.757, L["Sen'jin Village, Durotar"], true),
		riding(1, "Tauren", "Kar Stormsinger", 1412, 0.468, 0.619, L["Bloodhoof Village, Mulgore"]),
		riding(1, "Tauren", "Harb Clawhoof", 1412, 0.475, 0.586, L["Bloodhoof Village, Mulgore"], true),
		riding(1, "Scourge", "Velma Warnam", 1420, 0.602, 0.524, L["Brill, Tirisfal Glades"]),
		riding(1, "Scourge", "Zachariah Post", 1420, 0.599, 0.526, L["Brill, Tirisfal Glades"], true),
		riding(2, "Human", "Randal Hunter", 1429, 0.843, 0.649, L["Eastvale Logging Camp, Elwynn Forest"]),
		riding(2, "Human", "Katie Hunter", 1429, 0.841, 0.654, L["Eastvale Logging Camp, Elwynn Forest"], true),
		riding(2, "Dwarf", "Ultham Ironhorn", 1426, 0.637, 0.501, L["Amberstill Ranch, Dun Morogh"]),
		riding(2, "Dwarf", "Veron Amberstill", 1426, 0.635, 0.506, L["Amberstill Ranch, Dun Morogh"], true),
		riding(2, "Gnome", "Binjy Featherwhistle", 1426, 0.492, 0.481, L["Steelgrill's Depot, Dun Morogh"]),
		riding(2, "Gnome", "Milli Featherwhistle", 1426, 0.491, 0.480, L["Steelgrill's Depot, Dun Morogh"], true),
		riding(2, "NightElf", "Jartsam", 1457, 0.381, 0.161, L["Darnassus"]),
		riding(2, "NightElf", "Lelanai", 1457, 0.383, 0.153, L["Darnassus"], true),
		-- Skyborne can belong to either side; both learn to ride on their own isle.
		riding(1, "Skyborne", "Genn Fairweather", 2521, 0.538, 0.813, L["Zephras Isle"]),
		riding(2, "Skyborne", "Genn Fairweather", 2521, 0.538, 0.813, L["Zephras Isle"]),
	},

	-- Riding, as the guides give it at launch. Money is in copper. Level 40 and 100 gold: Warcraft
	-- Tavern and Icy Veins agree; the level 60 lesson (1000 gold, 100% speed) is from Warcraft Tavern only.
	riding = {
		level = 40, cost = 100 * 10000, speed = 60,
		fastLevel = 60, fastCost = 1000 * 10000, fastSpeed = 100,
		-- These classes get a mount through their class instead of the riding trainer.
		classMount = { PALADIN = true, WARLOCK = true },
	},

	-- Learning a new kind of weapon (10 silver; polearms from level 20 for 1 gold: Warcraft Tavern's
-- weapon trainer guide, and the classic figures that Wowpedia lists, which agree) from a weapon master.
	weapons = { cost = 10 * 100, polearmLevel = 20, polearmCost = 10000 },
}
