local _, T = ...
local L = T.L

-- Priest builds. Written by tools/gen_builds.py from tools/builds/PRIEST.json: change that file,
-- not this one. Talents are keyed by the game's own node ids, each with the spell it must
-- still be; a build whose talents no longer match the live tree is not offered.

T.Builds = T.Builds or {}

T.Builds.PRIEST = {
	{
		id = "levelling",
		name = L["Easy levelling"],
		icon = "moon",
		draft = true, -- not yet played to the top level
		suits = L["Mostly Shadow spells: you hurt enemies from a distance with damage that keeps ticking while you cast the next spell. Shadowform comes in your 40s."],
		gear = L["Intellect first, then Spirit and Stamina. Use a staff or a wand, and gear that adds Spell Damage."],
		-- 35 Shadow, 16 Discipline.
		talents = {
			[105850] = { spell = 14524, why = L["Your wand does more damage, so it is free damage when your mana runs out."] }, -- Wand Specialization
			[110851] = { spell = 15260, why = L["Your Shadow spells miss less often."] }, -- Shadow Focus
			[105832] = { spell = 15326, why = L["Your Shadow damage spells sometimes stun the enemy for a moment."] }, -- Blackout
			[105831] = { spell = 15273, why = L["Mind Blast is ready again much sooner, so you can use it more."] }, -- Improved Mind Blast
			[105830] = { spell = 15275, why = L["Shadow Word: Pain lasts longer, so you cast it less often."] }, -- Improved Shadow Word: Pain
			[105826] = { spell = 15407, why = L["A spell you hold down that hurts the enemy and slows how fast it moves."] }, -- Mind Flay
			[105825] = { spell = 1225139, why = L["Each tick of Mind Flay hits harder than the one before it."] }, -- Improved Mind Flay
			[105820] = { spell = 15286, why = L["Heals your party from your Shadow damage, and it opens Shadowform."] }, -- Vampiric Embrace
			[105821] = { spell = 15257, why = L["Each Shadow spell makes the enemy take more Shadow damage from you."] }, -- Shadow Weaving
			[105823] = { spell = 1326159, why = L["Mind Blast and a full Mind Flay raise your and your party's Spirit for a while."] }, -- Dark Inspiration
			[105818] = { spell = 15259, why = L["All your Shadow damage goes up."] }, -- Darkness
			[105817] = { spell = 15473, why = L["Your Shadow spells hurt more and cost half the Mana, and you take less Physical damage."] }, -- Shadowform
			[105849] = { spell = 1225132, why = L["Your instant spells do more damage and healing."] }, -- Twin Disciplines
			[105837] = { spell = 18551, why = L["More Intellect, which means a bigger pool of mana."] }, -- Mental Strength
			[105843] = { spell = 14521, why = L["Part of your mana regeneration keeps going while you cast."] }, -- Meditation
			[105844] = { spell = 14751, why = L["A button that makes your next spell free and more likely to crit."] }, -- Inner Focus
		},
		order = {
			{ 105850, 2 }, { 110851, 5 }, { 105832, 5 }, { 105831, 5 }, { 105830, 2 },
			{ 105826, 1 }, { 105825, 2 }, { 105820, 1 }, { 105821, 3 }, { 105823, 5 },
			{ 105818, 1 }, { 105817, 1 }, { 105818, 4 }, { 105849, 5 }, { 105837, 5 },
			{ 105843, 3 }, { 105844, 1 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Put Shadow Word: Pain on the enemy first, then use Mind Blast whenever it is ready."] },
			{ text = L["Use Smite to fill the gaps. Put Power Word: Shield on yourself before a hard fight."] },
			{ text = L["Hurt after a fight? Rest and let your health and mana fill up before the next one."] },
			{ node = 105826, text = L["Hold Mind Flay between Mind Blasts. It also slows the enemy so it reaches you later."] },
			{ node = 105817, text = L["Turn on Shadowform before you pull, so every Shadow spell costs less mana."] },
			{ node = 105844, text = L["Out of mana in a long fight? Press Inner Focus so your next spell is free."] },
			{ text = L["Losing a fight? Put Power Word: Shield on yourself and back away."] },
		},
	},
	{
		id = "healer",
		name = L["Dungeon healer"],
		icon = "wing",
		draft = true, -- not yet played to the top level
		suits = L["You keep your party alive in a dungeon, mostly with Holy healing. Renew heals over time, and Power Word: Shield stops a hit before it lands."],
		gear = L["Intellect first, then Spirit and Stamina. Use a staff, a wand, or a held item that adds healing."],
		-- 31 Holy, 20 Discipline.
		talents = {
			[105866] = { spell = 14908, why = L["Renew heals more on every target."] }, -- Improved Renew
			[105867] = { spell = 14913, why = L["Spells are less likely to be slowed down when you get hit."] }, -- Twilight Focus
			[105863] = { spell = 18530, why = L["Heal and Greater Heal cast faster, so hurt allies get help sooner."] }, -- Divine Fury
			[105864] = { spell = 27900, why = L["You take less damage from enemy spells."] }, -- Spell Warding
			[105861] = { spell = 27811, why = L["After a big hit on you, you heal yourself for a while."] }, -- Blessed Recovery
			[105858] = { spell = 14912, why = L["Heal, Greater Heal and Prayer of Mending cost less mana."] }, -- Improved Healing
			[105856] = { spell = 1328569, why = L["Flash Heal on a friend also heals you."] }, -- Holy Binding
			[105855] = { spell = 1317006, why = L["Mana comes back when you mix different heals."] }, -- Litany of Light
			[105854] = { spell = 20711, why = L["If you die you can still heal for a short time, and it opens Prayer of Mending."] }, -- Spirit of Redemption
			[105853] = { spell = 14901, why = L["Your Spirit makes your healing stronger."] }, -- Spiritual Guidance
			[105851] = { spell = 401859, why = L["A heal that jumps from one ally to the next as they take damage."] }, -- Prayer of Mending
			[105849] = { spell = 1225132, why = L["Your instant spells, such as Renew, heal for more."] }, -- Twin Disciplines
			[105837] = { spell = 18551, why = L["More Intellect, which means a bigger pool of mana."] }, -- Mental Strength
			[105842] = { spell = 14520, why = L["Renew and your other instant spells cost less mana."] }, -- Mental Agility
			[105846] = { spell = 14748, why = L["Your Power Word: Shield soaks up more damage."] }, -- Improved Power Word: Shield
			[105844] = { spell = 14751, why = L["A button that makes your next heal free and more likely to crit."] }, -- Inner Focus
			[105843] = { spell = 14521, why = L["Part of your mana regeneration keeps going while you cast."] }, -- Meditation
		},
		order = {
			{ 105866, 3 }, { 105867, 3 }, { 105863, 5 }, { 105864, 5 }, { 105861, 3 },
			{ 105858, 3 }, { 105856, 1 }, { 105855, 2 }, { 105854, 1 }, { 105853, 4 },
			{ 105851, 1 }, { 105849, 5 }, { 105837, 5 }, { 105842, 3 }, { 105846, 3 },
			{ 105844, 1 }, { 105843, 3 },
		},
		-- What to press. A line with a node is shown once that talent has a point in it.
		fight = {
			{ text = L["Watch your party's health bars. Heal whoever is lowest."] },
			{ text = L["Put Renew on anyone who keeps taking damage. Power Word: Shield stops a hit before it lands."] },
			{ text = L["Use Lesser Heal to top people up, and Heal (level 16) for bigger heals. Skip it if no one is hurt."] },
			{ node = 105863, text = L["Use Heal on the player taking hits. It is quicker to cast now."] },
			{ node = 105851, text = L["Put Prayer of Mending on the tank. It jumps by itself as they take damage."] },
			{ node = 105844, text = L["A big hit and your mana is low? Press Inner Focus, then cast a heal for free."] },
			{ text = L["Mana low? Stop and drink, or ask the party to wait for you."] },
		},
	},
}
