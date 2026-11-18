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
local MAX_PAGE_ROWS = 6 -- rows a paged topic shows at once, leaving room for its words
local ROW_PAD = 6 -- above and below the words in a row
local NOTE_W, TAG_W = PANEL_W - 40 - 104, 62 -- a row of words, and the room a tag and arrow take from it
local ROW_INSET, ARROW = 8, 10 -- a row's hover fill reaches this far past its words; the arrow's size
local LABEL_H, GAP = 10, 14 -- a small section label, and the space above one
local FOOT = 18 -- under the last line or button
local MAX_USE_ROWS = 3
local MAX_QUEST_ROWS = 2 -- class quests shown in the Your class topic, the next ones first
local LEGACY_LEVEL = 25 -- the game: Legacy opens when a first character reaches it
local DUAL_SPEC_LEVEL = 40 -- the guides: the class trainer offers dual spec from this level

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

-- The game's own name for a spell or an item, in the player's language; the English name
-- from the shipped tables when the game gives none.
local function spellName(id, fallback)
	local name = id and C.Plain(C.Call("C_Spell.GetSpellName", id), nil)
	return type(name) == "string" and name ~= "" and name or fallback
end

local function itemName(id, fallback)
	local name = id and C.Plain(C.Call("C_Item.GetItemNameByID", id), nil)
	return type(name) == "string" and name ~= "" and name or fallback
end

-- Whether the character knows a spell: true, false, or nil when the game will not say.
local function knows(id)
	for _, path in ipairs({ "C_SpellBook.IsSpellKnown", "IsSpellKnown", "IsPlayerSpell" }) do
		if C.Has(path) then
			local known = C.Plain(C.Call(path, id), nil)
			if known ~= nil then
				return known == true
			end
		end
	end
	return nil
end

-- The class quests (Data/ClassQuests.lua) by the spells they teach.
local function questSpells(class)
	local by = {}
	for _, quest in ipairs((T.ClassQuests and T.ClassQuests[class]) or {}) do
		for _, id in ipairs(quest.spells or {}) do
			by[id] = quest
		end
	end
	return by
end

local function shippedSpells(class)
	local key = (class or "") .. (mySide() or "")
	if not parsed.spells[key] then
		local list, side, quests = {}, mySide(), questSpells(class)
		for line in ((T.ClassSpells and T.ClassSpells[class]) or ""):gmatch("[^;]+") do
			local level, name, rank, only, id = line:match("^(%d+)|([^|]*)|(%d+)|([AH]?)|?(%d*)$")
			if level and (only == "" or only == side) then
				rank, id = tonumber(rank), tonumber(id)
				name = spellName(id, name)
				-- A spell a class quest teaches is marked, so it is not promised at the trainer.
				list[#list + 1] = { name = rank > 1 and L["%s (Rank %d)"]:format(name, rank) or name, level = tonumber(level), cost = 0,
					shipped = true, id = id, quest = id and quests[id] ~= nil or nil }
			end
		end
		parsed.spells[key] = list
	end
	return parsed.spells[key]
end

-- What the class's abilities use up: { item, itemID, spell, spellID, level, count }, one per
-- item, by level. Names are the game's own when it gives them.
local function shippedUses(class)
	local key = (class or "") .. (mySide() or "")
	if not parsed.uses[key] then
		local list, side, seen = {}, mySide(), {}
		for line in ((T.ClassUses and T.ClassUses[class]) or ""):gmatch("[^;]+") do
			local level, spell, item, count, only, spellID, itemID = line:match("^(%d+)|([^|]*)|([^|]*)|(%d+)|([AH]?)|?(%d*)|?(%d*)$")
			if level and (only == "" or only == side) and not seen[item] then
				seen[item] = true
				spellID, itemID = tonumber(spellID), tonumber(itemID)
				list[#list + 1] = { item = itemName(itemID, item), itemID = itemID, english = item, spell = spellName(spellID, spell),
					spellID = spellID, level = tonumber(level), count = tonumber(count) }
			end
		end
		table.sort(list, function(a, b)
			if a.level ~= b.level then
				return a.level < b.level
			end
			return a.english < b.english
		end)
		parsed.uses[key] = list
	end
	return parsed.uses[key]
end
Guide.ShippedSpells, Guide.ShippedUses = shippedSpells, shippedUses

-- Items the class makes or earns itself rather than buys: Soul Shards and the four totems.
local MADE = { [6265] = true, [5175] = true, [5176] = true, [5177] = true, [5178] = true }

