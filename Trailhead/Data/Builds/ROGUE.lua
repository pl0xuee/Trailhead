local _, T = ...
local L = T.L

-- Rogue builds. Written from the talents' own texts as the game check read them on
-- 2026-11-11 (build 1.60.1.70888), not from the 2006 game: Forever's tree is different.
-- Talents are keyed by the game's own node ids, each with the spell it must still be; a
-- build whose talents no longer match the live tree is not offered (see Services/Builds).
--
-- order: { node, points } in the order to take them. A row of a tree opens for every 5
-- points in that tree, and the order below respects that.

T.Builds = T.Builds or {}

T.Builds.ROGUE = {
	{
		id = "levelling",
		name = L["Easy levelling"],
		icon = "spark",
		draft = true, -- not yet played to the top level
		suits = L["Sinister Strike and Eviscerate with any one-handed weapons. Steady damage, little to learn, and a few tools for the fight that goes wrong."],
		gear = L["Agility first, then Stamina. Two one-handed weapons, and leather armor."],
		talents = {
			[105741] = { spell = 13732, why = L["Sinister Strike is your main attack. Cheaper means more of them."] },
			[105708] = { spell = 14162, why = L["Eviscerate, your finishing move, hits harder."] },
			[105737] = { spell = 13705, why = L["More of your attacks land."] },
			[105738] = { spell = 13713, why = L["You parry more, and at 3 of 3 it opens Riposte."] },
			[105735] = { spell = 14251, why = L["A strong hit after every parry, and it disarms."] },
			[105736] = { spell = 13742, why = L["Evasion and Sprint are ready far more often."] },
			[113398] = { spell = 13712, why = L["You dodge more, so you take less damage."] },
			[108100] = { spell = 1310711, why = L["Eviscerate costs much less Energy."] },
			[105730] = { spell = 18427, why = L["Sinister Strike and Eviscerate hit harder."] },
			[105726] = { spell = 30919, why = L["Fewer of your attacks are dodged or parried."] },
			[105728] = { spell = 13877, why = L["Faster attacks that also hit a second enemy."] },
			[113635] = { spell = 13715, why = L["Your off-hand weapon hits much harder."] },
			[105727] = { spell = 13960, why = L["A bonus that depends on your weapon: extra attacks with swords and axes."] },
			[105724] = { spell = 13750, why = L["Your Energy comes back twice as fast for a while: your big button."] },
			[105722] = { spell = 14138, why = L["More critical strikes with everything."] },
			[105721] = { spell = 14156, why = L["Finishing moves often give a combo point back."] },
			[105739] = { spell = 14165, why = L["Slice and Dice lasts longer."] },
			[105716] = { spell = 14128, why = L["Your critical strikes hit harder."] },
			[105723] = { spell = 14144, why = L["After a kill, your next attack is far more likely to crit."] },
			[105720] = { spell = 14983, why = L["A bigger pool of Energy."] },
		},
		order = {
			-- Combat, levels 10 to 40.
			{ 105741, 2 }, { 105708, 3 },
			{ 105737, 3 }, { 105738, 3 },
			{ 105735, 1 }, { 105736, 2 }, { 113398, 1 },
			{ 108100, 1 }, { 105730, 3 }, { 105726, 1 },
			{ 105728, 1 }, { 113635, 2 }, { 105727, 5 },
			{ 105726, 1 }, { 113398, 1 },
			{ 105724, 1 },
			-- Assassination, levels 41 to 57.
			{ 105722, 5 }, { 105721, 3 }, { 105739, 2 },
			{ 105716, 2 }, { 105723, 2 }, { 105739, 1 }, { 105720, 2 },
			-- The last three levels.
			{ 113398, 3 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Use Sinister Strike to build combo points, then Eviscerate to spend them."] },
			{ text = L["Losing a fight? Press Evasion, or get away with Sprint."] },
			{ node = 105735, text = L["Riposte lights up after you parry. Press it: a strong hit that disarms."] },
			{ node = 105728, text = L["Two enemies on you? Blade Flurry makes your attacks hit both."] },
			{ node = 105724, text = L["Save Adrenaline Rush for the hard fights."] },
		},
	},
}
