local _, T = ...
local L = T.L

-- Hunter builds. Written by tools/gen_builds.py from tools/builds/HUNTER.json: change that file,
-- not this one. Talents are keyed by the game's own node ids, each with the spell it must
-- still be; a build whose talents no longer match the live tree is not offered.

T.Builds = T.Builds or {}

T.Builds.HUNTER = {
	{
		id = "levelling",
		name = L["Easy levelling"],
		icon = "spark",
		draft = true, -- not yet played to the top level
		suits = L["A bow or gun and a pet that fights beside you. You shoot from range while the pet holds the enemy, so most fights are easy and safe."],
		gear = L["Agility first, then Stamina and Intellect. Use the hardest-hitting bow, gun or crossbow you can find."],
		-- 31 Marksmanship, 20 Beast Mastery.
		talents = {
			[105011] = { spell = 19426, why = L["More critical strikes with all your attacks, and it opens the next row."] }, -- Lethal Attacks
			[105008] = { spell = 1223984, why = L["Your Intellect also adds to your Attack Power, and it opens Mortal Shots."] }, -- Careful Aim
			[105009] = { spell = 19416, why = L["Shots and Stings cost less Mana, so you can shoot for longer."] }, -- Efficiency
			[105006] = { spell = 19454, why = L["Arcane Shot is ready again sooner, so you press it more often."] }, -- Improved Arcane Shot
			[105005] = { spell = 415405, why = L["Rapid Fire is ready again sooner, and kills make your next shot hit harder."] }, -- Rapid Killing
			[105002] = { spell = 19485, why = L["Your critical strikes with ranged attacks hit much harder."] }, -- Mortal Shots
			[105004] = { spell = 1299346, why = L["Party members nearby get more ranged Attack Power, and it opens Sniper Shot."] }, -- Trueshot Aura
			[104998] = { spell = 19507, why = L["More damage every time you shoot with your bow or gun."] }, -- Ranged Weapon Specialization
			[104997] = { spell = 1310687, why = L["A long-range shot that also lets your next shots reach further."] }, -- Sniper Shot
			[104960] = { spell = 19552, why = L["Your Aspect of the Hawk can make your shots come faster for a short time."] }, -- Deadly Aspects
			[104976] = { spell = 19583, why = L["Your pet has more Health and Armor, so it lasts longer in fights."] }, -- Endurance Training
			[104969] = { spell = 19616, why = L["Your pet does more damage, so fights end sooner."] }, -- Unleashed Fury
			[104967] = { spell = 19598, why = L["Your pet lands more critical strikes."] }, -- Ferocity
		},
		order = {
			{ 105011, 5 }, { 105008, 5 }, { 105009, 5 }, { 105006, 5 }, { 105005, 2 },
			{ 105002, 5 }, { 105004, 1 }, { 104998, 2 }, { 104997, 1 }, { 104960, 5 },
			{ 104976, 5 }, { 104969, 5 }, { 104967, 5 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Call Pet, put Hunter's Mark on the enemy, then shoot with Auto Shot."] },
			{ text = L["Add Serpent Sting, then press Arcane Shot every time it is ready."] },
			{ text = L["Turn on Aspect of the Hawk before you fight and leave it on."] },
			{ node = 104997, text = L["Press Sniper Shot to hit from far away when you pull an enemy."] },
			{ text = L["Wing Clip (level 12) slows an enemy that reaches you. Step back, then shoot."] },
			{ text = L["Mend Pet (level 12) heals your pet after a fight. Feed Pet when your pet is hungry."] },
			{ text = L["Losing a fight? Use Concussive Shot to slow the enemy, then run."] },
		},
	},
}