-- The class quests for this character: { level, name, done, from, quest = true }, by level.
-- done is true, false, or nil when the game cannot tell; from says who starts it.
local function classQuests(class)
	local list, race, side = {}, G.RaceFile(), mySide()
	for _, quest in ipairs((T.ClassQuests and T.ClassQuests[class]) or {}) do
		local entry = { level = quest.level, quest = true, cost = 0 }
		if quest.racial then
			entry.name = L["a spell of your race's own"]
		elseif quest.item then
			entry.name = itemName(quest.item, quest.name)
			local held = C.Plain(C.Call("C_Item.GetItemCount", quest.item, true), nil)
			entry.done = type(held) == "number" and held > 0 or nil
			entry.item = true
		else
			entry.name = spellName(quest.spells[1], quest.name)
			for _, id in ipairs(quest.spells) do
				local known = knows(id)
				if known then
					entry.done = true
					break
				elseif known == false then
					entry.done = false
				end
			end
		end
		local place = quest.where and (race and quest.where[race] or side and quest.where[side])
		local trainer = quest.trainer == true or type(quest.trainer) == "table" and race and quest.trainer[race]
		if place then
			entry.from = L["%s: in %s"]:format(entry.name, G.MapName(place) or (T.ClassQuestPlaces or {})[place] or "?")
		elseif trainer then
			entry.from = L["%s: from your class trainer"]:format(entry.name)
		else
			entry.from = L["%s: ask your class trainer"]:format(entry.name)
		end
		list[#list + 1] = entry
	end
	table.sort(list, function(a, b)
		return a.level < b.level
	end)
	return list
end
Guide.ClassQuests = classQuests

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

-- The main professions by the game's skill line IDs, with what each makes or gathers and the
-- one it pairs with. A main profession the character has is not suggested again.
local MAIN_PROFESSIONS = {
	{ 171, L["Alchemy"], L["Potions and elixirs. Pairs with Herbalism."] },
	{ 164, L["Blacksmithing"], L["Weapons and mail armor. Pairs with Mining."] },
	{ 333, L["Enchanting"], L["Enchants gear with what you break down. Needs no gatherer."] },
	{ 202, L["Engineering"], L["Gadgets, guns and bombs. Pairs with Mining."] },
	{ 182, L["Herbalism"], L["Gathers herbs. Pairs with Alchemy, or sell what you pick."] },
	{ 165, L["Leatherworking"], L["Leather and mail armor. Pairs with Skinning."] },
	{ 186, L["Mining"], L["Gathers ore and stone. Pairs with Blacksmithing or Engineering."] },
	{ 393, L["Skinning"], L["Skins the beasts you kill. Pairs with Leatherworking."] },
	{ 197, L["Tailoring"], L["Cloth armor and bags, from cloth enemies drop. Needs no gatherer."] },
}
local MAIN_SLOTS = 2 -- a character can learn two main professions
local GATHERING = { [182] = true, [186] = true, [393] = true, [129] = true, [356] = true, [185] = true } -- and the everyday ones

-- A topic whose rows come in pages ({ title, rows }), empty pages left out: the page shown,
-- its title in the heading and a button to the next. One page shows plainly under its heading.
local function paged(id, out, pages)
	local kept = {}
	for _, page in ipairs(pages) do
		if #page.rows > 0 then
			kept[#kept + 1] = page
		end
	end
	if #kept == 0 then
		return out
	end
	local at = Guide.pageOf[id] or 1
	if at > #kept then
		at = 1
	end
	out.rows = kept[at].rows
	if #kept > 1 then
		local following = at % #kept + 1
		out.heading = L["Page %d of %d: %s"]:format(at, #kept, kept[at].title)
		out.pager = { label = L["Next: %s"]:format(kept[following].title), run = function()
			Guide.pageOf[id] = following
			Guide:Refresh()
		end }
	end
	return out
end

local function mainCount(skills)
	local mains = 0
	for _, profession in ipairs(MAIN_PROFESSIONS) do
		if skills.byId[profession[1]] then
			mains = mains + 1
		end
	end
	return mains
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
	elseif skills.complete and mainCount(skills) < MAIN_SLOTS then
		out.next = L["You have room for another main profession. Pick professions, under Gold and more, says what each one does and which pairs well."]
		out.action = find
	else
		out.next = L["Nothing needs doing. Your skills rise as you gather and make things."]
	end
	return out
end

-- Choosing professions: each main one the character could still learn, what it makes or
-- gathers and its partner. Hidden once both main professions are chosen.
local function choosing()
	local skills = G.Skills()
	local mains = mainCount(skills)
	local out = { rows = {}, attention = 0, hidden = skills.complete and mains >= MAIN_SLOTS, heading = L["The main professions"] }
	out.what = L["You can learn two main professions, and Cooking, First Aid and Fishing on top of them for free. A gatherer brings in materials; a crafter turns them into gear, potions and more."]
	local gather, craft = {}, {}
	for _, profession in ipairs(MAIN_PROFESSIONS) do
		if not skills.byId[profession[1]] then
			local list = GATHERING[profession[1]] and gather or craft
			list[#list + 1] = { name = profession[2], text = profession[3], run = findRun("professions"),
				tag = L["Find"], tagRole = "accentText" }
		end
	end
	out.total = #gather + #craft
	if out.total <= MAX_PAGE_ROWS then
		for _, row in ipairs(gather) do
			craft[#craft + 1] = row
		end
		out.rows = craft
	else
		paged("choosing", out, { { title = L["Gathering"], rows = gather }, { title = L["Crafting"], rows = craft } })
	end
	out.next = L["Two gathering professions, such as Herbalism and Mining, earn the most gold early. Every profession also makes a camp item: see Camping."]
	out.action = { label = L["Find a profession trainer"], run = findRun("professions") }
	return out
end

local function talents()
	local out = { rows = {}, attention = 0 }
	out.what = L["Talent points make your abilities stronger. Your class has three trees to put them in, and the deeper rows of a tree open as you put more points into it."]
		-- A wrong point can be undone, as the guides agree (no price for dual spec: they do not).
		.. " " .. L["A wrong point is not forever: your class trainer can reset your talents for a fee that starts at 1 gold and grows each time."]
		.. (G.Level() >= DUAL_SPEC_LEVEL and " " .. L["From level 40 the trainer also offers a second set of talents to switch between."] or "")
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
	local open = { label = L["Open talents"], secure = "talents", after = T.BuildGuide.AfterOpen, run = function()
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
-- full list (saved at the last visit), the class quests (Data/ClassQuests.lua), and the
-- levels the group finder gives for dungeons and zones. Levels with nothing new are left out.
local function coming()
	local out = { rows = {}, attention = 0 }
	out.what = L["What your next levels bring: new abilities from your class trainer and your class quests, and the dungeons and zones that open up. Levels with nothing new are left out."]
	local level, top = G.Level(), G.MaxLevel()
	if level >= top then
		out.next = L["You are at the top level. Nothing more unlocks by levelling."]
		return out
	end
	local training, world = G.Training(), G.World()
	local byLevel, levels = {}, {}
	local function at(need)
		if not byLevel[need] then
			byLevel[need] = { level = need, spells = {}, quests = {}, dungeons = {}, zones = {}, cost = 0 }
			levels[#levels + 1] = byLevel[need]
		end
		return byLevel[need]
	end
	-- Before a trainer visit the shipped list stands in; the trainer's own list wins after.
	local upcoming = training.later
	if not training.source then
		upcoming = {}
		for _, item in ipairs(shippedSpells(G.ClassFile())) do
			if item.level > level and not item.quest then
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
	-- Abilities a class quest teaches come from the quest, not from the trainer.
	for _, quest in ipairs(classQuests(G.ClassFile())) do
		if quest.level > level and quest.level <= top then
			local entry = at(quest.level)
			entry.quests[#entry.quests + 1] = quest
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
		if #entry.quests > 0 then
			parts[#parts + 1] = L["Class quest: %s"]:format(G.NameList(entry.quests, 2))
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
	for _, entry in ipairs(levels) do
		if #entry.quests > 0 then
			lines[#lines + 1] = L["At level %d a class quest teaches %s, not the trainer."]:format(entry.level, G.NameList(entry.quests, 2))
			break
		end
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
			-- Counted by the item's ID, so it works in every language.
			local held = use.itemID and C.Plain(C.Call("C_Item.GetItemCount", use.itemID), nil) or nil
			local made = MADE[use.itemID] or false
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
		out.rows[#out.rows + 1] = { name = L["You can wear"], text = L["Your character window's skills list shows it under Armor Proficiencies."] }
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
	local level = G.Level()
	out.rows = {
		{ name = L["Power"], text = def.resource },
		{ name = L["Good at"], text = def.good },
		{ name = L["Roles"], text = #roles > 0 and table.concat(roles, ", ") or L["Not listed"] },
		{ name = L["Needs"], text = def.needs },
	}
	-- Class quests (Data/ClassQuests.lua): the ones still to do first, then the ones done.
	-- A quest the character can do now whose reward the game says it lacks wants attention.
	local quests, open = classQuests(class), nil
	local shownQuests, done = 0, 0
	for _, wanted in ipairs({ false, true }) do
		for _, quest in ipairs(quests) do
			if (quest.done == true) == wanted then
				done = done + (quest.done and 1 or 0)
				if quest.done == false and quest.level <= level then
					open = open or quest
				end
				if shownQuests < MAX_QUEST_ROWS then
					shownQuests = shownQuests + 1
					local row = { name = L["Level %d"]:format(quest.level), text = quest.from }
					if quest.done then
						row.tag, row.tagRole, row.tone = L["Done"], "go", "faint"
					else
						row.run, row.tag, row.tagRole = findRun("trainer"), L["Find"], "accentText"
						row.tone = quest.level > level and "faint" or nil
					end
					out.rows[#out.rows + 1] = row
				end
			end
		end
	end
	out.rows[#out.rows + 1] = soonRow(class, level)
	out.total = #out.rows
	-- Only quests whose reward the game can confirm are counted.
	local checked = 0
	for _, quest in ipairs(quests) do
		checked = checked + (quest.done ~= nil and 1 or 0)
	end
	if checked > 0 then
		out.heading = L["Your class: %d of %d class quests done"]:format(done, checked)
	end
	if open then
		out.attention = 1
		out.next = L["Your class quest for %s is open now. It teaches what no trainer sells; your class trainer can tell you where it starts."]:format(open.name)
	elseif #quests > 0 then
		out.next = L["Some of your abilities come from class quests, listed here by level. Coming up shows what each level brings."]
	else
		out.next = L["The Supplies topic counts what your abilities use up. Coming up lists what each level brings, and the Builds page helps with talents."]
	end
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
	-- The dungeon that suits you now (Services/Readiness.lua), with its route.
	local R = T.Readiness
	local best = R and R.Best()
	if best then
		local label, run = R.Opener(best)
		out.rows[#out.rows + 1] = { name = L["Ready for"], text = L["%s, levels %d to %d"]:format(best.name, best.lo, best.hi),
			run = run, tag = best.id and L["Route"] or L["Find"], tagRole = "accentText" }
		out.action = { label = label, run = run }
	elseif R and R.FirstLevel() and G.Level() < R.FirstLevel() then
		out.rows[#out.rows + 1] = { name = L["Ready for"], text = L["No dungeon yet: the first opens at level %d"]:format(R.FirstLevel()) }
	end
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

-- The kinds of place the game's zone PvP info names.
local ZONE_KINDS = {
	sanctuary = L["A sanctuary: nobody can fight here"],
	friendly = L["Your side's land: its guards help you"],
	hostile = L["The other side's land: their guards attack you"],
	contested = L["Contested: both sides meet here"],
	combat = L["A battle zone: anyone can attack you"],
	arena = L["An arena: everyone fights"],
}

local function danger()
	local def = D.danger
	local level = G.Level()
	local out = { rows = plainRows(def.rows), attention = 0, what = def.what, heading = L["Reading enemy levels"] }
	-- The game's own colour rule: orange from 3 levels above you, red from 5.
	out.rows[3].text = L["Level %d or %d: 3 or 4 above you. Hard."]:format(level + 3, level + 4)
	out.rows[4].text = L["Level %d and up: 5 or more above. Very risky."]:format(level + 5)
	-- What kind of place the character is in, as the game reports it.
	local kind = C.Plain(C.Call("C_PvP.GetZonePVPInfo"), nil)
	if kind == nil and not C.Has("C_PvP.GetZonePVPInfo") then
		kind = C.Plain(C.Call("GetZonePVPInfo"), nil)
	end
	local here = type(kind) == "string" and ZONE_KINDS[kind]
	if here then
		out.rows[#out.rows + 1] = { name = L["Here"], text = here, tone = (kind == "hostile" or kind == "combat") and "warn" or nil }
	end
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

-- First steps: early milestones read from the game (Services/FirstSteps.lua), the ones still
-- to do first. The topic is hidden once every one is done.
local function firstSteps()
	local F = T.FirstSteps
	local list = F and F.List() or {}
	local done = F and F.Counts(list) or 0
	local total = #list
	local out = { rows = {}, attention = 0, hidden = total == 0 or done == total }
	out.what = L["A short list of things that make the first days easier. Trailhead ticks each one off when it sees you do it, and the list goes away once all are done."]
	out.heading = L["%d of %d done"]:format(done, total)
	local nextStep
	for _, wanted in ipairs({ false, true }) do
		for _, step in ipairs(list) do
			if (step.done == true) == wanted then
				local row = { name = step.name, text = step.text }
				if step.done then
					row.tag, row.tagRole, row.tone = L["Done"], "go", "faint"
				else
					nextStep = nextStep or step
					row.run = step.link.run
					row.tag = step.link.kind == "find" and L["Find"] or step.link.kind == "guide" and L["Read"] or L["Open"]
					row.tagRole = "accentText"
				end
				out.rows[#out.rows + 1] = row
			end
		end
	end
	out.total = #out.rows
	if nextStep then
		out.next = L["Next: %s."]:format(nextStep.text) .. " " .. nextStep.advice
		out.action = { label = nextStep.link.label, run = nextStep.link.run }
	else
		out.next = L["You have done every first step. Well done."]
	end
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

-- Each week: what resets, in short, with the way into the This week page (Modules/Weekly.lua).
local function week()
	local Wk = T.Weekly
	local out = { rows = {}, attention = 0 }
	out.what = L["A few things in Forever start over once a week: raid lockouts, and the cap on PvP Rank Points goes up. Legacy challenges never reset."]
	if not Wk then
		out.total = 0
		return out
	end
	out.rows[#out.rows + 1] = { name = L["Next reset"], text = Wk.ResetText() or L["Your game does not say"] }
	local state, days = Wk.RaidState()
	out.rows[#out.rows + 1] = { name = L["Raids"], text = state == "before" and L["Open on 9 December, in %d days"]:format(days)
		or state == "today" and L["Open today"] or L["Each raid resets once a week"] }
	out.rows[#out.rows + 1] = { name = L["PvP rank"], text = L["Rank Points have a weekly cap that goes up each reset"] }
	out.rows[#out.rows + 1] = { name = L["PvP journey"], text = L["Weekly tasks that give Honor and Rank Points"] }
	out.total = #out.rows
	out.next = L["Raids are for level 60 characters: Barrow Deeps for 10 players, Hyjal Summit for 20 and Onyxia's Lair for 40."]
	out.action = { label = L["Open This week"], run = function()
		T.Window:Select("weekly")
	end }
	return out
end

-- Camping, Forever's own: a cook's campfire and one camp item from each profession. Facts from
-- Blizzard's "Gather Around the Campfire" article, with the Mining item from Warcraft Tavern's
-- and RankedBoost's lists (Blizzard's table leaves Mining out). No durations: sources differ.
local CAMPFIRE_SPELL = 818 -- Basic Campfire
local CAMP_ITEMS = {
	{ 129, L["First Aid"], 279968, L["First Aid Kit"], L["%s: more Stamina"] },
	{ 356, L["Fishing"], 279967, L["Fish Bowl"], L["%s: more of all your stats"] },
	{ 171, L["Alchemy"], 279956, L["Mana Well"], L["%s: your mana comes back faster"] },
	{ 164, L["Blacksmithing"], 279944, L["Sharpening Wheel"], L["%s: more Strength"] },
	{ 333, L["Enchanting"], 279976, L["Enchanted Lute"], L["%s: more armor, stats and resistances"] },
	{ 202, L["Engineering"], 279950, L["Reagent Bot"], L["%s: sells reagents at the camp, no buff"] },
	{ 182, L["Herbalism"], 279962, L["Incense Candle"], L["%s: more Intellect"] },
	{ 165, L["Leatherworking"], 279978, L["Camp Tent"], L["%s: rested experience, if you have little"] },
	{ 186, L["Mining"], 279960, L["Lodestone"], L["%s: more attack power"] },
	{ 393, L["Skinning"], 279979, L["Camp Chair"], L["%s: 2%% more critical strike chance"] },
	{ 197, L["Tailoring"], 279972, L["Faction Banner"], L["%s: more Spirit, for your own side only"] },
}
local COOKING = 185

local function camping()
	local out = { rows = {}, attention = 0, heading = L["Camp items"] }
	out.what = L["Camping is Forever's own system. A cook lights a campfire with Flint and Tinder and Simple Wood, and anyone who sits or crafts beside it for a minute gets the buffs of the camp items set up around it."]
	local skills = G.Skills()
	local pages = { { title = L["The fire and gathering"], mine = {}, others = {} }, { title = L["Crafting"], mine = {}, others = {} } }
	local fire = spellName(CAMPFIRE_SPELL, L["Basic Campfire"])
	local cook = skills.byId[COOKING]
	local rows = { { COOKING, cook and cook.name or L["Cooking"], L["%s: the fire every camp needs"]:format(fire) } }
	for _, item in ipairs(CAMP_ITEMS) do
		local skill = skills.byId[item[1]]
		rows[#rows + 1] = { item[1], skill and skill.name or item[2], item[5]:format(itemName(item[3], item[4])) }
	end
	-- Your own professions first on each page.
	for _, row in ipairs(rows) do
		local page = pages[GATHERING[row[1]] and 1 or 2]
		local entry = { name = row[2], text = row[3] }
		if skills.byId[row[1]] then
			entry.tag, entry.tagRole = L["Yours"], "go"
			page.mine[#page.mine + 1] = entry
		else
			page.others[#page.others + 1] = entry
		end
	end
	for _, page in ipairs(pages) do
		page.rows = page.mine
		for _, entry in ipairs(page.others) do
			page.rows[#page.rows + 1] = entry
		end
	end
	out.total = #rows
	paged("camping", out, pages)
	out.next = L["A campfire holds three camp items, one per player, and each has an hour's cooldown. Trainers teach the first ones at skill 20. On a PvP ruleset, enemies can find your camp."]
	if cook then
		out.action = { label = L["Find a vendor"], run = findRun("vendor") }
	else
		out.next = out.next .. " " .. L["Any cooking trainer teaches the campfire."]
		out.action = { label = L["Find a profession trainer"], run = findRun("professions") }
	end
	return out
end

-- Fighting safely: the habits that keep a new character alive, with health, mana and food
-- read from the game.
local LOW_HEALTH = 50

local function percentOf(value, most)
	value, most = C.Plain(value, nil), C.Plain(most, nil)
	if type(value) == "number" and type(most) == "number" and most > 0 then
		return math.floor(value / most * 100 + 0.5)
	end
	return nil
end

local function fighting()
	local out = { rows = {}, attention = 0, heading = L["Before the next fight"] }
	out.what = L["Most deaths early on come from fighting too many enemies at once. Take them one at a time, and start each fight with full health and mana."]
	local health = percentOf(C.Call("UnitHealth", "player"), C.Call("UnitHealthMax", "player"))
	if health then
		out.rows[#out.rows + 1] = { name = L["Health"], text = L["%d%%"]:format(health), tone = health < LOW_HEALTH and "warn" or nil }
	end
	local mana = percentOf(C.Call("UnitPower", "player", 0), C.Call("UnitPowerMax", "player", 0))
	if mana then
		out.rows[#out.rows + 1] = { name = L["Mana"], text = L["%d%%"]:format(mana), tone = mana < LOW_HEALTH and "warn" or nil }
	end
	local carried = G.Supplies()
	if carried.read then
		local food = carried.food
		out.rows[#out.rows + 1] = { name = L["Food and drink"], tone = food.count == 0 and "warn" or nil,
			text = food.count == 0 and L["None"] or food.name and L["%d, mostly %s"]:format(food.count, food.name) or tostring(food.count),
			run = function()
				T.Window:Select("guide", "supplies")
			end, tag = L["Read"], tagRole = "accentText" }
	end
	for _, row in ipairs(plainRows(D.fighting and D.fighting.rows)) do
		out.rows[#out.rows + 1] = row
	end
	out.total = #out.rows
	local low = health and health < LOW_HEALTH or mana and mana < LOW_HEALTH
	out.next = (low and L["Eat or drink before your next fight: it brings you back far faster than waiting."] .. " " or "")
		.. L["Look at what is around an enemy before you pull it, and if a fight goes wrong, run early."]
	if carried.read and carried.food.count == 0 then
		out.action = { label = L["Find a vendor"], run = findRun("vendor") }
	end
	return out
end

-- The hunter's pet, in words only (whether the game tells addons a pet's happiness on Forever
-- is unchecked). Figures from Warcraft Tavern's Forever pet guide, matched by others.
local TAME_BEAST = 1515

local function pet()
	local hunter = G.ClassFile() == "HUNTER"
	local out = { rows = {}, attention = 0, hidden = not hunter, heading = L["Looking after it"] }
	out.what = L["A hunter's pet fights beside you. Keep it fed and happy: a happy pet hits harder and an unhappy one hits softer."]
	local tamed = knows(TAME_BEAST)
	for _, row in ipairs(plainRows(D.pet and D.pet.rows)) do
		out.rows[#out.rows + 1] = row
	end
	if out.rows[1] and tamed then
		out.rows[1].tag, out.rows[1].tagRole, out.rows[1].tone = L["Done"], "go", "faint"
	elseif out.rows[1] then
		out.rows[1].run, out.rows[1].tag, out.rows[1].tagRole = findRun("trainer"), L["Find"], "accentText"
	end
	out.total = #out.rows
	if hunter and tamed == false and G.Level() >= 10 then
		out.attention = 1
		out.next = L["You can tame a pet now. Your class trainer starts the class quest that teaches Tame Beast."]
		out.action = { label = L["Find your trainer"], run = findRun("trainer") }
	else
		out.next = L["Feed your pet before a long fight. Before you tame a new one, leave your current pet with a stable master."]
		out.action = { label = L["Find a stable master"], run = findRun("stable") }
	end
	return out
end

-- Quests: how they work, with how full the log is, as the game reports it.
local function quests()
	local out = { rows = {}, attention = 0, heading = L["Quest know-how"] }
	out.what = L["Quests are the main way to level. People with a yellow ! above their heads have work for you; go back to a yellow ? to hand it in and get your reward."]
	local _, count = C.Call("C_QuestLog.GetNumQuestLogEntries")
	count = C.Plain(count, nil)
	local most = C.Plain(C.Call("C_QuestLog.GetMaxNumQuestsCanAccept"), nil)
	if most == nil then
		most = C.Plain(C.Call("GetMaxNumQuestsCanAccept"), nil)
	end
	local full = false
	if type(count) == "number" and type(most) == "number" and most > 0 then
		full = count >= most
		out.rows[#out.rows + 1] = { name = L["Your log"], text = L["%d of %d quests"]:format(count, most),
			tone = most - count <= 2 and "warn" or nil }
	end
	for _, row in ipairs(plainRows(D.quests and D.quests.rows)) do
		out.rows[#out.rows + 1] = row
	end
	out.total = #out.rows
	if full then
		out.attention = 1
		out.next = L["Your quest log is full. Abandon grey quests first: they give little experience now."]
	else
		out.next = L["Take every quest in a town before you head out, and do the ones in the same area together."]
	end
	return out
end

local TOPICS = {
	{ id = "class", group = "you", icon = "sword", label = L["Your class"], read = classNotes },
	{ id = "talents", group = "you", icon = "spark", label = L["Talents"], read = talents },
	{ id = "levels", group = "you", icon = "burst", label = L["Coming up"], read = coming },
	{ id = "gear", group = "you", icon = "shield", label = L["Gear"], read = gear },
	{ id = "weapons", group = "you", icon = "hammer", label = L["Weapon skills"], read = weapons },
	{ id = "professions", group = "you", icon = "pick", label = L["Professions"], read = professions },
	{ id = "fighting", group = "you", icon = "tri", label = L["Fighting"], read = fighting },
	{ id = "screen", group = "you", icon = "gear", label = L["Screen setup"], read = screen },

	{ id = "firststeps", group = "world", icon = "check", label = L["First steps"], read = firstSteps },
	{ id = "rest", group = "world", icon = "bed", label = L["Inns and rest"], read = rest },
	{ id = "services", group = "world", icon = "home", label = L["Towns and services"], read = services },
	{ id = "supplies", group = "world", icon = "bag", label = L["Supplies"], read = supplies },
	{ id = "travel", group = "world", icon = "wing", label = L["Travel"], read = travel },
	{ id = "mount", group = "world", icon = "shoe", label = L["Mount"], read = mount },
	{ id = "dying", group = "world", icon = "moon", label = L["Dying"], read = dying },
	{ id = "quests", group = "world", icon = "pin", label = L["Quests"], read = quests },

	{ id = "grouping", group = "others", icon = "plus", label = L["Grouping"], read = grouping },
	{ id = "danger", group = "others", icon = "tri", label = L["Danger and PvP"], read = danger },
	{ id = "words", group = "others", icon = "book", label = L["Words and chat"], read = words },
	{ id = "pet", group = "others", icon = "bulb", label = L["Your pet"], read = pet },

	{ id = "money", group = "gold", icon = "coin", label = L["Money"], read = money },
	{ id = "reputation", group = "gold", icon = "bars", label = L["Reputation"], read = reputation },
	{ id = "camping", group = "gold", icon = "bed", label = L["Camping"], read = camping },
	{ id = "choosing", group = "gold", icon = "pick", label = L["Pick professions"], read = choosing },
	{ id = "forever", group = "gold", icon = "mtn", label = L["Forever's systems"], read = forever },
	{ id = "week", group = "gold", icon = "scroll", label = L["Each week"], read = week },
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

local function rowLook(row)
	row:SetStyle({ fill = row.hover and row.run and "cardHover" or false })
	row.name:SetRole(row.hover and row.run and "accentText" or "ink")
end

local function makeRow(panel, index)
	-- A button, so a row that leads somewhere (a service, a vendor) can be clicked. It reaches
	-- ROW_INSET past the words on each side, so its hover fill frames them.
	local row = W.Panel(panel, { shape = "card" }, "Button")
	row:SetSize(PANEL_W - 40 + 2 * ROW_INSET, ROW_H)
	row.name = W.Text(row, "body", 11.5, "ink")
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_INSET, -ROW_PAD)
	row.name:SetWidth(100)
	row.bar = W.Bar(row, 150, 8, "accent", "accent")
	row.bar:SetPoint("LEFT", row, "LEFT", ROW_INSET + 128, 0)
	row.value = W.Text(row, "body", 11, "muted")
	row.value:SetPoint("LEFT", row.bar, "RIGHT", 12, 0)
	-- A row of plain words instead of a bar (the "Coming up" topic).
	-- It may run to a second line; the row grows with it (Guide:Refresh).
	row.note = W.Text(row, "body", 11, "muted", { width = NOTE_W })
	row.note:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_INSET + 104, -ROW_PAD)
	row.note:SetSpacing(2)
	if row.note.SetMaxLines then
		row.note:SetMaxLines(2)
	end
	-- A row that leads somewhere ends in an arrow, with its tag (Find, Read) before it.
	row.arrow = W.Icon(row, "arrow", ARROW, "accentText")
	row.arrow:SetPoint("RIGHT", row, "RIGHT", -ROW_INSET, 0)
	row.tag = W.Text(row, "label", 10, "go")
	row.tag:SetJustifyH("RIGHT")
	row:SetScript("OnClick", function(self)
		if self.run then
			C.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
			self.run()
		end
	end)
	row:SetScript("OnEnter", function(self)
		self.hover = true
		rowLook(self)
	end)
	row:SetScript("OnLeave", function(self)
		self.hover = false
		rowLook(self)
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
			row:SetPoint("TOPLEFT", ui.standLabel, "BOTTOMLEFT", -ROW_INSET, -6)
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
	-- The next page of a topic that has several (Words and chat).
	ui.pager = W.Button(panel, "", "ghost", {
		role = "accentText", height = 28, size = 11,
		onClick = function()
			if ui.pager.run then
				ui.pager.run()
			end
		end,
	})
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
	row.arrow:SetShown(item.run ~= nil)
	row.tag:ClearAllPoints()
	if item.run then
		row.tag:SetPoint("RIGHT", row.arrow, "LEFT", -6, 0)
	else
		row.tag:SetPoint("RIGHT", row, "RIGHT", -ROW_INSET, 0)
	end
	rowLook(row)
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
	local waiting, slots = {}, {}
	for index, topic in ipairs(TOPICS) do
		local button = ui.topics[index]
		local info = topic.read()
		button.info = info
		button.count:SetLabel(info.attention > 0 and tostring(info.attention) or "")
		button.badge:SetShown(info.attention > 0)
		button:SetShown(topic.group == self.group and not info.hidden)
		-- A hidden topic (First steps, once done) leaves no gap in its group's list.
		if not info.hidden then
			slots[topic.group] = (slots[topic.group] or 0) + 1
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", self.page, "TOPLEFT", 0, -(LIST_TOP + (slots[topic.group] - 1) * (TOPIC_H + TOPIC_GAP)))
		end
		waiting[topic.group] = (waiting[topic.group] or 0) + info.attention
		if topic.id == self.topic then
			current = topic
		end
		topicLook(button)
	end
	-- A hidden topic is never the open one: the next one in its group opens instead, or the
	-- one before it when it is the last (Your pet for a class without one).
	local hiddenAt
	for index, topic in ipairs(TOPICS) do
		if topic == current and ui.topics[index].info.hidden then
			hiddenAt = index
		end
	end
	if hiddenAt then
		local group = current.group
		local order = {}
		for later = hiddenAt + 1, #TOPICS do
			order[#order + 1] = later
		end
		for earlier = hiddenAt - 1, 1, -1 do
			order[#order + 1] = earlier
		end
		for _, other in ipairs(order) do
			if TOPICS[other].group == group and not ui.topics[other].info.hidden then
				current = TOPICS[other]
				self.topic = current.id
				break
			end
		end
	end
	for _, button in ipairs(ui.topics) do
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
		ui.nextLabel:SetPoint("TOPLEFT", ui.rows[shown], "BOTTOMLEFT", ROW_INSET, -(GAP - ROW_PAD))
	else
		ui.nextLabel:SetPoint("TOPLEFT", ui.what, "BOTTOMLEFT", 0, -GAP)
	end
	-- The buttons sit under the last block of words.
	local last, lastGap = ui.what, GAP
	if hasNext then
		last = ui.next
	elseif shown > 0 then
		last, lastGap = ui.rows[shown], GAP - ROW_PAD
	end
	ui.action:ClearAllPoints()
	ui.action:SetPoint("TOPLEFT", last, "BOTTOMLEFT", last == ui.rows[shown] and ROW_INSET or 0, -lastGap)
	ui.pager:ClearAllPoints()
	if info.action then
		ui.pager:SetPoint("LEFT", ui.action, "RIGHT", 10, 0)
	else
		ui.pager:SetPoint("TOPLEFT", ui.action, "TOPLEFT", 0, 0)
	end
	ui.action:SetShown(info.action ~= nil)
	if info.action then
		ui.action:SetLabel(info.action.label)
		ui.action.run = info.action.run
	end
	T.Secure.Set(ui.action, info.action and info.action.secure, info.action and info.action.after)
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
