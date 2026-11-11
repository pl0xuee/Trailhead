local _, T = ...
local L = T.L

-- Written routes for the first dungeons, in the order a group meets the bosses. Boss names
-- must match Data/DungeonIndex.lua exactly (the tests check it). Where a route is from the
-- general layout of the old dungeon rather than a Forever guide, it names places, not turns.

T.DungeonGuides = T.DungeonGuides or {}
local G = T.DungeonGuides

-- Ragefire Chasm
G[389] = {
	summary = L["Orgrimmar's own dungeon: a hot cave of troggs and cultists under the city. Four bosses, for levels 13 to 18."],
	door = L["Go to the Cleft of Shadow, the cave in the middle of Orgrimmar, and follow the path down. The way in is at the bottom."],
	tips = {
		L["Cultists cast spells that hurt. Pull one group at a time."],
		L["Alliance players can enter, but it is a long, risky walk, and its quests are for the Horde."],
	},
	steps = {
		{ text = L["Walk down the long ramp into the lava cave. The path soon splits into side tunnels."] },
		{ boss = "Oggleflint", where = L["In a small room at the end of the right-hand side path, soon after the first ramp."],
			tip = L["He has two helpers. Kill them first, and fight in his room so other monsters stay away."] },
		{ text = L["Go back to the ramp and follow it up and around into a big cave with many crossing paths."] },
		{ boss = "Taragaman the Hungerer", where = L["On the middle platform of the big cave."],
			tip = L["His uppercut throws you back. Do not stand near the lava edge. Patrols can join in."] },
		{ text = L["Take the narrow passages beyond the big cave and clear the guards in the way."] },
		{ boss = "Jergosh the Invoker", where = L["Past the guards in the passages beyond the big cave."],
			tip = L["He has two helpers. Kill them first, and interrupt his fire spell if you can."] },
		{ text = L["Walk into the last chamber. It has a low floor and a raised ledge behind it. Go up to the ledge."] },
		{ boss = "Bazzalan", where = L["At the very end of the dungeon, on the raised ledge."],
			tip = L["He has two helpers and a poison. Kill the helpers first and cure the poison. He is the last boss."] },
	},
}

-- Wailing Caverns
G[43] = {
	summary = L["A twisting cave of snakes, raptors and druids gone bad, with a short escort at the end. Eight bosses, for levels 15 to 24."],
	door = L["In the Lushwater Oasis, in the middle of The Barrens, find the cave called the Cavern of Mists. Follow the winding tunnel down to a big pool."],
	tips = {
		L["Elite monsters walk the tunnel outside. Go in as a group."],
		L["Lady Anacondra can wait at any of several spots, so look around the first cave."],
	},
	steps = {
		{ text = L["Follow the tunnel down to the cave with the pool and step into the way in. You arrive in a big central cave."] },
		{ boss = "Lady Anacondra", where = L["In the central cave, on a high ledge. She stands at one of several circles."],
			tip = L["She puts people to sleep. Keep the group close and finish her quickly."] },
		{ boss = "Lord Cobrahn", where = L["In the left-hand wing: climb the winding path up to the Pit of Fangs."],
			tip = L["Kill the three snakes around him first, then him."] },
		{ text = L["Jump down to the cave floor, walk back to the central cave and take the much bigger side on the other hand."] },
		{ boss = "Kresh", optional = true, where = L["A turtle that walks along the stream in the central cave, on the way to the bigger side."],
			tip = L["He wanders the stream and is often skipped. A plain fight if you want him."] },
		{ boss = "Lord Pythas", where = L["Further along the main path of the bigger side."],
			tip = L["A druid helper stands with him. Kill it first."] },
		{ boss = "Lord Serpentis", where = L["Along the main path, in his own room with no helpers."],
			tip = L["Nothing else joins him, so put everything on him."] },
		{ boss = "Skum", optional = true, where = L["A big lizard in the Winding Chasm, after Lord Serpentis."],
			tip = L["Often skipped. He is immune to nature damage and hits hard. Keep the one in front healed."] },
		{ boss = "Verdan the Everliving", where = L["Near the waterfall past Lord Serpentis."],
			tip = L["His vines root everyone near him. Stand well back, and keep the tank healed."] },
		{ text = L["Jump into the pool behind Verdan to drop back to the start area."] },
		{ text = L["Talk to the Disciple of Naralax and walk with him to the final room. Keep him alive: he calls the last boss."] },
		{ boss = "Mutanus the Devourer", where = L["He rises from the water in the final room after the Disciple's ritual."],
			tip = L["Kill the small monsters first, then the boss comes out of the water. Keep the Disciple safe."] },
	},
}

