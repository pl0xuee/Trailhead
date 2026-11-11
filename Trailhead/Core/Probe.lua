local _, T = ...
local L = T.L
local C = T.Compat

-- Probe ("game check"): records what this client's APIs actually return, into the saved
-- variables, so features can be built on facts. Run with /th check, then /reload so the
-- file is written to disk. Nothing here runs in combat, and every section is isolated:
-- one failing API leaves the rest of the report intact.

local Probe = {}
T.Probe = Probe

-- Raised whenever the check learns to ask something new; Home then offers to run it again.
Probe.VERSION = 8

local MAX_ZONES, MAX_LIST = 200, 60

-- APIs later features rely on; the report lists which exist.
local APIS = {
	"C_Map.GetBestMapForUnit", "C_Map.GetMapInfo", "C_Map.GetMapLevels", "C_Map.GetMapChildrenInfo",
	"C_Map.GetPlayerMapPosition", "C_Map.CanSetUserWaypointOnMap", "C_Map.SetUserWaypoint",
	"C_Map.ClearUserWaypoint", "C_Map.HasUserWaypoint", "C_SuperTrack.SetSuperTrackedUserWaypoint",
	"C_SuperTrack.IsSuperTrackingUserWaypoint", "UiMapPoint.CreateFromCoordinates",
	"C_TaxiMap.GetTaxiNodesForMap", "C_TaxiMap.GetAllTaxiNodes",
	"C_EncounterJournal.GetDungeonEntrancesForMap",
	"C_Minimap.GetNumTrackingTypes", "C_Minimap.GetTrackingInfo", "C_Minimap.SetTracking",
	"C_GossipInfo.GetPoiForUiMapID", "C_GossipInfo.GetPoiInfo",
	"C_SpellBook.GetNumSpellBookSkillLines", "C_SpellBook.GetSpellBookSkillLineInfo",
	"C_SpellBook.GetSpellBookItemInfo", "C_SpellBook.GetSpellBookItemLevelLearned",
	"C_SpellBook.IsSpellBookItemLowRank", "C_SpellBook.GetCurrentLevelSpells",
	"ActionButtonUtil.GetActionBarStatusForSpell", "C_ActionBar.FindSpellActionButtons",
	"C_ActionBar.IsOnBarOrSpecialBar",
	"GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "C_Trainer.GetTrainerType",
	"C_ClassTalents.HasUnspentTalentPoints", "C_SpecializationInfo.GetSpecialization",
	"C_Traits.GetConfigIDByTreeID", "C_MajorFactions.GetMajorFactionData",
	"C_LFGList.GetAvailableActivities", "C_LFGList.GetActivityInfoTable",
	"C_GameRules.GetForeverExperiencePreset", "C_Container.GetContainerNumFreeSlots",
	"C_Container.GetContainerNumSlots", "GetInventoryItemDurability", "GetBindLocation",
	"GetXPExhaustion", "GetMaxPlayerLevel", "GetMaxLevelForPlayerExpansion", "IsResting",
	"GetCategoryList", "GetAchievementInfo", "C_Item.GetItemInfo", "C_QuestLog.GetNumQuestLogEntries",
	"C_AddOns.IsAddOnLoaded", "MenuUtil.CreateContextMenu", "issecretvalue", "securecallfunction",
	"C_Timer.After", "C_UI.Reload", "ReloadUI", "TomTom.AddWaypoint",
	"C_Map.GetMapRectOnMap", "C_Map.GetMapWorldSize", "C_Map.GetMapLinksForMap", "C_Map.GetWorldPosFromMapPos",
	"C_AreaPoiInfo.GetAreaPOIForMap", "GetTaxiMapID", "NumTaxiNodes", "TaxiNodeGetType", "IsInInstance", "GetInstanceInfo",
	"C_Timer.NewTicker", "C_SkillInfo.GetNumSkillLines", "C_SkillInfo.GetSkillLineInfo",
	"C_Traits.GetTreeInfo", "C_Traits.GetConditionInfo", "C_Traits.GetNodeCost", "C_Spell.GetSpellDescription",
	"C_Spell.RequestLoadSpellData", "C_Spell.IsSpellDataCached", "C_Item.GetItemNameByID",
	"C_TooltipInfo.GetTraitEntry", "C_Traits.GetTreeCurrencyInfo",
	"C_SpecializationInfo.GetActiveSpecGroup", "C_SpecializationInfo.GetCombatConfigIDForSpecGroup",
	"C_ClassTalents.GetActiveConfigID", "C_Traits.GetConfigInfo", "C_Traits.GetTreeNodes", "C_Traits.GetNodeInfo",
	"C_Traits.GetEntryInfo", "C_Traits.GetDefinitionInfo", "C_Traits.GetGroupDisplayInfoByTreeID",
	"C_Traits.PurchaseRank", "C_Traits.CommitConfig", "C_ClassTalents.ImportLoadout", "C_LFGList.GetLfgCategoryInfo",
	"GetRestState", "C_Container.GetItemCooldown", "C_Container.GetContainerItemInfo", "C_Item.GetItemCount",
	"C_Item.GetItemInfoInstant", "C_TooltipInfo.GetItemByID", "C_TooltipInfo.GetMerchantItem", "C_TooltipInfo.GetInventoryItem",
	"C_MerchantFrame.GetItemInfo", "GetMerchantNumItems", "GetMerchantItemID", "GetInventoryItemID",
	"C_MountJournal.GetNumMounts", "C_MountJournal.GetMountIDs", "GetItemCooldown", "C_Spell.GetSpellCooldown",
	"C_MountJournal.GetMountInfoByID", "C_MountJournal.GetMountInfoExtraByID", "C_TooltipInfo.GetSpellByID",
	"CanMerchantRepair", "GetRepairAllCost", "C_GossipInfo.GetOptions", "C_GossipInfo.GetText",
	"C_Container.GetContainerItemDurability", "C_PlayerInfo.CanPlayerUseMountEquipment", "IsMounted",
}

