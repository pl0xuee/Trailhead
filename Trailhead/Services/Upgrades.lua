local _, T = ...
local L = T.L
local C = T.Compat
local G = T.Game

-- Upgrades: one short line on an item's tooltip. "Upgrade for you" or "Not better than what
-- you wear" with the main difference, or "You can't use this: Plate".
--
-- Taint: the line is added from the game's own sanctioned hook for addons,
-- TooltipDataProcessor.AddTooltipPostCall. The game runs it insecurely on its own, after the
-- tooltip is filled and before it is shown. Nothing here replaces or hooks a Blizzard
-- function, writes onto a Blizzard frame or calls Blizzard Lua; the only thing done to the
-- tooltip is the widget's own AddLine. Nothing runs in combat, and every value read from the
-- tooltip or the item functions may be a secret value, so any doubt means no line.
--
-- How it compares: only the stats the character's build looks for (see PRIORITY), and only
-- when one item has at least as much of every one of them. When one item has more of one
-- and less of another, nothing is said: that choice depends on more than this can know. The
-- same goes for items with an "Equip:", "Use:", "Chance on hit:" or set bonus, and for stats
-- it does not know.

local U = {}
T.Upgrades = U

local STR, AGI, STA, INT, SPI = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT",
	"ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT"
local ARMOR, DPS = "RESISTANCE0_NAME", "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
U.STATS = { STR = STR, AGI = AGI, STA = STA, INT = INT, SPI = SPI, ARMOR = ARMOR, DPS = DPS }

-- Names for when the game's own words are missing.
local NAMES = { [STR] = L["Strength"], [AGI] = L["Agility"], [STA] = L["Stamina"], [INT] = L["Intellect"], [SPI] = L["Spirit"],
	[ARMOR] = L["Armor"], [DPS] = L["damage per second"] }

-- What each build looks for, in its order, read from the build's own "What to look for on
-- gear" (Data/Builds/<CLASS>.lua; tests/suites/upgrades.lua checks the two agree).
-- dps: the weapon's damage per second counts too ("ranged": only for the ranged slot).
U.PRIORITY = {
	WARRIOR = {
		levelling = { stats = { STR, STA }, dps = true },
		tank = { stats = { STA, ARMOR, STR } },
	},
	PALADIN = {
		levelling = { stats = { STR, STA }, dps = true },
		healer = { stats = { INT, STA, SPI } },
		tank = { stats = { STA, STR, ARMOR } },
	},
	HUNTER = { levelling = { stats = { AGI, STA, INT }, dps = "ranged" } },
	ROGUE = { levelling = { stats = { AGI, STA }, dps = true } },
	PRIEST = {
		levelling = { stats = { INT, SPI, STA } },
		healer = { stats = { INT, SPI, STA } },
	},
	SHAMAN = {
		levelling = { stats = { INT, STA }, dps = true },
		healer = { stats = { INT, STA, SPI } },
	},
	MAGE = { levelling = { stats = { INT, STA, SPI } } },
	WARLOCK = { levelling = { stats = { STA, INT } } },
	DRUID = {
		levelling = { stats = { STR, AGI, STA } },
		healer = { stats = { INT, SPI, STA } },
		tank = { stats = { STA, ARMOR, STR, AGI } },
	},
}

-- Stats that only decide when every stat the build looks for is equal.
local TIEBREAK = { ARMOR, DPS }
-- Stats this file knows. A difference in any other stat means nothing is said.
local KNOWN = { [STR] = true, [AGI] = true, [STA] = true, [INT] = true, [SPI] = true, [ARMOR] = true, [DPS] = true }

