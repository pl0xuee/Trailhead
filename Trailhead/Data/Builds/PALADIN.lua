local _, T = ...
local L = T.L

-- Paladin builds. Written by tools/gen_builds.py from tools/builds/PALADIN.json: change that file,
-- not this one. Talents are keyed by the game's own node ids, each with the spell it must
-- still be; a build whose talents no longer match the live tree is not offered.

T.Builds = T.Builds or {}

T.Builds.PALADIN = {
	{
		id = "levelling",
		name = L["Easy levelling"],
		icon = "hammer",
		draft = true, -- not yet played to the top level
		suits = L["A two-handed weapon and Seal of Command from level 20. Simple to play: you hit hard and can heal yourself between fights."],
		gear = L["Strength first, then Stamina. A two-handed sword, axe or mace, and the heaviest armor you can wear."],
		-- 34 Retribution, 17 Holy.
		talents = {
			[105706] = { spell = 20101, why = L["Seals and other instant spells cost less Mana, so you can fight longer."] }, -- Benediction
			[105703] = { spell = 20117, why = L["More critical strikes with every attack and spell."] }, -- Conviction
			[105705] = { spell = 25956, why = L["Judgement is ready again sooner, so you use it more often."] }, -- Improved Judgement
			[105696] = { spell = 20375, why = L["A Seal that adds extra Holy damage to your hits, from level 20."] }, -- Seal of Command
			[105701] = { spell = 1311074, why = L["Judgement gives back Mana from your Seal, so fights cost you less."] }, -- Sanctified Judgement
			[105699] = { spell = 26022, why = L["You run faster, on foot and on a mount."] }, -- Pursuit of Justice
			[105702] = { spell = 9452, why = L["Your hits sometimes make the enemy weaker, so it hits you less hard."] }, -- Vindication
			[105697] = { spell = 20111, why = L["More damage with a two-handed weapon, but enemies notice you less."] }, -- Two-Handed Weapon Specialization
			[105700] = { spell = 1311087, why = L["Holy Strike hits harder and keeps your Judgements on the enemy fresh."] }, -- Sacred Arbiter
			[105698] = { spell = 9799, why = L["Enemies that crit you take some of the pain themselves."] }, -- Eye for an Eye
			[105693] = { spell = 20049, why = L["After a critical strike, you deal more damage for a while."] }, -- Vengeance
			[105694] = { spell = 20066, why = L["Holds one Humanoid enemy still until you hit it, and it opens Unsealed Wrath."] }, -- Repentance
			[110882] = { spell = 1311084, why = L["Your spells do more damage, based on your Intellect."] }, -- Champion of the Light
			[105692] = { spell = 1310735, why = L["Your hits store extra Seal effects that go off when you change Seals."] }, -- Unsealed Wrath
			[113630] = { spell = 20262, why = L["More Strength, so your weapon hits harder."] }, -- Divine Strength
			[105333] = { spell = 20237, why = L["Holy Light and Flash of Light heal you for more."] }, -- Healing Light
			[110871] = { spell = 1310899, why = L["You keep some Mana regeneration while casting, handy when you heal."] }, -- Reverence
			[105335] = { spell = 20205, why = L["Your heals are less likely to be interrupted when you are hit."] }, -- Spiritual Focus
			[105704] = { spell = 1237268, why = L["Consecration, Exorcism and Holy Wrath cost less Mana."] }, -- Holy Conduit
			[105324] = { spell = 1310904, why = L["Your Holy spells miss less, and Silence effects on you end sooner."] }, -- Divine Precision
		},
		order = {
			{ 105706, 5 }, { 105703, 3 }, { 105705, 2 }, { 105696, 1 }, { 105701, 3 },
			{ 105699, 2 }, { 105702, 3 }, { 105697, 3 }, { 105700, 1 }, { 105698, 1 },
			{ 105693, 3 }, { 105694, 1 }, { 110882, 5 }, { 105692, 1 }, { 113630, 5 },
			{ 105333, 3 }, { 110871, 2 }, { 105335, 3 }, { 105704, 2 }, { 105324, 2 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Cast Seal of Righteousness before the fight, then hit the enemy with your weapon."] },
			{ text = L["Use Judgement every time it is ready."] },
			{ text = L["Use Holy Strike for extra damage when you have Mana to spare."] },
			{ node = 105696, text = L["Seal of Command (level 20) adds more Holy damage. Use it instead of Seal of Righteousness."] },
			{ node = 105694, text = L["Repentance, a late talent, holds one Humanoid still. Two at once? Hold one, kill the other."] },
			{ text = L["Health low? Cast Holy Light between fights, or Flash of Light in a pinch."] },
			{ text = L["In real danger, use Lay on Hands, a big heal you can only use now and then."] },
		},
	},
	{
		id = "healer",
		name = L["Dungeon healer"],
		icon = "bulb",
		draft = true, -- not yet played to the top level
		suits = L["Heal your group with Holy Light and Flash of Light. You also wear heavy armor, so you can take a hit if an enemy gets to you."],
		gear = L["Intellect first, then Stamina and Spirit. Look for gear that adds healing, and a shield or a held item."],
		-- 34 Holy, 17 Protection.
		talents = {
			[105332] = { spell = 20257, why = L["More Intellect, which means more Mana for healing."] }, -- Divine Intellect
			[105335] = { spell = 20205, why = L["Flash of Light and Holy Light are less likely to be slowed when you are hit."] }, -- Spiritual Focus
			[105333] = { spell = 20237, why = L["Holy Light, Flash of Light and Holy Shock heal for more."] }, -- Healing Light
			[110871] = { spell = 1310899, why = L["Part of your Mana comes back while you cast, so you can heal for longer."] }, -- Reverence
			[105325] = { spell = 20216, why = L["Makes your next heal a critical heal, which is an extra-big one."] }, -- Divine Favor
			[105329] = { spell = 20210, why = L["A critical heal can give you some Mana back."] }, -- Illumination
			[105704] = { spell = 1237268, why = L["Consecration, Exorcism and Holy Wrath cost less Mana."] }, -- Holy Conduit
			[105324] = { spell = 1310904, why = L["Your Holy spells miss less, and Silence effects on you end sooner."] }, -- Divine Precision
			[110873] = { spell = 426065, why = L["After a critical Holy Shock or Flash of Light, your next Holy Light casts faster."] }, -- Infusion of Light
			[105330] = { spell = 1328548, why = L["Swear an Oath to one friend, and your heals on that friend heal more."] }, -- Oath of Light
			[105327] = { spell = 429144, why = L["Cleanse and Purify cost less Mana, and Exorcism and Holy Wrath are ready sooner."] }, -- Purifying Power
			[105323] = { spell = 1311606, why = L["Hurts an enemy or heals a friend."] }, -- Holy Shock
			[113631] = { spell = 1328550, why = L["Holy Shock gets more critical heals on friends who do not have your Oath."] }, -- Boundless Light
			[105321] = { spell = 5923, why = L["Your critical heals heal even more."] }, -- Holy Power
			[105320] = { spell = 1310911, why = L["Your next Holy Shock on that friend has no wait and heals their party too."] }, -- Light's Vigil
			[105637] = { spell = 20174, why = L["Blessing of Protection is ready sooner, and Blessing of Freedom lasts longer."] }, -- Guardian's Favor
			[105632] = { spell = 1224697, why = L["Divine Shield and Divine Protection are ready sooner, and Forbearance wears off faster."] }, -- Sacred Duty
			[105638] = { spell = 20189, why = L["You miss a little less often with attacks."] }, -- Precision
			[105625] = { spell = 1311015, why = L["A big shield around you for emergencies."] }, -- Templar's Bulwark
			[105633] = { spell = 20487, why = L["Hammer of Justice, a stun, is ready again sooner."] }, -- Improved Hammer of Justice
			[105630] = { spell = 20143, why = L["More Armor from your gear, so you take less damage."] }, -- Toughness
		},
		order = {
			{ 105332, 5 }, { 105335, 5 }, { 105333, 3 }, { 110871, 2 }, { 105325, 1 },
			{ 105329, 5 }, { 105704, 2 }, { 105324, 2 }, { 110873, 2 }, { 105330, 1 },
			{ 105327, 2 }, { 105323, 1 }, { 113631, 2 }, { 105321, 5 }, { 105320, 1 },
			{ 105637, 2 }, { 105632, 2 }, { 105638, 1 }, { 105625, 1 }, { 105633, 3 },
			{ 105630, 3 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Use Flash of Light for quick small heals, and Holy Light for slow, big ones."] },
			{ text = L["Cast Blessing of Wisdom (level 14) on party members who use Mana, and on yourself."] },
			{ node = 105325, text = L["Divine Favor makes your next heal a critical heal. Save it for an emergency."] },
			{ node = 105323, text = L["Holy Shock heals a friend, or hurts an enemy. Use it whenever it is ready."] },
			{ text = L["Lay on Hands saves a friend about to die. You can use it only now and then."] },
			{ text = L["Hammer of Justice stuns an enemy that is hitting your friend."] },
			{ text = L["Low on Mana? Stop healing those who are fine, and drink between fights."] },
		},
	},
	{
		id = "tank",
		name = L["Dungeon tank"],
		icon = "shield",
		draft = true, -- not yet played to the top level
		suits = L["Hold the enemies' attention in a dungeon with a shield and Righteous Fury, and take hits while your group does the damage."],
		gear = L["Stamina first, then Strength and Armor. A shield and a one-handed weapon, and the heaviest armor you can wear."],
		-- 41 Protection, 10 Holy.
		talents = {
			[105626] = { spell = 20127, why = L["After you are hit, you sometimes block more for a while."] }, -- Redoubt
			[105638] = { spell = 20189, why = L["You miss a little less often with attacks."] }, -- Precision
			[105632] = { spell = 1224697, why = L["Divine Shield and Divine Protection are ready sooner, and Forbearance wears off faster."] }, -- Sacred Duty
			[105630] = { spell = 20143, why = L["More Armor from your gear, so you take less damage."] }, -- Toughness
			[105625] = { spell = 1311015, why = L["A big shield around you for emergencies."] }, -- Templar's Bulwark
			[110874] = { spell = 20150, why = L["Your shield absorbs more damage, and blocks sometimes give you Mana."] }, -- Shield Specialization
			[105634] = { spell = 20468, why = L["With Righteous Fury on, you take less damage."] }, -- Improved Righteous Fury
			[105636] = { spell = 20096, why = L["More Defense, so enemies hit you less often."] }, -- Anticipation
			[105628] = { spell = 20925, why = L["You block much more for a while, and enemies that you block take damage."] }, -- Holy Shield
			[105627] = { spell = 20177, why = L["Blocking, and being critically hit, sometimes gives you a free extra attack."] }, -- Reckoning
			[110879] = { spell = 1311034, why = L["Holy Strike keeps more enemy attention on you, and with Righteous Fury it cuts damage you take."] }, -- Iron Creed
			[110875] = { spell = 1328544, why = L["Holy Strike is ready sooner, and works with your Holy Shield."] }, -- Shieldsworn
			[105332] = { spell = 20257, why = L["More Intellect, which means more Mana for healing yourself."] }, -- Divine Intellect
			[113630] = { spell = 20262, why = L["More Strength, so your attacks hit harder."] }, -- Divine Strength
			[105333] = { spell = 20237, why = L["Holy Light and Flash of Light heal for more, so you can heal yourself."] }, -- Healing Light
			[110871] = { spell = 1310899, why = L["Part of your Mana comes back while you cast."] }, -- Reverence
		},
		order = {
			{ 105626, 5 }, { 105638, 3 }, { 105632, 2 }, { 105630, 5 }, { 105625, 1 },
			{ 110874, 2 }, { 105634, 3 }, { 105636, 5 }, { 105628, 1 }, { 105627, 5 },
			{ 110879, 3 }, { 110875, 1 }, { 105332, 5 }, { 113630, 5 }, { 105333, 3 },
			{ 110871, 2 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Turn on Righteous Fury before a fight. It makes enemies pay more attention to you."] },
			{ text = L["Fight with a shield. Seal of Fury (level 10) gives you a small shield with each hit."] },
			{ text = L["Use Judgement and Holy Strike every time they are ready. Hitting keeps their attention."] },
			{ text = L["Judgement while Seal of Fury is on makes an enemy attack you. Use it on one hitting a friend."] },
			{ node = 105628, text = L["Holy Shield makes you block much more for a while. Use it before a hard hit."] },
			{ node = 105625, text = L["Templar's Bulwark gives you a big shield. Save it for an emergency."] },
			{ text = L["Health low? Cast Holy Light between fights, or Flash of Light in a pinch."] },
		},
	},
}
