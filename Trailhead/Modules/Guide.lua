local _, T = ...
local L = T.L
local W = T.Widgets
local Theme = T.Theme
local C = T.Compat
local G = T.Game
local P = T.Places

-- Guide: the things nobody tells a new player. Every topic reads the same way: what it
-- is, where you stand right now (read from the game), and what to do next.

local Guide = T:NewModule("guide", { label = L["Guide"], icon = "scroll", order = 5 })

local PAGE_W = 778
local LIST_W, TOP = 214, 44
local PANEL_X = LIST_W + 14
local PANEL_W, PANEL_H = PAGE_W - PANEL_X, 496 - TOP
local TOPIC_H, TOPIC_GAP = 38, 5
local ROW_H, MAX_ROWS = 24, 9
local ROW_PAD = 6 -- above and below the words in a row
local NOTE_W, TAG_W = PANEL_W - 40 - 104, 44 -- a row of words, and the room a tag takes from it
local LABEL_H, GAP = 10, 14 -- a small section label, and the space above one
local FOOT = 18 -- under the last line or button
local MAX_USE_ROWS = 3
local LEGACY_LEVEL = 25 -- the game: Legacy opens when a first character reaches it

local ui = { topics = {}, rows = {} }
Guide.topic = "talents"

local DOT = "  \194\183  "

local D = T.GuideTopics or {}

local function findRun(category)
	return function()
		T.Window:Open("find", category)
	end
end

-- Rows of plain words from the shipped text; a row with `find` is a button into Find it.
local function plainRows(list)
	local rows = {}
	for _, row in ipairs(list or {}) do
		rows[#rows + 1] = { name = row[1], text = row[2], run = row.find and findRun(row.find) or nil,
			tag = row.find and L["Find"] or nil, tagRole = "accentText" }
	end
	return rows
end

-- The class's trainer spells and what they use up, from the game's own tables (shipped in
-- Data/ClassSpells.lua). Parsed once per class. Teleports of the other side's cities are left out.
local parsed = { spells = {}, uses = {} }

local function mySide()
	local faction = G.Faction()
	return faction == 1 and "H" or faction == 2 and "A" or nil
end

