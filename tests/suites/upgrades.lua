local H = ...
local Stub, check = H.Stub, H.check

-- Upgrade hints on item tooltips (Services/Upgrades.lua).

local STR, AGI, STA, INT, SPI = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT",
	"ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT"
local ARMOR, DPS = "RESISTANCE0_NAME", "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"

local nextID = 50000
-- A fake item: kind = "cloth" | "leather" | "plate" | "ring" | "trinket" | "staff" | "sword2h" | "dagger" | "shield" | "bow".
local KINDS = {
	cloth = { "INVTYPE_HEAD", 4, 1, "Cloth" }, leather = { "INVTYPE_CHEST", 4, 2, "Leather" },
	plate = { "INVTYPE_CHEST", 4, 4, "Plate" }, ring = { "INVTYPE_FINGER", 4, 0, "Miscellaneous" },
	trinket = { "INVTYPE_TRINKET", 4, 0, "Miscellaneous" }, staff = { "INVTYPE_2HWEAPON", 2, 10, "Staves" },
	sword2h = { "INVTYPE_2HWEAPON", 2, 8, "Two-Handed Swords" }, dagger = { "INVTYPE_WEAPON", 2, 15, "Daggers" },
	shield = { "INVTYPE_SHIELD", 4, 6, "Shields" }, bow = { "INVTYPE_RANGED", 2, 2, "Bows" },
	fist = { "INVTYPE_WEAPON", 2, 13, "Fist Weapons" },
}
local function item(kind, stats, extra)
	nextID = nextID + 1
	local def = KINDS[kind]
	local link = "|cff1eff00|Hitem:" .. nextID .. "::::::::14:::::|h[Item " .. nextID .. "]|h|r"
	local entry = { id = nextID, equipLoc = def[1], classID = def[2], subClassID = def[3], subType = def[4], stats = stats,
		name = "Item " .. nextID }
	for key, value in pairs(extra or {}) do
		entry[key] = value
	end
	Stub.world.items = Stub.world.items or {}
	Stub.world.items[link] = entry
	return link
end

-- Puts an item on, and tells Trailhead the way the game does.
local function wear(slot, link)
	Stub.world.equipped = Stub.world.equipped or {}
	Stub.world.equipped[slot] = link
	Stub.fire("PLAYER_EQUIPMENT_CHANGED", slot)
end

