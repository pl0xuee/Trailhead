local _, T = ...
local L = T.L
T.DungeonGuides = T.DungeonGuides or {}

-- Routes below are from 2006-era knowledge, checked against Warcraft Tavern's Forever guides
-- (which for these older dungeons say they follow Classic) and the game's own tables. Boss names
-- follow the game's encounter table. Where sources disagree or nothing confirms a claim, the
-- text says less rather than guess. Raids not yet announced for Forever say so in the summary.

T.DungeonGuides[209] = {
	summary = L["A sandy troll city in Tanaris, for levels 44 to 54. Its big event is the stairs fight in the middle."],
	door = L["In the north-west corner of Tanaris. Walk in through the big gate of the troll city."],
	tips = { L["Several bosses cast spells that need interrupting. Agree who interrupts whom before you start."], L["Wait for the whole group before you start the stairs event."] },
	steps = {
		{ text = L["From the entrance, head into the city and take the left-hand paths first."] },
		{ boss = "Theka the Martyr", where = L["Walks among the shallow graves near the start."], tip = L["Stun him at low health so he cannot turn into his stronger form."] },
		{ boss = "Antu'sul", where = L["Through the cracked wall on the right of Theka's room, in a cave guarded by elite patrols."], tip = L["Pull him out of the cave. Kill his totems and interrupt his heals."] },
		{ boss = "Witch Doctor Zum'rah", where = L["In a room past Theka. He looks friendly until you step in."], tip = L["Kill the totems at once."] },
		{ text = L["Talk to Weegli Blastfuse first, so he sets charges on the far door. Then free Sergeant Bly at the stairs. This starts a long wave of fighters."] },
		{ boss = "Nekrum Gutchewer", where = L["Comes with the last wave of the stairs event."], tip = L["Kill him first, then the priest. Healers stay far back."] },
		{ boss = "Shadowpriest Sezz'ziz", where = L["Comes with the last wave of the stairs event."], tip = L["Interrupt his spells."] },
		{ boss = "Chief Ukorz Sandscalp", where = L["Behind the door that the gnome Weegli blasts open."], tip = L["Weegli must set the door charges before the stairs event, or this door stays shut. Melee: avoid his sweeping hits."] },
		{ boss = "Hydromancer Velratha", where = L["In the courtyard with the pool and the gong, tucked round a corner."], tip = L["Clear the area first. Interrupt her spells and kill her totems."] },
		{ boss = "Gahz'rilla", where = L["Comes out of the pool when someone hits the gong with the Mallet of Zul'Farrak."], tip = L["Fight him inside the pool so his knockback hurts less."], optional = true },
	},
}

T.DungeonGuides[349] = {
	summary = L["A cave of living plants and earth spirits in Desolace, with an orange side, a purple side and a deeper part. For levels 46 to 55."],
	door = L["Walk into the Stone Door on the west side of the Valley of Spears in Desolace. At the fork, right is orange, left is purple and the middle gate leads to Earth Song Falls."],
	tips = { L["Pick a side first. Both sides lead down to the deeper part."], L["Stay on the upper path on the purple side. The ramps down lead to strong monsters."] },
	steps = {
		{ text = L["Take the right path with orange crystals. This is the orange side."] },
		{ boss = "Noxxion", where = L["First boss of the orange side, in a poison cave."], tip = L["When he splits into copies, kill them one at a time."] },
		{ boss = "Razorlash", where = L["Further along the orange side."], tip = L["Melee should stay behind him."] },
		{ boss = "Celebras the Cursed", where = L["At the end of the orange side, in Poison Falls."], tip = L["Kill him, not the spirits around him. Killing one makes him call another."] },
		{ text = L["Go back to the split and take the left path with purple crystals."] },
		{ boss = "Lord Vyletongue", where = L["First boss of the purple side, on the upper level."], tip = L["Kill him before his helpers."] },
		{ text = L["Follow the paths down to Earth Song Falls, the waterfall cave at the bottom."] },
		{ boss = "Landslide", where = L["At the top of the spiral ramp in Earth Song Falls."], tip = L["Kill him first. His helpers disappear when he dies."] },
		{ boss = "Tinkerer Gizlock", where = L["At the bottom of the ramp, before the last boss."], tip = L["Stand behind him, away from his bombs."] },
		{ boss = "Rotgrip", where = L["In the water under the last boss's platform."], tip = L["Kill the water snakes around him first."] },
		{ boss = "Princess Theradras", where = L["On the platform at the very bottom."], tip = L["Stay far away when she kicks up dust."] },
	},
}

