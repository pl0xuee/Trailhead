local _, T = ...
local L = T.L
T.DungeonGuides = T.DungeonGuides or {}

-- Dungeons and raids that are new in Forever. Boss names follow the game's own encounter table.
-- Where we only know the boss list, steps carry no real route (we say so honestly).
-- Sources: Warcraft Tavern Forever guides, wowclassicforever.info, kami-labs.fr (early 2026 notes).

local UNKNOWN = L["We do not know yet where this boss stands."]

T.DungeonGuides[3065] = {
	summary = L["The old dwarf burial halls under Ironforge, now overrun by ghosts and Dark Iron dwarves. Four bosses."],
	door = L["In Ironforge, go to the king's hall and turn left to a web-covered passage. Follow it down. Do not fall off the edge."],
	tips = { L["Shoot the powder kegs from range to hurt groups of dwarves."], L["Early reports say the quests are for the Alliance. We have not confirmed it."] },
	steps = {
		{ text = L["From the entrance, clear the ghosts and take the west corridor."] },
		{ boss = "Faldrim Anvilmar", where = L["In the big tomb room at the end of the west corridor. He patrols the tomb."], tip = L["His curse slows the tank. Remove it if you can."] },
		{ text = L["Leave through the south-east corridor, past Dark Iron dwarves, toward a natural cave."] },
		{ boss = "Infurnus", where = L["In the natural cave beyond the tombs, with Dark Iron dwarves around."], tip = L["Kill the summoner dwarf first and keep ranged players away from him."] },
		{ text = L["Follow the cave tunnel back up into the main hall."] },
		{ boss = "Plunder", where = L["Patrols the main hall. Pull him away from other enemies."], tip = L["Tank him with your back to a wall so his knock-back does not throw you."] },
		{ text = L["Cross the bridge to the north."] },
		{ boss = "Durgen Dirgehammer", where = L["In the Reliquary of Kings, the room across the north bridge."], tip = L["Clear the room first. His fear scatters the group and pulls the rest."] },
	},
}

T.DungeonGuides[2999] = {
	summary = L["The ruined old city of Lordaeron under the Undercity, with wave fights and a graveyard. Seven bosses, one is rare. Early reports say it suits the Horde best."],
	door = L["In Tirisfal Glades, at the Undercity gate. Reports say the stairs are on the left before the keep."],
	tips = { L["Cure the disease called Ghoul Plague at once. It slows you."], L["Fill your mana before the wave fights."] },
	steps = {
		{ text = L["Go down the stairs heading east into the first area."] },
		{ boss = "Witherfang", where = L["Patrols the first area with small spiders. Jump through the right window to skip the web gate."], tip = L["Kill his spiderlings first."] },
		{ text = L["Head south along the left wall and turn right past the three ghost citizens."] },
		{ boss = "The Butcher", where = L["In his arena to the west, past the ghost citizens."], tip = L["Melee should stand behind him, away from his frontal cone."] },
		{ text = L["Go forward into the graveyard and on to a burned house with a fireplace."] },
		{ boss = "Viktor the Vile", where = L["At the fireplace of the burned house. Five waves of undead come first."], tip = L["Start with full mana. Five waves arrive before he does."] },
		{ boss = "The Abandoned", where = L["In the courtyard. Touch the statue with glowing eyes to start waves."], tip = L["Interrupt his life drain. Three waves come from both sides."] },
		{ boss = "Lordaeron Captain", where = L["A rare boss on the west side. Reports say only Horde can fight him."], tip = L["Skip him if you cannot reach him."], optional = true },
		{ boss = "Bjork", where = L["North-west section. From the courtyard, go through the narrow stairs, turn right, then jump through the big window."], tip = L["Her shield blocks spells. Use weapons or wait."] },
		{ boss = "Rath'mael", where = L["South, in the fenced graveyard. This is the last boss."], tip = L["Do not stand near the tank when he casts his fire spell."] },
	},
}