-- Hovers the item and returns the lines Trailhead added.
local function hover(link, data)
	local tip = Stub.tooltip(data and data.forbidden)
	local fields = data or {}
	local tooltipData = { type = 0, id = 1, hyperlink = link, lines = fields.lines }
	if not fields.lines and link and Stub.world.items[link] then
		tooltipData.lines = Stub.itemLines(Stub.world.items[link])
	end
	for key, value in pairs(fields) do
		if key ~= "forbidden" then
			tooltipData[key] = value
		end
	end
	Stub.itemTooltip(tip, fields.raw or tooltipData)
	local out = {}
	for _, line in ipairs(tip.added) do
		out[#out + 1] = line.text
	end
	return out, tip
end

local function said(lines)
	return table.concat(lines, " / ")
end

H.section("upgrades: the hook", function()
	local T = H.load()
	check(#(Stub.tooltipPostCalls[0] or {}) == 1, "one post-call is registered for item tooltips")
	check(Stub.tooltipPostCalls[1] == nil and Stub.tooltipPostCalls[2] == nil, "and none for spells or units")
	check(T.db.upgradeHints == true, "upgrade hints are on by default")
	H.noErrors(T, "hook")

	T = H.load({ bare = true })
	check(next(Stub.tooltipPostCalls) == nil, "a client without the tooltip processor gets no hook and no error")
	H.noErrors(T, "bare client")
end)

H.section("upgrades: better and worse (mage)", function()
	local T = H.load()
	wear(1, item("cloth", { [INT] = 2, [STA] = 1, [ARMOR] = 10 }))
	local better = item("cloth", { [INT] = 6, [STA] = 4, [SPI] = 1, [ARMOR] = 12 })
	local lines, tip = hover(better)
	check(said(lines) == "Upgrade for you: +4 Intellect, +3 Stamina", "an upgrade names the main difference: " .. said(lines))
	check(tip.added[1].wrap == true, "the line wraps rather than widening the tooltip")
	local worse = item("cloth", { [INT] = 1, [STA] = 1, [ARMOR] = 14 })
	lines = hover(worse)
	check(said(lines) == "Not better than what you wear: -1 Intellect", "a worse item says what it loses: " .. said(lines))
	lines = hover(item("cloth", { [INT] = 4, [STA] = 0 }))
	check(#lines == 0, "more of one stat and less of another: nothing is said")
	lines = hover(item("cloth", { [INT] = 2, [STA] = 1, [ARMOR] = 10 }))
	check(#lines == 0, "the same stats: nothing is said")
	lines = hover(item("cloth", { [INT] = 2, [STA] = 1, [ARMOR] = 15 }))
	check(said(lines) == "Upgrade for you: +5 Armor", "with the same stats, more armor decides: " .. said(lines))
	lines = hover(item("cloth", { [INT] = 2, [STA] = 1, [AGI] = 9, [ARMOR] = 10 }))
	check(#lines == 0, "a stat the build does not look for changes nothing")
	lines = hover(item("cloth", { [INT] = 3, [STA] = 2, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 5 }))
	check(#lines == 0, "a stat Trailhead does not weigh: nothing is said")
	lines = hover(item("cloth", { [INT] = 9, [STA] = 9 }, { lines = { "Equip: Restores 3 mana per 5 sec." } }))
	check(#lines == 0, "an item with an effect: nothing is said")
	wear(1, item("cloth", { [INT] = 1 }, { lines = { "Use: Something special." } }))
	lines = hover(better)
	check(#lines == 0, "a worn item with an effect is never called beaten")
	wear(1, better)
	lines = hover(better)
	check(#lines == 0, "the worn item itself gets no line")
	wear(1, item("cloth", { [INT] = 1 }))
	lines = hover(item("cloth", { [INT] = 9 }, { minLevel = 30 }))
	check(said(lines) == "Upgrade for you: +8 Intellect / You can wear it from level 30.", "a level not reached yet is named: " .. said(lines))
	H.noErrors(T, "better and worse")
end)

H.section("upgrades: empty slots", function()
	local T = H.load()
	local lines = hover(item("cloth", { [INT] = 1 }))
	check(said(lines) == "Upgrade for you: that slot is empty", "anything beats an empty slot: " .. said(lines))
	wear(11, item("ring", { [INT] = 5 }))
	lines = hover(item("ring", { [STA] = 1 }))
	check(said(lines) == "Upgrade for you: that slot is empty", "and an empty second ring slot")
	lines = hover(item("staff", { [INT] = 1 }))
	check(said(lines) == "Upgrade for you: that slot is empty", "and an empty main hand")
	H.noErrors(T, "empty")
end)

H.section("upgrades: rings and trinkets", function()
	local T = H.load()
	local strong = item("ring", { [INT] = 6, [STA] = 6 })
	local weak = item("ring", { [INT] = 2, [STA] = 1 })
	wear(11, strong)
	wear(12, weak)
	local lines = hover(item("ring", { [INT] = 3, [STA] = 2 }))
	check(said(lines) == "Upgrade for you: +1 Intellect, +1 Stamina", "compared with the weaker ring: " .. said(lines))
	lines = hover(item("ring", { [INT] = 1, [STA] = 1 }))
	check(said(lines) == "Not better than what you wear: -1 Intellect", "worse than both: the loss against the weaker one: " .. said(lines))
	lines = hover(item("ring", { [INT] = 9, [STA] = 9 }))
	check(said(lines) == "Upgrade for you: +7 Intellect, +8 Stamina", "better than both: against the weaker one: " .. said(lines))
	lines = hover(item("ring", { [INT] = 4, [STA] = 0 }))
	check(#lines == 0, "unclear against both: nothing is said")
	lines = hover(strong)
	check(#lines == 0, "a worn ring gets no line, even though it beats the other")
	wear(13, item("trinket", { [STA] = 1 }))
	wear(14, item("trinket", { [STA] = 3 }))
	lines = hover(item("trinket", { [STA] = 2 }))
	check(said(lines) == "Upgrade for you: +1 Stamina", "trinkets work the same way: " .. said(lines))
	H.noErrors(T, "rings")
end)

H.section("upgrades: kinds the class cannot use", function()
	local T = H.load()
	local lines, tip = hover(item("plate", { [INT] = 20 }))
	check(said(lines) == "You can't use this: Plate", "a mage cannot wear plate: " .. said(lines))
	check(tip.added[1].r == 1, "in a warning colour")
	lines = hover(item("leather", { [INT] = 20 }))
	check(said(lines) == "You can't use this: Leather", "nor leather")
	lines = hover(item("sword2h", { [INT] = 20 }))
	check(said(lines) == "You can't use this: Two-Handed Swords", "nor two-handed swords")
	lines = hover(item("fist", { [INT] = 20 }))
	check(not said(lines):find("can't use", 1, true), "fist weapons are left alone (unsure which skill counts)")
	Stub.world.armorFolded = true
	Stub.world.now = 3000 -- the skill list is read again a second later
	lines = hover(item("plate", { [INT] = 20 }))
	check(not said(lines):find("can't use", 1, true), "a folded armor list: no claim")
	Stub.world.armorFolded = nil
	H.noErrors(T, "unusable")

	T = H.load({ class = "WARRIOR" })
	Stub.world.armor = { "Cloth", "Leather", "Mail", "Shield" }
	Stub.world.weapons = { { "Two-Handed Swords", 55, 50 }, { "Daggers", 173, 40 }, { "Bows", 45, 10 } }
	lines = hover(item("plate", { [STR] = 1 }))
	check(said(lines) == "You can't use this: Plate", "a warrior before plate: " .. said(lines))
	Stub.world.armor = { "Cloth", "Leather", "Mail", "Plate Mail", "Shield" }
	Stub.flush()
	Stub.world.now = 2000 -- the skill list is read again a second later
	lines = hover(item("plate", { [STR] = 1 }))
	check(not said(lines):find("can't use", 1, true), "and once plate is learned, no warning: " .. said(lines))
	H.noErrors(T, "warrior kinds")
end)

H.section("upgrades: weapons and builds (warrior)", function()
	local T = H.load({ class = "WARRIOR" })
	Stub.world.armor = { "Cloth", "Leather", "Mail", "Shield" }
	Stub.world.weapons = { { "Two-Handed Swords", 55, 50 }, { "Daggers", 173, 40 }, { "Bows", 45, 10 } }
	wear(16, item("sword2h", { [STR] = 3, [DPS] = 10.5 }))
	local lines = hover(item("sword2h", { [STR] = 3, [STA] = 2, [DPS] = 12 }))
	check(said(lines) == "Upgrade for you: +2 Stamina, +1.5 damage per second", "weapon damage counts for a warrior: " .. said(lines))
	lines = hover(item("dagger", { [STR] = 9 }))
	check(#lines == 0, "a one-hander against a two-hander: nothing is said")
	wear(5, item("leather", { [STA] = 2, [ARMOR] = 50 }))
	lines = hover(item("leather", { [STA] = 2, [ARMOR] = 80, [STR] = 0 }))
	check(said(lines) == "Upgrade for you: +30 Armor", "no build chosen: armor counts, since the tank build wants it: " .. said(lines))
	lines = hover(item("leather", { [STA] = 1, [STR] = 4, [ARMOR] = 50 }))
	check(#lines == 0, "no build chosen: less Stamina for more Strength is not called better")
	T.cdb.build = "levelling"
	lines = hover(item("leather", { [STA] = 2, [STR] = 4, [ARMOR] = 40 }))
	check(said(lines) == "Upgrade for you: +4 Strength", "the levelling build looks past a little armor: " .. said(lines))
	T.cdb.build = "tank"
	lines = hover(item("leather", { [STA] = 2, [STR] = 4, [ARMOR] = 40 }))
	check(#lines == 0, "the tank build does not")
	wear(18, item("bow", { [AGI] = 2, [DPS] = 5 }))
	lines = hover(item("bow", { [AGI] = 1, [DPS] = 6 }))
	check(said(lines) == "Upgrade for you: +1.0 damage per second", "tank build: Agility is not weighed, weapon damage breaks the tie: " .. said(lines))
	H.noErrors(T, "warrior")
end)

H.section("upgrades: combat, secrets, switch, errors", function()
	local T = H.load()
	wear(1, item("cloth", { [INT] = 1 }))
	local better = item("cloth", { [INT] = 5 })
	Stub.combat = true
	local lines = hover(better)
	check(#lines == 0, "nothing in combat")
	lines = hover(item("plate", { [INT] = 1 }))
	check(#lines == 0, "not even a warning")
	Stub.combat = false
	check(#hover(better) == 1, "and back after combat")

	lines = hover(item("cloth", Stub.SECRET))
	check(#lines == 0, "secret stats: nothing")
	lines = hover(nil, { hyperlink = Stub.SECRET })
	check(#lines == 0, "a secret link: nothing")
	lines = hover(nil, { raw = Stub.SECRET })
	check(#lines == 0, "secret tooltip data: nothing")
	lines = hover(item("cloth", { [INT] = 9 }), { lines = { { leftText = Stub.SECRET } } })
	check(#lines == 0, "secret tooltip text: nothing")
	wear(1, item("cloth", { [INT] = Stub.SECRET }))
	lines = hover(better)
	check(#lines == 0, "a secret stat on the worn item: nothing")
	wear(1, item("cloth", { [INT] = 1 }))
	lines = hover(better, { forbidden = true })
	check(#lines == 0, "a forbidden tooltip is left alone")
	Stub.world.guids = { ["Item-1-0-ABC"] = better }
	lines = hover(nil, { guid = "Item-1-0-ABC", lines = Stub.itemLines(Stub.world.items[better]) })
	check(#lines == 1, "a bag item is found by its GUID")
	lines = hover(nil, {})
	check(#lines == 0, "no link at all: nothing")
	H.noErrors(T, "secrets")

	H.slash("settings")
	Stub.click("Items")
	check(Stub.sees("Upgrade hints"), "the setting is on the Items section")
	Stub.click("On")
	check(T.db.upgradeHints == false, "and turns the hints off")
	check(#hover(better) == 0, "switched off: nothing")
	check(#hover(item("plate", { [INT] = 1 })) == 0, "not even a warning")
	Stub.click("Off")
	check(T.db.upgradeHints == true and #hover(better) == 1, "and on again")
	H.noErrors(T, "switch")

	T.Upgrades.Judge = function() error("broken on purpose") end
	local ok = pcall(hover, better)
	check(ok, "an error inside never reaches the game's tooltip")
	check(#T.db.errors == 1 and T.db.errors[1].where == "Upgrades.OnTooltip", "it is recorded")
	Stub.errors = {}
	T.db.errors = {}
end)

H.section("upgrades: build data agrees with the builds", function()
	local T = H.load()
	local U = T.Upgrades
	local names = { [STR] = "Strength", [AGI] = "Agility", [STA] = "Stamina", [INT] = "Intellect", [SPI] = "Spirit", [ARMOR] = "Armor" }
	for class, builds in pairs(T.Builds) do
		for _, build in ipairs(builds) do
			local wanted = U.PRIORITY[class] and U.PRIORITY[class][build.id]
			check(wanted ~= nil, class .. " " .. build.id .. " has stats to compare")
			if wanted then
				local last = 0
				for _, key in ipairs(wanted.stats) do
					local at = build.gear:find(names[key], 1, true)
					check(at ~= nil, class .. " " .. build.id .. ": " .. names[key] .. " is in its gear text")
					check(at and at >= last, class .. " " .. build.id .. ": " .. names[key] .. " in the gear text's order")
					last = at or last
				end
			end
		end
		for id in pairs(U.PRIORITY[class] or {}) do
			local found = false
			for _, build in ipairs(builds) do
				found = found or build.id == id
			end
			check(found, class .. " " .. id .. " is a real build")
		end
	end
end)

H.section("upgrades: the verdict is kept while the tooltip is hovered", function()
	local T = H.load()
	wear(1, item("cloth", { [INT] = 2, [STA] = 1, [ARMOR] = 10 }))
	local better = item("cloth", { [INT] = 6, [STA] = 4, [ARMOR] = 12 })
	local reads = 0
	local real = C_Item.GetItemStats
	C_Item.GetItemStats = function(...)
		reads = reads + 1
		return real(...)
	end
	Stub.world.now = 5000
	local first = said(hover(better))
	local after = reads
	for _ = 1, 5 do
		hover(better)
	end
	check(first:find("Upgrade for you", 1, true) ~= nil and reads == after, "hovered again within a second: worked out once")
	Stub.world.now = 5001
	hover(better)
	check(reads > after, "a second later it is worked out again")
	after = reads
	wear(1, item("cloth", { [INT] = 9, [STA] = 9, [ARMOR] = 20 }))
	check(said(hover(better)):find("Not better", 1, true) ~= nil and reads > after, "new gear: the verdict follows at once")
	after = reads
	hover(better)
	Stub.fire("PLAYER_LEVEL_UP", 15)
	hover(better)
	check(reads > after + 1, "a level up forgets it")
	after = reads
	T:Fire("TH_SKILLS_CHANGED")
	hover(better)
	check(reads > after, "a change in skills forgets it")
	after = reads
	T:Fire("TH_BUILD_CHANGED")
	hover(better)
	check(reads > after, "another build forgets it")
	C_Item.GetItemStats = real
	Stub.world.now = nil
	check(T.Upgrades.Wanted() == T.Upgrades.Wanted(), "the class's merged stat list is made once")
	H.noErrors(T, "verdict cache")
end)