T.DungeonGuides[109] = {
	summary = L["A flooded troll temple in the Swamp of Sorrows, for levels 50 to 60 (you can enter at 45). It ends with a fight against the avatar of a snake god."],
	door = L["Swim or walk to the temple island in the middle of the lake in the Swamp of Sorrows. The door is on the island. Strong monsters patrol the wet passages."],
	tips = { L["Falling into the central pit hurts a lot. Use the stairs."], L["The last boss needs a quest chain that starts in Tanaris. The Shade of Eranikus needs none."] },
	steps = {
		{ text = L["Go in through the portal and enter the temple's first level."] },
		{ boss = "Atal'alarion", where = L["In the Pit of Refuse, to the right of the portal. Click the six shrines in the right order to wake him."], tip = L["Click the shrines in the right order or you get cursed. Do not jump into the pit."] },
		{ text = L["Go up the stairs to the ring round the top. Six troll mini bosses stand on platforms around it. All six must die before the Prophet can be reached."] },
		{ boss = "Jammal'an the Prophet", where = L["In the Lair of the Chosen, after the six troll mini bosses are dead. Ogom the Wretched stands with him."], tip = L["Spread out. His hex turns a player into a berserker, so keep your distance."] },
		{ boss = "Weaver", where = L["Appears in the Pit of Sacrifice after the Prophet dies. Guides say to pull it with Dreamscythe, one dragon at a time."], tip = L["Pull one dragon at a time and tank it against a wall."] },
		{ boss = "Dreamscythe", where = L["Appears in the Pit of Sacrifice with Weaver."], tip = L["Pull one dragon at a time and tank it against a wall."] },
		{ boss = "Hazzas", where = L["Appears when Weaver and Dreamscythe are dead."], tip = L["This pair cannot be pulled apart. Tank them against a wall."] },
		{ boss = "Morphaz", where = L["Appears with Hazzas."], tip = L["Same as Hazzas: they come together."] },
		{ boss = "Shade of Eranikus", where = L["Deep in the temple, after the dragon fights. No ritual or quest is needed."], tip = L["Clear the dragonkin first or they join the fight. He puts the highest threat target to sleep."] },
		{ boss = "Avatar of Hakkar", where = L["A small room on the west side of the Pit of Sacrifice. Needs the Ancient Egg quest chain."], tip = L["Kill four Bloodkeepers and use their blood on four braziers to bring him out."], optional = true },
		{ text = L["The five fights below come from the 20-player version of this temple in the game's files. Blizzard has not announced it for Forever, so you will probably not meet them."] },
		{ boss = "Jammal'an and Ogom", where = L["Only in the 20-player version, in Jammal'an's room."], optional = true },
		{ boss = "Atal'ai Defenders", where = L["Only in the 20-player version. Where they stand is not known."], optional = true },
		{ boss = "Festering Rotslime", where = L["Only in the 20-player version. Where it stands is not known."], optional = true },
		{ boss = "Dreamscythe and Weaver", where = L["Only in the 20-player version: the two dragons as one fight."], optional = true },
		{ boss = "Morphaz and Hazzas", where = L["Only in the 20-player version: the two dragons as one fight."], optional = true },
	},
}