-- The Deadmines
G[36] = {
	summary = L["Pirates and goblins in a mine under Westfall that ends on a ship. Eight bosses, for levels 17 to 26. A good first group dungeon."],
	door = L["In Westfall, in the town of Moonbrook, go into the big Defias Hideout building in the south-west corner. Follow the cave maze down to the bottom."],
	tips = {
		L["Pull one group at a time and kill the casters first."],
		L["Mr. Smite and Edwin VanCleef each bring two hidden guards. Expect a surprise attack."],
	},
	steps = {
		{ text = L["From the entrance, follow the tunnels. The path is mostly one way."] },
		{ boss = "Rhahk'Zor", where = L["A big ogre guarding a door in the tunnels, with two helpers who shoot from range."],
			tip = L["Kill the shooters first or they keep hurting you from behind him."] },
		{ boss = "Miner Johnson", optional = true, where = L["Past that door, on the left side of the next junction. He is not always there."],
			tip = L["If he is not there, just walk on."] },
		{ boss = "Sneed", where = L["In his workshop, inside a big machine called the Shredder."],
			tip = L["Clear the goblins in the room first. When the machine dies, Sneed jumps out and can disarm someone."] },
		{ boss = "Gilnid", where = L["In the goblin foundry room further along."],
			tip = L["Clear the goblins around him first, then pull him on his own."] },
		{ text = L["Follow the tunnel into a huge cave with wooden docks. Cross the docks to the pirate ship."] },
		{ boss = "Mr. Smite", where = L["On the pirate ship, on the main deck."],
			tip = L["Kill his two hidden guards first. Save your defences for when he pulls out two weapons."] },
		{ boss = "Captain Greenskin", where = L["In the captain's area at the back of the ship."],
			tip = L["Easy to pull by accident, and that often ends in a wipe. Stop and get ready first."] },
		{ boss = "Edwin VanCleef", where = L["In the cabin at the very top of the ship, past Captain Greenskin."],
			tip = L["He calls helpers, and again at half health. Focus him, not the helpers. He is the last boss."] },
		{ boss = "Cookie", optional = true, where = L["Lower deck of the ship, near the gangplank. Most groups fight him on the way out."],
			tip = L["He drops a wand that casters like. Interrupt his cooking, which heals him."] },
	},
}

-- Shadowfang Keep
G[33] = {
	summary = L["A haunted keep full of worgen and ghosts, with a wizard at the top. Eight bosses, for levels 20 to 30. Most fights have helpers."],
	door = L["In Silverpine Forest, in the mountains just north of Pyrewood Village, walk up to the big keep gate."],
	tips = {
		L["Rooms are full of monsters. Pull small groups, never the whole room."],
		L["Pick a spot to fall back to. Worgen run fast. A rare boss, the Deathsworn Captain, shows up only sometimes."],
	},
	steps = {
		{ boss = "Rethilgore", where = L["Near the start, with two worgen at his side."],
			tip = L["When he dies, the door to the courtyard opens."] },
		{ text = L["Cross the courtyard and go in through the doors to the twisting halls of the main keep."] },
		{ boss = "Razorclaw the Butcher", where = L["In the main keep, with helpers around him."],
			tip = L["Kill the helpers first."] },
		{ boss = "Baron Silverlaine", where = L["In a room of the main keep, full of guards."],
			tip = L["Clear the guards first. His veil cuts the healing you get, so interrupt it."] },
		{ boss = "Commander Springvale", where = L["In a room of the keep that is packed with monsters."],
			tip = L["Pull small groups. Do not try to take the whole room."] },
		{ boss = "Odo the Blindwatcher", where = L["In the keep, with a swarm of bats."],
			tip = L["Kill the bats first. He hits harder as his health drops, so save your big attacks for the end."] },
		{ boss = "Fenrus the Devourer", where = L["A big wolf guarding the way to the wizard's rooms."],
			tip = L["He has no helpers, but he hits hard. Use defences and save mana."] },
		{ boss = "Wolf Master Nandos", where = L["At the door to the wizard's room."],
			tip = L["He calls four wolves at 80% health. Be ready to pick them up, then kill them."] },
		{ boss = "Archmage Arugal", where = L["In the last room at the top of the keep, with three worgen."],
			tip = L["Kill the three worgen with him first. He teleports, takes over minds and casts a shadow bolt. He is the last boss."] },
	},
}