T.DungeonGuides[2998] = {
	summary = L["A dig site in the Wetlands where the Dragonmaw orcs are digging up old relics. Four bosses."],
	door = L["In the Wetlands, take the winding path left of Thelgen Rock. The entrance is a cave at the end."],
	tips = { L["Bring a way to cure disease and poison."], L["Healers should watch for raptor bleeds."] },
	steps = {
		{ text = L["From the entrance slope, walk into the Lost Marsh."] },
		{ boss = "Saltspine", where = L["A huge crocolisk that patrols the Lost Marsh, just past the entrance slope."], tip = L["Keep ranged players and healers out of his dust cloud."] },
		{ text = L["Cross the marsh to Stalker's Thicket, a field of tall grass full of raptors."] },
		{ boss = "Shadetooth", where = L["In Stalker's Thicket, with two helper hunters. Some raptors are hidden."], tip = L["Kill the helper hunters first and cure his fear."] },
		{ text = L["Go on to the Lost Dig Site where the orcs work. Do not pull too many at once."] },
		{ boss = "Highland Horror", where = L["North of the Lost Dig Site, ringed by oil slimes."], tip = L["Pull it alone and interrupt its healing. It drops almost nothing."], optional = true },
		{ text = L["From the dig site, go south through spiders to the Site of the Guardian."] },
		{ boss = "Relic Guardian", where = L["At the Site of the Guardian. Click the panel by the right column to start."], tip = L["Do not tank near the edge. He knocks you back."] },
	},
}

T.DungeonGuides[2959] = {
	summary = L["The old wizard city of Dalaran, now a dungeon below and in its streets, with strange magic bosses. Nine bosses, some are secret."],
	door = L["Through the sewers under the Cantrips and Crows bar in Silverpine Forest. Reports say you need a key from a quest chain. We have not confirmed it."],
	tips = { L["Do the quests first. Reports say they give the key."], L["Clear every guard before you pull a boss. They join the fight."] },
	steps = {
		{ text = L["Start in the bar in the sewers. Cross the bridge and turn right, not to the locked door."] },
		{ boss = "Atrexis the Grave Knight", where = L["In the sewer's Underbelly, past three big pipes, in a summoning circle."], tip = L["The tank must pick up the skeletons he calls."] },
		{ boss = "Lyn the Ignored", where = L["Secret boss in the sewers. Needs the Tome of Dalaran to call her."], tip = L["Remove her curse from the tank quickly."], optional = true },
		{ text = L["Climb out of the sewers into the streets of Dalaran."] },
		{ boss = "Mana Devourer", where = L["In the Violet Hold, to the left in the streets."], tip = L["Clear the whole hold first. He drains mana."] },
		{ boss = "Arcane Anomaly", where = L["Right of the Violet Hold, in the old landing area."], tip = L["Stand behind the boss to avoid his sweeping beam."] },
		{ boss = "Fel Ancient", where = L["In the central Runeweaver Square. Speak to Magus Fansy Goodbringer to drop the barrier."], tip = L["Break roots if you can. Stay out of the green pools."] },
		{ boss = "Mana Elemental", where = UNKNOWN, tip = L["One of the Mana Elemental and Mana Wraith is the boss in the Path of Renewal. It is not clear which."], optional = true },
		{ boss = "Mana Wraith", where = UNKNOWN, tip = L["One of the Mana Elemental and Mana Wraith is the boss in the Path of Renewal. It is not clear which."], optional = true },
		{ boss = "Unstable Sentinel", where = L["Further west, in a nook at the Magus Commerce Exchange."], tip = L["Spread out. Melee should step away from his big blast."] },
		{ boss = "Shade of the Archmage", where = L["In the Violet Chamber. Talk to Archmage Modera on the Violet Citadel steps to go in."], tip = L["Spread out. When he runs out of mana he turns the group into sheep."] },
	},
}

