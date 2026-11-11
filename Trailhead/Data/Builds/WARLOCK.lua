local _, T = ...
local L = T.L

-- Warlock builds. Written by tools/gen_builds.py from tools/builds/WARLOCK.json: change that file,
-- not this one. Talents are keyed by the game's own node ids, each with the spell it must
-- still be; a build whose talents no longer match the live tree is not offered.

T.Builds = T.Builds or {}

T.Builds.WARLOCK = {
	{
		id = "levelling",
		name = L["Easy levelling"],
		icon = "moon",
		draft = true, -- not yet played to the top level
		suits = L["Damage over time and a Voidwalker to hold the enemy. You start a fight, then watch it fall. Slow and safe, with little to learn."],
		gear = L["Stamina and Intellect first, then gear that adds Spell Damage. A staff, or a one-handed weapon with an item for your other hand, and a wand."],
		-- 31 Affliction, 20 Demonology.
		talents = {
			[105925] = { spell = 18174, why = L["Your spells miss less often."] }, -- Suppression
			[105924] = { spell = 17810, why = L["Corruption casts faster and hurts more."] }, -- Improved Corruption
			[105923] = { spell = 18218, why = L["Your Affliction spells reach 20% further, so you can start fights from safer ground."] }, -- Grim Reach
			[105920] = { spell = 403511, why = L["Your Drain spells do more, and Drain Life heals you more."] }, -- Improved Drains
			[105918] = { spell = 17783, why = L["Being hit is less likely to interrupt your Drain spells and Wrack."] }, -- Fel Concentration
			[105914] = { spell = 18094, why = L["Sometimes your next Shadow Bolt casts much faster."] }, -- Nightfall
			[105912] = { spell = 18265, why = L["A spell that slowly takes health from the enemy and gives it to you. It opens Wrack."] }, -- Siphon Life
			[105911] = { spell = 17804, why = L["Drain Life and Wrack hurt more for each other Affliction effect on the target."] }, -- Soul Siphon
			[110876] = { spell = 1310949, why = L["Your Shadow spells critically strike more often."] }, -- Malevolence
			[105910] = { spell = 18271, why = L["All your Shadow spells do more damage and drain more life."] }, -- Shadow Mastery
			[105909] = { spell = 1316697, why = L["A strong over-time spell that also boosts your other Shadow damage over time."] }, -- Wrack
			[105907] = { spell = 18697, why = L["More Stamina, so you have more health to survive with."] }, -- Demonic Embrace
			[105904] = { spell = 18705, why = L["Your Voidwalker's own spells work better, so it protects you more."] }, -- Improved Voidwalker
			[105903] = { spell = 18731, why = L["More Health and Mana for your demon, and more Mana for you."] }, -- Fel Vitality
			[105898] = { spell = 18709, why = L["Summoning a demon is quicker and costs less Mana."] }, -- Master Summoner
			[105902] = { spell = 1235316, why = L["Demon Armor protects you better."] }, -- Demonic Aegis
			[105906] = { spell = 18769, why = L["Your demon does more damage."] }, -- Unholy Power
		},
		order = {
			{ 105925, 5 }, { 105924, 5 }, { 105923, 2 }, { 105920, 3 }, { 105918, 3 },
			{ 105914, 2 }, { 105912, 1 }, { 105911, 3 }, { 110876, 1 }, { 105910, 5 },
			{ 105909, 1 }, { 105907, 5 }, { 105904, 3 }, { 105903, 3 }, { 105898, 2 },
			{ 105902, 2 }, { 105906, 5 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Summon Voidwalker first. It stands in front and takes the hits."] },
			{ text = L["Cast Corruption and Bane of Agony on the enemy, then Shadow Bolt until it falls."] },
			{ text = L["Mana low? Use Life Tap to turn health into Mana, but only when you are healthy."] },
			{ text = L["Drain Soul drains the enemy while you hold it. If the enemy dies from it, you get a Soul Shard."] },
			{ node = 105912, text = L["Put Siphon Life on the enemy early. It slowly gives health to you."] },
			{ node = 105909, text = L["Add Wrack to the enemy. It makes your other damage over time spells hurt more."] },
			{ text = L["Losing a fight? Cast Fear on the enemy, then step away and recover."] },
		},
	},
}