-- Blackfathom Deeps
G[48] = {
	summary = L["Sunken night elf ruins above and below the water, full of naga and murlocs. Seven bosses, for levels 24 to 32. Some parts are under water."],
	door = L["In the north-west corner of Ashenvale, at the Zoram Strand, find the sunken ruins. Swim down into the pool at the bottom, then follow the narrow cave."],
	tips = {
		L["The cave after the pool is full of strong naga. Take it slowly."],
		L["Most of the temple is dry, but a few ruins can only be reached by swimming."],
	},
	steps = {
		{ text = L["Swim down through the pool and follow the narrow winding cave. The path is mostly one way."] },
		{ boss = "Ghamoo-ra", where = L["The first boss, in a cave soon after the tunnel."],
			tip = L["A big, slow turtle. Keep the one in front healed."] },
		{ boss = "Lady Sarevess", where = L["The second boss, with two helpers."],
			tip = L["Spread out, because her lightning jumps between people. Kill the helpers first."] },
		{ boss = "Geilhast", optional = true, where = L["A murloc boss in a side room."],
			tip = L["Clear the murlocs in his room first, then pull him alone. His net lowers threat."] },
		{ boss = "Lorgus Jett", optional = true, where = L["A smaller boss on the way. Horde quests need him."],
			tip = L["Skip him if you have no quest for him."] },
		{ boss = "Old Serra'kis", optional = true, where = L["You fight this one in the water. Guides disagree on whether he comes before or after Kelris."],
			tip = L["Only go for him if the whole group is happy to swim. Watch your breath."] },
		{ boss = "Twilight Lord Kelris", where = L["In the ceremonial chamber just before the last room."],
			tip = L["He can put people to sleep. Have someone ready to remove it, especially from the tank."] },
		{ boss = "Aku'mai", where = L["In the last cave. A huge sea creature."],
			tip = L["Move out of his poison cloud. Save stuns for his frenzy. He is the last boss."] },
	},
}

-- The Stockade
G[34] = {
	summary = L["Stormwind's prison, under the canals: a small jail full of Defias and prisoners. Five bosses, for levels 25 to 29."],
	door = L["In Stormwind City, go to the canals near the Mage Quarter. The gate to the Stockade is on the water's edge."],
	tips = {
		L["Many Defias fighters stand in the halls. Pull one group at a time."],
		L["Horde players can enter too, but its quests are for the Alliance."],
	},
	steps = {
		{ text = L["Go straight ahead from the entrance. The jail is shaped like a T: you can clear the left and right wings in any order."] },
		{ boss = "Targorr the Dread", where = L["In one of the two cell wings."],
			tip = L["Strong Defias guards nearby often join in. Pull carefully."] },
		{ boss = "Kam Deepfury", where = L["In one of the two cell wings."],
			tip = L["His shield bash often stuns. Strong Defias guards nearby may join in."] },
		{ boss = "Hamhock", where = L["In the cell block, with two guards."],
			tip = L["Kill his two guards first. Interrupt his lightning."] },
		{ boss = "Dextren Ward", where = L["In the cell block."],
			tip = L["His shout can pull people out of healing range. Stay close to the healer."] },
		{ boss = "Bazil Thredd", where = L["In his own room. Guides call him the last boss."],
			tip = L["Clear his helpers before you start on him. The tank holds them while others kill them."] },
	},
}