T.DungeonGuides[230] = {
	summary = L["A huge dwarf city inside Blackrock Mountain, for levels 52 to 60. It has many sections, and a full clear takes several hours. Many groups skip parts."],
	door = L["Go into Blackrock Mountain, climb down the big chain, go through Forgewright's Tomb and down another chain, then through the Grinding Quarry. Go left to the Masonry. The portal is in the far corner."],
	tips = { L["Do not wander off. The city is huge and easy to get lost in."], L["The Dark Iron Highway gates need a Shadowforge Key or a rogue with high lockpicking."] },
	steps = {
		{ text = L["Walk in from the portal. The first part is the Detention Block, a prison."] },
		{ boss = "High Interrogator Gerstahn", where = L["In the southernmost room of the Detention Block. She drops the Prison Cell Key."], tip = L["Interrupt her mana burn."] },
		{ boss = "Lord Roccor", where = L["Patrols the northern ring of the Detention Block."], tip = L["Step away when he shakes the ground."] },
		{ boss = "Houndmaster Grebmar", where = L["At the lowest point of the hall loop."], tip = L["Kill the hounds around him first."] },
		{ boss = "Ring of Law", where = L["The arena. A random fighter comes out after the first waves."], tip = L["Stay near the inner rail. The crowd watching the arena wakes up easily."] },
		{ text = L["Go on to the Dark Iron Highway. The gates need a Shadowforge Key or a rogue with lockpicking."] },
		{ boss = "Bael'Gar", where = L["At the west end of the Dark Iron Highway."], tip = L["Tank him against the wall and kill his helpers first."] },
		{ boss = "Lord Incendius", where = L["On the central bridge of Shadowforge City."], tip = L["Stay away from the edges. His heavy blow can throw you off, and there is no short way back up."] },
		{ boss = "Fineous Darkvire", where = L["Patrols the winding ramp in the Hall of Crafting."], tip = L["Interrupt his healing spell."] },
		{ boss = "Warder Stilgiss", where = L["In the Black Vault, with his hound."], tip = L["Kill his hound first and use no frost damage on him."] },
		{ boss = "The Vault", where = L["In the Black Vault. Opening all twelve relic coffer doors brings out this fight."], tip = L["Needs the coffer keys, so most groups skip it."], optional = true },
		{ boss = "Pyromancer Loregrain", where = L["Kneeling before the monument in the Shrine of Thaurissan."], tip = L["Kill his fire totem when it appears."] },
		{ boss = "General Angerforge", where = L["In the West Garrison."], tip = L["Kill his helpers with area damage."] },
		{ boss = "Golem Lord Argelmach", where = L["In the Manufactory, the machine hall."], tip = L["Kill the two golems beside him first."] },
		{ boss = "Ribbly Screwspigot", where = L["In the Grim Guzzler, the dwarf bar. He fights if you threaten him in talk."], tip = L["Most patrons in the bar are neutral. Do not use area attacks near them."], optional = true },
		{ boss = "Hurley Blackbreath", where = L["Appears when the three beer kegs in the bar are smashed."], tip = L["Do not hit the friendly drinkers."], optional = true },
		{ boss = "Plugger Spazzring", where = L["Behind the bar. Attacking him turns the whole bar hostile."], tip = L["Only fight him if the group is ready for the whole bar."], optional = true },
		{ boss = "Phalanx", where = L["Appears after you buy Dark Iron Ale mugs and hand them to Private Rocknot."], tip = L["Fight him in a corner."], optional = true },
		{ boss = "Ambassador Flamelash", where = L["In the Chamber of Enchantment."], tip = L["Kill his fire spirits before they reach him."] },
		{ boss = "The Seven", where = L["In the Summoners' Tomb: seven dwarf spirits, one after another."], tip = L["Pull each one back to the middle and manage mana."] },
		{ boss = "Magmus", where = L["At the back of the Iron Hall."], tip = L["Tank him in a corner and stack behind him, out of the fire."] },
		{ boss = "Princess Moira Bronzebeard", where = L["In the Imperial Seat, with the Emperor."], tip = L["Killing her gives loot. Saving her is for a quest. Ask your group."], optional = true },
		{ boss = "Emperor Dagran Thaurissan", where = L["On the throne in the Imperial Seat. He is the last boss."], tip = L["He is the last boss of the dungeon."] },
	},
}

