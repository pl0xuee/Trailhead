local _, T = ...

-- Quest hubs: towns and camps where several quest givers stand, per zone map.
-- Written by tools/gen_hubs.py from quest data of the 2006 game (pfQuest, via the MIT-licensed
-- Waypoint Tracker data) with positions from All The Things and from Forever players, and
-- names from the game's own AreaPOI, TaxiNodes and WorldMapOverlay tables. Quests added by
-- Forever are not in it. Zephras Isle is hand-checked against Warcraft Tavern's walkthrough.
-- Do not edit by hand.
-- Row: { name, x, y, faction, lowest level, typical level, quests, flags }
--   x and y are thousandths of the zone map; faction 0 both, 1 Horde, 2 Alliance;
--   flags: 1 inn, 2 flight master, 4 start hub for the Alliance, 8 start hub for the Horde.

T.HubData = {
	[1411] = { -- Durotar
		{ "Valley of Trials", 424, 686, 1, 1, 2, 28, 8 },
		{ "Sen'jin Village", 558, 746, 1, 1, 8, 13, 0 },
		{ "Razor Hill", 524, 437, 1, 6, 10, 32, 1 },
		{ "Razormane Grounds", 393, 600, 1, 5, 12, 6, 0 },
	},
	[1412] = { -- Mulgore
		{ "Camp Narache", 443, 771, 1, 1, 3, 15, 8 },
		{ "Bloodhoof Village", 470, 622, 1, 5, 8, 26, 1 },
	},
	[1413] = { -- The Barrens
		{ "Thorn Hill", 621, 202, 1, 10, 14, 7, 0 },
		{ "The Crossroads", 518, 308, 1, 10, 15, 37, 11 },
		{ "Dreadmist Peak", 431, 119, 1, 18, 18, 5, 0 },
		{ "Honor's Stand", 353, 278, 1, 18, 18, 6, 0 },
		{ "Camp Taurajo", 447, 590, 1, 19, 20, 22, 3 },
		{ "Ratchet", 626, 368, 1, 14, 20, 31, 3 },
		{ "Ratchet", 626, 368, 2, 14, 20, 26, 7 },
		{ "Bael Modan", 445, 780, 1, 22, 23, 7, 0 },
		{ "Ratchet (south)", 663, 453, 0, 20, 25, 6, 0 },
		{ "The Crossroads (east)", 569, 305, 1, 10, 30, 7, 0 },
		{ "The Mor'shan Rampart", 470, 84, 1, 25, 32, 6, 0 },
	},
	[1416] = { -- Alterac Mountains
		{ "Gallows' Corner", 581, 682, 2, 34, 34, 6, 0 },
		{ "Chillwind Point", 802, 668, 0, 37, 40, 7, 0 },
	},
	[1417] = { -- Arathi Highlands
		{ "Go'Shek Farm", 602, 538, 2, 36, 36, 4, 0 },
		{ "Refuge Pointe", 460, 461, 2, 25, 39, 24, 6 },
		{ "Faldir's Cove", 330, 812, 0, 35, 40, 8, 0 },
		{ "Hammerfall", 737, 326, 1, 32, 40, 42, 11 },
	},
	[1418] = { -- Badlands
		{ "Angor Fortress", 423, 528, 0, 36, 38, 6, 0 },
		{ "Hammertoe's Digsite", 536, 433, 2, 35, 39, 6, 0 },
		{ "The Dustbowl", 259, 447, 0, 37, 42, 11, 4 },
		{ "Kargath", 39, 471, 1, 40, 52, 24, 10 },
	},
	[1419] = { -- Blasted Lands
		{ "Nethergarde Keep", 664, 196, 2, 47, 47, 5, 0 },
		{ "Dreadmaul Hold", 506, 142, 0, 50, 50, 10, 12 },
	},
	[1420] = { -- Tirisfal Glades
		{ "Deathknell", 312, 664, 1, 1, 3, 17, 8 },
		{ "Brill", 605, 519, 1, 6, 10, 33, 1 },
		{ "Garren's Haunt", 678, 427, 1, 10, 11, 4, 0 },
	},
	[1421] = { -- Silverpine Forest
		{ "The Shining Strand", 541, 124, 1, 11, 11, 4, 0 },
		{ "The Sepulcher", 437, 407, 1, 11, 15, 31, 11 },
	},
	[1422] = { -- Western Plaguelands
		{ "Felstone Field (west)", 380, 555, 0, 52, 53, 6, 0 },
		{ "Felstone Field", 533, 650, 0, 54, 55, 6, 0 },
		{ "Felstone Field (north)", 470, 509, 0, 55, 55, 6, 0 },
		{ "Chillwind Camp", 430, 841, 2, 52, 56, 28, 6 },
		{ "Dalson's Tears", 394, 668, 0, 56, 56, 9, 0 },
		{ "The Bulwark", 264, 561, 1, 53, 56, 24, 8 },
		{ "The Writhing Haunt", 702, 738, 0, 60, 60, 7, 0 },
		{ "The Writhing Haunt (west)", 502, 780, 0, 55, 60, 5, 0 },
	},
	[1423] = { -- Eastern Plaguelands
		{ "Light's Hope Chapel", 716, 492, 0, 60, 60, 147, 15 },
	},
	[1424] = { -- Hillsbrad Foothills
		{ "Tarren Mill", 622, 201, 1, 22, 30, 45, 11 },
		{ "Southshore", 504, 580, 2, 32, 34, 21, 5 },
	},
	[1425] = { -- The Hinterlands
		{ "Plaguemist Ravine", 233, 585, 1, 43, 43, 8, 0 },
		{ "Plaguemist Ravine (east)", 316, 577, 1, 43, 43, 4, 0 },
		{ "Aerie Peak", 101, 449, 2, 43, 46, 6, 6 },
		{ "Plaguemist Ravine (north)", 267, 484, 0, 43, 46, 4, 0 },
		{ "Aerie Peak (east)", 145, 442, 2, 45, 47, 5, 1 },
		{ "Revantusk Village", 790, 799, 1, 48, 48, 16, 9 },
	},
	[1426] = { -- Dun Morogh
		{ "Coldridge Valley", 295, 701, 2, 1, 1, 16, 4 },
		{ "Coldridge Valley (south)", 242, 743, 2, 3, 4, 6, 0 },
		{ "Brewnall Village", 303, 457, 2, 6, 8, 6, 0 },
		{ "Kharanos", 473, 513, 2, 4, 10, 31, 1 },
	},
	[1427] = { -- Searing Gorge
		{ "The Cauldron", 391, 390, 0, 48, 50, 9, 0 },
		{ "Thorium Point", 388, 274, 1, 48, 50, 12, 8 },
		{ "Thorium Point", 388, 274, 2, 48, 50, 13, 4 },
	},
	[1428] = { -- Burning Steppes
		{ "Flame Crest", 652, 234, 1, 52, 55, 17, 10 },
		{ "Flame Crest", 652, 234, 2, 52, 55, 17, 0 },
		{ "Morgan's Vigil", 849, 690, 2, 52, 56, 17, 6 },
		{ "Altar of Storms", 125, 316, 0, 58, 60, 9, 0 },
		{ "Blackrock Mountain", 319, 261, 0, 60, 60, 23, 0 },
	},
	[1429] = { -- Elwynn Forest
		{ "Northshire Valley", 490, 415, 2, 1, 4, 22, 4 },
		{ "Fargodeep Mine (south)", 346, 842, 2, 6, 6, 4, 0 },
		{ "Jerod's Landing", 431, 866, 2, 1, 6, 4, 0 },
		{ "Eastvale Logging Camp", 834, 679, 2, 1, 10, 8, 0 },
		{ "Fargodeep Mine", 244, 755, 2, 10, 10, 4, 0 },
		{ "Goldshire", 426, 658, 2, 7, 10, 26, 1 },
	},
	[1431] = { -- Duskwood
		{ "The Hushed Bank", 78, 339, 2, 21, 26, 6, 0 },
		{ "Darkshire", 739, 466, 2, 23, 28, 43, 5 },
		{ "Raven Hill Cemetery", 282, 314, 2, 24, 28, 6, 0 },
	},
	[1432] = { -- Loch Modan
		{ "Valley of Kings", 231, 743, 2, 12, 15, 5, 0 },
		{ "Thelsamar", 358, 476, 2, 10, 16, 14, 5 },
		{ "Ironband's Excavation Site", 828, 643, 2, 15, 17, 5, 0 },
	},
	[1433] = { -- Redridge Mountains
		{ "Lakeshire", 261, 468, 2, 14, 20, 25, 5 },
	},
	[1434] = { -- Stranglethorn Vale
		{ "Rebel Camp", 381, 37, 2, 33, 37, 12, 4 },
		{ "Lake Nazferiti", 357, 106, 0, 31, 38, 19, 0 },
		{ "Booty Bay", 274, 764, 2, 35, 41, 64, 3 },
		{ "Grom'gol Base Camp", 322, 281, 1, 37, 41, 21, 11 },
		{ "Booty Bay", 274, 764, 1, 35, 42, 56, 3 },
		{ "Venture Co. Base Camp", 509, 202, 0, 45, 45, 8, 0 },
	},
	[1435] = { -- Swamp of Sorrows
		{ "Stagalbog", 828, 806, 1, 42, 43, 5, 0 },
		{ "Stonard", 467, 558, 1, 35, 44, 8, 11 },
	},
	[1436] = { -- Westfall
		{ "Furlbrow's Pumpkin Farm (north)", 600, 194, 2, 10, 11, 4, 0 },
		{ "Furlbrow's Pumpkin Farm", 562, 309, 2, 10, 12, 4, 0 },
		{ "Sentinel Hill", 562, 482, 2, 10, 16, 14, 4 },
	},
	[1437] = { -- Wetlands
		{ "Ironbeard's Tomb", 383, 516, 2, 24, 27, 5, 0 },
		{ "Menethil Harbor", 103, 591, 2, 22, 28, 24, 7 },
		{ "Dun Modr", 498, 182, 2, 18, 31, 7, 0 },
	},
	[1438] = { -- Teldrassil
		{ "Shadowglen", 589, 425, 2, 1, 4, 19, 4 },
		{ "Dolanaar", 561, 591, 2, 5, 10, 29, 1 },
	},
	[1439] = { -- Darkshore
		{ "Auberdine", 377, 431, 2, 12, 14, 38, 7 },
		{ "The Master's Glaive", 437, 763, 2, 1, 17, 5, 0 },
		{ "Cliffspring River", 543, 248, 2, 16, 18, 5, 0 },
		{ "Remtravel's Excavation", 317, 844, 0, 16, 19, 4, 0 },
	},
	[1440] = { -- Ashenvale
		{ "Astranaar", 360, 499, 2, 19, 22, 14, 7 },
		{ "Thistlefur Village", 263, 387, 2, 20, 24, 7, 0 },
		{ "Zoram'gar Outpost", 123, 339, 1, 19, 24, 9, 10 },
		{ "Fallen Sky Lake (north)", 708, 688, 1, 21, 26, 4, 0 },
		{ "Splintertree Post", 734, 609, 1, 20, 26, 6, 3 },
		{ "Iris Lake", 541, 469, 2, 27, 28, 5, 0 },
		{ "Lake Falathim", 220, 531, 2, 30, 31, 4, 0 },
		{ "Fallen Sky Lake", 618, 839, 2, 25, 35, 7, 0 },
	},
	[1441] = { -- Thousand Needles
		{ "Freewind Post", 454, 505, 1, 25, 28, 8, 11 },
		{ "The Shimmering Flats", 790, 767, 1, 30, 37, 26, 0 },
		{ "The Shimmering Flats", 790, 767, 2, 30, 38, 28, 4 },
	},
	[1442] = { -- Stonetalon Mountains
		{ "Malaka'jin", 730, 957, 1, 19, 20, 4, 0 },
		{ "Sishir Canyon", 596, 660, 2, 21, 22, 14, 4 },
		{ "Sun Rock Retreat", 469, 615, 1, 20, 25, 13, 11 },
	},
	[1443] = { -- Desolace
		{ "Ghost Walker Post", 524, 538, 1, 33, 33, 8, 0 },
		{ "Kormek's Hut", 560, 588, 1, 31, 33, 5, 0 },
		{ "Gelkis Village", 368, 790, 2, 32, 36, 6, 0 },
		{ "Shadowprey Village", 240, 710, 1, 25, 36, 7, 9 },
		{ "Ethel Rethor", 374, 288, 2, 33, 37, 4, 0 },
		{ "Gelkis Village", 368, 790, 1, 35, 37, 5, 0 },
		{ "Nijel's Point", 663, 99, 2, 33, 39, 16, 6 },
	},
	[1444] = { -- Feralas
		{ "Camp Mojache", 748, 433, 1, 43, 45, 37, 11 },
		{ "Feathermoon Stronghold", 311, 445, 2, 43, 45, 30, 7 },
		{ "Grimtotem Compound", 658, 456, 2, 47, 47, 4, 0 },
	},
	[1445] = { -- Dustwallow Marsh
		{ "The Den of Flame", 297, 480, 0, 35, 35, 4, 0 },
		{ "Witch Hill", 554, 260, 0, 35, 35, 5, 0 },
		{ "Theramore Isle", 670, 479, 2, 30, 38, 17, 5 },
		{ "Brackenwall Village", 362, 315, 1, 35, 40, 15, 10 },
	},
	[1446] = { -- Tanaris
		{ "Gadgetzan", 518, 277, 1, 45, 49, 67, 11 },
		{ "Gadgetzan", 518, 277, 2, 45, 49, 68, 7 },
		{ "Steamwheedle Port", 663, 216, 0, 45, 58, 23, 0 },
	},
	[1447] = { -- Azshara
		{ "Valormok", 223, 514, 1, 52, 52, 7, 10 },
	},
	[1448] = { -- Felwood
		{ "Emerald Sanctuary", 510, 825, 1, 48, 54, 15, 0 },
		{ "Emerald Sanctuary", 510, 825, 2, 51, 54, 20, 4 },
		{ "Emerald Sanctuary (south)", 541, 868, 1, 55, 55, 6, 0 },
		{ "Emerald Sanctuary (south)", 541, 868, 2, 55, 55, 12, 0 },
		{ "Emerald Sanctuary (west)", 467, 832, 1, 55, 55, 12, 0 },
		{ "Emerald Sanctuary (west)", 467, 832, 2, 55, 55, 6, 0 },
		{ "Felpaw Village", 650, 49, 0, 55, 55, 8, 0 },
		{ "Shatter Scar Vale", 419, 447, 0, 50, 55, 9, 0 },
		{ "Bloodvenom Post", 352, 523, 1, 54, 56, 12, 10 },
	},
	[1449] = { -- Un'Goro Crater
		{ "Marshal's Refuge", 441, 85, 0, 51, 52, 13, 14 },
	},
	[1450] = { -- Moonglade
		{ "Moonglade (south)", 519, 439, 0, 52, 58, 4, 0 },
		{ "Moonglade", 537, 353, 0, 60, 60, 12, 12 },
		{ "Moonglade (west)", 363, 413, 0, 60, 60, 4, 0 },
	},
	[1451] = { -- Silithus
		{ "Cenarion Hold", 506, 380, 1, 59, 60, 85, 11 },
		{ "Cenarion Hold", 506, 380, 2, 59, 60, 85, 5 },
	},
	[1452] = { -- Winterspring
		{ "Starfall Village", 520, 303, 2, 56, 57, 4, 0 },
		{ "Everlook", 613, 383, 1, 54, 60, 35, 11 },
		{ "Everlook", 613, 383, 2, 54, 60, 21, 7 },
	},
	[2521] = { -- Zephras Isle
		{ "Thendal Village", 430, 240, 0, 1, 1, 10, 12 },
		{ "Shen'dar Village", 454, 455, 0, 8, 8, 5, 0 },
	},
}
