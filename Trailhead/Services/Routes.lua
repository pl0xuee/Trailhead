local _, T = ...
local L = T.L
local C = T.Compat
local G = T.Game
local P = T.Places

-- Routes: "how do I get there?" for anything Trailhead lists. A route is a short list of
-- numbered steps from where the player stands: walk to a flight master, fly, walk the
-- last stretch. Built only from what the game says (flight points, map positions) and
-- what the player has found; where Trailhead does not know, the step says so.

local R = {}
T.Routes = R

local RUN = 7 -- yards a second on foot
local WIGGLE = 1.3 -- roads are not straight lines
local LONG_WALK = 5 -- minutes; from here a walking time is given as "or more"
local SHORT = 500 -- yards: no flight is worth it for less
local AT = 60 -- yards: closer than this, you are standing at the flight master
local FLY_WORTH = 0.7 -- flying must cut the walking to this share of going straight
local LONG = 2500 -- yards: a walk long enough to say something about
local MUCH_CLOSER = 0.6 -- a flight point you lack is worth naming when it is this much closer
local GUESS_HEIGHT = 24000 -- yards down a continent map, when the game will not say

local COMPASS = {
	L["north"], L["north-east"], L["east"], L["south-east"],
	L["south"], L["south-west"], L["west"], L["north-west"],
}

-- Yards across and down a continent's map, and whether the game gave them.
local function measure(continent)
	local width, height = G.MapYards(continent)
	if width then
		return width, height, true
	end
	return GUESS_HEIGHT * 1.5, GUESS_HEIGHT, false -- the maps are three wide to two tall
end

local function yards(ax, ay, bx, by, width, height)
	local dx, dy = (bx - ax) * width, (by - ay) * height
	return math.sqrt(dx * dx + dy * dy), dx, dy
end

-- Which way: dx is yards east, dy is yards south.
local function compass(dx, dy)
	local angle = math.deg(math.atan2(dx, -dy)) -- 0 is north, 90 is east
	return COMPASS[math.floor((angle + 22.5) / 45) % 8 + 1]
end
R.Compass = compass