-- Copies a value into something that can be saved: plain values and shallow tables only.
local function clean(value, depth)
	depth = depth or 0
	if C.IsSecret(value) then
		return "<secret>"
	end
	local kind = type(value)
	if kind == "number" or kind == "string" or kind == "boolean" then
		return value
	elseif kind == "nil" then
		return nil
	elseif kind ~= "table" then
		return "<" .. kind .. ">"
	elseif depth >= 4 then
		return "<table>"
	end
	local out, count = {}, 0
	for key, item in pairs(value) do
		local keyKind = type(key)
		if (keyKind == "string" or keyKind == "number") and type(item) ~= "function" then
			out[key] = clean(item, depth + 1)
			count = count + 1
			if count >= 80 then
				out["<more>"] = true
				break
			end
		end
	end
	return out
end

-- All return values of a call, cleaned, as a list (nil if the API is missing or failed).
local function pack(...)
	local out = { n = select("#", ...) }
	for i = 1, out.n do
		out[i] = clean((select(i, ...)))
	end
	return out
end

local function levels(mapID)
	local lo, hi, petLo, petHi = C.Call("C_Map.GetMapLevels", mapID)
	return clean(lo), clean(hi), clean(petLo), clean(petHi)
end

local function playerMap()
	local mapID = C.Call("C_Map.GetBestMapForUnit", "player")
	if type(mapID) ~= "number" or C.IsSecret(mapID) then
		return nil
	end
	local x, y
	local position = C.Call("C_Map.GetPlayerMapPosition", mapID, "player")
	if type(position) == "table" and type(position.GetXY) == "function" then
		local ok, px, py = pcall(position.GetXY, position)
		if ok and not C.IsSecret(px) and not C.IsSecret(py) then
			x, y = px, py
		end
	end
	return mapID, x, y
end

local sections = {}

sections.build = function()
	local version, build, date, toc = GetBuildInfo()
	return {
		version = version, build = build, date = date, toc = toc,
		locale = GetLocale and GetLocale(),
		project = WOW_PROJECT_ID,
		preset = clean(C.Call("C_GameRules.GetForeverExperiencePreset")),
		addon = T.version,
		missingEvents = clean(T.missingEvents),
	}
end

sections.player = function()
	local _, classFile = UnitClass("player")
	local _, raceFile = UnitRace("player")
	return {
		class = clean(classFile),
		race = clean(raceFile),
		faction = clean((UnitFactionGroup("player"))),
		level = clean(UnitLevel("player")),
		nameIsSecret = C.IsSecret(UnitName("player")),
		maxLevel = clean(C.Call("GetMaxPlayerLevel")),
		maxLevelExpansion = clean(C.Call("GetMaxLevelForPlayerExpansion")),
	}
end

sections.apis = function()
	local out = {}
	for _, path in ipairs(APIS) do
		out[path] = C.Has(path)
	end
	return out
end

sections.character = function()
	local free, total = 0, 0
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		free = free + (C.Plain(C.Call("C_Container.GetContainerNumFreeSlots", bag), 0) or 0)
		total = total + (C.Plain(C.Call("C_Container.GetContainerNumSlots", bag), 0) or 0)
	end
	return {
		xp = clean(UnitXP("player")),
		xpMax = clean(UnitXPMax("player")),
		rested = clean(C.Call("GetXPExhaustion")),
		resting = clean(C.Call("IsResting")),
		bind = clean(C.Call("GetBindLocation")),
		money = clean(GetMoney()),
		bagsFree = free,
		bagsTotal = total,
		zone = clean(GetRealZoneText and GetRealZoneText()),
		subzone = clean(GetSubZoneText and GetSubZoneText()),
	}
end

-- Where the player is, the chain of parent maps, and whether zone level ranges are real.
sections.map = function()
	local mapID, x, y = playerMap()
	local out = { id = mapID, x = x, y = y, chain = {} }
	if not mapID then
		return out
	end
	out.canWaypoint = clean(C.Call("C_Map.CanSetUserWaypointOnMap", mapID))
	local id, top = mapID, mapID
	for _ = 1, 10 do
		local info = C.Call("C_Map.GetMapInfo", id)
		if type(info) ~= "table" then
			break
		end
		local lo, hi = levels(id)
		out.chain[#out.chain + 1] = {
			id = id, name = clean(info.name), mapType = clean(info.mapType),
			parent = clean(info.parentMapID), lo = lo, hi = hi,
		}
		top = id
		local parent = info.parentMapID
		if type(parent) ~= "number" or parent == 0 then
			break
		end
		id = parent
	end
	out.top = top
	return out
end

-- Every zone under the top-level map, with the level range the game reports for it.
sections.zones = function(report)
	local top = report.map and report.map.top
	local zoneType = C.Resolve("Enum.UIMapType.Zone")
	local out = { count = 0, withLevels = 0, list = {} }
	if not top or not zoneType then
		return out
	end
	local children = C.Call("C_Map.GetMapChildrenInfo", top, zoneType, true)
	if type(children) ~= "table" then
		return out
	end
	for _, info in ipairs(children) do
		out.count = out.count + 1
		local lo, hi = levels(info.mapID)
		if type(lo) == "number" and lo > 0 then
			out.withLevels = out.withLevels + 1
		end
		if #out.list < MAX_ZONES then
			out.list[#out.list + 1] = {
				id = clean(info.mapID), name = clean(info.name), parent = clean(info.parentMapID),
				lo = lo, hi = hi,
			}
		end
	end
	return out
end

