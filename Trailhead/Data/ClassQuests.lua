local _, T = ...

-- Class quests: the abilities (and shaman totems) a class gets from a quest, not from its
-- trainer. Hand-checked on 2026-11-17 against Conquest Capped's and wow4ever's Forever class
-- quest lists, SenseOS's Forever class quest guide and Icy Veins' class quest pages; an entry
-- is here only where those agree. Spell and item IDs are the game's own (wago.tools,
-- build 1.60.1.70888); the English name matches Data/ClassSpells.lua and is the fallback when
-- the game gives no name.
--
-- An entry: level, name, spells = { spell IDs, any one of them counts } or item = item ID
-- (shaman totems, carried in the bags), and who starts it:
--   trainer = true            your class trainer starts it (for every race)
--   trainer = { Race = true } your class trainer starts it, for those races
--   where = { Race or A/H = uiMapID } it starts in that city or zone (race first, then side)
--   none of these             ask your class trainer: the sources do not agree
-- racial = true: a spell of the race's own (priests); the races' spells differ, so no name.
-- Races are the game's race file names (Scourge is the undead).

local STORMWIND, ORGRIMMAR, UNDERCITY, BARRENS = 1453, 1454, 1458, 1413

T.ClassQuestPlaces = {
	[STORMWIND] = "Stormwind City", [ORGRIMMAR] = "Orgrimmar", [UNDERCITY] = "Undercity", [BARRENS] = "The Barrens",
}

T.ClassQuests = {
	WARRIOR = {
		{ level = 10, name = "Defensive Stance", spells = { 71 }, where = { Orc = BARRENS, Troll = BARRENS, Tauren = BARRENS } },
		{ level = 30, name = "Berserker Stance", spells = { 2458 } },
	},
	PALADIN = {
		{ level = 12, name = "Redemption", spells = { 7328 }, trainer = { Human = true, Dwarf = true } },
		{ level = 40, name = "Summon Warhorse", spells = { 13819, 1279399 }, where = { Human = STORMWIND, Dwarf = STORMWIND } },
		{ level = 60, name = "Summon Charger", spells = { 23214, 1296534 }, where = { Human = STORMWIND, Dwarf = STORMWIND } },
	},
	HUNTER = {
		{ level = 10, name = "Tame Beast", spells = { 1515 }, trainer = true },
	},
	ROGUE = {
		{ level = 20, name = "Poisons", spells = { 2842 }, where = { A = STORMWIND, H = ORGRIMMAR } },
	},
	PRIEST = {
		{ level = 10, racial = true },
		{ level = 20, racial = true },
	},
	SHAMAN = {
		{ level = 4, name = "Earth Totem", item = 5175 },
		{ level = 10, name = "Fire Totem", item = 5176 },
		{ level = 20, name = "Water Totem", item = 5177 },
		{ level = 30, name = "Air Totem", item = 5178 },
	},
	MAGE = {},
	WARLOCK = {
		{ level = 1, name = "Summon Imp", spells = { 688 } },
		{ level = 10, name = "Summon Voidwalker", spells = { 697 },
			where = { Human = STORMWIND, Gnome = STORMWIND, Orc = ORGRIMMAR, Troll = ORGRIMMAR, Scourge = UNDERCITY } },
		{ level = 20, name = "Summon Succubus", spells = { 712, 713 } },
		{ level = 30, name = "Summon Felhunter", spells = { 691 } },
		{ level = 40, name = "Summon Felsteed", spells = { 5784 } },
		{ level = 60, name = "Summon Dreadsteed", spells = { 23161 } },
	},
	DRUID = {
		{ level = 10, name = "Bear Form", spells = { 5487 }, trainer = true },
		{ level = 14, name = "Cure Poison", spells = { 8946 }, trainer = true },
		{ level = 16, name = "Aquatic Form", spells = { 1066 } },
		{ level = 20, name = "Cat Form", spells = { 768 }, trainer = true },
	},
}
