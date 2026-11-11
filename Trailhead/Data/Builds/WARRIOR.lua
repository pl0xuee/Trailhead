local _, T = ...
local L = T.L

-- Warrior builds. Written by tools/gen_builds.py from tools/builds/WARRIOR.json: change that file,
-- not this one. Talents are keyed by the game's own node ids, each with the spell it must
-- still be; a build whose talents no longer match the live tree is not offered.

T.Builds = T.Builds or {}

T.Builds.WARRIOR = {
	{
		id = "levelling",
		name = L["Easy levelling"],
		icon = "sword",
		draft = true, -- not yet played to the top level
		suits = L["A big two-handed weapon, Charge to start every fight and Mortal Strike at 40. Simple, sturdy, and it works with whatever weapon drops."],
		gear = L["Strength first, then Stamina. A two-handed weapon is best, and wear the heaviest armor you can."],
		-- 31 Arms, 20 Fury.
		talents = {
			[105956] = { spell = 12286, why = L["Rend's bleed does more damage, and it opens Deep Wounds."] }, -- Improved Rend
			[105958] = { spell = 12282, why = L["Heroic Strike costs less Rage."] }, -- Improved Heroic Strike
			[105955] = { spell = 12285, why = L["Charge gives more Rage, so every fight starts with a hit ready."] }, -- Improved Charge
			[105954] = { spell = 12295, why = L["You keep more Rage when you change stance."] }, -- Improved Tactical Mastery
			[105951] = { spell = 12296, why = L["A steady trickle of Rage in every fight."] }, -- Anger Management
			[105950] = { spell = 12834, why = L["Your critical strikes make the enemy bleed."] }, -- Deep Wounds
			[105948] = { spell = 12163, why = L["More damage with a two-handed weapon."] }, -- Two-Handed Weapon Specialization
			[105947] = { spell = 16493, why = L["Your critical strikes hit harder."] }, -- Impale
			[105945] = { spell = 12292, why = L["Your next attacks also hit a second enemy."] }, -- Sweeping Strikes
			[105944] = { spell = 1290261, why = L["A bonus that depends on your weapon, such as more crits with an axe."] }, -- Weaponmaster
			[105952] = { spell = 12290, why = L["Overpower crits far more often."] }, -- Improved Overpower
			[110524] = { spell = 1289682, why = L["Hitting an enemy that has your Rend on it can make Overpower usable."] }, -- Bloodthrill
			[105941] = { spell = 12294, why = L["Your big attack from level 40. It also cuts how much the enemy can be healed."] }, -- Mortal Strike
			[105939] = { spell = 12320, why = L["More critical strikes with every attack."] }, -- Cruelty
			[105937] = { spell = 12322, why = L["Your hits sometimes give extra Rage."] }, -- Unbridled Wrath
			[105931] = { spell = 12317, why = L["After you are hit, you often deal more damage for a while."] }, -- Enrage
			[105932] = { spell = 20502, why = L["Execute costs less Rage."] }, -- Improved Execute
			[113636] = { spell = 1329555, why = L["A button for a burst of extra Rage."] }, -- Reckless Swings
			[105935] = { spell = 12323, why = L["Slows every enemy near you, so you can get away."] }, -- Piercing Howl
			[105934] = { spell = 16487, why = L["Heals you a little after a heavy hit."] }, -- Blood Craze
		},
		order = {
			{ 105956, 3 }, { 105958, 2 }, { 105955, 2 }, { 105954, 3 }, { 105951, 1 },
			{ 105950, 3 }, { 105958, 1 }, { 105948, 3 }, { 105947, 2 }, { 105945, 1 },
			{ 105944, 5 }, { 105952, 2 }, { 110524, 2 }, { 105941, 1 }, { 105939, 5 },
			{ 105937, 5 }, { 105931, 5 }, { 105932, 2 }, { 113636, 1 }, { 105935, 1 },
			{ 105934, 1 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Charge in, put Rend on the enemy, then spend Rage on Heroic Strike."] },
			{ text = L["Overpower (level 12) works only right after an enemy dodges. Press it then: it is cheap and strong."] },
			{ text = L["Execute (level 24) finishes an enemy that has 20% Health or less."] },
			{ node = 105945, text = L["Two enemies on you? Sweeping Strikes makes your attacks hit both."] },
			{ node = 105941, text = L["Use Mortal Strike every time it is ready."] },
			{ node = 105935, text = L["Losing a fight? Piercing Howl slows them all; then run."] },
		},
	},
	{
		id = "tank",
		name = L["Dungeon tank"],
		icon = "shield",
		draft = true, -- not yet played to the top level
		suits = L["Hold the enemies' attention in a dungeon with a shield, and take the hits while your group does the damage."],
		gear = L["Stamina and Armor first, then Strength. A shield and a one-handed weapon, and the heaviest armor you can wear."],
		-- 44 Protection, 7 Arms.
		talents = {
			[105976] = { spell = 12298, why = L["You block more often, and each block gives you Rage."] }, -- Shield Specialization
			[105975] = { spell = 12297, why = L["More Defense, so enemies hit you less often."] }, -- Anticipation
			[105969] = { spell = 12797, why = L["Revenge hits much harder."] }, -- Improved Revenge
			[110856] = { spell = 12792, why = L["With a shield in Defensive Stance, enemies pay even more attention to you."] }, -- Defiance
			[105972] = { spell = 12287, why = L["Thunder Clap costs less Rage."] }, -- Improved Thunder Clap
			[105970] = { spell = 12975, why = L["A button that gives you extra Health for a short time."] }, -- Last Stand
			[105968] = { spell = 12308, why = L["Sunder Armor costs less Rage, so you can use it more."] }, -- Improved Sunder Armor
			[105963] = { spell = 12311, why = L["Shield Bash also stops the enemy from casting spells for a while."] }, -- Improved Shield Bash
			[105961] = { spell = 29787, why = L["Your attacks cost less Rage."] }, -- Focused Rage
			[105965] = { spell = 12809, why = L["Stuns an enemy for a short time, and it opens Shield Slam."] }, -- Concussion Blow
			[105964] = { spell = 12312, why = L["Shield Wall, a big cut in damage you take, is ready again sooner."] }, -- Improved Shield Wall
			[113570] = { spell = 12962, why = L["Stuns and Fear effects on you wear off a little sooner."] }, -- Iron Will
			[105962] = { spell = 16538, why = L["You deal more damage while you hold a shield."] }, -- Bastion
			[105959] = { spell = 23922, why = L["A strong shield attack that keeps enemies on you."] }, -- Shield Slam
			[105974] = { spell = 12301, why = L["Bloodrage gives you more Rage."] }, -- Improved Bloodrage
			[105957] = { spell = 16462, why = L["You parry a little more often."] }, -- Deflection
			[105958] = { spell = 12282, why = L["Heroic Strike costs less Rage."] }, -- Improved Heroic Strike
		},
		order = {
			{ 105976, 5 }, { 105975, 5 }, { 105969, 3 }, { 110856, 3 }, { 105972, 3 },
			{ 105970, 1 }, { 105968, 3 }, { 105963, 2 }, { 105961, 3 }, { 105965, 1 },
			{ 105964, 2 }, { 113570, 5 }, { 105962, 5 }, { 105959, 1 }, { 105974, 2 },
			{ 105957, 5 }, { 105958, 2 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Use Defensive Stance (level 10) and a shield. You take less damage, and enemies notice you more."] },
			{ text = L["Taunt makes an enemy attack you. Use it on one that is hitting your friends."] },
			{ text = L["Use Sunder Armor up to five times on the main enemy. It cuts its armor and keeps its attention."] },
			{ text = L["Revenge (level 14) hits back after you block, dodge or parry. Use it when it lights up."] },
			{ text = L["Thunder Clap hits all enemies near you and makes them attack more slowly."] },
			{ node = 105970, text = L["Last Stand gives you extra Health for a short time. Use it when you are in danger."] },
			{ node = 105959, text = L["Shield Slam hits hard and keeps the enemy on you. Use it every time it is ready."] },
		},
	},
}