-- Gnomeregan
G[90] = {
	summary = L["A gnome city overrun by troggs and broken machines, with narrow halls on many floors. Five bosses, for levels 29 to 38."],
	door = L["In the north-west of Dun Morogh, take the lift down to the outer tunnels, then walk to the dungeon portal."],
	tips = {
		L["Do not jump or fall down. Monsters on lower paths run up to you."],
		L["The door is deep in Alliance land. Horde players: ask your group about the teleporter quest."],
	},
	steps = {
		{ text = L["At the start, take the first side tunnel on the left. Blastmaster Emi Shortfuse waits at the end."] },
		{ boss = "Grubbis", where = L["Talk to Emi Shortfuse. Her event ends with the fight against Grubbis and his pet."],
			tip = L["Kill the pet first, then Grubbis."] },
		{ boss = "Viscous Fallout", where = L["Further in, in the glowing, dirty part of the old city."],
			tip = L["A plain fight, but he is immune to frost. Use other damage."] },
		{ boss = "Electrocutioner 6000", where = L["On the platform at the top of the Launch Bay."],
			tip = L["Spread out. He drops the Workshop Key, which opens a back door."] },
		{ boss = "Crowd Pummeler 9-60", where = L["In the engineering labs."],
			tip = L["A big machine that hits hard. Keep the one in front healed."] },
		{ boss = "Mekgineer Thermaplugg", where = L["In the last room."],
			tip = L["Tank him in the middle of the room. Someone presses the pillar buttons to stop his bombs for a while."] },
	},
}

-- Razorfen Kraul
G[47] = {
	summary = L["A maze of thorn bushes and tunnels full of quilboar, with paths above and below each other. Six bosses, for levels 29 to 38."],
	door = L["In the far south-west of The Barrens, push through the maze of thorns and quilboar to the portal at its end."],
	tips = {
		L["The paths cross over and under each other. Stay together."],
		L["Rare bosses here do not always show up. Do not wait for them."],
	},
	steps = {
		{ boss = "Roogug", where = L["The first boss, with two helpers."],
			tip = L["He calls a stone monster. Kill the seer helper first, and mark the targets."] },
		{ boss = "Aggem Thorncurse", where = L["The second boss, further in."],
			tip = L["He keeps summoning spirit boars. Kill them as they come."] },
		{ boss = "Death Speaker Jargba", where = L["The third boss, with two helpers."],
			tip = L["Kill his helpers first: the acolyte, then the big one. Interrupt the acolyte's mana burn."] },
		{ boss = "Overlord Ramtusk", where = L["The fourth boss, with two spear guards."],
			tip = L["Kill the guards first. Step away from them when they spin."] },
		{ text = L["Earthcaller Halmgar is a rare boss on a plateau after Ramtusk. He does not always show up and is not needed."] },
		{ boss = "Agathelos the Raging", where = L["The fifth boss, sealed in by a priest and two guards."],
			tip = L["Beat the three at the seal first. If he seems to die early, keep hitting him: he is faking."] },
		{ text = L["A rare bat, the Blind Hunter, can be after Agathelos. Clear nearby bats before taking him. His screech silences."] },
		{ boss = "Charlga Razorflank", where = L["The final boss, on the ramp outside her hut."],
			tip = L["Tank her on the ramp. Do not put damage-over-time spells on her: she cleanses them."] },
	},
}

-- Scarlet Monastery
G[189] = {
	summary = L["Four wings behind one door: Graveyard, Library, Armory and Cathedral, each for higher levels (30 to 46 in all). Seven bosses in all."],
	door = L["In the north-east corner of Tirisfal Glades. The four wing portals sit in the main building. The Scarlet Key opens the locked doors; the Graveyard needs none."],
	tips = {
		L["Pick one wing and finish it. The Graveyard (levels 30 to 38) is the easiest start and needs no key."],
		L["Scarlet monsters hit hard and heal. Interrupt healers when you can."],
	},
	steps = {
		{ text = L["Graveyard wing, levels 30 to 38. Its portal is the one on the far left as you walk in. No key needed."] },
		{ boss = "Interrogator Vishas", where = L["In the Graveyard wing, near the start."],
			tip = L["He is a caster. Pull him back from other monsters so the group is not hit from two sides."] },
		{ boss = "Bloodmage Thalnos", where = L["Deeper in the Graveyard wing, near the end."],
			tip = L["He casts fire. Kill him quickly. Rare bosses can also show up in this wing."] },
		{ text = L["Library wing, levels 33 to 41. One guide says its door is locked, so ask your group who has the Scarlet Key."] },
		{ boss = "Houndmaster Loksey", where = L["In the Library wing, with his dogs."],
			tip = L["Kill the dogs first."] },
		{ boss = "Arcanist Doan", where = L["At the end of the Library wing."],
			tip = L["He casts a big blast. Step away when he starts. A chest behind him holds the Scarlet Key."] },
		{ text = L["Armory wing, levels 36 to 44. The Scarlet Key opens its door. The key is in the Library wing."] },
		{ boss = "Herod", where = L["At the end of the Armory wing."],
			tip = L["He hits everyone close to him. Kill the guards with him first."] },
		{ text = L["Cathedral wing, levels 38 to 46, the strongest. It also needs the Scarlet Key to reach its portal."] },
		{ boss = "High Inquisitor Fairbanks", where = L["In the Cathedral wing, in the first part."],
			tip = L["He heals himself. Keep up the damage."] },
		{ text = L["Scarlet Commander Mograine and High Inquisitor Whitemane share the last room. Mograine is fought with her, not on his own."] },
		{ boss = "High Inquisitor Whitemane", where = L["In the last room of the Cathedral wing, with Scarlet Commander Mograine."],
			tip = L["When Mograine falls, she brings him back. Kill them in turn."] },
	},
}