T.DungeonGuides[229] = {
	summary = L["One doorway leads into two dungeons: Lower Blackrock Spire for five players and Upper Blackrock Spire for ten. Levels 55 and up. Lower is the best first target."],
	door = L["Inside Blackrock Mountain, on its east side. Take the door by the meeting stone and climb the path, or jump down from the balcony where the gnome Bodley stands, which skips the monsters."],
	tips = { L["Upper Spire must be unlocked. We could not confirm how in Forever, so ask your group."], L["Rare bosses here do not always show up. Do not wait for them."] },
	steps = {
		{ text = L["Lower Spire first. The game lists its bosses in the order below, but groups often take another path. Follow your group's lead."] },
		{ boss = "Highlord Omokk", where = L["Lower Spire. He is first in the game's boss list."], tip = L["Do not fight him in a doorway."] },
		{ boss = "Shadow Hunter Vosh'gajin", where = L["Lower Spire, among the orcs."], tip = L["Interrupt her hex."] },
		{ boss = "War Master Voone", where = L["Lower Spire, among the orcs."], tip = L["Stay away from his sweeping hits."] },
		{ boss = "Mother Smolderweb", where = L["Lower Spire, in the spider area."], tip = L["Her bite is poison. Bring a cure if you can."] },
		{ boss = "Urok Doomhowl", where = L["Lower Spire, in the ogre area. He must be called out with a special item."], tip = L["Only appears after you use the item. Ask your group."], optional = true },
		{ boss = "Quartermaster Zigris", where = L["Lower Spire, in the dragonkin area."], tip = L["Interrupt his shooting."] },
		{ boss = "Halycon", where = L["Lower Spire, in the cave with the baby dragons."], tip = L["Kill the cubs that run out."] },
		{ boss = "Gizrul the Slavener", where = L["Lower Spire, with Halycon in the same cave."], tip = L["Tank him against a wall."] },
		{ boss = "Overlord Wyrmthalak", where = L["Lower Spire, near the end, with his guards."], tip = L["Kill or control the guards first."] },
		{ text = L["Upper Spire starts past the Pyroguard's door. It is for ten players and must be unlocked. Ask your group what it needs."] },
		{ boss = "Pyroguard Emberseer", where = L["Upper Spire, in a cell room right inside the door."], tip = L["He burns anyone close."] },
		{ boss = "Warchief Rend Blackhand", where = L["Upper Spire, in the arena."], tip = L["Kill the dragonkin that rush in."] },
		{ boss = "The Beast", where = L["Upper Spire, in a cave off the arena."], tip = L["Do not stand in front of him."] },
		{ boss = "General Drakkisath", where = L["Upper Spire, the throne room. He is the last boss."], tip = L["Spread out."] },
		{ boss = "Lord Valthalak", where = L["A secret boss in the Upper Spire, from a quest."], tip = L["Needs a special quest item to appear."], optional = true },
	},
}

T.DungeonGuides[289] = {
	summary = L["A spooky school of necromancers on Caer Darrow in the Western Plaguelands, for levels 58 to 60."],
	door = L["On Caer Darrow, the island in the Western Plaguelands. The door to the portal needs the Skeleton Key, from a long quest chain."],
	tips = { L["Bring the key. The door is locked."], L["Rattlegore drops the Viewing Room key you need to go deeper. Marduk and Vectus need a quest first."] },
	steps = {
		{ text = L["Enter and go up to the patio where the first boss is summoned. The game lists the bosses in the order below; groups may vary it."] },
		{ boss = "Kirtonos", where = L["Called out on the patio with a quest item (Blood of Innocents)."], tip = L["Tank him against a wall."], optional = true },
		{ boss = "Jandice Barov", where = L["In the lower rooms of the first part."], tip = L["Kill the real one, not the copies. Guides call her optional."], optional = true },
		{ boss = "Rattlegore", where = L["In the basement of the Great Ossuary."], tip = L["Pull only one helper at a time. He drops the Viewing Room key."] },
		{ boss = "Marduk Blackpool", where = L["In the Viewing Room. A party member needs a related quest to start him."], tip = L["Keep ranged players out of his aura."], optional = true },
		{ boss = "Vectus", where = L["In the Viewing Room. A party member needs a related quest to start him."], tip = L["Spread out for his fire spells."], optional = true },
		{ boss = "Ras Frostwhisperer", where = L["In the Alchemy Lab."], tip = L["Clear the guards first. Interrupt his fear."] },
		{ boss = "Kormok", where = L["Called out near Ras Frostwhisper with a quest item (a brazier)."], tip = L["Kill the skeletons he calls."], optional = true },
		{ text = L["Go down to the Barov Family Vault with its six rooms."] },
		{ boss = "Lady Illucia Barov", where = L["Lower left room."], tip = L["Break mind control quickly."] },
		{ boss = "Lord Alexei Barov", where = L["Lower middle room."], tip = L["Crowd control the helpers and kill him first."] },
		{ boss = "The Ravenian", where = L["Lower right room."], tip = L["Clear the whole room before you pull."] },
		{ boss = "Lorekeeper Polkelt", where = L["Upper left room."], tip = L["Stay away from his blasts."] },
		{ boss = "Doctor Theolen Krastinov", where = L["Upper middle room."], tip = L["Kill him fast before he enrages."] },
		{ boss = "Instructor Malicia", where = L["Upper right room."], tip = L["Interrupt her spells."] },
		{ boss = "Darkmaster Gandling", where = L["In the Barov Family Vault, once the six rooms are cleared."], tip = L["He sends people to side rooms. Kill the helpers and come back."] },
	},
}

