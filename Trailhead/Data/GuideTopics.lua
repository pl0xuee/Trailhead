local _, T = ...
local L = T.L

-- The words of the Guide's know-how topics. Facts come from the game's own text (its help
-- tips, tutorial strings, ruleset descriptions and interface source) and from Blizzard's and
-- the guides' articles on World of Warcraft: Forever; a number is given only where the
-- sources agree. A row is { name, text, find = category }: a row with `find` is a button
-- into Find it. Names stay under 15 characters and texts under 69 so a row fits on a line.

T.GuideGroups = {
	{ id = "you", label = L["Character"] },
	{ id = "world", label = L["The world"] },
	{ id = "others", label = L["With others"] },
	{ id = "gold", label = L["Gold and more"] },
}

T.GuideTopics = {
	services = {
		what = L["Towns and cities have people who do things for you. Each row below is one of them. Click a row to find the nearest one on your map."],
		rows = {
			{ L["Inn"], L["Rest here. The innkeeper can make it your hearthstone's home."], find = "inn" },
			{ L["Bank"], L["A bank keeps items safe when your bags are full."], find = "bank" },
			{ L["Mailbox"], L["Send items and gold to anyone, even your other characters."], find = "mailbox" },
			{ L["Auction house"], L["Players buy and sell here. Your side's big cities share one."], find = "auction" },
			{ L["Flight master"], L["Fly to flight masters you have met before, for a small fee."], find = "flight" },
			{ L["Trainer"], L["Teaches new abilities for gold. Yours is in your start area."], find = "trainer" },
			{ L["Stable master"], L["Hunters keep their spare pets here."], find = "stable" },
		},
		next = L["Vendors sell food, drink and gear, and some of them repair what you wear. Ask a guard if you cannot find a place in a city."],
	},

	grouping = {
		what = L["Some fights and dungeons are too hard alone. Up to five players make a party, and each one has a job: tank, healer or damage."],
		rows = {
			{ L["Tank"], L["Takes the hits and keeps the enemy's attention."] },
			{ L["Healer"], L["Keeps everyone alive."] },
			{ L["Damage"], L["Kills the enemy. Most groups have several."] },
			{ L["Find a group"], L["No automatic queue. Ask in chat or use Looking For Group."] },
			{ L["Loot rolls"], L["Need if you will use it. Greed to sell it. Pass to skip."] },
		},
		manners = L["Talk before you invite someone, and be polite: it gets you invited back. To invite a player, right-click their portrait and choose Invite."],
	},

	danger = {
		what = L["Every enemy shows a level. The colour of its name tells you how a fight against it will go. Players of the other side can also be a danger."],
		rows = {
			{ L["Green or grey"], L["Easy to beat."] },
			{ L["Yellow"], L["A fair fight."] },
			{ L["Orange"], L["3 or 4 levels above you. Hard."] },
			{ L["Red"], L["5 or more levels above you. Very risky."] },
			{ L["Skull"], L["Far above you. It will kill you, so walk around it."] },
			{ L["Dragon"], L["Gold: much tougher, best with a group. Silver: rare, better loot."] },
		},
		next = L["If a fight goes badly, run toward a town or a guard. Your ruleset decides who can attack you: PvE only when you choose, PvP almost always."],
		pvp = L["On the PvE ruleset you fight other players only when you choose (type /pvp). On the PvP ruleset you can be attacked almost anywhere. Dying to a player does not wear your gear."],
	},

	money = {
		what = L["Gold pays for new abilities, repairs, riding and gear. You earn it from quests, from selling things and from what enemies drop."],
		rows = {
			{ L["Abilities"], L["Your trainer charges for every new ability and rank."] },
			{ L["Repairs"], L["A vendor who repairs restores worn gear for a fee."] },
			{ L["Sell"], L["Grey items sell to any vendor. Keep what you can use."] },
			{ L["Keep"], L["Food, drink, bandages and what your abilities use up."] },
		},
	},

	reputation = {
		what = L["Reputation is how much a group in the world likes you. Quests and kills for a group raise it. Open your character window and its Reputation tab to see where you stand."],
		standings = { L["Hated"], L["Hostile"], L["Unfriendly"], L["Neutral"], L["Friendly"], L["Honored"], L["Revered"], L["Exalted"] },
		next = L["Many groups offer rewards once they like you enough. The Legacy reward track is a reputation of its own that fills as you earn Legacy points."],
	},

	travel = {
		what = L["You can ride, use your hearthstone, fly with a flight master, or take a boat, a zeppelin or the tram between far places."],
		rows = {
			{ L["Flight master"], L["Talk to each new one you pass. You can fly to those you met."], find = "flight" },
			{ L["Boats"], L["Boats and zeppelins cross the water. Ask a guard where to board."] },
		},
		tram = L["The Deeprun Tram joins Stormwind and Ironforge."],
	},

	forever = {
		what = L["World of Warcraft: Forever adds a few systems of its own: Legacy, which carries rewards between your characters, camping, and rulesets that decide who you play with."],
		rows = {
			{ L["Legacy points"], L["Challenges you finish earn them. Your whole account shares them."] },
			{ L["Legacy trees"], L["Spend them in three trees: Professions, Adventure, Resourcefulness."] },
			{ L["Camping"], L["Light a campfire and sit by it for bonuses from camp items."] },
			{ L["Rulesets"], L["Yours decides who you meet. You only play with the same ruleset."] },
			{ L["Hardcore"], L["A ruleset where death is permanent."] },
		},
	},

	-- Shorthand a new player meets, a page at a time.
	words = {
		what = L["Players write in short forms. Here is what they mean, and the chat channels and commands you will use. Press the button below for the next page."],
		pages = {
			{ title = L["Groups"], rows = {
				{ "LFG", L["Looking for group. A player who wants to join one."] },
				{ "LFM", L["Looking for more. A group that needs another player."] },
				{ "DPS", L["Damage per second. A player who deals damage."] },
				{ L["Tank"], L["The player who takes the hits."] },
				{ L["Need, greed"], L["Loot rolls: need if you will use it, greed to sell it."] },
				{ L["Wipe"], L["The whole group dies."] },
				{ L["Res"], L["Resurrect: bring a dead player back to life."] },
			} },
			{ title = L["Fights"], rows = {
				{ L["Pull"], L["Start a fight by drawing enemies to you."] },
				{ L["Add"], L["An extra enemy that joins a fight."] },
				{ L["Aggro"], L["An enemy's attention. Tanks try to hold it."] },
				{ "AoE", L["Area of effect: hits many enemies at once."] },
				{ L["Kite"], L["Keep moving away from an enemy while you hit it."] },
				{ L["Proc"], L["A chance effect that fires from your attacks or spells."] },
				{ "CC", L["Crowd control: keeps an enemy from fighting for a while."] },
			} },
			{ title = L["Items and enemies"], rows = {
				{ L["Buff"], L["A good effect on you, such as more strength."] },
				{ L["Debuff"], L["A bad effect on you or an enemy, such as a slow."] },
				{ "BoP", L["Bind on pickup: it is yours alone once you take it."] },
				{ "BoE", L["Bind on equip: yours alone once you put it on."] },
				{ L["Hearth"], L["Use your hearthstone to go back to your inn."] },
				{ L["Mob"], L["Any monster or enemy creature."] },
				{ L["Elite, rare"], L["Tougher enemies. Gold dragon: elite. Silver: rare."] },
			} },
			{ title = L["Chat channels"], rows = {
				{ "/1", L["General: talk to everyone in the area."] },
				{ "/2", L["Trade: buying and selling items."] },
				{ "/4", L["LookingForGroup: ask for a group (the number can differ)."] },
				{ "/join", L["Type /join and a channel name to join a channel."] },
			} },
			{ title = L["Chat commands"], rows = {
				{ "/s, /y", L["Say to people nearby, or yell to people further away."] },
				{ "/w name", L["Whisper: a private message to one player."] },
				{ "/r", L["Reply to the last player who whispered you."] },
				{ "/p", L["Talk to your party."] },
				{ "/g", L["Talk to your guild."] },
				{ "/who", L["Search for players online by name, level or zone."] },
			} },
		},
	},

	-- What each class is. resource and good are plain lines; needs is what to carry or know.
	classes = {
		WARRIOR = { resource = L["Rage. It builds as you fight and fades after."],
			good = L["A close-range fighter."],
			needs = L["Stances change what you can do: Defensive comes at level 10."] },
		PALADIN = { resource = L["Mana, which refills when you rest or drink."],
			good = L["An armored fighter with healing and blessings."],
			needs = L["Little at first. Some blessings need Symbols later."] },
		HUNTER = { resource = L["Mana, which refills when you rest or drink."],
			good = L["Hits from a distance and fights beside a pet."],
			needs = L["Ammunition for your bow or gun, and food for your pet."] },
		ROGUE = { resource = L["Energy, which refills fast, and combo points."],
			good = L["Sneaks up with Stealth and hits hard up close."],
			needs = L["Powders for some abilities. Poisons are brewed from vendor reagents."] },
		PRIEST = { resource = L["Mana, which refills when you rest or drink."],
			good = L["Heals the group, or casts shadow spells."],
			needs = L["Candles for group buffs later, and a feather for Levitate."] },
		SHAMAN = { resource = L["Mana, which refills when you rest or drink."],
			good = L["Uses totems, spells and melee. Can heal or deal damage."],
			needs = L["A totem item for each element, and an Ankh later."] },
		MAGE = { resource = L["Mana, which refills when you rest or drink."],
			good = L["Casts strong spells from a distance. Makes food and water."],
			needs = L["Runes for teleports and portals later, and a feather for Slow Fall."] },
		WARLOCK = { resource = L["Mana, which refills when you rest or drink."],
			good = L["Casts damaging spells and calls demons to help."],
			needs = L["Soul Shards in your bags: summoning demons and some spells use one."] },
		DRUID = { resource = L["Mana, plus rage or energy in animal forms."],
			good = L["Changes shape: bear to take hits, cat to fight, or heals."],
			needs = L["Seeds and berries for a few spells later."] },
	},
	roleNames = { [2] = L["Tank"], [4] = L["Healer"], [8] = L["Damage"] },
}
