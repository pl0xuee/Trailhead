local _, T = ...
local L = T.L
local C = T.Compat
local G = T.Game

-- Hubs: the towns and camps of each zone where several quest givers stand, which side each
-- serves, and where a character of each side should start. The list is Data/Hubs.lua (made by
-- tools/gen_hubs.py from older quest data: quests Forever added are mostly missing).

local H = {}
T.Hubs = H

local HORDE, ALLIANCE = 1, 2 -- the numbers Game.Faction uses
local FLAG_INN, FLAG_FLIGHT, FLAG_START_ALLIANCE, FLAG_START_HORDE = 1, 2, 4, 8
local MAX_SEARCH = 8

local cache = {}

local function has(flags, bit)
	return flags % (bit * 2) >= bit
end

-- A data row turned into a record. `mine` is the player's side (1, 2 or nil).
local function record(mapID, row, mine)
	local flags = row[8]
	local start = (mine == ALLIANCE and has(flags, FLAG_START_ALLIANCE)) or (mine == HORDE and has(flags, FLAG_START_HORDE))
	return {
		map = mapID, name = row[1], x = row[2] / 1000, y = row[3] / 1000, side = row[4],
		lo = row[5], typical = row[6], quests = row[7],
		inn = has(flags, FLAG_INN), flight = has(flags, FLAG_FLIGHT), start = start and true or false,
	}
end

local function usable(row, mine)
	return mine == nil or row[4] == 0 or (row[4] == HORDE and mine == HORDE) or (row[4] == ALLIANCE and mine == ALLIANCE)
end

local function order(a, b)
	if a.start ~= b.start then
		return a.start
	end
	if a.typical ~= b.typical then
		return a.typical < b.typical
	end
	return a.name < b.name
end

-- Forget what was worked out (the data or the player's side changed).
function H.Reset()
	cache = {}
end

-- The hubs of a zone map that the player's side can use: the start hub first, then by level.
function H.ForZone(mapID)
	if type(mapID) ~= "number" or C.InCombat() then
		return {}
	end
	local mine = G.Faction()
	local key = mapID .. ":" .. tostring(mine)
	if cache[key] then
		return cache[key]
	end
	local out = {}
	for _, row in ipairs(T.HubData and T.HubData[mapID] or {}) do
		if usable(row, mine) then
			out[#out + 1] = record(mapID, row, mine)
		end
	end
	table.sort(out, order)
	cache[key] = out
	return out
end

-- The hub a character of the player's side should start the zone at, or nil.
function H.Start(mapID)
	local first = H.ForZone(mapID)[1]
	return first and first.start and first or nil
end

-- True when the zone has quest hubs for either side (so a zone with none for the player's
-- side, but some for the other, is the other side's territory).
function H.Known(mapID)
	return T.HubData ~= nil and T.HubData[mapID] ~= nil
end

-- The name of the town or camp at a spot ("Razor Hill"), whichever side its quests are for.
-- Find it uses this to say which town a built-in place stands in.
local NEAR = 0.045

function H.Near(mapID, x, y)
	local rows = T.HubData and T.HubData[mapID]
	if not rows or type(x) ~= "number" or type(y) ~= "number" then
		return nil
	end
	local best, bestDist
	for _, row in ipairs(rows) do
		local dx, dy = row[2] / 1000 - x, row[3] / 1000 - y
		local dist = dx * dx + dy * dy
		if dist < NEAR * NEAR and (not bestDist or dist < bestDist) then
			best, bestDist = row[1], dist
		end
	end
	return best
end

-- "Levels 6 to 10" or "Level 10": the quests there. The top figure is the usual level, so it says "about".
function H.Levels(hub)
	if hub.typical > hub.lo then
		return L["levels %d to about %d"]:format(hub.lo, hub.typical)
	end
	return L["level %d"]:format(hub.typical)
end

-- Searches hub names (and their zone's name) for a list of lower-case words. Results have the
-- shape of the other Places.Search results, so the search page can show them as they are.
function H.Search(words)
	local out = {}
	if type(words) ~= "table" or #words == 0 or C.InCombat() then
		return out
	end
	local mapID = G.PlayerMap()
	for map, rows in pairs(T.HubData or {}) do
		local zone = G.MapName(map) or ""
		for _, hub in ipairs(H.ForZone(map)) do
			local text = (hub.name .. " " .. zone):lower()
			local all = true
			for _, word in ipairs(words) do
				if not text:find(word, 1, true) then
					all = false
					break
				end
			end
			if all then
				out[#out + 1] = {
					kind = "place", icon = "pin", category = "other", title = hub.name,
					where = L["Quest hub in %s"]:format(zone),
					note = hub.start and L["Where to start. Quests for %s"]:format(H.Levels(hub))
						or L["Quests for %s"]:format(H.Levels(hub)),
					here = map == mapID, known = true, shipped = true, hub = true, rank = 2,
					map = map, x = hub.x, y = hub.y, start = hub.start, level = hub.typical,
				}
			end
		end
	end
	-- Start hubs first, then the lowest levels; a total order so that sort never fails.
	table.sort(out, function(a, b)
		if a.start ~= b.start then
			return a.start
		end
		if a.level ~= b.level then
			return a.level < b.level
		end
		if a.title ~= b.title then
			return a.title < b.title
		end
		return a.map < b.map
	end)
	for index = #out, MAX_SEARCH + 1, -1 do
		out[index] = nil
	end
	return out
end