local function taxiFor(mapID)
	local nodes = C.Call("C_TaxiMap.GetTaxiNodesForMap", mapID)
	if type(nodes) ~= "table" then
		return nil
	end
	local out = { count = #nodes, list = {} }
	for i = 1, math.min(#nodes, MAX_LIST) do
		out.list[i] = clean(nodes[i])
	end
	return out
end

sections.taxi = function(report)
	local out = {}
	for _, entry in ipairs(report.map and report.map.chain or {}) do
		out[entry.id] = taxiFor(entry.id) or "nil"
	end
	return out
end

sections.dungeons = function(report)
	local out = { perMap = {}, zonesChecked = 0, zonesWithEntrances = 0, list = {} }
	local function check(mapID, name)
		local entrances = C.Call("C_EncounterJournal.GetDungeonEntrancesForMap", mapID)
		if type(entrances) ~= "table" then
			return nil
		end
		for _, entrance in ipairs(entrances) do
			if #out.list < MAX_LIST then
				local item = clean(entrance)
				if type(item) == "table" then
					item.onMap, item.onMapName = mapID, name
				end
				out.list[#out.list + 1] = item
			end
		end
		return #entrances
	end
	for _, entry in ipairs(report.map and report.map.chain or {}) do
		out.perMap[entry.id] = check(entry.id, entry.name) or "nil"
	end
	for _, zone in ipairs(report.zones and report.zones.list or {}) do
		local found = check(zone.id, zone.name)
		out.zonesChecked = out.zonesChecked + 1
		if found and found > 0 then
			out.zonesWithEntrances = out.zonesWithEntrances + 1
		end
	end
	return out
end

sections.tracking = function()
	local count = C.Call("C_Minimap.GetNumTrackingTypes")
	local out = { count = clean(count), list = {} }
	if type(count) ~= "number" then
		return out
	end
	for i = 1, math.min(count, MAX_LIST) do
		out.list[i] = pack(C.Call("C_Minimap.GetTrackingInfo", i))
	end
	return out
end

sections.spellbook = function()
	local bank = C.Resolve("Enum.SpellBookSpellBank.Player")
	local types = C.Resolve("Enum.SpellBookItemType") or {}
	local level = C.Plain(UnitLevel("player"), 0)
	local lines = C.Call("C_SpellBook.GetNumSpellBookSkillLines")
	local out = { lines = {}, future = {}, missing = {}, status = {}, lineCount = clean(lines) }
	if type(lines) ~= "number" or bank == nil then
		return out
	end
	for line = 1, lines do
		local info = C.Call("C_SpellBook.GetSpellBookSkillLineInfo", line)
		if type(info) == "table" then
			local entry = clean(info)
			entry.byType = {}
			local first = C.Plain(info.itemIndexOffset, 0)
			local total = C.Plain(info.numSpellBookItems, 0)
			for slot = first + 1, first + total do
				local item = C.Call("C_SpellBook.GetSpellBookItemInfo", slot, bank)
				if type(item) == "table" then
					local kind = C.Plain(item.itemType, -1)
					entry.byType[kind] = (entry.byType[kind] or 0) + 1
					if kind == types.FutureSpell and #out.future < MAX_LIST then
						out.future[#out.future + 1] = {
							name = clean(item.name), spellID = clean(item.spellID), sub = clean(item.subName),
							level = clean(C.Call("C_SpellBook.GetSpellBookItemLevelLearned", slot, bank)),
							lowRank = clean(C.Call("C_SpellBook.IsSpellBookItemLowRank", slot, bank)),
						}
					elseif kind == types.Spell and item.isPassive == false and item.isOffSpec ~= true then
						local status = C.Call("ActionButtonUtil.GetActionBarStatusForSpell", item.actionID, true, false)
						if status ~= nil and not C.IsSecret(status) then
							out.status[status] = (out.status[status] or 0) + 1
							if status ~= 1 and #out.missing < MAX_LIST then
								out.missing[#out.missing + 1] = {
									name = clean(item.name), spellID = clean(item.spellID), status = status,
									lowRank = clean(C.Call("C_SpellBook.IsSpellBookItemLowRank", slot, bank)),
								}
							end
						end
					end
				end
			end
			out.lines[line] = entry
		end
	end
	out.thisLevel = pack(C.Call("C_SpellBook.GetCurrentLevelSpells", level))
	return out
end

-- A value as short text for a packed row ("?" for anything unreadable).
local function cell(value)
	value = clean(value)
	if type(value) == "table" then
		local parts = {}
		for _, item in ipairs(value) do
			parts[#parts + 1] = tostring(item)
		end
		return table.concat(parts, ",")
	elseif value == nil then
		return ""
	end
	return (tostring(value):gsub("|", "/"))
end

local function row(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = cell((select(i, ...)))
	end
	return table.concat(parts, "|")
end

-- The talent tree as the game's own talent window reads it: one row per talent.
-- Row: node|x|y|maxRanks|ranksPurchased|groups|spell|name|available|visible|type|edgesTo|conditions|cost
-- Gate row: topLeftNode|condition|spentRequired|currency|met|type|playerLevel
-- Condition row: condition|spentRequired|currency|met|gate|type|playerLevel|tooltipFormat
-- texts[node] = { first, full }: the talent's tooltip text at rank 1 and at its last rank,
-- read the way the game's own talent button reads it. descriptions[spell] is the spell's
-- plain text. The game fetches both on request, so whatever it did not have ready is read
-- again a moment after the check, and once more as the interface reloads (see Probe:Run).
local pendingTexts

local function tipText(entryID, rank)
	local data = C.Call("C_TooltipInfo.GetTraitEntry", entryID, rank)
	if type(data) ~= "table" or type(data.lines) ~= "table" then
		return nil
	end
	local parts = {}
	for _, line in ipairs(data.lines) do
		local text = type(line) == "table" and C.Plain(line.leftText, nil) or nil
		if type(text) == "string" and text ~= "" then
			parts[#parts + 1] = text
		end
	end
	return #parts > 0 and table.concat(parts, " / ") or nil
end

local function describe(out)
	local missing = 0
	for spellID in pairs(out.spells) do
		if out.descriptions[spellID] == nil then
			local text = C.Plain(C.Call("C_Spell.GetSpellDescription", spellID), nil)
			if type(text) == "string" and text ~= "" then
				out.descriptions[spellID] = text
			else
				missing = missing + 1
			end
		end
	end
	for nodeID, entry in pairs(out.entries) do
		local text = out.texts[nodeID] or {}
		text.first = text.first or tipText(entry.e, 1)
		if entry.m > 1 then
			text.full = text.full or tipText(entry.e, entry.m)
		end
		out.texts[nodeID] = text
		if not text.first then
			missing = missing + 1
		end
	end
	out.descriptionsMissing = missing
	return missing
end

sections.talents = function()
	local out = {
		unspent = pack(C.Call("C_ClassTalents.HasUnspentTalentPoints")),
		spec = pack(C.Call("C_SpecializationInfo.GetSpecialization")),
		legacyConsts = clean(C.Resolve("Constants.LegacyConsts")),
		specGroup = pack(C.Call("C_SpecializationInfo.GetActiveSpecGroup")),
		activeConfig = pack(C.Call("C_ClassTalents.GetActiveConfigID")),
		can = {
			purchase = C.Has("C_Traits.PurchaseRank"), commit = C.Has("C_Traits.CommitConfig"),
			import = C.Has("C_ClassTalents.ImportLoadout"), canPurchase = C.Has("C_Traits.CanPurchaseRank"),
		},
		nodes = {},
	}
	local group = C.Call("C_SpecializationInfo.GetActiveSpecGroup")
	local configID = C.Call("C_SpecializationInfo.GetCombatConfigIDForSpecGroup", type(group) == "number" and group or 1)
	if type(configID) ~= "number" then
		configID = C.Call("C_ClassTalents.GetActiveConfigID")
	end
	out.config = clean(configID)
	if type(configID) ~= "number" then
		return out
	end
	local config = C.Call("C_Traits.GetConfigInfo", configID)
	out.configInfo = clean(config)
	local treeID = type(config) == "table" and type(config.treeIDs) == "table" and config.treeIDs[1] or nil
	out.tree = clean(treeID)
	if type(treeID) ~= "number" then
		return out
	end
	out.groups = clean(C.Call("C_Traits.GetGroupDisplayInfoByTreeID", treeID))
	out.currencies = clean(C.Call("C_Traits.GetTreeCurrencyInfo", configID, treeID, false))
	local tree = C.Call("C_Traits.GetTreeInfo", configID, treeID)
	out.treeInfo = clean(tree)
	out.gates = {}
	for _, gate in ipairs(type(tree) == "table" and type(tree.gates) == "table" and tree.gates or {}) do
		local cond = type(gate) == "table" and C.Call("C_Traits.GetConditionInfo", configID, gate.conditionID) or nil
		cond = type(cond) == "table" and cond or {}
		out.gates[#out.gates + 1] = row(gate.topLeftNodeID, gate.conditionID, cond.spentAmountRequired, cond.traitCurrencyID,
			cond.isMet, cond.type, cond.playerLevel)
	end
	out.spells, out.descriptions, out.entries, out.texts, out.conditions = {}, {}, {}, {}, {}
	local conditionSeen = {}
	local nodeIDs = C.Call("C_Traits.GetTreeNodes", treeID)
	out.nodeCount = type(nodeIDs) == "table" and #nodeIDs or "nil"
	for index, nodeID in ipairs(type(nodeIDs) == "table" and nodeIDs or {}) do
		if index > 140 then
			break
		end
		local node = C.Call("C_Traits.GetNodeInfo", configID, nodeID)
		if type(node) == "table" then
			local entryID = type(node.entryIDs) == "table" and node.entryIDs[1] or nil
			local entry = entryID and C.Call("C_Traits.GetEntryInfo", configID, entryID)
			local definition = type(entry) == "table" and entry.definitionID and C.Call("C_Traits.GetDefinitionInfo", entry.definitionID)
			local spellID = type(definition) == "table" and definition.spellID or nil
			local name = type(definition) == "table" and definition.overrideName or nil
			if not name and type(spellID) == "number" then
				name = C.Call("C_Spell.GetSpellName", spellID)
			end
			local edges = {}
			for _, edge in ipairs(type(node.visibleEdges) == "table" and node.visibleEdges or {}) do
				edges[#edges + 1] = type(edge) == "table" and edge.targetNode or nil
			end
			if index == 1 then
				out.firstNode, out.firstEntry, out.firstDefinition = clean(node), clean(entry), clean(definition)
			end
			local costs = {}
			local cost = C.Call("C_Traits.GetNodeCost", configID, nodeID)
			for _, item in ipairs(type(cost) == "table" and cost or {}) do
				costs[#costs + 1] = type(item) == "table" and item.amount or nil
			end
			if index == 2 then
				out.secondNode = clean(node)
			end
			if type(entryID) == "number" and type(node.maxRanks) == "number" then
				out.entries[nodeID] = { e = entryID, m = node.maxRanks }
			end
			for _, condID in ipairs(type(node.conditionIDs) == "table" and node.conditionIDs or {}) do
				if type(condID) == "number" and not conditionSeen[condID] then
					conditionSeen[condID] = true
					local cond = C.Call("C_Traits.GetConditionInfo", configID, condID)
					cond = type(cond) == "table" and cond or {}
					out.conditions[#out.conditions + 1] = row(condID, cond.spentAmountRequired, cond.traitCurrencyID, cond.isMet,
						cond.isGate, cond.type, cond.playerLevel, cond.tooltipFormat)
				end
			end
			if type(spellID) == "number" and not C.IsSecret(spellID) then
				out.spells[spellID] = true
				C.Call("C_Spell.RequestLoadSpellData", spellID)
			end
			out.nodes[#out.nodes + 1] = row(nodeID, node.posX, node.posY, node.maxRanks, node.ranksPurchased, node.groupIDs,
				spellID, name, node.isAvailable, node.isVisible, node.type, edges, node.conditionIDs, costs)
		end
	end
	pendingTexts = describe(out) > 0 and out or nil
	return out
end

-- Every skill the character sheet lists (weapon skills, professions, languages).
-- Row: name|id|rank|maxRank|modifier|header|collapsed|category|parent
-- descriptions[id] is the game's own text for a skill; words holds the lines its skills
-- window prints about weapon skill.
-- A tooltip's lines as one string ("line / line"), cut to `most` characters.
local function tipLines(path, most, ...)
	local data = C.Call(path, ...)
	if type(data) ~= "table" or type(data.lines) ~= "table" then
		return nil
	end
	local parts = {}
	for _, line in ipairs(data.lines) do
		local text = type(line) == "table" and C.Plain(line.leftText, nil) or nil
		if type(text) == "string" and text ~= "" then
			parts[#parts + 1] = text
		end
	end
	local text = table.concat(parts, " / ")
	return text ~= "" and text:sub(1, most or 200) or nil
end

-- What kind of thing an item is, the way the game files it: classID, subClassID, type, subType, equipLoc.
local function itemKind(itemID)
	if type(itemID) ~= "number" then
		return nil
	end
	local _, kind, subKind, equipLoc, _, classID, subClassID = C.Call("C_Item.GetItemInfoInstant", itemID)
	return classID, subClassID, kind, subKind, equipLoc
end

-- Rest, the hearthstone and the inn: for the Guide's "Hearthstone, inns and rested XP" topic.
local HEARTHSTONE = 6948
sections.rest = function()
	local out = {
		state = pack(C.Call("GetRestState")),
		rested = clean(C.Call("GetXPExhaustion")),
		resting = clean(C.Call("IsResting")),
		bind = clean(C.Call("GetBindLocation")),
		words = {},
		stone = {
			count = clean(C.Call("C_Item.GetItemCount", HEARTHSTONE)),
			cooldown = pack(C.Call("C_Container.GetItemCooldown", HEARTHSTONE)),
			text = tipLines("C_TooltipInfo.GetItemByID", 400, HEARTHSTONE),
		},
		mounts = clean(C.Call("C_MountJournal.GetNumMounts")),
	}
	for _, name in ipairs({ "EXHAUST_TOOLTIP1", "EXHAUST_TOOLTIP2", "EXHAUST_TOOLTIP3", "EXHAUST_TOOLTIP4", "XP_TEXT",
		"TUTORIAL_TITLE26", "TUTORIAL26", "NEWBIE_TOOLTIP_XPBAR", "ERR_EXHAUSTION_RESTED", "ERR_EXHAUSTION_NORMAL",
		"ERR_EXHAUSTION_WELLRESTED" }) do
		out.words[name] = clean(_G[name])
	end
	return out
end

-- What the character carries and wears, as the game files each item: for the Guide's Gear
-- and Supplies topics. Bag row: bag|slot|item|count|name|classID|subClassID|type|subType|equipLoc
-- Worn row: slot|item|name|classID|subClassID|type|subType|equipLoc|durability|durabilityMax
local MAX_BAG_ROWS = 120
sections.bags = function()
	local out = { items = {}, worn = {}, count = 0 }
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		local slots = C.Plain(C.Call("C_Container.GetContainerNumSlots", bag), 0) or 0
		for slot = 1, type(slots) == "number" and slots or 0 do
			local info = C.Call("C_Container.GetContainerItemInfo", bag, slot)
			local itemID = type(info) == "table" and C.Plain(info.itemID, nil) or nil
			if type(itemID) == "number" then
				out.count = out.count + 1
				if #out.items < MAX_BAG_ROWS then
					out.items[#out.items + 1] = row(bag, slot, itemID, info.stackCount, info.itemName or C.Call("C_Item.GetItemNameByID", itemID),
						itemKind(itemID))
				end
			end
		end
	end
	for slot = 0, 19 do
		local itemID = C.Plain(C.Call("GetInventoryItemID", "player", slot), nil)
		if type(itemID) == "number" then
			local classID, subClassID, kind, subKind, equipLoc = itemKind(itemID)
			local now, most = C.Call("GetInventoryItemDurability", slot)
			out.worn[#out.worn + 1] = row(slot, itemID, C.Call("C_Item.GetItemNameByID", itemID), classID, subClassID, kind, subKind, equipLoc, now, most)
		end
	end
	return out
end

-- The game's own words for new players: its tutorial texts, the help tooltips of its
-- interface, and what it says about durability, repairs, death, mounts and reagents. The
-- Guide's topics are written from these, never from memory of the old game.
local WORD_KEYS = { "^TUTORIAL", "^NEWBIE_TOOLTIP", "DURABILITY", "^REPAIR", "RIDING", "^MOUNT", "XP_LOSS", "^SPELL_REAGENTS",
	"RESURRECT", "^DEATH", "SPIRIT_HEALER", "^ERR_MOUNT", "GHOST", "^ITEM_REQ", "^ITEM_MIN", "^BIND_" }
local MAX_WORDS, MAX_WORD = 900, 600
sections.words = function()
	local out = { list = {}, count = 0, cut = false }
	for key, value in pairs(_G) do
		if type(key) == "string" and type(value) == "string" and key == key:upper() then
			for _, pattern in ipairs(WORD_KEYS) do
				if key:find(pattern) then
					if out.count < MAX_WORDS then
						out.count = out.count + 1
						out.list[key] = value:sub(1, MAX_WORD)
					else
						out.cut = true
					end
					break
				end
			end
		end
	end
	return out
end

-- The mount journal: every mount the game lists, where it says each comes from and
-- whether this character can use it. For the Guide's Mount topic.
-- Row: mount|name|spell|usable|sourceType|factionSpecific|faction|hidden|collected|mountType|source|description
local MAX_MOUNT_ROWS = 170
sections.mounts = function()
	local out = { count = clean(C.Call("C_MountJournal.GetNumMounts")), rows = {}, mounted = clean(C.Call("IsMounted")) }
	local ids = C.Call("C_MountJournal.GetMountIDs")
	if type(ids) ~= "table" then
		return out
	end
	out.ids = #ids
	local function short(text, most)
		text = C.Plain(text, nil)
		return type(text) == "string" and text:gsub("%s+", " "):sub(1, most) or nil
	end
	for _, id in ipairs(ids) do
		if #out.rows >= MAX_MOUNT_ROWS then
			break
		end
		local name, spellID, _, _, usable, sourceType, _, factionSpecific, faction, hidden, collected = C.Call("C_MountJournal.GetMountInfoByID", id)
		local _, description, source, _, mountType = C.Call("C_MountJournal.GetMountInfoExtraByID", id)
		out.rows[#out.rows + 1] = row(id, name, spellID, usable, sourceType, factionSpecific, faction, hidden, collected, mountType,
			short(source, 220), short(description, 90))
	end
	return out
end

-- The top of each known ability's tooltip (cost, range, cast time, reagents, what it
-- needs), so Supplies can say which abilities use something up. Row: name|spell|text
local MAX_SPELL_TIPS = 90
sections.spelltips = function()
	local out = { rows = {} }
	local bank = C.Resolve("Enum.SpellBookSpellBank.Player")
	local types = C.Resolve("Enum.SpellBookItemType") or {}
	local lines = C.Call("C_SpellBook.GetNumSpellBookSkillLines")
	if type(lines) ~= "number" or bank == nil or not C.Has("C_TooltipInfo.GetSpellByID") then
		return out
	end
	for line = 1, lines do
		local info = C.Call("C_SpellBook.GetSpellBookSkillLineInfo", line)
		if type(info) == "table" then
			local first = C.Plain(info.itemIndexOffset, 0)
			local total = C.Plain(info.numSpellBookItems, 0)
			for slot = first + 1, first + total do
				local item = C.Call("C_SpellBook.GetSpellBookItemInfo", slot, bank)
				local spellID = type(item) == "table" and C.Plain(item.spellID, nil) or nil
				if type(spellID) == "number" and C.Plain(item.itemType, -1) == types.Spell and #out.rows < MAX_SPELL_TIPS then
					out.rows[#out.rows + 1] = row(item.name, spellID, tipLines("C_TooltipInfo.GetSpellByID", 280, spellID))
				end
			end
		end
	end
	return out
end

-- The last few vendors and trainers the player opened, written down as they were opened
-- (see the bottom of this file): for the Guide's Mount, Supplies and Gear topics.
sections.visits = function()
	return clean(T.db and T.db.visits)
end

sections.skills = function()
	local out = { count = pack(C.Call("C_SkillInfo.GetNumSkillLines")), rows = {}, descriptions = {}, words = {} }
	for _, name in ipairs({ "WEAPON_SKILL_DETAIL_SAME_LEVEL_HEADER", "WEAPON_SKILL_DETAIL_SAME_LEVEL", "WEAPON_SKILL_DETAIL_SAME_LEVEL_RANGED",
		"WEAPON_SKILL_DETAIL_BOSS_HEADER", "WEAPON_SKILL_DETAIL_BOSS", "WEAPON_SKILL_DETAIL_BOSS_RANGED" }) do
		out.words[name] = clean(_G[name])
	end
	local total = C.Call("C_SkillInfo.GetNumSkillLines")
	for index = 1, math.min(type(total) == "number" and total or 0, 80) do
		local info = C.Call("C_SkillInfo.GetSkillLineInfo", index)
		if type(info) == "table" then
			if index == 1 then
				out.first = clean(info)
			end
			out.rows[#out.rows + 1] = row(info.name, info.skillID, info.rank, info.maxRank, info.modifier, info.isHeader,
				info.isCollapsed, info.skillLineCategoryID, info.parentSkillLineID)
			local text = C.Plain(info.description, nil)
			if type(text) == "string" and text ~= "" and type(C.Plain(info.skillID, nil)) == "number" then
				out.descriptions[info.skillID] = text
			end
		end
	end
	-- What is in each hand, to match against the weapon skills.
	out.hands = {}
	for _, slot in ipairs({ 16, 17, 18 }) do
		local itemID = C.Call("GetInventoryItemID", "player", slot)
		if type(itemID) == "number" then
			local _, _, _, _, _, classID, subClassID = C.Call("C_Item.GetItemInfoInstant", itemID)
			out.hands[#out.hands + 1] = row(slot, itemID, classID, subClassID)
		end
	end
	return out
end

-- What "How to get there" stands on: where zones sit on their continent, map sizes,
-- map links, points of interest, and what Trailhead has learned about travel.
sections.routes = function(report)
	local out = { rects = {}, sizes = {}, links = {}, pois = {}, positions = {} }
	local chain = report.map and report.map.chain or {}
	local continent
	for _, entry in ipairs(chain) do
		if entry.mapType == C.Resolve("Enum.UIMapType.Continent") then
			continent = entry.id
		end
	end
	out.continent = continent
	for _, entry in ipairs(chain) do
		out.sizes[entry.id] = pack(C.Call("C_Map.GetMapWorldSize", entry.id))
		out.links[entry.id] = clean(C.Call("C_Map.GetMapLinksForMap", entry.id))
		local position = C.Call("C_Map.GetPlayerMapPosition", entry.id, "player")
		if type(position) == "table" and type(position.GetXY) == "function" then
			out.positions[entry.id] = pack(select(2, pcall(position.GetXY, position)))
		end
		local ids = C.Call("C_AreaPoiInfo.GetAreaPOIForMap", entry.id)
		local list = { count = type(ids) == "table" and #ids or "nil" }
		for index, id in ipairs(type(ids) == "table" and ids or {}) do
			if index > 40 then
				break
			end
			local info = C.Call("C_AreaPoiInfo.GetAreaPOIInfo", entry.id, id)
			if type(info) == "table" then
				local position = info.position
				list[#list + 1] = row(id, info.name, info.atlasName, type(position) == "table" and position.x, type(position) == "table" and position.y)
			end
		end
		out.pois[entry.id] = list
	end
	if continent then
		for index, zone in ipairs(report.zones and report.zones.list or {}) do
			if zone.parent == continent and index <= MAX_ZONES then
				out.rects[#out.rects + 1] = row(zone.id, zone.name, C.Call("C_Map.GetMapRectOnMap", zone.id, continent))
			end
		end
	end
	out.instance = pack(C.Call("IsInInstance"))
	out.instanceInfo = pack(C.Call("GetInstanceInfo"))
	out.taxiLog = clean(T.Game and T.Game.taxiLog)
	out.knownFlights = {}
	for mapID, known in pairs(T.cdb and type(T.cdb.taxi) == "table" and T.cdb.taxi or {}) do
		local count = 0
		for _ in pairs(known) do
			count = count + 1
		end
		out.knownFlights[mapID] = count
	end
	out.entrances = clean(T.db and T.db.entrances)
	local route = T.modules and T.modules.route and T.modules.route.plan
	if route then
		out.lastPlan = { title = route.title, note = route.note, steps = {} }
		for index, step in ipairs(route.steps) do
			out.lastPlan.steps[index] = row(step.text, step.detail, step.map, step.x, step.y)
		end
	end
	return out
end

sections.groupFinder = function()
	local ids = C.Call("C_LFGList.GetAvailableActivities")
	local out = { count = type(ids) == "table" and #ids or "nil", list = {} }
	if type(ids) ~= "table" then
		return out
	end
	for i = 1, math.min(#ids, MAX_LIST) do
		local info = C.Call("C_LFGList.GetActivityInfoTable", ids[i])
		if type(info) == "table" then
			out.list[#out.list + 1] = {
				id = clean(ids[i]), name = clean(info.fullName), min = clean(info.minLevel),
				lo = clean(info.minLevelSuggestion), hi = clean(info.maxLevelSuggestion),
				map = clean(info.mapID), category = clean(info.categoryID),
			}
		end
	end
	return out
end

-- What Trailhead has learned by itself so far: places found, and the trainer's list.
sections.learned = function()
	local out = { places = 0, byCategory = {}, bySource = {}, recent = {} }
	local places = T.db and T.db.places
	if type(places) == "table" then
		out.places = #places
		for index, place in ipairs(places) do
			if type(place) == "table" then
				local category, source = tostring(place.c), tostring(place.s)
				out.byCategory[category] = (out.byCategory[category] or 0) + 1
				out.bySource[source] = (out.bySource[source] or 0) + 1
				if index > #places - 12 then
					out.recent[#out.recent + 1] = clean(place)
				end
			end
		end
	end
	local trainer = T.cdb and T.cdb.trainer
	if type(trainer) == "table" and type(trainer.list) == "table" then
		local states = {}
		for _, entry in ipairs(trainer.list) do
			local state = tostring(entry.t)
			states[state] = (states[state] or 0) + 1
		end
		out.trainer = {
			at = trainer.at, level = trainer.level, count = #trainer.list, states = states,
			full = trainer.full,
			first = clean(trainer.list[1]), last = clean(trainer.list[#trainer.list]),
		}
	end
	out.guardLog = clean(T.Places and T.Places.guardLog)
	out.trainerLog = clean(T.Game and T.Game.trainerLog)
	out.dockLog = clean(T.Window and T.Window.dockLog)
	local mapID = playerMap()
	if mapID then
		out.poiNow = pack(C.Call("C_GossipInfo.GetPoiForUiMapID", mapID))
	end
	out.marker = clean(C.Call("C_Map.HasUserWaypoint"))
	return out
end

-- Sections that read another section's result run after it.
local ORDER = {
	"build", "player", "apis", "character", "map", "zones", "taxi", "dungeons", "tracking",
	"spellbook", "talents", "skills", "rest", "bags", "visits", "words", "mounts", "spelltips", "routes", "groupFinder", "learned",
}

-- Runs the check. Returns true when it ran.
function Probe:Run()
	if C.InCombat() then
		T:Print(L["The game check cannot run in combat. Try again after the fight."])
		return false
	end
	local report, failed = {}, 0
	for _, name in ipairs(ORDER) do
		local ok, result = pcall(sections[name], report)
		if ok then
			report[name] = result
		else
			report[name] = { error = tostring(result) }
			failed = failed + 1
		end
	end
	report.compatErrors = clean(C.errors)
	T.db.probe = { at = time(), v = Probe.VERSION, failed = failed, report = report }
	-- Talent texts the game had to fetch: read them again once they have had time to arrive.
	if pendingTexts and C.Has("C_Timer.After") then
		for _, wait in ipairs({ 1, 3, 6 }) do
			C_Timer.After(wait, Probe.FinishTexts)
		end
	end
	T:Print(L["Game check finished. Type /reload so the results are saved."])
	T:Fire("TH_PROBE_DONE")
	return true
end

-- Reads the talent texts that were not ready during the check. Also run as the interface
-- reloads, so a quick "Reload now" does not lose them.
function Probe.FinishTexts()
	local pending = pendingTexts
	if pending and not C.InCombat() then
		local ok, missing = pcall(describe, pending)
		if ok and missing == 0 then
			pendingTexts = nil
		end
	end
end
T:On("PLAYER_LOGOUT", Probe.FinishTexts)

-- True when the check has been run by this version of Trailhead.
function Probe:IsCurrent()
	local probe = T.db and T.db.probe
	return type(probe) == "table" and probe.v == Probe.VERSION
end

-- When the check last ran (a time() value), or nil.
function Probe:LastRun()
	local probe = T.db and T.db.probe
	return type(probe) == "table" and probe.at or nil
end

-- ---------------------------------------------------------------------------
-- Vendors and trainers the player opens are written down (the last few only), so a game
-- check can show what they sell and teach, at what price and from what level. This is how
-- facts such as "what a mount costs" are read from the game instead of remembered.
-- Vendor row: name|price|stack|item|classID|subClassID|type|subType|usable|tooltip
-- Trainer row: name|rank|state|level|cost|group
-- A menu of four or more choices (a guard's list of what the town has, mostly) is written
-- down too, as kind "menu": this is how "does a guard send you to a weapon master or a
-- riding trainer" is answered. Menu row: choice|icon
local MAX_VISITS, MAX_VISIT_ROWS = 16, 40
local MENU_MIN = 4

local function keepVisit(visit)
	if not T.db or #visit.rows == 0 then
		return
	end
	T.db.visits = type(T.db.visits) == "table" and T.db.visits or {}
	local list = T.db.visits
	-- The same vendor or trainer again replaces the earlier record.
	for index = #list, 1, -1 do
		if type(list[index]) == "table" and list[index].npc == visit.npc and list[index].kind == visit.kind and list[index].first == visit.first then
			table.remove(list, index)
		end
	end
	list[#list + 1] = visit
	while #list > MAX_VISITS do
		table.remove(list, 1)
	end
end

local function newVisit(kind)
	return {
		kind = kind, at = time(), npc = clean(UnitName("npc")), level = clean(UnitLevel("player")),
		zone = clean(GetRealZoneText and GetRealZoneText()), subzone = clean(GetSubZoneText and GetSubZoneText()), rows = {},
	}
end

local function readVendor()
	if C.InCombat() then
		return
	end
	local count = C.Plain(C.Call("GetMerchantNumItems"), 0)
	if type(count) ~= "number" or count <= 0 then
		return
	end
	local visit = newVisit("vendor")
	visit.count = count
	visit.repairs = clean(C.Call("CanMerchantRepair"))
	for index = 1, math.min(count, MAX_VISIT_ROWS) do
		local info = C.Call("C_MerchantFrame.GetItemInfo", index)
		if type(info) == "table" then
			local itemID = C.Plain(C.Call("GetMerchantItemID", index), nil)
			local classID, subClassID, kind, subKind = itemKind(itemID)
			visit.rows[#visit.rows + 1] = row(info.name, info.price, info.stackCount, itemID, classID, subClassID, kind, subKind, info.isUsable,
				tipLines("C_TooltipInfo.GetMerchantItem", 220, index))
		end
	end
	keepVisit(visit)
end

local function readTrainer()
	if C.InCombat() then
		return
	end
	local count = C.Plain(C.Call("GetNumTrainerServices"), 0)
	if type(count) ~= "number" or count <= 0 then
		return
	end
	local visit = newVisit("trainer")
	visit.count = count
	visit.type = clean(C.Call("C_Trainer.GetTrainerType"))
	visit.tradeskill = clean(C.Call("IsTradeskillTrainer"))
	for index = 1, math.min(count, MAX_VISIT_ROWS) do
		local name, state, _, level, sub, group = C.Call("GetTrainerServiceInfo", index)
		visit.rows[#visit.rows + 1] = row(name, sub, state, level, C.Call("GetTrainerServiceCost", index), group)
	end
	keepVisit(visit)
end

local function readMenu()
	if C.InCombat() then
		return
	end
	local options = C.Call("C_GossipInfo.GetOptions")
	if type(options) ~= "table" or #options < MENU_MIN then
		return
	end
	local visit = newVisit("menu")
	visit.count = #options
	visit.said = clean(C.Call("C_GossipInfo.GetText"))
	visit.said = type(visit.said) == "string" and visit.said:sub(1, 200) or nil
	for index = 1, math.min(#options, MAX_VISIT_ROWS) do
		local option = options[index]
		if type(option) == "table" then
			visit.rows[#visit.rows + 1] = row(option.name, option.icon)
		end
	end
	-- A guard's second menu (the list of class trainers, say) is kept beside the first.
	visit.first = visit.rows[1]
	keepVisit(visit)
end

-- The lists fill in a moment after the window opens.
local function soon(read)
	return function()
		if C.Has("C_Timer.After") then
			C_Timer.After(0.6, function()
				T.SafeCall("probe.visit", read)
			end)
		end
	end
end
T:On("MERCHANT_SHOW", soon(readVendor))
T:On("TRAINER_SHOW", soon(readTrainer))
-- A menu is complete the moment it shows, and the next click replaces it.
T:On("GOSSIP_SHOW", function()
	T.SafeCall("probe.menu", readMenu)
end)
