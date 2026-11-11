local _, T = ...
local L = T.L

-- Mage builds. Written by tools/gen_builds.py from tools/builds/MAGE.json: change that file,
-- not this one. Talents are keyed by the game's own node ids, each with the spell it must
-- still be; a build whose talents no longer match the live tree is not offered.

T.Builds = T.Builds or {}

T.Builds.MAGE = {
	{
		id = "levelling",
		name = L["Easy levelling"],
		icon = "snow",
		draft = true, -- not yet played to the top level
		suits = L["Frostbolt from range, with ice to slow enemies and Ice Barrier at level 40 to soak hits. A few Arcane talents at the end save mana."],
		gear = L["Intellect first, then Stamina and Spirit. Use a staff or a wand, and cloth armor."],
		-- 39 Frost, 12 Arcane.
		talents = {
			[105779] = { spell = 11070, why = L["Frostbolt, your main spell, takes less time to cast."] }, -- Improved Frostbolt
			[105778] = { spell = 29438, why = L["Your spells miss less often."] }, -- Precision
			[105774] = { spell = 11071, why = L["Your chilling effects sometimes freeze the enemy in place."] }, -- Frostbite
			[105777] = { spell = 11207, why = L["Your Frost spells hit harder when they critically strike."] }, -- Ice Shards
			[105772] = { spell = 11160, why = L["Frost spells cost less mana, so you can cast more before you drink."] }, -- Frost Channeling
			[105780] = { spell = 11189, why = L["Your Frost Armor protects you more, and so will Ice Barrier when you learn it."] }, -- Frost Warding
			[105767] = { spell = 1312002, why = L["An extra Frost hit to use while an enemy is chilled."] }, -- Ice Lance
			[105769] = { spell = 11958, why = L["A button that makes you safe for a short time when a fight goes badly."] }, -- Ice Block
			[105766] = { spell = 12472, why = L["Makes your other Frost spells ready again, and it opens Ice Barrier."] }, -- Cold Snap
			[105776] = { spell = 11175, why = L["Chill effects last longer and slow enemies more, so they reach you later."] }, -- Permafrost
			[105775] = { spell = 11165, why = L["Frost Nova is ready again sooner, so you can freeze enemies in place more often."] }, -- Improved Frost Nova
			[105770] = { spell = 16757, why = L["Your Frostbolt reaches a little further, so you start fights from safer ground."] }, -- Arctic Reach
			[105762] = { spell = 11426, why = L["A shield you cast on yourself that soaks up damage, from level 40."] }, -- Ice Barrier
			[105815] = { spell = 6057, why = L["Your wand does more damage, which helps to finish enemies for free."] }, -- Wand Specialization
			[105802] = { spell = 28574, why = L["Gives you more Armor, based on your Intellect."] }, -- Arcane Resilience
			[105810] = { spell = 11213, why = L["Your spells can make your next spell cost less mana."] }, -- Arcane Concentration
			[105768] = { spell = 11170, why = L["Your spells crit more often against a frozen enemy."] }, -- Shatter
			[105764] = { spell = 400647, why = L["Your chill effects sometimes treat the next two spells as hitting a frozen enemy."] }, -- Fingers of Frost
			[105765] = { spell = 11190, why = L["Cone of Cold, an area blast in front of you, hits harder."] }, -- Improved Cone of Cold
			[105811] = { spell = 29441, why = L["Gives you a little protection against spells, and some mana back."] }, -- Magic Absorption
		},
		order = {
			{ 105779, 5 }, { 105778, 3 }, { 105774, 3 }, { 105777, 5 }, { 105772, 3 },
			{ 105780, 2 }, { 105767, 1 }, { 105769, 1 }, { 105766, 1 }, { 105776, 3 },
			{ 105775, 2 }, { 105770, 1 }, { 105762, 1 }, { 105815, 2 }, { 105802, 3 },
			{ 105810, 5 }, { 105768, 3 }, { 105764, 2 }, { 105765, 3 }, { 105811, 2 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Start with Frostbolt from far away. Keep casting it until the enemy is dead."] },
			{ text = L["Enemy at your feet? Frost Nova freezes it. Back away before you cast, as damage can break the freeze."] },
			{ text = L["Fire Blast is a quick extra hit. Use it to finish an enemy that is nearly dead."] },
			{ node = 105767, text = L["Ice Lance hits much harder on a frozen enemy. Cast it right after Frost Nova."] },
			{ node = 105762, text = L["Cast Ice Barrier on yourself before a hard fight."] },
			{ text = L["Out of mana? Sit down and drink water. Conjure Water makes more."] },
			{ node = 105769, text = L["Losing a fight? Use Ice Block to be safe, then recover and try again."] },
		},
	},
}