T.DungeonGuides[329] = {
	summary = L["A burning city in the Eastern Plaguelands with two parts, Living and Undead. For levels 58 and up. The two parts are joined."],
	door = L["North-west corner of the Eastern Plaguelands, across the long stone bridge, into the Living part. The Eastwall Gate, a cave a little east, leads to the Undead part and needs a key."],
	tips = { L["The Key to the City comes from the Living part. It opens many locked gates and the Eastwall Gate."], L["Stay together. Big packs come from every side."] },
	steps = {
		{ text = L["Go through the main gate into the living part. Fight across the market and the streets."] },
		{ boss = "The Unforgiven", where = L["On the streets of the Living part."], tip = L["Pull him away from other monsters."] },
		{ boss = "Timmy the Cruel", where = L["In the streets of the Living part."], tip = L["Kill him before more monsters join."] },
		{ boss = "Archivist Galford", where = L["In the Crimson buildings of the Living part."], tip = L["Do not stand in his fire."] },
		{ boss = "Cannon Master Willey", where = L["At the big cannon in the Living part."], tip = L["Pull his guards away first."] },
		{ boss = "Balnazzar", where = L["In the Slaughterhouse at the end of the living part."], tip = L["He summons helpers and tries to control players."] },
		{ boss = "Crimson Hammersmith", where = L["In the Living part. Mostly wanted for a smithing quest."], tip = L["Skip him if you have no quest for him."], optional = true },
		{ boss = "Ezra Grimm", where = L["A rare boss in the Living part. Not in every guide."], tip = L["Skip him if your group is weak."], optional = true },
		{ boss = "Hearthsinger Forresten", where = L["A rare boss in the Living part. He does not always show up."], tip = L["Do not stand in his cone."], optional = true },
		{ boss = "Skul", where = L["A rare boss in the Living part. He does not always show up."], tip = L["Skip him unless you want his drops."], optional = true },
		{ boss = "Malor the Zealous", where = L["Called out for a quest in the Living part."], tip = L["Only needed for quests."], optional = true },
		{ boss = "Postmaster Malown", where = L["Called out by a mail quest in the Living part."], tip = L["Only needed for quests."], optional = true },
		{ text = L["Take the Undead part next, through the Eastwall Gate (needs the Key to the City), or from inside the city, since the parts are joined."] },
		{ boss = "Nerub'enkan", where = L["At the start of the Undead part, in the crypts."], tip = L["Kill the spiders that rush out."] },
		{ boss = "Black Guard Swordsmith", where = L["In the Undead part."], tip = L["Kill him fast."], optional = true },
		{ boss = "Maleki the Pallid", where = L["In the Undead part."], tip = L["Interrupt his big spells."] },
		{ boss = "Baroness Anastari", where = L["In the Undead part."], tip = L["Break her mind control."] },
		{ boss = "Magistrate Barthilas", where = L["Deeper in the Undead part."], tip = L["Stay out of his leaps."] },
		{ boss = "Ramstein the Gorger", where = L["After Barthilas, near the end of the Undead part."], tip = L["Kill the helpers he brings."] },
		{ boss = "Stonespine", where = L["A rare boss in the Undead part."], tip = L["Skip him if you are in a hurry."], optional = true },
		{ boss = "Baron Rivendare", where = L["The last boss, in the Undead part."], tip = L["Kill his helpers when they rise."] },
	},
}