-- Razorfen Downs
G[129] = {
	summary = L["An old quilboar city of bone and thorn, with undead at its heart. Six bosses, for levels 37 to 46."],
	door = L["In the south-east of The Barrens, cross the maze of thorns and quilboar to the portal at its end."],
	tips = {
		L["Ring the gong in the first big room only when the group is ready."],
		L["Rare bosses here do not always show up. Do not wait for them."],
	},
	steps = {
		{ boss = "Tuten'kash", where = L["In the first big room, where a gong stands."],
			tip = L["Each gong ring brings spiders from both sides. The third ring calls the boss."] },
		{ boss = "Plaguemaw the Rotting", optional = true, where = L["Appears only if you walk the Belnistrasz escort quest to its end."],
			tip = L["Keep monsters off the escort. Only start it if you have the quest."] },
		{ boss = "Mordresh Fire Eye", where = L["On a pile of bones, among skeletons."],
			tip = L["Kill the skeletons first, then him. Interrupt his fireball."] },
		{ boss = "Ragglesnout", optional = true, where = L["A rare boss. He does not always show up."],
			tip = L["He can take over a player's mind. Be ready to swap tank or healer."] },
		{ boss = "Glutton", where = L["Below the Spiral of Thorns, where he patrols."],
			tip = L["Stay out of the cloud of disease. Heal the tank when he goes wild."] },
		{ boss = "Amnennar the Coldbringer", where = L["In his tent, the last stop in the dungeon."],
			tip = L["Kill the frost ghosts he calls, then go back to him. He is the last boss."] },
	},
}

-- Uldaman
G[70] = {
	summary = L["A buried dwarf ruin with stone guardians. Eight bosses, for levels 41 to 51. A long one, so plan for it."],
	door = L["In the north of the Badlands, near Loch Modan, find the excavation tunnels and go in. Strong monsters wait in the tunnels."],
	tips = {
		L["There is also a back door in Dustwind Gulch, inside a cave of strong troggs."],
		L["Ironaya wakes only when someone uses two special items. Ask your group."],
	},
	steps = {
		{ boss = "Revelosh", where = L["A trogg boss, with two small helpers."],
			tip = L["He drops the Shaft of Tsol, needed for Ironaya."] },
		{ boss = "The Lost Dwarves", where = L["Three dwarf bosses together. The dwarves are friendly to Alliance players, so this fight is for Horde."],
			tip = L["Kill them together. The chest behind has a medallion for Ironaya."] },
		{ boss = "Ironaya", optional = true, where = L["Wakes in the big hall once someone uses the medallion and the shaft."],
			tip = L["She has lots of health and a knockback. Stand away from edges."] },
		{ boss = "Obsidian Sentinel", where = L["A stone guardian in the ruins."],
			tip = L["At two points in the fight it makes smaller stone helpers. Kill them."] },
		{ boss = "Ancient Stone Keeper", where = L["A stone guardian further in."],
			tip = L["Its sand storm slows and silences. Ranged fighters and healers should stay far away."] },
		{ boss = "Galgann Firehammer", where = L["A fire dwarf, with two helpers."],
			tip = L["His fire spell makes fire hit harder. Remove it if you can."] },
		{ boss = "Grimlok", where = L["A trogg boss, with helpers."],
			tip = L["Stop the helpers where you can. If not, kill the basilisk first. Then burn him down."] },
		{ text = L["The last room is a big round hall with columns. Archaedas is here."] },
		{ boss = "Archaedas", where = L["In the big round hall with columns, the last room."],
			tip = L["He wakes stone helpers during the fight. They fall when he dies, so keep the damage on him."] },
	},
}
