local _, T = ...
local L = T.L

-- Druid builds. Written by tools/gen_builds.py from tools/builds/DRUID.json: change that file,
-- not this one. Talents are keyed by the game's own node ids, each with the spell it must
-- still be; a build whose talents no longer match the live tree is not offered.

T.Builds = T.Builds or {}

T.Builds.DRUID = {
	{
		id = "levelling",
		name = L["Easy levelling"],
		icon = "mtn",
		draft = true, -- not yet played to the top level
		suits = L["Fight in Bear Form to start, then Cat Form from level 20. You take hits well and can heal yourself between fights."],
		gear = L["Strength, Agility and Stamina. Leather armor, and a staff or other two-handed weapon. A little Intellect helps your healing."],
		-- 31 Feral Combat, 20 Restoration.
		talents = {
			[104938] = { spell = 16934, why = L["Maul, and later Claw and Rake, cost less Rage or Energy, so you can use them more."] }, -- Ferocity
			[104942] = { spell = 16929, why = L["More armor in your animal forms, so you take less damage."] }, -- Thick Hide
			[104943] = { spell = 17002, why = L["You run faster in Cat Form (level 20), and you dodge more."] }, -- Feral Swiftness
			[104948] = { spell = 16998, why = L["Claw, Rake, Shred, Maul and Swipe hit harder, and it opens Lacerate."] }, -- Savage Fury
			[104945] = { spell = 16966, why = L["Shred costs less Energy, so your Cat Form attacks come faster."] }, -- Shredding Attacks
			[104952] = { spell = 16972, why = L["Your melee attacks hit harder in Cat Form and Bear Form."] }, -- Predatory Strikes
			[104946] = { spell = 16942, why = L["More critical strikes while in Bear Form or Cat Form."] }, -- Sharpened Claws
			[104955] = { spell = 17007, why = L["Your group gets more critical strikes while you are in an animal form."] }, -- Leader of the Pack
			[104949] = { spell = 1328617, why = L["A bleed attack that stacks on the enemy. Rend and Tear makes your hits stronger against it."] }, -- Lacerate
			[104950] = { spell = 1223242, why = L["Your melee critical strikes hit harder."] }, -- Natural Instinct
			[104939] = { spell = 17056, why = L["Helps you start strong when you change into Bear Form or Cat Form."] }, -- Furor
			[104953] = { spell = 1223246, why = L["Your melee attacks hit harder against bleeding enemies."] }, -- Rend and Tear
			[104956] = { spell = 407995, why = L["A strong bite attack, and it makes the enemy pay more attention to you."] }, -- Primal Bite
			[104958] = { spell = 17003, why = L["More Intellect, more Stamina in Bear Form, more Strength in Cat Form."] }, -- Heart of the Wild
			[104919] = { spell = 16833, why = L["Changing form costs less Mana, so you can change often."] }, -- Natural Shapeshifter
			[104920] = { spell = 17106, why = L["Part of your Mana comes back while you cast, so healing costs less downtime."] }, -- Reflection
			[104916] = { spell = 17104, why = L["Your healing spells heal a little more."] }, -- Gift of Nature
			[104914] = { spell = 17111, why = L["Rejuvenation heals more, so you recover faster after a fight."] }, -- Improved Rejuvenation
			[104912] = { spell = 18562, why = L["An instant heal for anyone who has your Rejuvenation or Regrowth on them."] }, -- Swiftmend
		},
		order = {
			{ 104938, 5 }, { 104942, 3 }, { 104943, 2 }, { 104948, 2 }, { 104945, 3 },
			{ 104952, 3 }, { 104946, 2 }, { 104955, 1 }, { 104949, 1 }, { 104950, 2 },
			{ 104939, 1 }, { 104953, 5 }, { 104956, 1 }, { 104958, 5 }, { 104919, 3 },
			{ 104920, 3 }, { 104916, 5 }, { 104914, 3 }, { 104912, 1 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Change into Bear Form, then use Maul and Growl to keep the enemy on you."] },
			{ text = L["Moonfire from a distance starts a fight, then change into Bear Form as it arrives."] },
			{ node = 104945, text = L["Cat Form (level 20): Claw, or Shred from behind, builds points. Ferocious Bite (level 24) spends them."] },
			{ node = 104949, text = L["In Bear Form use Lacerate again and again so the bleed grows."] },
			{ text = L["After a fight, cast Rejuvenation on yourself (and Regrowth from level 12), then move on."] },
			{ node = 104912, text = L["Hurt badly? Swiftmend heals you at once if you have Rejuvenation or Regrowth on you."] },
			{ text = L["Losing a fight? Change into Bear Form, and heal yourself with Rejuvenation."] },
		},
	},
	{
		id = "healer",
		name = L["Dungeon healer"],
		icon = "bulb",
		draft = true, -- not yet played to the top level
		suits = L["Keeps your group alive with healing spells that work over time. Wild Growth, late in the build, heals a whole party."],
		gear = L["Intellect first, then Spirit and Stamina. Look for gear that adds healing, in cloth or leather, and a staff or a held item."],
		-- 46 Restoration, 5 Balance.
		talents = {
			[104957] = { spell = 17063, why = L["Your Nature spells are less likely to be slowed when you are hit."] }, -- Nature's Focus
			[104958] = { spell = 17003, why = L["More Intellect, which means more Mana for healing."] }, -- Heart of the Wild
			[104922] = { spell = 17069, why = L["Healing Touch casts faster, and it opens Nature's Swiftness."] }, -- Naturalist
			[104920] = { spell = 17106, why = L["Part of your Mana comes back while you cast."] }, -- Reflection
			[104916] = { spell = 17104, why = L["Your healing spells heal a little more."] }, -- Gift of Nature
			[104914] = { spell = 17111, why = L["Rejuvenation heals more, and it opens Improved Regrowth."] }, -- Improved Rejuvenation
			[104912] = { spell = 18562, why = L["An instant heal for a friend who has your Rejuvenation or Regrowth on them."] }, -- Swiftmend
			[104921] = { spell = 17116, why = L["Your next Nature spell is instant, so you can rescue someone fast."] }, -- Nature's Swiftness
			[104911] = { spell = 1309631, why = L["More Spirit, and it opens Wild Growth."] }, -- Living Spirit
			[104917] = { spell = 17118, why = L["Your healing spells draw less attention from enemies."] }, -- Subtlety
			[104915] = { spell = 24968, why = L["Healing Touch and Tranquility cost less Mana."] }, -- Tranquil Spirit
			[104913] = { spell = 17074, why = L["Regrowth critical heals happen more often."] }, -- Improved Regrowth
			[104910] = { spell = 408120, why = L["Heals your target and the party members near them over a short time."] }, -- Wild Growth
			[104918] = { spell = 1328621, why = L["When Rejuvenation or Regrowth runs out, the friend gets a final heal."] }, -- Bloom
			[104924] = { spell = 1223081, why = L["Your healing over time heals a little more."] }, -- Genesis
		},
		order = {
			{ 104957, 5 }, { 104958, 5 }, { 104922, 5 }, { 104920, 3 }, { 104916, 5 },
			{ 104914, 3 }, { 104912, 1 }, { 104921, 1 }, { 104911, 3 }, { 104917, 3 },
			{ 104915, 5 }, { 104913, 5 }, { 104910, 1 }, { 104918, 1 }, { 104924, 5 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Put Rejuvenation on whoever is being hit. It heals them over time."] },
			{ text = L["Use Healing Touch for a big heal. From level 12, Regrowth helps when someone is in trouble."] },
			{ text = L["Cast Mark of the Wild on everyone before the first fight."] },
			{ node = 104912, text = L["Swiftmend heals at once when Rejuvenation or Regrowth is on that friend."] },
			{ node = 104921, text = L["In an emergency, Nature's Swiftness makes your next heal instant."] },
			{ node = 104910, text = L["When the whole group is hurt, use Wild Growth on the one who is hit most."] },
			{ text = L["Run low on Mana? Stop healing those who are fine and drink between fights."] },
		},
	},
	{
		id = "tank",
		name = L["Dungeon tank"],
		icon = "shield",
		draft = true, -- not yet played to the top level
		suits = L["Fight in Bear Form and keep enemies on you while your group hits them. You take a lot of damage and have the armor for it."],
		gear = L["Stamina and Armor first, then Strength and Agility. Leather armor, and a staff or other two-handed weapon."],
		-- 40 Feral Combat, 11 Restoration.
		talents = {
			[104938] = { spell = 16934, why = L["Maul, and later Claw and Rake, cost less Rage or Energy."] }, -- Ferocity
			[104942] = { spell = 16929, why = L["More Armor in your animal forms, so you take less damage."] }, -- Thick Hide
			[104940] = { spell = 16947, why = L["Swipe, your attack that hits several enemies, does more damage."] }, -- Feral Instinct
			[104948] = { spell = 16998, why = L["Maul, Swipe and Claw hit harder, and it opens Lacerate."] }, -- Savage Fury
			[104945] = { spell = 16966, why = L["Lacerate costs less Rage, so you can use it more often."] }, -- Shredding Attacks
			[104949] = { spell = 1328617, why = L["A bleed that stacks on the enemy and draws a lot of its attention to you."] }, -- Lacerate
			[104946] = { spell = 16942, why = L["More critical strikes in Bear Form, and it opens Blood Frenzy."] }, -- Sharpened Claws
			[104952] = { spell = 16972, why = L["You hit harder with every attack in Bear Form."] }, -- Predatory Strikes
			[104947] = { spell = 16958, why = L["Critical strikes give you extra Rage, so you can use your attacks more."] }, -- Blood Frenzy
			[104941] = { spell = 16940, why = L["Bash stuns for longer and is ready again sooner."] }, -- Brutal Impact
			[104955] = { spell = 17007, why = L["Your group gets more critical strikes while you are in Bear Form."] }, -- Leader of the Pack
			[104950] = { spell = 1223242, why = L["Your melee critical strikes hit harder."] }, -- Natural Instinct
			[104939] = { spell = 17056, why = L["Changing into Bear Form can give you Rage to start a fight with."] }, -- Furor
			[104953] = { spell = 1223246, why = L["Your attacks hit harder against bleeding enemies, such as ones with Lacerate."] }, -- Rend and Tear
			[104956] = { spell = 407995, why = L["A strong bite attack, and it makes the enemy pay more attention to you."] }, -- Primal Bite
			[104958] = { spell = 17003, why = L["Much more Stamina in Bear Form, so you have more Health."] }, -- Heart of the Wild
			[104919] = { spell = 16833, why = L["Changing form costs less Mana."] }, -- Natural Shapeshifter
			[104920] = { spell = 17106, why = L["Part of your Mana comes back while you cast, so you can heal yourself."] }, -- Reflection
		},
		order = {
			{ 104938, 5 }, { 104942, 3 }, { 104940, 3 }, { 104948, 2 }, { 104945, 3 },
			{ 104949, 1 }, { 104946, 2 }, { 104952, 3 }, { 104947, 2 }, { 104941, 2 },
			{ 104955, 1 }, { 104950, 2 }, { 104939, 5 }, { 104953, 5 }, { 104956, 1 },
			{ 104958, 5 }, { 104919, 3 }, { 104920, 3 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Change into Bear Form. Start each fight with Growl, so the enemy attacks you."] },
			{ text = L["Use Maul as your main attack, and Demoralizing Roar to make enemies hit softer."] },
			{ node = 104949, text = L["Use Lacerate again and again on the main enemy. The bleed grows and keeps its attention on you."] },
			{ text = L["Bash (level 14) stuns an enemy for a moment. Use it to stop a hard hit."] },
			{ text = L["Several enemies? Swipe hits them all. At level 28, Challenging Roar makes all of them attack you."] },
			{ text = L["Keep an eye on your Health. Rejuvenation on yourself between fights saves your healer."] },
		},
	},
}