T.DungeonGuides[429] = {
	summary = L["Dire Maul is a ruined elf city in Feralas with three parts: East, West and North, all for level 55 and up. All three are in this one dungeon."],
	door = L["In Feralas, in the ruins. The East door needs no key. West and North need the Crescent Key, which comes from the East part."],
	tips = { L["Do East first. It has the key for the others."], L["Once one player opens the West or North door, a torch just inside lets the others in."] },
	steps = {
		{ text = L["East part first, the Warpwood Quarter. It has no key door. The game lists its bosses in the order below."] },
		{ boss = "Pusillin", where = L["A small imp near the start. Chase him down."], tip = L["He is the first boss on the East list. Ask your group about the Crescent Key."] },
		{ boss = "Zevrim Thornhoof", where = L["In the East part."], tip = L["Spread out a little. Ask your group for the plan."] },
		{ boss = "Hydrospawn", where = L["In the East part."], tip = L["Kill the small water spirits as they appear."] },
		{ boss = "Lethtendris", where = L["In the garden next to the pylon."], tip = L["Kill the small imp first."] },
		{ boss = "Alzzin the Wildshaper", where = L["The last boss of the East part."], tip = L["Kill his plant helpers first."] },
		{ text = L["West part now. The Crescent Key opens the door. Walk through the Capital Gardens."] },
		{ boss = "Tendris Warpwood", where = L["In the Capital Gardens, a walking tree."], tip = L["Spread out because he roots people."] },
		{ boss = "Illyanna Ravenoak", where = L["On the high ledge in the gardens."], tip = L["Kill her first. Her bird helper comes with her."] },
		{ boss = "Magister Kalendris", where = L["In the West part."], tip = L["Break his mind control."] },
		{ boss = "Immol'thar", where = L["In the West part."], tip = L["A hard fight. Ask your group for the plan."] },
		{ boss = "Prince Tortheldrin", where = L["The last boss of the West part."], tip = L["He is strong. Stay near the tank."] },
		{ boss = "Lord Hel'nurath", where = L["Only appears for a warlock quest."], tip = L["Skip him unless you have the quest."], optional = true },
		{ boss = "Tsu'zee", where = L["A rare boss in the West part."], tip = L["Skip him if you are in a hurry."], optional = true },
		{ text = L["North part, the ogre keep (Gordok Commons). The Crescent Key opens its door."] },
		{ boss = "Guard Mol'dar", where = L["In the North part."], tip = L["Pull one ogre guard at a time."] },
		{ boss = "Stomper Kreeg", where = L["In the North part, a drunk ogre at a table."], tip = L["Skip him unless you want his buff drinks."], optional = true },
		{ boss = "Guard Fengus", where = L["In the North part."], tip = L["Pull one ogre guard at a time."] },
		{ boss = "Guard Slip'kik", where = L["In the North part."], tip = L["Pull one ogre guard at a time."] },
		{ boss = "Captain Kromcrush", where = L["In the North part, near the throne room."], tip = L["Keep ranged players away."] },
		{ boss = "Cho'Rush the Observer", where = L["In the North part, by the throne room."], tip = L["Ask your group for the plan."] },
		{ boss = "King Gordok", where = L["On the throne at the back of the keep. He is the last boss."], tip = L["Killing the other ogre bosses first earns a tribute buff. Ask your group."] },
	},
}

-- Raids: shorter, boss order with one tip for a first timer.

T.DungeonGuides[409] = {
	summary = L["A fire raid for 40 players deep in Blackrock Mountain. It ends with Ragnaros. Plan on a long evening."],
	door = L["Deep inside Blackrock Depths, past the lava lake. Reach it through the Blackrock Mountain entrance in the Burning Steppes or Searing Gorge."],
	tips = { L["Raids are for large groups. Join a guild run."], L["Bring fire resistance gear if your guild has some."] },
	steps = {
		{ text = L["Go in from the Blackrock Depths side and follow the lava tunnel to the first boss."] },
		{ boss = "Lucifron", where = L["One of the first bosses inside."], tip = L["Ask your raid leader for the plan. Cure curses if you can."] },
		{ boss = "Magmadar", where = L["Near the start, a giant hound."], tip = L["Bring fear protection."] },
		{ boss = "Gehennas", where = L["Further in."], tip = L["Cure his curse on the group."] },
		{ boss = "Garr", where = L["Further in."], tip = L["Kill the adds or pull them away."] },
		{ boss = "Shazzrah", where = L["Further in."], tip = L["He jumps to random players. Cure his curse."] },
		{ boss = "Baron Geddon", where = L["Further in."], tip = L["Run away from the player who becomes a bomb."] },
		{ boss = "Sulfuron Harbinger", where = L["Further in."], tip = L["Kill his healers first."] },
		{ boss = "Golemagg the Incinerator", where = L["Further in."], tip = L["Leave his dogs alone until he is nearly dead."] },
		{ boss = "Majordomo Executus", where = L["Near the end, with his guards."], tip = L["Talk to him after his guards are dead."] },
		{ boss = "Ragnaros", where = L["The last boss, in the lava."], tip = L["Run out of the way when he knocks players back."] },
		{ boss = "The Molten Core", where = L["Not a boss you walk to. It is the progress for the whole raid."], tip = L["It counts when the raid is done."], optional = true },
	},
}