local function join(parts)
	local out = {}
	for _, part in ipairs(parts) do
		if part and part ~= "" then
			out[#out + 1] = part
		end
	end
	return table.concat(out, "  \194\183  ")
end

-- "To the north-east  ·  about 3 minutes on foot". Times only when the yards are real.
local function walkLine(distance, dx, dy, real, where)
	local way = distance > AT and L["To the %s"]:format(compass(dx, dy)) or nil
	local time
	if real then
		local minutes = distance * WIGGLE / RUN / 60
		if minutes < 1 then
			time = L["Under a minute on foot"]
		else
			minutes = math.floor(minutes + 0.5)
			-- The time is measured as the crow flies, so a long walk is only a lower figure:
			-- mountains and winding roads can add to it.
			time = minutes == 1 and L["About a minute on foot"]
				or minutes >= LONG_WALK and L["%d minutes or more on foot"]:format(minutes)
				or L["About %d minutes on foot"]:format(minutes)
		end
	end
	return join({ where, way, time })
end

-- Flight points the player's side can use on a continent.
local function flightPoints(continent)
	local out = {}
	local mine = G.Faction()
	for _, node in ipairs(G.TaxiNodes(continent)) do
		if node.faction == 0 or mine == nil or node.faction == mine then
			out[#out + 1] = node
		end
	end
	return out
end

-- The nearest flight point to a spot; with `known`, only among those the character has.
local function nearest(nodes, x, y, width, height, known)
	local best, bestYards
	for _, node in ipairs(nodes) do
		if not known or known[node.name] then
			local distance = yards(x, y, node.x, node.y, width, height)
			if not bestYards or distance < bestYards then
				best, bestYards = node, distance
			end
		end
	end
	return best, bestYards
end

local function flightStep(text, node, detail, continent)
	local mapID, x, y = P.FlightSpot(continent, node)
	return { text = text, detail = detail, map = mapID, x = x, y = y, mark = node.town }
end

local function lastStep(target, detail)
	local text = target.node and L["Walk to the flight master in %s"]:format(target.title)
		or L["Walk to %s"]:format(target.title)
	return { text = text, detail = detail, map = target.markMap or target.map,
		x = target.markX or target.x, y = target.markY or target.y, mark = target.title }
end

local FLY_IF = L["If the flight master does not list it, you have not found it yet. Fly as close as you can."]

-- The steps on one continent, from a spot on its map to the target.
local function overland(plan, target, continent, px, py, tx, ty)
	local width, height, real = measure(continent)
	local direct, dx, dy = yards(px, py, tx, ty, width, height)
	local nodes = flightPoints(continent)
	local known = G.KnownFlights(continent)
	local from, fromYards = nearest(nodes, px, py, width, height, known)
	local to, toYards = nearest(nodes, tx, ty, width, height, known)
	local closest, closestYards = nearest(nodes, tx, ty, width, height, nil)

	local fly = from and to and from ~= to and direct > SHORT and fromYards + toYards < FLY_WORTH * direct
	if fly then
		if fromYards <= AT then
			plan.steps[#plan.steps + 1] = flightStep(L["Talk to the flight master in %s"]:format(from.town), from,
				L["You are standing next to them."], continent)
		else
			local _, fx, fy = yards(px, py, from.x, from.y, width, height)
			plan.steps[#plan.steps + 1] = flightStep(L["Go to the flight master in %s"]:format(from.town), from,
				walkLine(fromYards, fx, fy, real, from.zone), continent)
		end
		plan.steps[#plan.steps + 1] = {
			text = L["Fly to %s"]:format(to.town),
			detail = known and to.zone or join({ to.zone, FLY_IF }),
		}
		if not (target.node and target.node == to.id) then
			local _, wx, wy = yards(to.x, to.y, tx, ty, width, height)
			plan.steps[#plan.steps + 1] = lastStep(target, walkLine(toYards, wx, wy, real, target.where))
		end
	else
		plan.steps[#plan.steps + 1] = lastStep(target, walkLine(direct, dx, dy, real, target.where))
	end

	if known and target.node and closest and closest.id == target.node and not known[closest.name] then
		plan.note = L["You have not found this flight point yet, so you cannot fly to it. Walk there once and talk to the flight master."]
	elseif known and closest and closest ~= to and (not fly or closestYards < MUCH_CLOSER * toYards)
		and closestYards < MUCH_CLOSER * direct then
		plan.note = L["%s has a flight point closer to it, but you have not found that one yet. Talk to its flight master when you pass and the next trip is quicker."]:format(closest.town)
	elseif not known and #nodes > 0 then
		plan.note = L["Trailhead does not know which flight points you have yet. Talk to any flight master once and it will."]
	elseif not fly and direct > LONG then
		plan.note = L["None of your flight points gets you closer. Every flight master you talk to on the way makes later trips quicker."]
	end
end

-- Builds the steps to a target: { title, where, icon, steps = { {text, detail, map, x, y, mark} }, note }.
function R.Plan(target)
	local plan = { title = target.title, where = target.where, icon = target.icon or "pin", steps = {} }
	if type(target.map) ~= "number" then
		plan.unknown = true
		plan.note = target.unknown
			or L["Trailhead does not know where this is yet."]
		return plan
	end
	local continent, tx, ty = G.OnContinent(target.map, target.x, target.y)
	local mine = G.Continent()
	local px, py
	if continent and mine == continent then
		px, py = G.PositionOn(continent)
	end
	if not continent or not mine or (mine == continent and not px) then
		-- Inside a building or a dungeon, or the game will not place the spot: the marker is
		-- still right, there is just nothing more to say.
		plan.steps[1] = lastStep(target, target.where or "")
		plan.steps[1].text = L["Follow the marker to %s"]:format(target.title)
		plan.note = L["Trailhead cannot tell where you are standing right now, so it cannot break the trip into steps."]
		return plan
	end
	if mine ~= continent then
		local name = G.MapName(continent) or L["the other continent"]
		plan.steps[1] = {
			text = L["Cross the sea to %s"]:format(name),
			detail = L["Boats and zeppelins link the continents from the big cities and ports. Ask a city guard which one goes to %s."]:format(name),
		}
		local width, height = measure(continent)
		local nodes = flightPoints(continent)
		local known = G.KnownFlights(continent)
		local to, toYards = nearest(nodes, tx, ty, width, height, known)
		if to and toYards > SHORT and not (target.node and target.node == to.id) then
			plan.steps[2] = {
				text = L["Once there, fly to %s"]:format(to.town),
				detail = known and to.zone or join({ to.zone, FLY_IF }),
			}
		end
		plan.steps[#plan.steps + 1] = lastStep(target, target.where or "")
		plan.note = L["Trailhead does not know the sea crossings yet. Open this again once you have landed for the rest of the way."]
		return plan
	end
	overland(plan, target, continent, px, py, tx, ty)
	return plan
end

-- ---------------------------------------------------------------------------
-- Targets: what a route can lead to.

-- A quest hub in a zone (a record from T.Hubs): the spot itself on the zone's map.
function R.ForHub(hub, zoneName)
	local zone = zoneName or G.MapName(hub.map) or ""
	return {
		title = hub.name, icon = "pin", map = hub.map, x = hub.x, y = hub.y,
		where = (hub.start and L["Where to start in %s"] or L["Quest hub in %s"]):format(zone),
	}
end

-- A zone: the hub where the player's side should start when the zone has one; else its flight
-- point for the player's side when it has one, else its middle.
function R.ForZone(mapID, name)
	local start = T.Hubs and T.Hubs.Start(mapID)
	if start then
		return R.ForHub(start, name)
	end
	local target = { title = name or G.MapName(mapID) or "", icon = "mtn", map = mapID, x = 0.5, y = 0.5 }
	local zone = G.World().byMap[mapID]
	local continent = G.ContinentOf(mapID)
	if zone and continent then
		for _, node in ipairs(flightPoints(continent)) do
			local key = G.NormalName(node.zone)
			if zone.key == key or zone.key:sub(1, #key + 1) == key .. " " then
				target.map, target.x, target.y = continent, node.x, node.y
				target.node, target.where = node.id, L["Flight point: %s"]:format(node.town)
				target.markMap, target.markX, target.markY = P.FlightSpot(continent, node)
				break
			end
		end
	end
	return target
end

-- A dungeon or raid: its entrance, once a character has walked in.
function R.ForDungeon(name)
	local spot = G.Entrance(name)
	if spot then
		return { title = name, icon = "gate", map = spot.map, x = spot.x, y = spot.y,
			where = spot.zone and L["Entrance in %s"]:format(spot.zone) or nil }
	end
	return {
		title = name, icon = "gate",
		unknown = L["Trailhead does not know where %s is entered yet."]:format(name)
			.. "\n" .. L["It learns an entrance the first time one of your characters walks in, and keeps it for all of them. Until then, ask your group to lead the way."],
	}
end

-- Anything from the Find it list or the search.
function R.ForResult(item)
	if item.kind == "zone" then
		return R.ForZone(item.map, item.title)
	elseif item.kind == "dungeon" then
		return R.ForDungeon(item.title)
	elseif item.kind == "flight" then
		local mapID, x, y = P.FlightSpot(item.map, { id = item.node, x = item.x, y = item.y, zoneKey = item.zoneKey, townKey = item.townKey })
		return { title = item.title, where = item.where, icon = "wing", map = item.map, x = item.x, y = item.y,
			node = item.node, markMap = mapID, markX = x, markY = y }
	elseif item.kind == "place" then
		return { title = item.title, where = item.where, icon = item.icon, map = item.map, x = item.x, y = item.y }
	end
	return nil
end

-- Puts the marker on a step's spot and opens the map on it.
function R.Mark(step)
	if not step or type(step.map) ~= "number" then
		return false
	end
	local ok = P.SetMarker(step.map, step.x, step.y, step.mark)
	P.ShowMap(step.map)
	return ok
end