T.DungeonGuides[2970] = {
	summary = L["A troll city that sank into the sea off Stranglethorn Vale. We know only part of the route."],
	door = L["Swim past The Vile Reef to the Sunken Hollow. A cave with a large tablet beside it is the entrance, underwater."],
	tips = { L["Bring a way to breathe underwater if you have one."] },
	steps = {
		{ text = L["From the cave, climb a hill toward the main ruins. Light enemies come first."] },
		{ boss = "Zul'Alai", where = L["The first boss, just up the path from the cave."], tip = L["Spread out. Save a defensive for when he is nearly dead."] },
		{ text = L["Beyond him, turn right and climb to a view of the city. The path splits."] },
		{ boss = "Var'Taka", where = L["At the top of a staircase on the left path, in a room with a pool."], tip = L["Kill both of his healers before him."] },
		{ text = L["Dive into the pool beside the staircase to reach the flooded tomb."] },
		{ boss = "Deathless Guardians", where = L["In the flooded tomb under the pool, reached by swimming."], tip = L["Kill all but one or two so the last boss does not spawn early."] },
		{ boss = "Primeval Elemental", where = L["Appears in the flooded tomb when the last guardian dies."], tip = L["Save a big heal for his freezing water spell."] },
		{ boss = "Captain Dreadrise", where = UNKNOWN, tip = L["Nothing known yet."] },
		{ boss = "Min'loth the Serpent", where = L["Deeper in the city. Exact place is not known."], tip = L["Nothing known yet."] },
	},
}

T.DungeonGuides[3039] = {
	summary = L["An ogre fortress in Riverglades, run by the Twilight cult. The route winds up a hill. We know only part of it."],
	door = L["In the Riverglades, a cave to the west of the big fortress gates, near a meeting stone."],
	tips = { L["Do not chain-pull. Wait for the ogre patrols to pass."] },
	steps = {
		{ text = L["Go in through the cave and follow the winding path uphill between rough buildings."] },
		{ boss = "Slavecrusher Grox", where = L["Early in the stronghold. Exact place is not known."], tip = L["The ogre patrols before him are the real danger."] },
		{ boss = "Twilight Commander Zarmok", where = L["After Grox. His death opens the big gate behind him."], tip = L["He gives the tank a heavy bleed. Cure it if you can."] },
		{ boss = "Handler Ashka", where = UNKNOWN, tip = L["He may stand off the main road, with wolves."] },
		{ boss = "Nar'gurk", where = UNKNOWN, tip = L["He takes control of a player. Heal them and stop damage to them."] },
		{ boss = "Overseer Mugg", where = L["The last boss, in a large room at the top. Cross the big bridge first."], tip = L["Kill his helpers first and spread out."] },
	},
}

T.DungeonGuides[2974] = {
	summary = L["A bear and boar people stronghold deep inside Azshara. We only know the boss list, not the route."],
	door = L["Enter the furbolg tunnel in northern Azshara. The portal is deep inside it."],
	tips = {},
	steps = {
		{ boss = "Withermaw", where = UNKNOWN },
		{ boss = "Impaan the Imprisoner", where = UNKNOWN },
		{ boss = "Elder Shaman Bloodmane", where = UNKNOWN },
		{ boss = "Bonesnout the Unbroken", where = UNKNOWN },
		{ boss = "Varrox Bleakhoof", where = UNKNOWN },
		{ boss = "Blackmaw Behemoth", where = UNKNOWN },
		{ boss = "Unbound Spirit", where = UNKNOWN },
	},
}

T.DungeonGuides[2994] = {
	summary = L["The famous island prison off Dustwallow Marsh. We only know the boss list, not the route."],
	door = L["On Alcaz Island, off the shore of Dustwallow Marsh. The entrance is in the basement of the large building."],
	tips = {},
	steps = {
		{ boss = "Overseer Wrex", where = UNKNOWN },
		{ boss = "Tidemistress Ca'zass", where = UNKNOWN },
		{ boss = "Katerina the Cleaner", where = UNKNOWN },
		{ boss = "The Questioner", where = UNKNOWN },
		{ boss = "Blazeroar", where = UNKNOWN },
	},
}

T.DungeonGuides[3001] = {
	summary = L["A titan facility in Un'Goro Crater. We only know the boss list, not the route."],
	door = L["On a hill over Marshal's Refuge in Un'Goro Crater."],
	tips = {},
	steps = {
		{ boss = "Titanosaur", where = UNKNOWN },
		{ boss = "Ravasaur Hunters", where = UNKNOWN },
		{ boss = "Thunderhoof", where = UNKNOWN },
		{ boss = "Venomridge", where = UNKNOWN },
		{ boss = "Direhorn Matriarch", where = UNKNOWN },
		{ boss = "Cinder", where = UNKNOWN },
		{ boss = "King Op", where = UNKNOWN },
		{ boss = "Snowtalon", where = UNKNOWN, optional = true },
		{ boss = "Bolt", where = UNKNOWN },
		{ boss = "Vitrix", where = UNKNOWN },
		{ boss = "Nanaya", where = UNKNOWN },
	},
}