local function shippedSpells(class)
	local key = (class or "") .. (mySide() or "")
	if not parsed.spells[key] then
		local list, side = {}, mySide()
		for line in ((T.ClassSpells and T.ClassSpells[class]) or ""):gmatch("[^;]+") do
			local level, name, rank, only = line:match("^(%d+)|([^|]*)|(%d+)|(.*)$")
			if level and (only == "" or only == side) then
				rank = tonumber(rank)
				list[#list + 1] = { name = rank > 1 and L["%s (Rank %d)"]:format(name, rank) or name, level = tonumber(level), cost = 0, shipped = true }
			end
		end
		parsed.spells[key] = list
	end
	return parsed.spells[key]
end

-- What the class's abilities use up: { item, spell, level, count }, one per item, by level.
local function shippedUses(class)
	local key = (class or "") .. (mySide() or "")
	if not parsed.uses[key] then
		local list, side, seen = {}, mySide(), {}
		for line in ((T.ClassUses and T.ClassUses[class]) or ""):gmatch("[^;]+") do
			local level, spell, item, count, only = line:match("^(%d+)|([^|]*)|([^|]*)|(%d+)|(.*)$")
			if level and (only == "" or only == side) and not seen[item] then
				seen[item] = true
				list[#list + 1] = { item = item, spell = spell, level = tonumber(level), count = tonumber(count) }
			end
		end
		table.sort(list, function(a, b)
			if a.level ~= b.level then
				return a.level < b.level
			end
			return a.item < b.item
		end)
		parsed.uses[key] = list
	end
	return parsed.uses[key]
end
Guide.ShippedSpells, Guide.ShippedUses = shippedSpells, shippedUses

local SOON = 10 -- levels ahead that count as "soon"

-- ---------------------------------------------------------------------------
-- Topics. Each returns { what, rows = { {name, rank, max, tag, tone} }, next, attention,
-- action = { label, run } } from what the game says right now.

local NOT_LISTED = L["The game has not listed your skills yet. Open your character window once, or try again in a moment."]

local function weapons()
	local skills = G.Skills()
	local hands = G.Hands(skills)
	local behind = G.WeaponsBehind(nil, skills)
	local out = { rows = {}, attention = #behind }
	out.what = L["Every kind of weapon has its own skill. It rises as you fight with that kind of weapon, up to a limit of 5 for each level you have. Every point under the limit takes a little off your chance to hit and to crit."]
	table.sort(skills.weapons, function(a, b)
		if (a.inHand or false) ~= (b.inHand or false) then
			return a.inHand or false
		end
		if a.rank ~= b.rank then
			return a.rank > b.rank
		end
		return a.name < b.name
	end)
	local room = skills.defense and MAX_ROWS - 1 or MAX_ROWS
	out.total = #skills.weapons + (skills.defense and 1 or 0)
	for index, skill in ipairs(skills.weapons) do
		if index > room then
			break
		end
		local low = skill.inHand and skill.max - skill.rank >= G.SKILL_BEHIND
		out.rows[#out.rows + 1] = {
			name = skill.name, rank = skill.rank, max = skill.max,
			tag = low and L["In hand, low"] or skill.inHand and L["In hand"] or nil, tone = low and "warn" or "go",
		}
	end
	if skills.defense then
		-- The tag is the game's own description of the Defense skill.
		out.rows[#out.rows + 1] = { name = skills.defense.name, rank = skills.defense.rank, max = skills.defense.max,
			tag = L["Makes you harder to hit"], tone = "faint" }
		out.pinLast = true
	end
	if #skills.weapons == 0 then
		out.next = skills.complete and L["The game lists no weapon skills for this character."] or NOT_LISTED
	elseif #behind > 0 then
		local skill = behind[1]
		out.next = L["Your %s skill is behind: %d of %d. By the game's own figures that costs about %.1f%% of your chance to hit and to crit an enemy of your level. Keep using it on enemies you beat easily until it catches up."]
			:format(skill.name, skill.rank, skill.max, G.SkillCost(skill))
	elseif #hands > 0 then
		out.next = L["The weapons in your hands are in good shape. When you pick up a new kind of weapon, look here first: a skill far under its limit means you will hit and crit a little less often until you have used it for a while."]
	else
		out.next = L["When you pick up a new kind of weapon, look here first: a skill far under its limit means you will hit and crit a little less often until you have used it for a while."]
	end
	-- A kind of weapon the character cannot use yet is learned from a weapon master.
	if #skills.weapons > 0 and #P.Known("weapons") + #P.Find("weapons") > 0 then
		local facts = T.Known.weapons
		out.next = out.next .. " " .. L["A kind of weapon you cannot use yet is taught by a weapon master in a city, for about %s (polearms: level %d, %s)."]
			:format(G.MoneyText(facts.cost), facts.polearmLevel, G.MoneyText(facts.polearmCost))
		out.action = { label = L["Find a weapon master"], run = function()
			T.Window:Open("find", "weapons")
		end }
	end
	return out
end

local function professions()
	local skills = G.Skills()
	local out = { rows = {}, attention = 0 }
	out.what = L["Professions let you gather materials and make things. Each one has a skill that rises as you use it, up to a limit."]
	local near
	for _, list in ipairs({ skills.professions, skills.secondary }) do
		for _, skill in ipairs(list) do
			local full = not skill.levelBound and skill.max - skill.rank <= G.SKILL_NEAR
			if full then
				out.attention = out.attention + 1
				near = near or skill
			end
			out.rows[#out.rows + 1] = {
				name = skill.name, rank = skill.rank, max = skill.max,
				tag = full and L["Near its limit"] or nil, tone = "warn",
			}
		end
	end
	out.total = #out.rows
	local find = { label = L["Find a profession trainer"], run = function()
		T.Window:Open("find", "professions")
	end }
	if #out.rows == 0 then
		out.next = skills.complete and L["You have no professions yet. Profession trainers in towns and cities teach them."] or NOT_LISTED
		out.action = find
	elseif near then
		out.next = L["%s is close to its limit: %d of %d. A skill stops rising at its limit, so see its trainer for the next step."]
			:format(near.name, near.rank, near.max)
		out.action = find
	else
		out.next = L["Nothing needs doing. Your skills rise as you gather and make things."]
	end
	return out
end

local function talents()
	local out = { rows = {}, attention = 0 }
	out.what = L["Talent points make your abilities stronger. Your class has three trees to put them in, and the deeper rows of a tree open as you put more points into it."]
	local info = G.Talents()
	if not info then
		out.next = L["The game has not listed your talents yet. Try again in a moment."]
		return out
	end
	local had = info.spent + info.unspent
	for _, tree in ipairs(info.trees) do
		out.rows[#out.rows + 1] = {
			name = tree.name, frac = info.spent > 0 and tree.spent / info.spent or 0,
			value = tree.spent == 1 and L["1 point"] or L["%d points"]:format(tree.spent),
		}
	end
	out.total = #out.rows
	-- With a build chosen the button leads to its next point, with the talent window beside it.
	local open = { label = L["Open talents"], run = function()
		T.BuildGuide.Open()
	end }
	local progress = T.BuildGuide.Following()
	local nextPoint = progress and progress.next
		and " " .. L["Next in your build: %s (%d of %d)."]:format(progress.next.name, progress.next.rank, progress.next.max) or ""
	if info.unspent > 0 then
		out.attention = 1
		out.next = (info.unspentUnknown and L["You have talent points to spend. Unspent points do nothing."]
			or info.unspent == 1 and L["You have 1 talent point to spend. Unspent points do nothing."]
			or L["You have %d talent points to spend. Unspent points do nothing."]:format(info.unspent)) .. nextPoint
		out.action = open
	elseif had == 0 then
		out.next = L["You have no talent points yet. They come as you level up."]
	elseif G.NextTalentLevel(info) then
		out.next = L["All %d of your points are spent. You have had one for every level since %d, so the next comes at level %d."]
			:format(had, G.FIRST_TALENT_LEVEL, G.NextTalentLevel(info)) .. nextPoint
		out.action = open
	else
		out.next = L["All your talent points are spent."] .. nextPoint
		out.action = open
	end
	return out
end

-- What the next levels bring, from what the game itself has listed: the class trainer's
-- full list (saved at the last visit), and the levels the group finder gives for dungeons
-- and zones. Levels with nothing new are left out.
local function coming()
	local out = { rows = {}, attention = 0 }
	out.what = L["What your next levels bring: new abilities at your class trainer, and the dungeons and zones that open up. Levels with nothing new are left out."]
	local level, top = G.Level(), G.MaxLevel()
	if level >= top then
		out.next = L["You are at the top level. Nothing more unlocks by levelling."]
		return out
	end
	local training, world = G.Training(), G.World()
	local byLevel, levels = {}, {}
	local function at(need)
		if not byLevel[need] then
			byLevel[need] = { level = need, spells = {}, dungeons = {}, zones = {}, cost = 0 }
			levels[#levels + 1] = byLevel[need]
		end
		return byLevel[need]
	end
	-- Before a trainer visit the shipped list stands in; the trainer's own list wins after.
	local upcoming = training.later
	if not training.source then
		upcoming = {}
		for _, item in ipairs(shippedSpells(G.ClassFile())) do
			if item.level > level then
				upcoming[#upcoming + 1] = item
			end
		end
	end
	for _, item in ipairs(upcoming) do
		if item.level <= top then
			local entry = at(item.level)
			entry.spells[#entry.spells + 1] = item
			entry.cost = entry.cost + item.cost
		end
	end
	for _, dungeon in ipairs(world.dungeons) do
		if dungeon.lo > level and dungeon.lo <= top then
			local entry = at(dungeon.lo)
			entry.dungeons[#entry.dungeons + 1] = dungeon
		end
	end
	for _, zone in ipairs(world.zones) do
		-- Not the other side's own lands.
		if zone.lo and zone.lo > level and zone.lo <= top and not (zone.hostile and not zone.friendly) then
			local entry = at(zone.lo)
			entry.zones[#entry.zones + 1] = zone
		end
	end
	table.sort(levels, function(a, b)
		return a.level < b.level
	end)
	out.total = #levels
	for index = 1, math.min(#levels, MAX_ROWS) do
		local entry, parts = levels[index], {}
		if #entry.spells > 0 then
			parts[#parts + 1] = L["Trainer: %s"]:format(G.NameList(entry.spells, 2))
		end
		if #entry.dungeons > 0 then
			parts[#parts + 1] = L["Dungeon: %s"]:format(G.NameList(entry.dungeons, 2))
		end
		if #entry.zones > 0 then
			parts[#parts + 1] = L["Zone: %s"]:format(G.NameList(entry.zones, 2))
		end
		out.rows[index] = { name = L["Level %d"]:format(entry.level), text = table.concat(parts, ". ") }
	end

	local lines = {}
	local xp, xpMax = C.Plain(UnitXP("player"), 0), C.Plain(UnitXPMax("player"), 0)
	if type(xp) == "number" and type(xpMax) == "number" and xpMax > 0 then
		lines[#lines + 1] = L["You are %d%% of the way to level %d."]:format(math.floor(xp / xpMax * 100), level + 1)
	end
	local first
	for _, entry in ipairs(levels) do
		if #entry.spells > 0 then
			first = entry
			break
		end
	end
	if not training.source then
		if first then
			lines[#lines + 1] = L["By the game's own tables, at level %d your trainer should have %s."]:format(first.level, G.NameList(first.spells, 3))
		end
		lines[#lines + 1] = L["Visit your class trainer once: Trailhead then knows every ability that is coming and what it costs."]
		out.action = { label = L["Find your trainer"], run = function()
			T.Window:Open("find", "trainer")
		end }
	elseif first then
		local have = C.Plain(GetMoney and GetMoney(), nil)
		lines[#lines + 1] = L["At level %d your trainer has %s for you, %s in all."]
			:format(first.level, G.NameList(first.spells, 3), G.MoneyText(first.cost))
		if type(have) == "number" then
			lines[#lines + 1] = have >= first.cost and L["You have enough for that already."]
				or L["You have %s, so keep some aside."]:format(G.MoneyText(have))
		end
	elseif #levels == 0 then
		lines[#lines + 1] = L["The game lists nothing new for the levels you have left."]
	end
	local info = G.Talents()
	local talentLevel = info and G.NextTalentLevel(info)
	if talentLevel then
		lines[#lines + 1] = L["Your next talent point comes at level %d."]:format(talentLevel)
	end
	out.next = table.concat(lines, " ")
	return out
end

-- Inns, the hearthstone and rested experience. Every statement is the game's own: the
-- experience bar's help text, the rest state it reports, and the hearthstone's tooltip
-- (game check 7).
local function rest()
	local out = { rows = {}, attention = 0 }
	out.what = L["Your hearthstone takes you back to your home inn, and an innkeeper somewhere else can make their inn your home instead. Time in an inn or a city, even logged out, makes you rested, and a rested character earns extra experience from killing monsters."]
	local state = G.Rest()
	local find = { label = L["Find an inn"], run = function()
		T.Window:Open("find", "inn")
	end }
	out.rows[#out.rows + 1] = { name = L["Home"], text = state.home or L["None yet"] }
	if state.stone then
		local minutes = math.ceil(state.stone.left / 60)
		out.rows[#out.rows + 1] = { name = L["Hearthstone"], text = not state.stone.carried and L["Not in your bags"]
			or minutes <= 0 and L["Ready"] or minutes == 1 and L["Ready in 1 minute"] or L["Ready in %d minutes"]:format(minutes) }
	end
	local bonus = state.multiplier and state.multiplier > 1
	if state.name and state.multiplier then
		out.rows[#out.rows + 1] = { name = L["Rest"],
			text = L["%s: %d%% of normal experience from monsters"]:format(state.name, math.floor(state.multiplier * 100 + 0.5)) }
	end
	if bonus then
		out.rows[#out.rows + 1] = { name = L["Bonus left"],
			text = state.rested > 0 and L["%d more experience from monsters at that rate"]:format(state.rested) or L["None"] }
	end
	out.rows[#out.rows + 1] = { name = L["Right now"], text = state.resting and L["In an inn or a city: your rest is building up"] or L["Out in the world"] }
	out.total = #out.rows

	if not state.home and C.Has("GetBindLocation") then
		out.attention = 1
		out.next = L["Your hearthstone has no home. Ask an innkeeper to make their inn your home."]
		out.action = find
	elseif state.resting then
		out.next = L["You are in an inn or a city, so your rest is building up right now. Log out here when you stop playing and it keeps building while you are away."]
	elseif bonus then
		out.next = L["You are rested, so monsters give more experience until the bonus runs out. When you stop playing, log out in an inn or a city to build it up again."]
		out.action = find
	else
		out.next = L["You are not rested. When you stop playing, log out in an inn or a city: your rest builds up while you are away, and a rested character earns extra experience from monsters."]
		out.action = find
	end
	return out
end

-- What gets used up: food and drink, bandages, potions, counted from the bags by the kinds
-- the game files them under.
local function supplies()
	local out = { rows = {}, attention = 0 }
	out.what = L["The things you use up between and during fights: food and drink, bandages and potions, and what your class abilities need. Trailhead counts what is in your bags, and each item says what it does in its own tooltip."]
	local carried = G.Supplies()
	if not carried.read then
		out.next = L["The game has not listed your bags yet. Try again in a moment."]
		return out
	end
	for _, group in ipairs({ { carried.food, L["Food and drink"] }, { carried.bandages, L["Bandages"] }, { carried.potions, L["Potions"] } }) do
		local have = group[1]
		out.rows[#out.rows + 1] = { name = have.label or group[2],
			text = have.count == 0 and L["None"] or have.name and L["%d, mostly %s"]:format(have.count, have.name) or tostring(have.count),
			tone = have.count == 0 and "warn" or nil }
	end
	-- What the class's abilities will use up, from the game's tables: items needed within
	-- the next levels, with what the bags hold. A row for something a vendor sells opens Find it.
	local level, shown = G.Level(), 0
	for _, use in ipairs(shippedUses(G.ClassFile())) do
		if use.level <= level + SOON and shown < MAX_USE_ROWS then
			shown = shown + 1
			local held = C.Plain(C.Call("C_Item.GetItemCount", use.item), nil)
			local made = use.item == "Soul Shard" or use.item:find(" Totem$") ~= nil
			out.rows[#out.rows + 1] = {
				name = use.level <= level and L["Uses up"] or L["Level %d"]:format(use.level),
				text = type(held) == "number" and L["%s for %s (you carry %d)"]:format(use.item, use.spell, held) or L["%s for %s"]:format(use.item, use.spell),
				tone = type(held) == "number" and held == 0 and use.level <= level and "warn" or nil,
				run = not made and findRun("vendor") or nil, tag = not made and L["Find"] or nil, tagRole = "accentText",
			}
		end
	end
	out.total = #out.rows
	if carried.food.count == 0 then
		out.attention = 1
		out.next = L["You carry no food or drink. Buy some before you leave town."]
		out.action = { label = L["Find a vendor"], run = function()
			T.Window:Open("find", "vendor")
		end }
	else
		local says = G.ItemUse(carried.food.item)
		out.next = L["You have food and drink with you. Look here again before you leave a town."]
			.. (says and carried.food.name and " " .. L["%s, in the game's words: %s"]:format(carried.food.name, says) or "")
	end
	return out
end

-- What the character can wear, what it wears and what condition that is in. The kinds of
-- armor come from the game's own skill list and item labels; nothing is ranked or advised
-- beyond repairing what is nearly broken (game check 7).
local REPAIR_BELOW = 0.25

local function gear()
	local out = { rows = {}, attention = 0 }
	out.what = L["Your class can wear only some kinds of armor, and the game lists them among your skills. Most pieces also have a durability that runs down, and a vendor who does repairs restores it for a fee."]
	local state = G.Gear()
	if not state.read then
		out.next = L["The game has not listed what you wear yet. Try again in a moment."]
		return out
	end
	if #state.can > 0 then
		out.rows[#out.rows + 1] = { name = L["You can wear"], text = table.concat(state.can, ", ") }
	elseif state.canFolded then
		out.rows[#out.rows + 1] = { name = L["You can wear"], text = L["Open Armor Proficiencies in the game's skills window to see"] }
	end
	if #state.worn > 0 then
		local parts = {}
		for _, kind in ipairs(state.worn) do
			parts[#parts + 1] = L["%d %s"]:format(kind.count, kind.label)
		end
		out.rows[#out.rows + 1] = { name = L["You wear"], text = table.concat(parts, ", ") }
	end
	local lowest = state.lowest
	local percent = lowest and math.floor(lowest.part * 100 + 0.5) or nil
	local piece = lowest and lowest.name or L["Your most worn piece"]
	local low = lowest and lowest.part < REPAIR_BELOW
	out.rows[#out.rows + 1] = { name = L["Condition"], tone = low and "warn" or nil,
		text = not lowest and L["Nothing you wear can break"] or lowest.part >= 1 and L["Everything is at full durability"]
			or L["Lowest: %s, at %d%%"]:format(piece, percent) }
	out.rows[#out.rows + 1] = { name = L["Empty slots"], text = #state.empty > 0 and table.concat(state.empty, ", ") or L["None"] }
	out.total = #out.rows

	local repair = { label = L["Find repair"], run = function()
		T.Window:Open("find", "repair")
	end }
	if not lowest then
		out.next = L["Nothing you wear has a durability yet, so there is nothing to repair."]
	elseif lowest.part <= 0 then
		out.attention = 1
		out.next = L["%s is broken. A vendor who does repairs can fix it."]:format(piece)
		out.action = repair
	elseif low then
		out.attention = 1
		out.next = L["%s is down to %d%% durability. Have it repaired before it breaks."]:format(piece, percent)
		out.action = repair
	elseif lowest.part < 1 then
		out.next = L["Nothing needs repair yet. %s is the most worn, at %d%% durability."]:format(piece, percent)
		out.action = repair
	else
		out.next = L["Everything you wear is at full durability. Nothing to repair."]
	end
	return out
end

-- Riding and the first mount. The game holds no list of where riding is taught or what it
-- costs, so the level and prices are the ones the guides give at launch (Data/Known.lua).
local function mount()
	local out = { rows = {}, attention = 0 }
	local facts = T.Known.riding
	out.what = L["From level %d you can learn to ride. Your own race's riding trainer teaches it for %s, with a mount vendor beside them, and a mount makes you %d%% faster. At level %d a second lesson for %s makes that %d%%. Prices are as reported at launch."]
		:format(facts.level, G.MoneyText(facts.cost), facts.speed, facts.fastLevel, G.MoneyText(facts.fastCost), facts.fastSpeed)
	local level, money, owned = G.Level(), G.Money(), G.MountsOwned()
	local classMount = facts.classMount[G.ClassFile() or ""] == true
	local trainer, vendor
	for _, place in ipairs(P.Known("riding")) do
		if place.race and place.race == G.RaceFile() then
			if place.vendor then
				vendor = vendor or place
			else
				trainer = trainer or place
			end
		end
	end
	out.rows[#out.rows + 1] = { name = L["You can ride"],
		text = level >= facts.level and L["Now"] or L["At level %d: %d levels to go"]:format(facts.level, facts.level - level) }
	if not classMount then
		out.rows[#out.rows + 1] = { name = L["Riding costs"], text = G.MoneyText(facts.cost) }
		if money then
			out.rows[#out.rows + 1] = { name = L["You have"], text = G.MoneyText(money), tone = level >= facts.level and money < facts.cost and "warn" or nil }
		end
	end
	if trainer then
		out.rows[#out.rows + 1] = { name = L["Your trainer"], text = L["%s, %s"]:format(trainer.n, trainer.z) }
	end
	if vendor then
		out.rows[#out.rows + 1] = { name = L["Mount vendor"], text = L["%s, %s"]:format(vendor.n, vendor.z) }
	end
	if owned then
		out.rows[#out.rows + 1] = { name = L["Your mounts"], text = owned > 0 and tostring(owned) or L["None yet"] }
	end
	out.total = #out.rows

	local find = { label = L["Find the riding trainer"], run = function()
		T.Window:Open("find", "riding")
	end }
	if classMount then
		out.next = level >= facts.level and L["Your class gets a mount of its own from level %d, through your class trainer or a class quest, without the riding fee. Ask your class trainer."]:format(facts.level)
			or L["Your class gets a mount of its own at level %d, through your class trainer or a class quest, so you need not save for riding."]:format(facts.level)
	elseif owned and owned > 0 then
		out.next = level >= facts.fastLevel and L["You have a mount. The faster lesson is open to you now, for %s."]:format(G.MoneyText(facts.fastCost))
			or L["You have a mount. The faster lesson comes at level %d, for %s."]:format(facts.fastLevel, G.MoneyText(facts.fastCost))
	elseif level >= facts.level then
		out.attention = 1
		out.next = (trainer and L["You can learn to ride now. Go to %s in %s."]:format(trainer.n, trainer.z) or L["You can learn to ride now. Go to your race's riding trainer."])
			.. (money and money < facts.cost and " " .. L["You are %s short of the fee."]:format(G.MoneyText(facts.cost - money)) or "")
		out.action = find
	elseif money and money >= facts.cost then
		out.next = L["You already have the %s for riding. Keep it aside until level %d."]:format(G.MoneyText(facts.cost), facts.level)
		out.action = trainer and find or nil
	else
		out.next = L["Riding is the big cost of levelling: %s at level %d."]:format(G.MoneyText(facts.cost), facts.level)
			.. (money and " " .. L["You have %s so far."]:format(G.MoneyText(money)) or "")
			.. " " .. L["Buy the abilities you use, sell what you do not need, and put the rest aside."]
		out.action = trainer and find or nil
	end
	return out
end

-- Dying and coming back, in the words of Blizzard's own starter guide and of the Spirit
-- Healer's question in the game. No figures: the guides do not agree on them.
local function dying()
	local out = { rows = {}, attention = 0 }
	out.what = L["When you die you can release your spirit to the nearest graveyard and run back to your body as a ghost: coming back to life there has no penalty. The Spirit Healer at the graveyard can bring you back on the spot instead, but that damages your gear and can leave you with Resurrection Sickness, which makes you much weaker for a while."]
	local dead, sick = G.Dead(), G.Sick()
	local lowest = G.LowestDurability()
	out.rows[#out.rows + 1] = { name = L["Right now"], tone = (dead or sick) and "warn" or nil,
		text = dead == "ghost" and L["You are a ghost"] or dead and L["You are dead"] or sick and L["Alive, with Resurrection Sickness"] or L["Alive"] }
	if lowest then
		out.rows[#out.rows + 1] = { name = L["Your gear"], tone = lowest < REPAIR_BELOW and "warn" or nil,
			text = lowest >= 1 and L["At full durability"] or L["Most worn piece at %d%%"]:format(math.floor(lowest * 100 + 0.5)) }
	end
	out.total = #out.rows
	local repair = { label = L["Find repair"], run = function()
		T.Window:Open("find", "repair")
	end }
	if dead == "ghost" then
		out.attention = 1
		out.next = L["Your body is marked on the minimap and on the map. Run to it, pick a safe spot nearby and choose Resurrect. If you cannot reach it, the Spirit Healer at the graveyard will bring you back, at a cost to your gear."]
	elseif dead then
		out.attention = 1
		out.next = L["Release your spirit to go to the nearest graveyard, then run back to your body. A healer in your group may be able to bring you back where you lie."]
	elseif sick then
		out.attention = 1
		out.next = L["You have Resurrection Sickness. Stay out of fights until it wears off, and have your gear repaired."]
		out.action = repair
	elseif lowest and lowest < REPAIR_BELOW then
		out.next = L["Your gear is worn. Repair it before your next fight: broken gear gives you nothing until it is repaired."]
		out.action = repair
	else
		out.next = L["If you die: release, run back to your body, and come back to life in a safe spot. Use the Spirit Healer only when you cannot reach your body."]
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Know-how topics: the words are shipped (Data/GuideTopics.lua); each reader adds what the
-- game says about this character.

Guide.pageOf = {}

local function stoneText(state)
	if not state.stone then
		return nil
	end
	local minutes = math.ceil(state.stone.left / 60)
	return not state.stone.carried and L["Not in your bags"]
		or minutes <= 0 and L["Ready"] or minutes == 1 and L["Ready in 1 minute"] or L["Ready in %d minutes"]:format(minutes)
end

-- The soonest item the class's abilities will use up, as one line.
local function soonRow(class, level)
	local list = shippedUses(class)
	local soon = {}
	for _, use in ipairs(list) do
		if use.level <= level + SOON then
			soon[#soon + 1] = use
		end
	end
	if #soon > 0 then
		local first = soon[1]
		local text = L["%s for %s, level %d"]:format(first.item, first.spell, first.level)
		if #soon > 1 then
			text = L["%s, and %d more"]:format(text, #soon - 1)
		end
		return { name = L["Soon"], text = text }
	end
	local later = list[1]
	if later then
		return { name = L["Later"], text = L["%s for %s, level %d"]:format(later.item, later.spell, later.level) }
	end
	return { name = L["Soon"], text = L["Nothing your abilities use up"] }
end

local function classNotes()
	local class = G.ClassFile()
	local def = D.classes and D.classes[class]
	local out = { rows = {}, attention = 0, heading = L["Your class"] }
	out.what = L["Your class has its own way to fight and some needs other classes do not have. This is the short version. Your trainer has the rest."]
	if not def then
		out.next = L["The game has not told Trailhead your class yet. Try again in a moment."]
		return out
	end
	local roles = {}
	for _, bit in ipairs({ 2, 4, 8 }) do
		if math.floor((T.ClassRoles and T.ClassRoles[class] or 0) / bit) % 2 == 1 then
			roles[#roles + 1] = D.roleNames[bit]
		end
	end
	out.rows = {
		{ name = L["Power"], text = def.resource },
		{ name = L["Good at"], text = def.good },
		{ name = L["Roles"], text = #roles > 0 and table.concat(roles, ", ") or L["Not listed"] },
		{ name = L["Needs"], text = def.needs },
		soonRow(class, G.Level()),
	}
	out.total = #out.rows
	out.next = L["The Supplies topic counts what your abilities use up. Coming up lists what each level brings, and the Builds page helps with talents."]
	out.action = { label = L["Find your trainer"], run = findRun("trainer") }
	return out
end

local function services()
	local def = D.services
	local out = { rows = plainRows(def.rows), attention = 0, what = def.what, heading = L["Places to know"] }
	out.total = #out.rows
	local home = G.Rest().home
	out.next = (home and L["Your home inn is %s."]:format(home) .. " " or "") .. def.next
	return out
end

local function grouping()
	local def = D.grouping
	local out = { rows = {}, attention = 0, what = def.what, heading = L["Jobs and finding a group"] }
	local members = C.Plain(C.Call("GetNumGroupMembers"), 0)
	members = type(members) == "number" and members or 0
	local inGroup = C.Plain(C.Call("IsInGroup"), false) == true and members > 0
	local raid = C.Plain(C.Call("IsInRaid"), false) == true
	out.rows[1] = { name = L["Your group"], text = not inGroup and L["You are not in a group"]
		or raid and L["In a raid of %d"]:format(members) or L["In a party of %d"]:format(members) }
	for _, row in ipairs(plainRows(def.rows)) do
		out.rows[#out.rows + 1] = row
	end
	out.total = #out.rows
	local roles = {}
	for _, bit in ipairs({ 2, 4, 8 }) do
		if math.floor((T.ClassRoles and T.ClassRoles[G.ClassFile()] or 0) / bit) % 2 == 1 then
			roles[#roles + 1] = D.roleNames[bit]:lower()
		end
	end
	out.next = (#roles > 0 and L["Your class can be: %s."]:format(table.concat(roles, ", ")) .. " " or "") .. def.manners
	return out
end

local function danger()
	local def = D.danger
	local level = G.Level()
	local out = { rows = plainRows(def.rows), attention = 0, what = def.what, heading = L["Reading enemy levels"] }
	-- The game's own colour rule: orange from 3 levels above you, red from 5.
	out.rows[3].text = L["Level %d or %d: 3 or 4 above you. Hard."]:format(level + 3, level + 4)
	out.rows[4].text = L["Level %d and up: 5 or more above. Very risky."]:format(level + 5)
	out.total = #out.rows
	out.next = def.pvp
	return out
end

local function money()
	local def = D.money
	local out = { rows = {}, attention = 0, what = def.what }
	local have, level, facts = G.Money(), G.Level(), T.Known.riding
	local classMount = facts.classMount[G.ClassFile() or ""] == true
	if have then
		out.rows[#out.rows + 1] = { name = L["You have"], text = G.MoneyText(have) }
	end
	out.rows[#out.rows + 1] = { name = L["Riding"], text = classMount and L["Your class gets its own mount. Ask your class trainer."]
		or L["%s at level %d, then %s at level %d (launch prices)"]:format(G.MoneyText(facts.cost), facts.level, G.MoneyText(facts.fastCost), facts.fastLevel) }
	for _, row in ipairs(plainRows(def.rows)) do
		out.rows[#out.rows + 1] = row
	end
	out.total = #out.rows
	if not classMount and have and level >= facts.level and have < facts.cost then
		out.next = L["Riding costs %s and you have %s. Sell what you do not need and put the rest aside."]:format(G.MoneyText(facts.cost), G.MoneyText(have))
	elseif not classMount and have and level >= facts.level then
		out.next = L["You can afford riding now. See the Mount topic."]
	else
		out.next = L["Early on, finish quests, sell grey items, and spend only on abilities and food. Put the rest aside for riding."]
	end
	return out
end

local function reputation()
	local def = D.reputation
	local out = { rows = {}, attention = 0, what = def.what, heading = L["The standings"] }
	local words = def.standings
	out.rows = {
		{ name = L["Where"], text = L["Character window, then the Reputation tab"] },
		{ name = L["Low"], text = table.concat(words, ", ", 1, 3) },
		{ name = L["Middle"], text = words[4] },
		{ name = L["High"], text = table.concat(words, ", ", 5, 8) },
	}
	out.total = #out.rows
	out.next = def.next
	return out
end

local function travel()
	local def = D.travel
	local out = { rows = {}, attention = 0, what = def.what, heading = L["Ways to travel"] }
	local state = G.Rest()
	local stone = stoneText(state)
	out.rows[1] = { name = L["Hearthstone"], text = state.home and (stone and L["Home: %s. %s"]:format(state.home, stone) or L["Home: %s"]:format(state.home))
		or L["No home yet. Ask an innkeeper to set one."], run = findRun("inn"), tag = L["Find"], tagRole = "accentText" }
	for _, row in ipairs(plainRows(def.rows)) do
		out.rows[#out.rows + 1] = row
	end
	if G.Faction() == 2 then
		out.rows[#out.rows + 1] = { name = L["Tram"], text = def.tram }
	end
	local facts = T.Known.riding
	out.rows[#out.rows + 1] = { name = L["Riding"], text = G.Level() >= facts.level and L["You can learn to ride now. See the Mount topic."]
		or L["From level %d. See the Mount topic."]:format(facts.level) }
	out.total = #out.rows
	out.next = L["Your hearthstone takes you home again and again, so set it at the inn nearest where you are working."]
	out.action = { label = L["Find a flight master"], run = findRun("flight") }
	return out
end

local function forever()
	local def = D.forever
	local out = { rows = plainRows(def.rows), attention = 0, what = def.what, heading = L["What is new"] }
	out.total = #out.rows
	local level = G.Level()
	out.next = level >= LEGACY_LEVEL and L["Legacy is open: use the Legacy button on the game's menu bar."]
		or L["Legacy opens once one of your characters reaches level %d. You are level %d."]:format(LEGACY_LEVEL, level)
	if T.modules.legacy then
		out.action = { label = L["Open the Legacy page"], run = function()
			T.Window:Open("legacy")
		end }
	end
	return out
end

local function words()
	local pages = D.words.pages
	local at = Guide.pageOf.words or 1
	if at > #pages then
		at = 1
	end
	local following = at % #pages + 1
	local out = { rows = plainRows(pages[at].rows), attention = 0, what = D.words.what, heading = L["Page %d of %d: %s"]:format(at, #pages, pages[at].title) }
	out.total = #out.rows
	out.next = L["Click a player's name in chat to whisper them. Shift-click an item to put it in a chat message."]
	out.pager = { label = L["Next: %s"]:format(pages[following].title), run = function()
		Guide.pageOf.words = following
		Guide:Refresh()
	end }
	return out
end

-- Screen setup: what the page offers, how many are set, and where the rest lives in the game.
local function screen()
	local I = T.Interface
	local set, total = I.Counts()
	local out = { rows = {}, attention = total - set > 0 and 1 or 0 }
	out.what = L["The game has options that make the first hours easier: picking up loot with one click, a health bar over enemies, a second row of spell buttons. Trailhead can switch a few of them on for you and put each one back."]
	out.rows[#out.rows + 1] = { name = L["Set so far"], text = total == 0 and L["Your game does not let Trailhead read them"]
		or L["%d of %d suggested settings"]:format(set, total), tone = total - set > 0 and "warn" or nil }
	out.rows[#out.rows + 1] = { name = L["Edit Mode"], text = L["Game Menu, Edit Mode: move the bars, the minimap and chat"] }
	out.rows[#out.rows + 1] = { name = L["Preset"], text = L["Options, System, Preset: Classic or Enhanced starting settings"] }
	out.rows[#out.rows + 1] = { name = L["Key Bindings"], text = L["Options, Key Bindings: choose which key does what"] }
	out.total = #out.rows
	out.next = L["Spells that are not on an action bar are listed on the Spells page. Trailhead never moves your spells."]
	out.action = { label = L["Open Screen setup"], run = function()
		T.Window:Select("setup")
	end }
	return out
end

local TOPICS = {
	{ id = "class", group = "you", icon = "sword", label = L["Your class"], read = classNotes },
	{ id = "talents", group = "you", icon = "spark", label = L["Talents"], read = talents },
	{ id = "levels", group = "you", icon = "burst", label = L["Coming up"], read = coming },
	{ id = "gear", group = "you", icon = "shield", label = L["Gear"], read = gear },
	{ id = "weapons", group = "you", icon = "hammer", label = L["Weapon skills"], read = weapons },
	{ id = "professions", group = "you", icon = "pick", label = L["Professions"], read = professions },
	{ id = "screen", group = "you", icon = "gear", label = L["Screen setup"], read = screen },

	{ id = "rest", group = "world", icon = "bed", label = L["Inns and rest"], read = rest },
	{ id = "services", group = "world", icon = "home", label = L["Towns and services"], read = services },
	{ id = "supplies", group = "world", icon = "bag", label = L["Supplies"], read = supplies },
	{ id = "travel", group = "world", icon = "wing", label = L["Travel"], read = travel },
	{ id = "mount", group = "world", icon = "shoe", label = L["Mount"], read = mount },
	{ id = "dying", group = "world", icon = "moon", label = L["Dying"], read = dying },

	{ id = "grouping", group = "others", icon = "plus", label = L["Grouping"], read = grouping },
	{ id = "danger", group = "others", icon = "tri", label = L["Danger and PvP"], read = danger },
	{ id = "words", group = "others", icon = "book", label = L["Words and chat"], read = words },

	{ id = "money", group = "gold", icon = "coin", label = L["Money"], read = money },
	{ id = "reputation", group = "gold", icon = "bars", label = L["Reputation"], read = reputation },
	{ id = "forever", group = "gold", icon = "mtn", label = L["Forever's systems"], read = forever },
}
Guide.Topics = TOPICS
Guide.group = "you"

-- What a topic says right now (also used by the tests).
function Guide.Read(id)
	for _, topic in ipairs(TOPICS) do
		if topic.id == id then
			return topic.read()
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- The page.

local CHIP_W, CHIP_H, CHIP_GAP = (LIST_W - 6) / 2, 28, 4
local LIST_TOP = TOP + 2 * (CHIP_H + CHIP_GAP) + 8

local function topicLook(button)
	local on = button.topic.id == Guide.topic
	button:SetStyle({ fill = on and "tile" or "card", line = on and "accent" or (button.hover and "accentText" or "cardLine") })
	button.label:SetRole(on and "ink" or "muted")
end

local function chipLook(chip)
	local on = chip.group.id == Guide.group
	chip:SetStyle({ fill = on and "tile" or "card", line = on and "accent" or (chip.hover and "accentText" or "cardLine") })
	chip.label:SetRole(on and "ink" or "muted")
end

-- Where a topic sits in its group's list.
local function slotOf(topic)
	local slot = 0
	for _, other in ipairs(TOPICS) do
		if other.group == topic.group then
			slot = slot + 1
		end
		if other == topic then
			return slot
		end
	end
	return slot
end

local function makeChip(page, group, index)
	local chip = W.Panel(page, { shape = "card", fill = "card", line = "cardLine" }, "Button")
	chip.group = group
	chip:SetSize(CHIP_W, CHIP_H)
	chip:SetPoint("TOPLEFT", page, "TOPLEFT", ((index - 1) % 2) * (CHIP_W + 6), -(TOP + math.floor((index - 1) / 2) * (CHIP_H + CHIP_GAP)))
	chip.label = W.Text(chip, "head", 10.5, "muted")
	chip.label:SetPoint("CENTER", chip, "CENTER", 0, 0)
	chip.label:SetLabel(group.label)
	-- Topics in the group that want attention: a number on a small warm disc.
	chip.badge = W.Tint(chip, "circle-fill", "warn")
	chip.badge:SetSize(14, 14)
	-- It sits on the corner, clear of the label whatever its length.
	chip.badge:SetPoint("TOPRIGHT", chip, "TOPRIGHT", 4, 4)
	chip.count = W.Text(chip, "body", 9, "accentInk")
	chip.count:SetPoint("CENTER", chip.badge, "CENTER", 0, 0)
	chip:SetScript("OnEnter", function(self)
		self.hover = true
		chipLook(self)
	end)
	chip:SetScript("OnLeave", function(self)
		self.hover = false
		chipLook(self)
	end)
	chip:SetScript("OnClick", function()
		C.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		-- The first topic of the group, unless the one open is already in it.
		for _, topic in ipairs(TOPICS) do
			if topic.group == group.id then
				T.Window:Select("guide", Guide.group == group.id and Guide.topic or topic.id)
				return
			end
		end
	end)
	return chip
end

local function makeTopic(page, topic)
	local button = W.Panel(page, { shape = "card", fill = "card", line = "cardLine" }, "Button")
	button.topic = topic
	button:SetSize(LIST_W, TOPIC_H)
	button:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(LIST_TOP + (slotOf(topic) - 1) * (TOPIC_H + TOPIC_GAP)))
	button.icon = W.Icon(button, topic.icon, 18, "accent")
	button.icon:SetPoint("LEFT", button, "LEFT", 14, 0)
	button.label = W.Text(button, "head", 12.5, "muted")
	button.label:SetPoint("LEFT", button, "LEFT", 44, 0)
	button.label:SetLabel(topic.label)
	-- How many things in the topic want attention: a number on a small warm disc.
	button.badge = W.Tint(button, "circle-fill", "warn")
	button.badge:SetSize(18, 18)
	button.badge:SetPoint("RIGHT", button, "RIGHT", -14, 0)
	button.count = W.Text(button, "body", 11, "accentInk")
	button.count:SetPoint("CENTER", button.badge, "CENTER", 0, 0)
	button:SetScript("OnEnter", function(self)
		self.hover = true
		topicLook(self)
	end)
	button:SetScript("OnLeave", function(self)
		self.hover = false
		topicLook(self)
	end)
	button:SetScript("OnClick", function()
		C.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		T.Window:Select("guide", topic.id)
	end)
	return button
end

local function makeRow(panel, index)
	-- A button, so a row that leads somewhere (a service, a vendor) can be clicked.
	local row = CreateFrame("Button", nil, panel)
	row:SetSize(PANEL_W - 40, ROW_H)
	row.name = W.Text(row, "body", 11.5, "ink")
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -ROW_PAD)
	row.name:SetWidth(100)
	row.bar = W.Bar(row, 150, 8, "accent", "accent")
	row.bar:SetPoint("LEFT", row, "LEFT", 128, 0)
	row.value = W.Text(row, "body", 11, "muted")
	row.value:SetPoint("LEFT", row.bar, "RIGHT", 12, 0)
	-- A row of plain words instead of a bar (the "Coming up" topic).
	-- It may run to a second line; the row grows with it (Guide:Refresh).
	row.note = W.Text(row, "body", 11, "muted", { width = NOTE_W })
	row.note:SetPoint("TOPLEFT", row, "TOPLEFT", 104, -ROW_PAD)
	row.note:SetSpacing(2)
	if row.note.SetMaxLines then
		row.note:SetMaxLines(2)
	end
	row.tag = W.Text(row, "label", 8.5, "go")
	row.tag:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.tag:SetJustifyH("RIGHT")
	row:SetScript("OnClick", function(self)
		if self.run then
			C.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
			self.run()
		end
	end)
	row:SetScript("OnEnter", function(self)
		if self.run then
			self.name:SetRole("accentText")
		end
	end)
	row:SetScript("OnLeave", function(self)
		self.name:SetRole("ink")
	end)
	return row
end

function Guide:Build(page)
	local heading = W.Text(page, "head", 18, "ink")
	heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	heading:SetLabel(L["Guide"])
	local sub = W.Text(page, "body", 11, "muted")
	sub:SetPoint("BOTTOMLEFT", heading, "BOTTOMRIGHT", 10, 2)
	sub:SetLabel(L["The things nobody tells you, checked against your own character."])

	ui.chips = {}
	for index, group in ipairs(T.GuideGroups) do
		ui.chips[index] = makeChip(page, group, index)
	end
	for index, topic in ipairs(TOPICS) do
		ui.topics[index] = makeTopic(page, topic)
	end

	local panel = W.Panel(page, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	panel:SetSize(PANEL_W, PANEL_H)
	panel:SetPoint("TOPLEFT", page, "TOPLEFT", PANEL_X, -TOP)
	ui.panel = panel
	ui.tile = W.IconTile(panel, "scroll", 38, "accent")
	ui.tile:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -18)
	ui.title = W.Text(panel, "head", 17, "ink")
	ui.title:SetPoint("LEFT", ui.tile, "RIGHT", 14, 0)

	ui.whatLabel = W.Text(panel, "label", 9, "accentText")
	ui.whatLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -72)
	ui.whatLabel:SetLabel(L["What it is"])
	ui.what = W.Text(panel, "body", 11.5, "muted", { width = PANEL_W - 40 })
	ui.what:SetPoint("TOPLEFT", ui.whatLabel, "BOTTOMLEFT", 0, -6)
	ui.what:SetSpacing(4)

	ui.standLabel = W.Text(panel, "label", 9, "accentText")
	-- Each section sits under the one before it, however many lines that one took.
	ui.standLabel:SetPoint("TOPLEFT", ui.what, "BOTTOMLEFT", 0, -GAP)
	ui.standLabel:SetLabel(L["Where you stand"])
	ui.showing = W.Text(panel, "body", 10, "faint")
	ui.showing:SetPoint("LEFT", ui.standLabel, "RIGHT", 10, 0)
	for index = 1, MAX_ROWS do
		local row = makeRow(panel, index)
		if index == 1 then
			row:SetPoint("TOPLEFT", ui.standLabel, "BOTTOMLEFT", 0, -6)
		else
			row:SetPoint("TOPLEFT", ui.rows[index - 1], "BOTTOMLEFT", 0, 0)
		end
		ui.rows[index] = row
	end

	ui.nextLabel = W.Text(panel, "label", 9, "accentText")
	ui.nextLabel:SetLabel(L["What to do next"])
	ui.next = W.Text(panel, "body", 11.5, "ink", { width = PANEL_W - 40 })
	ui.next:SetPoint("TOPLEFT", ui.nextLabel, "BOTTOMLEFT", 0, -6)
	ui.next:SetSpacing(4)
	ui.action = W.Button(panel, "", "ghost", {
		role = "accentText", height = 28, size = 11,
		onClick = function()
			if ui.action.run then
				ui.action.run()
			end
		end,
	})
	ui.action:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 20, FOOT)
	-- The next page of a topic that has several (Words and chat).
	ui.pager = W.Button(panel, "", "ghost", {
		role = "accentText", height = 28, size = 11,
		onClick = function()
			if ui.pager.run then
				ui.pager.run()
			end
		end,
	})
	ui.pager:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -20, FOOT)
	self.built = true
end

-- Chooses a topic (from a topic button or an advice card); its group opens with it.
function Guide:Goto(id)
	for _, topic in ipairs(TOPICS) do
		if topic.id == id then
			self.topic = id
			self.group = topic.group
		end
	end
end

-- Puts one line of a topic into a row and gives the height the row then needs.
local function fillRow(row, item)
	row.run = item.run
	row.name:SetLabel(item.name)
	row.name:SetRole("ink")
	row.bar:SetShown(item.text == nil)
	row.note:SetWidth(item.tag and NOTE_W - TAG_W or NOTE_W)
	row.note:SetLabel(item.text or "")
	row.note:SetRole(item.text and item.tone or "muted")
	if item.text then
		row.value:SetLabel("")
	else
		row.bar:Set(item.frac or (item.max > 0 and item.rank / item.max or 0))
		row.value:SetLabel(item.value or L["%d of %d"]:format(item.rank, item.max))
	end
	row.tag:SetLabel(item.tag or "")
	row.tag:SetRole(item.tagRole or item.tone or "go")
	local height = ROW_H
	if item.text then
		height = math.max(ROW_H, math.ceil(W.TextHeight(row.note)) + ROW_PAD * 2)
	end
	row:SetHeight(height)
	return height
end

function Guide:Refresh()
	if not self.built then
		return
	end
	local current = TOPICS[1]
	local waiting = {}
	for index, topic in ipairs(TOPICS) do
		local button = ui.topics[index]
		local info = topic.read()
		button.info = info
		button.count:SetLabel(info.attention > 0 and tostring(info.attention) or "")
		button.badge:SetShown(info.attention > 0)
		button:SetShown(topic.group == self.group)
		waiting[topic.group] = (waiting[topic.group] or 0) + info.attention
		if topic.id == self.topic then
			current = topic
		end
		topicLook(button)
	end
	for _, chip in ipairs(ui.chips) do
		local count = waiting[chip.group.id] or 0
		chip.count:SetLabel(count > 0 and tostring(count) or "")
		chip.badge:SetShown(count > 0)
		chipLook(chip)
	end
	local info
	for index, topic in ipairs(TOPICS) do
		if topic == current then
			info = ui.topics[index].info
		end
	end
	ui.tile.icon:SetTexture(Theme.MEDIA .. "icon-" .. current.icon)
	ui.title:SetLabel(current.label)
	ui.what:SetLabel(info.what)
	ui.next:SetLabel(info.next or "")
	local hasNext = (info.next or "") ~= ""
	-- The room left for rows: the panel, less the heading, the two blocks of words and the
	-- button under them. Rows that do not fit are left out and counted in "showing".
	local room = PANEL_H - 72 - (LABEL_H + 6 + W.TextHeight(ui.what)) - FOOT
	if info.action or info.pager then
		room = room - 28 - GAP
	end
	if hasNext then
		room = room - (GAP + LABEL_H + 6 + W.TextHeight(ui.next))
	end
	room = room - (GAP + LABEL_H + 6)
	-- A topic may pin its last row (Defense, under the weapon skills): it keeps its place
	-- when the rows above it are cut short.
	local items = info.rows
	local pinned = info.pinLast and #items > 1 and items[#items] or nil
	local count = pinned and #items - 1 or #items
	if pinned then
		room = room - ROW_H
	end
	local shown, full = 0, false
	for index = 1, count do
		local row = ui.rows[index]
		local height = row and not full and fillRow(row, items[index])
		if not height or height > room then
			full = true
		else
			room = room - height
			shown = index
		end
	end
	if pinned and ui.rows[shown + 1] then
		shown = shown + 1
		fillRow(ui.rows[shown], pinned)
	end
	for index, row in ipairs(ui.rows) do
		row:SetShown(index <= shown)
	end
	ui.standLabel:SetShown(shown > 0)
	ui.standLabel:SetLabel(info.heading or L["Where you stand"])
	local total = math.max(info.total or 0, #info.rows)
	ui.showing:SetLabel(shown > 0 and total > shown and L["showing %d of %d"]:format(shown, total) or "")
	ui.nextLabel:SetShown(hasNext)
	ui.nextLabel:ClearAllPoints()
	if shown > 0 then
		ui.nextLabel:SetPoint("TOPLEFT", ui.rows[shown], "BOTTOMLEFT", 0, -(GAP - ROW_PAD))
	else
		ui.nextLabel:SetPoint("TOPLEFT", ui.what, "BOTTOMLEFT", 0, -GAP)
	end
	ui.action:SetShown(info.action ~= nil)
	if info.action then
		ui.action:SetLabel(info.action.label)
		ui.action.run = info.action.run
	end
	ui.pager:SetShown(info.pager ~= nil)
	if info.pager then
		ui.pager:SetLabel(info.pager.label)
		ui.pager.run = info.pager.run
	end
end

local queued = false
local function queue()
	if queued or not Guide.built or not Guide.page:IsVisible() then
		return
	end
	queued = true
	C_Timer.After(0.3, function()
		queued = false
		if Guide.page:IsVisible() and not C.InCombat() then
			Guide:Refresh()
		end
	end)
end

function Guide:OnInit()
	T:On("TH_SKILLS_CHANGED", queue)
	T:On("PLAYER_LEVEL_UP", queue)
	for _, event in ipairs({ "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_MONEY", "TH_PLACES_CHANGED", "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING", "HEARTHSTONE_BOUND", "PLAYER_XP_UPDATE" }) do
		T:On(event, queue)
	end
end