T.DungeonGuides[249] = {
	summary = L["A single dragon fight in a cave in Dustwallow Marsh. Onyxia is a dragon boss with three phases."],
	door = L["In a cave in the hills of Dustwallow Marsh. You need an attunement quest to enter."],
	tips = { L["In the air phase, spread out and do not stand together."], L["Do the attunement quest before raid night."] },
	steps = {
		{ text = L["Walk in through the cave and past the whelps to the big cave at the end."] },
		{ boss = "Onyxia", where = L["In the biggest cave at the end."], tip = L["When she takes off, run away from the fire."] },
	},
}

T.DungeonGuides[469] = {
	summary = L["A big dragon raid for 40 players at the top of Blackrock Spire. It ends with Nefarian."],
	door = L["Go through Upper Blackrock Spire to the raid door. You need an attunement quest to enter."],
	tips = { L["Do the attunement quest before raid night."], L["Bring fire and shadow resistance gear if you have some."] },
	steps = {
		{ text = L["Walk in past the guards to the first room."] },
		{ boss = "Razorgore the Untamed", where = L["The first boss."], tip = L["Ask your raid leader for the plan. Players take control of him."] },
		{ boss = "Vaelastrasz the Corrupt", where = L["After the first boss."], tip = L["Do not stand near the player who burns."] },
		{ boss = "Broodlord Lashlayer", where = L["After the first bosses."], tip = L["Tank him with his back to a wall."] },
		{ boss = "Firemaw", where = L["In the area of the dragon bosses."], tip = L["Keep the tank at full health."] },
		{ boss = "Ebonroc", where = L["In the area of the dragon bosses."], tip = L["Heal the tank through the curse."] },
		{ boss = "Flamegor", where = L["In the area of the dragon bosses."], tip = L["Interrupt his enrage if you can."] },
		{ boss = "Chromaggus", where = L["In a side hall."], tip = L["Cure whatever he casts on the group."] },
		{ boss = "Nefarian", where = L["The last boss, at the top."], tip = L["When he calls skeletons, kill them quickly."] },
	},
}

T.DungeonGuides[309] = {
	summary = L["A troll raid for 20 players in the jungle of Stranglethorn Vale. It ends with Hakkar."],
	door = L["In the north of Stranglethorn Vale. Walk up the path from the village into the stone gate."],
	tips = { L["You can kill the troll priests in many orders. Ask your raid leader for the plan."] },
	steps = {
		{ text = L["Walk in. The priests stand in different parts of the city. Pick them in any order."] },
		{ boss = "High Priestess Jeklik", where = L["Top of the bat tower."], tip = L["Kill her bats and avoid the fire."] },
		{ boss = "High Priest Venoxis", where = L["In the snake temple."], tip = L["Stay out of the poison cloud."] },
		{ boss = "High Priestess Mar'li", where = L["In the spider temple."], tip = L["Kill the spiders first."] },
		{ boss = "High Priest Thekal", where = L["In the tiger temple."], tip = L["Kill all his friends within a few seconds of each other."] },
		{ boss = "High Priestess Arlokk", where = L["In the panther temple."], tip = L["She disappears and hits from behind. Be ready."] },
		{ boss = "Bloodlord Mandokir", where = L["Near the entrance, past the bridge."], tip = L["Do not stay in his sight."] },
		{ boss = "Edge of Madness", where = L["On an island in the lake."], tip = L["One of four trolls appears. Kill it and its friends."], optional = true },
		{ boss = "Gahz'ranka", where = L["In the pool, called out with fishing bait."], tip = L["Only needed for quests."], optional = true },
		{ boss = "Jin'do the Hexxer", where = L["Past Mandokir."], tip = L["Kill his totem guards quickly."] },
		{ boss = "Hakkar", where = L["The last boss, in the big temple at the end."], tip = L["Kill the high priests first to make him weaker."] },
	},
}

T.DungeonGuides[509] = {
	summary = L["A bug raid for 20 players in the Silithus sand dunes. It ends with Ossirian."],
	door = L["In the far south of Silithus, outside the big gate to the Ahn'Qiraj temple. Ask the raid leader if the door is open."],
	tips = { L["Do not stand in damage on the ground. Move out of it."] },
	steps = {
		{ text = L["Go in and fight the first bug packs."] },
		{ boss = "Kurinnaxx", where = L["The first boss."], tip = L["Keep the tank facing him, and everyone else away from the front."] },
		{ boss = "General Rajaxx", where = L["Beyond the first boss."], tip = L["Kill his waves first, then the General."] },
		{ boss = "Moam", where = L["Further in."], tip = L["Kill the stone helpers fast."] },
		{ boss = "Buru the Gorger", where = L["Further in, in the egg room."], tip = L["Kill the eggs, then the boss."] },
		{ boss = "Ayamiss the Hunter", where = L["Further in."], tip = L["Kill her helpers on the ground."] },
		{ boss = "Ossirian the Unscarred", where = L["The last boss."], tip = L["Use the crystals to weaken him."] },
	},
}