T.DungeonGuides[2875] = {
	summary = L["Crypts under the tower of Karazhan, carried over from an earlier season. We only know the boss list, not the route."],
	door = L["Reported to be in Deadwind Pass. We have not seen the entrance ourselves."],
	tips = {},
	steps = {
		{ boss = "Harbinger of Sin", where = UNKNOWN },
		{ boss = "Creeping Malison", where = UNKNOWN },
		{ boss = "Three Little Wolves", where = UNKNOWN },
		{ boss = "Dark Rider", where = UNKNOWN },
		{ boss = "Kharon", where = UNKNOWN },
		{ boss = "Unk'omon", where = UNKNOWN },
		{ boss = "Hans and Greta", where = UNKNOWN },
		{ boss = "The Ugly Goblin", where = UNKNOWN },
		{ boss = "Kaigy Maryla", where = UNKNOWN },
		{ boss = "Sairuh Maryla", where = UNKNOWN },
		{ boss = "Barian Maryla", where = UNKNOWN },
	},
}

T.DungeonGuides[2784] = {
	summary = L["A demon canyon carried over from an earlier season, for five players. We only know the boss list, not the route."],
	door = L["Reported to be in Ashenvale. We have not seen the entrance ourselves."],
	tips = {},
	steps = {
		{ boss = "Grimroot", where = UNKNOWN },
		{ boss = "Destructor's Wraith", where = UNKNOWN },
		{ boss = "Zilbagob", where = UNKNOWN },
		{ boss = "Pyranis", where = UNKNOWN },
		{ boss = "Diathorus the Seeker", where = UNKNOWN },
		{ boss = "Hellscream's Phantom", where = UNKNOWN },
		{ boss = "Azgaloth", where = UNKNOWN },
	},
}

T.DungeonGuides[2856] = {
	summary = L["A raid with Scarlet Crusade bosses, carried over from an earlier season. We only know the boss list, not the route."],
	door = L["Reported to be in the Eastern Plaguelands. We have not seen the entrance ourselves."],
	tips = {},
	steps = {
		{ boss = "Balnazzar", where = UNKNOWN },
		{ boss = "Beatrix", where = UNKNOWN },
		{ boss = "Beastmaster", where = UNKNOWN },
		{ boss = "Solistrasza", where = UNKNOWN },
		{ boss = "Mason", where = UNKNOWN },
		{ boss = "Reborn Council", where = UNKNOWN },
		{ boss = "Lillian Voss", where = UNKNOWN },
		{ boss = "Caldoran", where = UNKNOWN },
	},
}

T.DungeonGuides[2832] = {
	summary = L["A dragon grove from an earlier season. We only know that four dragons are listed as bosses."],
	tips = {},
	steps = {
		{ boss = "Emeriss", where = UNKNOWN },
		{ boss = "Lethon", where = UNKNOWN },
		{ boss = "Taerar", where = UNKNOWN },
		{ boss = "Ysondre", where = UNKNOWN },
	},
}

T.DungeonGuides[2789] = {
	summary = L["A scarred land with one big demon, Lord Kazzak. We know little more."],
	tips = {},
	steps = {
		{ boss = "Lord Kazzak", where = UNKNOWN },
	},
}

T.DungeonGuides[2791] = {
	summary = L["Storm Cliffs, home of the dragon Azuregos. We know little more."],
	tips = {},
	steps = {
		{ boss = "Azuregos", where = UNKNOWN },
	},
}

T.DungeonGuides[2804] = {
	summary = L["The Crystal Vale, home of Prince Thunderaan. We know little more."],
	tips = {},
	steps = {
		{ boss = "Prince Thunderaan", where = UNKNOWN },
	},
}

T.DungeonGuides[2921] = {
	summary = L["A second Naxxramas map with one listed boss, the Spirit of Mograine. We know little more."],
	tips = {},
	steps = {
		{ boss = "Spirit of Mograine", where = UNKNOWN },
	},
}