-- Which slots an item goes in, by the game's equip location. Two slots: compare with the
-- weaker. Weapons, off hands and the ranged slot have their own rules in slotsFor.
local SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
	INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
	INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
	INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
}
local MAIN, OFF, RANGED = 16, 17, 18
local WEAPON_CLASS, ARMOR_CLASS = 2, 4
-- Armor kinds and the skill each needs (the game's SkillLine table for build 1.60.1.70888):
-- cloth, leather, mail, plate, shield. Other kinds (librams, idols, totems) are left alone.
local ARMOR_SKILL = { [1] = 415, [2] = 414, [3] = 413, [4] = 293, [6] = 433 }
-- Weapon kinds left alone: fist weapons (the game has both an Unarmed and a Fist Weapons
-- skill and it is not clear which one counts), and everything without a skill.
local WEAPON_UNSURE = { [13] = true }

local function str(value)
	value = C.Plain(value, nil)
	return type(value) == "string" and value ~= "" and value or nil
end

local function num(value)
	value = C.Plain(value, nil)
	return type(value) == "number" and value or nil
end

-- The stats the character's build looks for: { stats = { key ... }, dps = true | "ranged" | nil }.
-- With no build chosen, every stat any of the class's builds looks for, so a "better" holds
-- whichever way the character plays. The merged list is made once per class.
local mergedFor = {}

function U.Wanted()
	local class = G.ClassFile()
	local builds = class and U.PRIORITY[class]
	if not builds then
		return nil
	end
	local chosen = T.cdb and T.cdb.build
	if chosen and builds[chosen] then
		return builds[chosen]
	end
	if mergedFor[class] then
		return mergedFor[class]
	end
	local out, seen, order = { stats = {} }, {}, {}
	for id in pairs(builds) do
		order[#order + 1] = id
	end
	table.sort(order, function(a, b)
		if (a == "levelling") ~= (b == "levelling") then
			return a == "levelling"
		end
		return a < b
	end)
	for _, id in ipairs(order) do
		local build = builds[id]
		for _, key in ipairs(build.stats) do
			if not seen[key] then
				seen[key] = true
				out.stats[#out.stats + 1] = key
			end
		end
		if build.dps and out.dps ~= true then
			out.dps = build.dps
		end
	end
	mergedFor[class] = out
	return out
end

-- The skills, read at most once a second: the tooltip asks again and again while it is shown.
local skillCache, skillAt
local function skills()
	local now = num(C.Call("GetTime"))
	if skillCache and now and skillAt and now - skillAt < 1 then
		return skillCache
	end
	skillCache, skillAt = G.Skills(), now
	return skillCache
end

-- What the game tells about an item: nil when anything needed is missing or secret.
local function info(link)
	if not C.Has("C_Item.GetItemInfoInstant") then
		return nil
	end
	local id, _, subType, equipLoc, _, classID, subClassID = C.Call("C_Item.GetItemInfoInstant", link)
	id, equipLoc, classID, subClassID = num(id), str(equipLoc), num(classID), num(subClassID)
	if not id or not equipLoc or not classID or not subClassID then
		return nil
	end
	return { id = id, link = link, subType = str(subType), equipLoc = equipLoc, classID = classID, subClassID = subClassID }
end

-- Why the character cannot use the item (the game's own word for its kind), or nil when it
-- can or when that cannot be told for sure.
function U.Unusable(item)
	if item.classID == ARMOR_CLASS then
		local skill = ARMOR_SKILL[item.subClassID]
		if not skill then
			return nil
		end
		local known = skills()
		if known.armorFolded or not next(known.armorIds or {}) then
			return nil
		end
		return not known.armorIds[skill] and item.subType or nil
	elseif item.classID == WEAPON_CLASS then
		local skill = not WEAPON_UNSURE[item.subClassID] and G.WEAPON_SKILL and G.WEAPON_SKILL[item.subClassID]
		if not skill then
			return nil
		end
		local known = skills()
		if not known.complete or not next(known.byId) then
			return nil
		end
		return not known.byId[skill] and item.subType or nil
	end
	return nil
end

local function equippedLink(slot)
	return str(C.Call("GetInventoryItemLink", "player", slot))
end

-- The slots to compare with, or nil when the comparison would be a guess.
local function slotsFor(item)
	local loc = item.equipLoc
	if SLOTS[loc] then
		return SLOTS[loc]
	end
	local main, off = equippedLink(MAIN), equippedLink(OFF)
	local mainInfo = main and info(main)
	if main and not mainInfo then
		return nil
	end
	local twoHanded = mainInfo and mainInfo.equipLoc == "INVTYPE_2HWEAPON"
	if loc == "INVTYPE_2HWEAPON" then
		-- Against one-handers, a two-hander is a different way to play.
		return (not main or (twoHanded and not off)) and { MAIN } or nil
	end
	if twoHanded then
		return nil
	end
	local offInfo = off and info(off)
	if off and not offInfo then
		return nil
	end
	local offWeapon = offInfo and offInfo.classID == WEAPON_CLASS
	if loc == "INVTYPE_WEAPON" then
		-- With a weapon in each hand it could go in either.
		return offWeapon and { MAIN, OFF } or { MAIN }
	elseif loc == "INVTYPE_WEAPONMAINHAND" then
		return { MAIN }
	elseif loc == "INVTYPE_WEAPONOFFHAND" then
		return offWeapon and { OFF } or nil
	elseif loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then
		return offInfo and offInfo.equipLoc == loc and { OFF } or nil
	end
	return nil
end

-- An item's stats as plain numbers, or nil when the game gave none or something is secret.
local function stats(link)
	local raw = C.Plain(C.Call("C_Item.GetItemStats", link), nil)
	if raw == nil and C.Has("GetItemStats") then
		raw = C.Plain(C.Call("GetItemStats", link), nil)
	end
	if type(raw) ~= "table" then
		return nil
	end
	local out = {}
	for key, value in pairs(raw) do
		key, value = C.Plain(key, nil), C.Plain(value, nil)
		if type(key) ~= "string" or type(value) ~= "number" then
			return nil
		end
		out[key] = value
	end
	return out
end

-- The start of every tooltip line that adds something stats cannot show ("Equip:", "Use:").
-- The game's texts do not change while it runs: worked out once, when first found.
local startsCache
local function effectStarts()
	if startsCache then
		return startsCache
	end
	local out = {}
	for _, name in ipairs({ "ITEM_SPELL_TRIGGER_ONEQUIP", "ITEM_SPELL_TRIGGER_ONUSE", "ITEM_SPELL_TRIGGER_ONPROC", "ITEM_SET_BONUS" }) do
		local text = str(_G[name])
		if text then
			text = text:gsub("%%s.*$", ""):gsub("%s+$", "")
			if text ~= "" then
				out[#out + 1] = text
			end
		end
	end
	if #out > 0 then
		startsCache = out
	end
	return out
end

-- True when the tooltip lines show an effect, nil when that cannot be told.
local function hasEffect(data, starts)
	if #starts == 0 then
		return nil
	end
	data = C.Plain(data, nil)
	local lines = type(data) == "table" and C.Plain(data.lines, nil)
	if type(lines) ~= "table" then
		return nil
	end
	for _, line in ipairs(lines) do
		line = C.Plain(line, nil)
		if type(line) ~= "table" then
			return nil
		end
		local text = C.Plain(line.leftText, nil)
		if C.IsSecret(line.leftText) then
			return nil
		end
		if type(text) == "string" then
			for _, start in ipairs(starts) do
				if text:sub(1, #start) == start then
					return true
				end
			end
		end
	end
	return false
end

-- Compares two stat tables for the wanted stats.
-- Returns "better" | "worse" | "same" | nil (unsure), and the differences that matter.
local function compare(new, old, wanted, weapon)
	local keys = {}
	for _, key in ipairs(wanted.stats) do
		keys[#keys + 1] = key
	end
	local counts = { [DPS] = weapon and (wanted.dps == true or (wanted.dps == "ranged" and weapon == RANGED)) }
	if counts[DPS] then
		keys[#keys + 1] = DPS
	end
	local listed = {}
	for _, key in ipairs(keys) do
		listed[key] = true
	end
	-- A stat this file does not know, different between the two: unsure.
	for _, tbl in ipairs({ new, old }) do
		for key in pairs(tbl) do
			if not KNOWN[key] and (new[key] or 0) ~= (old[key] or 0) then
				return nil
			end
		end
	end
	local function judge(list)
		local up, down, diffs = false, false, {}
		for _, key in ipairs(list) do
			local diff = (new[key] or 0) - (old[key] or 0)
			if diff > 0.001 then
				up = true
			elseif diff < -0.001 then
				down = true
			end
			if diff > 0.001 or diff < -0.001 then
				diffs[#diffs + 1] = { key = key, diff = diff }
			end
		end
		if up and down then
			return nil
		end
		return up and "better" or down and "worse" or "same", diffs
	end
	local verdict, diffs = judge(keys)
	if verdict ~= "same" then
		return verdict, diffs
	end
	local rest = {}
	for _, key in ipairs(TIEBREAK) do
		if not listed[key] then
			rest[#rest + 1] = key
		end
	end
	return judge(rest)
end

local function statText(entry)
	local name = str(_G[entry.key]) or NAMES[entry.key] or entry.key
	local amount = entry.key == DPS and ("%+.1f"):format(entry.diff) or ("%+d"):format(entry.diff)
	return amount .. " " .. name
end

-- Up to two differences, in the build's order, of the kind that decided.
local function detail(diffs, sign)
	local parts = {}
	for _, entry in ipairs(diffs) do
		if (sign > 0 and entry.diff > 0) or (sign < 0 and entry.diff < 0) then
			parts[#parts + 1] = statText(entry)
			if #parts == 2 then
				break
			end
		end
	end
	return table.concat(parts, ", ")
end

-- What to say about an item for this character:
--   { kind = "unusable", what } | { kind = "upgrade", text, level } | { kind = "worse", text } | nil
-- data: the tooltip's data, for its lines (effects); may be nil.
local judge

-- The game refreshes a tooltip several times a second while it is hovered: each item's
-- verdict is kept, and forgotten when the gear, skills, build or level change, or after a second.
local VERDICT_AGE = 1
local verdicts, verdictsAt = {}, nil

function U.Forget()
	verdicts, verdictsAt = {}, nil
end

function U.Judge(link, data)
	local now = num(C.Call("GetTime"))
	if not now or not verdictsAt or now - verdictsAt >= VERDICT_AGE or now < verdictsAt then
		verdicts, verdictsAt = {}, now
	end
	local key = tostring(link) .. (type(data) == "table" and "|d" or "|n")
	local kept = verdicts[key]
	if kept ~= nil then
		return kept or nil
	end
	local say = judge(link, data)
	if now then
		verdicts[key] = say or false
	end
	return say
end

function judge(link, data)
	local item = info(link)
	if not item or (item.classID ~= ARMOR_CLASS and item.classID ~= WEAPON_CLASS) then
		return nil
	end
	local what = U.Unusable(item)
	if what then
		return { kind = "unusable", what = what }
	end
	local wanted = U.Wanted()
	local slots = wanted and slotsFor(item)
	if not slots then
		return nil
	end
	local new = stats(link)
	if not new then
		return nil
	end
	local starts = effectStarts()
	local newEffect = hasEffect(data, starts)
	if newEffect ~= false then
		return nil
	end
	local weapon = (slots[1] == MAIN or slots[1] == OFF or slots[1] == RANGED) and slots[1] or nil

	-- What is worn there. An item already worn in one of those slots is not compared at all.
	local worn = {}
	for _, slot in ipairs(slots) do
		local old = equippedLink(slot)
		if old == link then
			return nil
		end
		worn[#worn + 1] = { slot = slot, link = old }
	end

	local level
	local minLevel = num((select(5, C.Call("C_Item.GetItemInfo", link))))
	if minLevel and minLevel > G.Level() then
		level = minLevel
	end

	-- An empty slot: anything usable is better than nothing (weapons only for the main hand).
	for _, entry in ipairs(worn) do
		if not entry.link and entry.slot ~= OFF then
			return { kind = "upgrade", text = L["Upgrade for you: that slot is empty"], level = level }
		end
	end
	for _, entry in ipairs(worn) do
		if not entry.link then
			return nil
		end
		entry.stats = stats(entry.link)
		if not entry.stats then
			return nil
		end
		entry.effect = hasEffect(C.Call("C_TooltipInfo.GetInventoryItem", "player", entry.slot), starts)
		if entry.effect == nil then
			return nil
		end
		entry.verdict, entry.diffs = compare(new, entry.stats, wanted, weapon)
		-- A worn item with an effect may be worth more than its stats: never call it beaten.
		if entry.effect and entry.verdict == "better" then
			entry.verdict = nil
		end
	end

	-- Two slots: the weaker of the two worn items is the one to replace.
	local target = worn[1]
	if #worn == 2 then
		local a, b = worn[1], worn[2]
		local weaker = compare(a.stats, b.stats, wanted, weapon) == "better" and b or a
		if a.verdict == "better" and b.verdict == "better" then
			target = weaker
		elseif a.verdict == "better" or b.verdict == "better" then
			target = a.verdict == "better" and a or b
		elseif a.verdict == "worse" and b.verdict == "worse" then
			target = weaker
		else
			return nil
		end
	end
	if target.verdict == "better" then
		return { kind = "upgrade", text = L["Upgrade for you: %s"]:format(detail(target.diffs, 1)), level = level }
	elseif target.verdict == "worse" then
		return { kind = "worse", text = L["Not better than what you wear: %s"]:format(detail(target.diffs, -1)) }
	end
	return nil
end

-- The tooltip hook. Runs for every item tooltip the game shows.
local function link(data)
	local guid = str(data.guid)
	if guid then
		return str(C.Call("C_Item.GetItemLinkByGUID", guid))
	end
	return str(data.hyperlink)
end

function U.OnTooltip(tooltip, data)
	if not T.db or T.db.upgradeHints == false or C.InCombat() then
		return
	end
	if type(tooltip) ~= "table" or type(tooltip.AddLine) ~= "function" then
		return
	end
	if type(tooltip.IsForbidden) == "function" then
		local ok, forbidden = pcall(tooltip.IsForbidden, tooltip)
		if not ok or C.Plain(forbidden, true) ~= false then
			return
		end
	end
	data = C.Plain(data, nil)
	if type(data) ~= "table" then
		return
	end
	local itemLink = link(data)
	if not itemLink then
		return
	end
	local say = U.Judge(itemLink, data)
	if not say then
		return
	end
	if say.kind == "unusable" then
		tooltip:AddLine(L["You can't use this: %s"]:format(say.what), 1, 0.38, 0.32, true)
	elseif say.kind == "upgrade" then
		tooltip:AddLine(say.text, 0.38, 0.92, 0.42, true)
		if say.level then
			tooltip:AddLine(L["You can wear it from level %d."]:format(say.level), 0.75, 0.75, 0.75, true)
		end
	else
		tooltip:AddLine(say.text, 0.7, 0.7, 0.7, true)
	end
end

local hooked = false
local Module = T:NewModule("upgrades")

for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "TH_SKILLS_CHANGED", "TH_BUILD_CHANGED", "PLAYER_LEVEL_UP" }) do
	T:On(event, U.Forget)
end

function Module:OnInit()
	local itemType = C.Resolve("Enum.TooltipDataType.Item")
	if hooked or itemType == nil or not C.Has("TooltipDataProcessor.AddTooltipPostCall") then
		return
	end
	hooked = true
	TooltipDataProcessor.AddTooltipPostCall(itemType, function(tooltip, data)
		T.SafeCall("Upgrades.OnTooltip", U.OnTooltip, tooltip, data)
	end)
end
