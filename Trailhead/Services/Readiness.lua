local _, T = ...
local L = T.L
local G = T.Game

-- Readiness: the dungeon that suits the character best right now, for the Home card and the
-- Guide's Grouping topic. Levels are the group finder's own (G.World().dungeons, the list the
-- Guide's "Coming up" reads); the roles are the game's own role mask for the class
-- (T.ClassRoles). Which side a dungeon belongs to comes from the flight points the game lists
-- around its door: a door among the other side's flight points is left out, and of two
-- that open at the same level your own side's goes first.

local R = {}
T.Readiness = R

local MINE, OPEN, THEIRS = 2, 1, 0

-- Whose land the door of a dungeon is in: MINE, OPEN (both sides, neutral or unknown) or THEIRS.
local function side(name)
	local id = T.Dungeons and T.Dungeons.Find(name)
	local entry = id and T.DungeonIndex[id]
	local map = entry and entry.entrance and entry.entrance.m
	local zone = map and G.World().byMap[map]
	if not zone then
		return OPEN
	end
	local friendly, hostile = zone.friendly, zone.hostile
	-- A capital city has no flight point named after it as a zone ("Orgrimmar, Durotar"), so
	-- its own flight point is found by the town's name instead.
	if not friendly and not hostile and zone.parent and zone.key then
		local mine = G.Faction()
		for _, node in ipairs(G.TaxiNodes(zone.parent)) do
			local town = G.NormalName(node.town or "")
			if town ~= "" and (zone.key == town or zone.key:sub(1, #town + 1) == town .. " ") then
				if node.faction == 0 or node.faction == mine then
					friendly = true
				else
					hostile = true
				end
			end
		end
	end
	if hostile and not friendly then
		return THEIRS
	elseif friendly and not hostile then
		return MINE
	end
	return OPEN
end
R.Side = side

-- The best dungeon for the character's level and side, or nil:
-- { name, lo, hi, id (the index id, or nil when Trailhead has no page for it) }.
function R.Best(level)
	level = level or G.Level()
	local best, bestSide
	for _, dungeon in ipairs(G.World().dungeons or {}) do
		if level >= dungeon.lo and level <= dungeon.hi then
			local where = side(dungeon.name)
			-- The one that opened most recently, and of two that opened together your own side's.
			if where ~= THEIRS and (not best or dungeon.lo > best.lo or (dungeon.lo == best.lo and where > bestSide)) then
				best, bestSide = dungeon, where
			end
		end
	end
	if not best then
		return nil
	end
	return { name = best.name, lo = best.lo, hi = best.hi, id = T.Dungeons and T.Dungeons.Find(best.name) }
end

-- The level the first dungeon opens at, from the group finder, or nil.
function R.FirstLevel()
	local first = G.World().dungeons[1]
	return first and first.lo or nil
end

-- What the class can be in a group, in the game's own role order: "tank, damage", or nil.
function R.Roles()
	local mask = T.ClassRoles and T.ClassRoles[G.ClassFile() or ""] or 0
	local names = T.GuideTopics and T.GuideTopics.roleNames or {}
	local out = {}
	for _, bit in ipairs({ 2, 4, 8 }) do
		if math.floor(mask / bit) % 2 == 1 and names[bit] then
			out[#out + 1] = names[bit]:lower()
		end
	end
	return #out > 0 and table.concat(out, ", ") or nil
end

-- Opens the route page for a dungeon, or the dungeon list when Trailhead has no page for it.
function R.Opener(best)
	if best and best.id then
		return L["Open the route"], function()
			T.Window:Open("dungeon", best.name)
		end
	end
	return L["See dungeons"], function()
		T.Window:Open("zones", "dungeons")
	end
end

-- The Home card. One at a time; dismissing it keeps it away (on this character) until the
-- level brings a different dungeon. Inside a dungeon the route card speaks instead.
function R.Card()
	if T.Dungeons and T.Dungeons.Current() then
		return nil
	end
	local best = R.Best()
	if not best then
		return nil
	end
	local roles = R.Roles()
	local action, run = R.Opener(best)
	return {
		id = "dungeon", tone = "info", icon = "gate", key = "dungeon:" .. best.name, persist = true,
		title = L["Ready for %s"]:format(best.name),
		body = L["Levels %d to %d. Dungeons need a group of five."]:format(best.lo, best.hi)
			.. (roles and "\n" .. L["Your class can be: %s."]:format(roles) or ""),
		action = action,
		run = run,
	}
end
