local _, T = ...
local L = T.L

-- Shaman builds. Written by tools/gen_builds.py from tools/builds/SHAMAN.json: change that file,
-- not this one. Talents are keyed by the game's own node ids, each with the spell it must
-- still be; a build whose talents no longer match the live tree is not offered.

T.Builds = T.Builds or {}

T.Builds.SHAMAN = {
	{
		id = "levelling",
		name = L["Easy levelling"],
		icon = "hammer",
		draft = true, -- not yet played to the top level
		suits = L["Fight up close with weapon hits, backed by Lightning Shield. Stormstrike at level 25 and a steady supply of Mana make the fights easy to follow."],
		gear = L["Intellect first, as it adds attack power and Mana. Then Stamina. A slow two-handed weapon, or a one-hander and shield, works well."],
		-- 33 Enhancement, 18 Restoration.
		talents = {
			[104753] = { spell = 16255, why = L["More critical strikes with every spell and attack."] }, -- Thundering Strikes
			[104756] = { spell = 17485, why = L["More Intellect, which means more mana and, with Mental Dexterity, more attack power."] }, -- Ancestral Knowledge
			[104755] = { spell = 415140, why = L["Your Intellect is added to your attack power, so weapon hits get stronger."] }, -- Mental Dexterity
			[104749] = { spell = 1223030, why = L["Shocks and Lightning Shield cost much less Mana."] }, -- Shamanistic Focus
			[104750] = { spell = 16266, why = L["Your weapon enchantments, such as Rockbiter Weapon, work better."] }, -- Elemental Weapons
			[104743] = { spell = 17364, why = L["A strong instant hit that also makes your next Lightning Bolt or Earth Shock hit harder."] }, -- Stormstrike
			[104752] = { spell = 16262, why = L["Ghost Wolf, your run-fast form, casts faster and works indoors."] }, -- Improved Ghost Wolf
			[104747] = { spell = 16256, why = L["After a critical strike you swing faster for a few hits."] }, -- Flurry
			[104744] = { spell = 30812, why = L["Your spells hit harder using your Intellect, and it opens Rage of the Farseer."] }, -- Mental Quickness
			[104741] = { spell = 408498, why = L["Weapon hits can make your next Lightning Bolt faster and cheaper."] }, -- Maelstrom Weapon
			[104740] = { spell = 425336, why = L["A button that makes you attack much faster for a while."] }, -- Rage of the Farseer
			[104729] = { spell = 16179, why = L["Healing spells cost less mana and you miss less often."] }, -- Tidal Focus
			[104739] = { spell = 16182, why = L["Healing Wave casts faster, so you can heal yourself sooner."] }, -- Improved Healing Wave
			[104734] = { spell = 1223033, why = L["Part of your mana regeneration keeps going while you cast."] }, -- Mindfulness
			[104737] = { spell = 16184, why = L["Reincarnation is ready sooner, and your health is a little higher."] }, -- Improved Reincarnation
			[104732] = { spell = 408510, why = L["A shield that gives mana back as you are hit. Less waiting to drink."] }, -- Water Shield
			[104735] = { spell = 16173, why = L["Totems cost less mana, so you can drop one every fight."] }, -- Totemic Focus
		},
		order = {
			{ 104753, 5 }, { 104756, 5 }, { 104755, 3 }, { 104749, 1 }, { 104750, 1 },
			{ 104743, 1 }, { 104752, 2 }, { 104750, 2 }, { 104747, 5 }, { 104744, 2 },
			{ 104741, 5 }, { 104740, 1 }, { 104729, 5 }, { 104739, 5 }, { 104734, 3 },
			{ 104737, 2 }, { 104732, 1 }, { 104735, 2 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Put Rockbiter Weapon on your weapon, and keep Lightning Shield on you."] },
			{ text = L["Start with Lightning Bolt as the enemy runs to you, then hit it in melee."] },
			{ text = L["Use Earth Shock whenever it is ready for extra damage."] },
			{ node = 104743, text = L["Use Stormstrike every time it is ready, then follow it with Lightning Bolt."] },
			{ node = 104741, text = L["When Lightning Bolt gets cheap and fast after weapon hits, cast it."] },
			{ node = 104732, text = L["Keep Water Shield on between fights to win mana back."] },
			{ text = L["Health low? Step back and cast Healing Wave on yourself."] },
		},
	},
	{
		id = "healer",
		name = L["Dungeon healer"],
		icon = "wing",
		draft = true, -- not yet played to the top level
		suits = L["Keeps a group of five alive with Healing Wave and, later, Chain Heal and Riptide. Stay back, watch health bars and spend mana wisely."],
		gear = L["Intellect first, then Stamina and Spirit. Look for items that add healing."],
		-- 31 Restoration, 20 Enhancement.
		talents = {
			[104739] = { spell = 16182, why = L["Healing Wave casts faster, so your big heal lands sooner."] }, -- Improved Healing Wave
			[104729] = { spell = 16179, why = L["Healing spells cost less mana, so you can heal for longer."] }, -- Tidal Focus
			[104734] = { spell = 1223033, why = L["Part of your mana regeneration keeps going while you cast."] }, -- Mindfulness
			[104733] = { spell = 16181, why = L["Being hit is less likely to slow down your healing spells."] }, -- Healing Focus
			[104732] = { spell = 408510, why = L["A shield that gives mana back as you are hit or score a critical strike."] }, -- Water Shield
			[104728] = { spell = 16190, why = L["A totem that gives mana to your whole group. Use it when you run low."] }, -- Mana Tide Totem
			[104738] = { spell = 16194, why = L["Your healing spells critically strike more often."] }, -- Tidal Mastery
			[104727] = { spell = 29206, why = L["Healing Wave heals more."] }, -- Healing Way
			[104726] = { spell = 16188, why = L["Your next Nature spell is instant. Use it for an emergency heal."] }, -- Nature's Swiftness
			[104725] = { spell = 16178, why = L["All your healing spells heal more."] }, -- Purification
			[104724] = { spell = 408521, why = L["A heal that keeps healing over time, and it makes Chain Heal stronger on that target."] }, -- Riptide
			[104756] = { spell = 17485, why = L["More Intellect, which means more mana."] }, -- Ancestral Knowledge
			[104753] = { spell = 16255, why = L["More critical strikes with all spells and attacks, healing included."] }, -- Thundering Strikes
			[104748] = { spell = 16254, why = L["A little more chance to dodge enemy hits."] }, -- Anticipation
			[104754] = { spell = 16258, why = L["Stoneskin Totem blocks more damage, which helps the whole group."] }, -- Guardian Totems
			[104757] = { spell = 16043, why = L["Stoneclaw Totem is tougher and Earthbind Totem reaches further."] }, -- Earth's Grasp
			[104751] = { spell = 16261, why = L["Lightning Shield hurts attackers more when they hit you."] }, -- Improved Lightning Shield
		},
		order = {
			{ 104739, 5 }, { 104729, 5 }, { 104734, 3 }, { 104733, 3 }, { 104732, 1 },
			{ 104728, 1 }, { 104738, 2 }, { 104727, 3 }, { 104726, 1 }, { 104738, 1 },
			{ 104725, 5 }, { 104724, 1 }, { 104756, 5 }, { 104753, 5 }, { 104748, 3 },
			{ 104754, 2 }, { 104757, 2 }, { 104751, 3 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Cast Healing Wave on whoever has the lowest health bar. Heal early."] },
			{ text = L["Between fights, sit down and drink so your Mana comes back."] },
			{ text = L["Lesser Healing Wave (level 20) is a fast heal for someone in trouble."] },
			{ node = 104732, text = L["Keep Water Shield on you. It gives mana back as you are hit."] },
			{ node = 104724, text = L["Put Riptide on the one taking damage, then use Chain Heal on that same target."] },
			{ node = 104726, text = L["Someone about to die? Press Nature's Swiftness, then Healing Wave."] },
			{ node = 104728, text = L["Mana low in a long fight? Drop Mana Tide Totem."] },
		},
	},
}