T.DungeonGuides[531] = {
	summary = L["A giant raid for 40 players in Silithus under the Temple of Ahn'Qiraj. It ends with C'Thun."],
	door = L["In the far south of Silithus, at the big gate to the Ahn'Qiraj temple. Ask the raid leader if the door is open."],
	tips = { L["Ask your raid leader for the plan before each boss."] },
	steps = {
		{ text = L["Walk in to the first boss."] },
		{ boss = "The Prophet Skeram", where = L["The first boss."], tip = L["He splits into copies. Kill the real one."] },
		{ boss = "Silithid Royalty", where = L["Beyond the first boss."], tip = L["Kill all three bugs together."] },
		{ boss = "Battleguard Sartura", where = L["Further in."], tip = L["Spread out and kill her guards."] },
		{ boss = "Fankriss the Unyielding", where = L["Further in."], tip = L["Kill the worms as they appear."] },
		{ boss = "Viscidus", where = L["Further in. Many groups skip him."], tip = L["Frost damage slows him."], optional = true },
		{ boss = "Princess Huhuran", where = L["Further in."], tip = L["Bring nature resistance gear."] },
		{ boss = "Twin Emperors", where = L["Near the end."], tip = L["Do not kill them at the same time as each other."] },
		{ boss = "Ouro", where = L["Near the end."], tip = L["Run away when he burrows."] },
		{ boss = "C'thun", where = L["The last boss, in the deepest chamber."], tip = L["Kill the eyes quickly. Then fight him inside his stomach."] },
	},
}

T.DungeonGuides[533] = {
	summary = L["A huge undead raid for 40 players in a floating fortress above the Eastern Plaguelands. It has four wings and ends with Kel'Thuzad."],
	door = L["The floating fortress hangs over the Eastern Plaguelands. The raid door is on the ground below it."],
	tips = { L["Each wing is a separate part. You can try them in any order."] },
	steps = {
		{ text = L["The Spider Wing is one of the four wings."] },
		{ boss = "Anub'Rekhan", where = L["In the Spider Wing."], tip = L["Spread out when he calls locusts."] },
		{ boss = "Grand Widow Faerlina", where = L["In the Spider Wing."], tip = L["Kill her followers first."] },
		{ boss = "Maexxna", where = L["At the back of the Spider Wing."], tip = L["Break people out of the webs fast."] },
		{ text = L["Next is the Plague Wing."] },
		{ boss = "Noth the Plaguebringer", where = L["In the Plague Wing."], tip = L["Handle the skeletons he calls."] },
		{ boss = "Heigan the Unclean", where = L["In the Plague Wing."], tip = L["Learn which floor tiles are safe."] },
		{ boss = "Loatheb", where = L["At the end of the Plague Wing."], tip = L["Keep healing even after the poison hits."] },
		{ text = L["Then the Military Wing."] },
		{ boss = "Instructor Razuvious", where = L["In the Military Wing."], tip = L["Use the trainee soldiers to hold him."] },
		{ boss = "Gothik the Harvester", where = L["In the Military Wing."], tip = L["Kill the waves from both sides."] },
		{ boss = "The Four Horsemen", where = L["In the Military Wing."], tip = L["Move between the four riders on a plan."] },
		{ text = L["Then the Construct Wing."] },
		{ boss = "Patchwerk", where = L["In the Construct Wing."], tip = L["The tank needs the best healer."] },
		{ boss = "Grobbulus", where = L["In the Construct Wing."], tip = L["Do not clump when he sprays."] },
		{ boss = "Gluth", where = L["In the Construct Wing."], tip = L["Kill the zombies he calls."] },
		{ boss = "Thaddius", where = L["At the end of the Construct Wing."], tip = L["Learn which side to stand on."] },
		{ text = L["Last come the frost dragon and the lich."] },
		{ boss = "Sapphiron", where = L["In a frozen lair at the back of the fortress."], tip = L["Hide behind an ice block when he casts."] },
		{ boss = "Kel'Thuzad", where = L["The last boss, at the center of the fortress."], tip = L["Kill the guards that rise around you."] },
	},
}
