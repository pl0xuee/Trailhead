local _, T = ...
local L = T.L
local C = T.Compat
local G = T.Game

-- Dungeons: what the shipped index (Data/DungeonIndex.lua, from the game's tables) and the
-- written guides (Data/Dungeons/*.lua) say about a dungeon or raid, which one the player is
-- standing in, and which of its bosses have died on this run.

local D = {}
T.Dungeons = D

T.DungeonIndex = T.DungeonIndex or {}
T.DungeonGuides = T.DungeonGuides or {}

local RUN_KEEP = 3600 -- seconds a run is remembered after leaving: a wipe and the walk back keep the ticks
local FUZZY_MIN = 6 -- letters a name must have before it may match as the start of another

-- Names that cannot be matched by shape alone, written as D.Key makes them.
local ALIASES = {}
local ALIAS_NAMES = {
	["Temple of Atal'Hakkar"] = 109, -- Sunken Temple
	["Temple of Ahn'Qiraj"] = 531,
	["Stockade"] = 34, ["Stockades"] = 34, ["Stormwind Stockades"] = 34,
}

-- One spelling for every name the game uses: no "The", no wing ("Scarlet Monastery:
-- Library", "Dire Maul - East"), no Lower or Upper, no punctuation, no doubled letters
-- ("Zul'Farak" and "Zul'Farrak" meet).
local function key(name)
	if type(name) ~= "string" then
		return nil
	end
	local k = name:lower()
	k = k:gsub(":.*$", "")
	k = k:gsub("%s+%-%s+.*$", "")
	k = k:gsub("^the ", "")
	k = k:gsub("^lower ", "")
	k = k:gsub("^upper ", "")
	k = k:gsub("'s%f[%A]", "") -- "Onyxia's Lair" and "Onyxia" meet
	k = k:gsub("[^%a%d ]", "")
	for _ = 1, 3 do
		k = k:gsub("(%a)%1", "%1") -- doubled letters: "Zul'Farak" and "Zul'Farrak" meet
	end
	k = k:gsub("%s+", " ")
	k = k:gsub("^ ", "")
	k = k:gsub(" $", "")
	if k == "" then
		return nil
	end
	return k
end
D.Key = key
for name, id in pairs(ALIAS_NAMES) do
	ALIASES[key(name)] = id
end

local byKey, built

local function build()
	byKey, built = {}, T.DungeonIndex
	for id, entry in pairs(T.DungeonIndex) do
		local k = key(entry.name)
		-- Two maps with one name (Naxxramas): the bigger one is the place people mean.
		if k and (not byKey[k] or (T.DungeonIndex[byKey[k]].size or 0) < (entry.size or 0)) then
			byKey[k] = id
		end
	end
end

-- Forgets what was read from the index (for tests that swap it).
function D.Reload()
	byKey, built = nil, nil
end

-- The index map id for a group finder or map name, or nil.
function D.Find(name)
	if not byKey or built ~= T.DungeonIndex then
		build()
	end
	local k = key(name)
	if not k then
		return nil
	end
	if byKey[k] then
		return byKey[k]
	end
	if ALIASES[k] and T.DungeonIndex[ALIASES[k]] then
		return ALIASES[k]
	end
	-- "Ragefire" for "Ragefire Chasm": the start of one name is the other, when that is
	-- long enough to mean it and only one dungeon fits.
	local found
	for other, id in pairs(byKey) do
		local short = #k < #other and k or other
		local long = #k < #other and other or k
		if #short >= FUZZY_MIN and long:sub(1, #short) == short and long:sub(#short + 1, #short + 1) == " " then
			if found and found ~= id then
				return nil
			end
			found = id
		end
	end
	return found
end

function D.Has(name)
	return D.Find(name) ~= nil
end

-- Index and guide together, or nil: { id, name, kind, size, entrance, bosses, guide, summary,
-- door, tips, steps }. Takes a name or an instance map id.
function D.Get(which)
	local id = type(which) == "number" and which or D.Find(which)
	local entry = id and T.DungeonIndex[id]
	if not entry then
		return nil
	end
	local guide = T.DungeonGuides[id]
	return {
		id = id, name = entry.name, kind = entry.kind, size = entry.size, entrance = entry.entrance,
		bosses = entry.bosses or {}, guide = guide ~= nil, summary = guide and guide.summary,
		door = guide and guide.door, tips = guide and guide.tips or {}, steps = guide and guide.steps,
	}
end

-- The door the tables ship, shaped like G.Entrance's answer: { map, x, y, zone }, or nil.
function D.Shipped(name)
	local id = D.Find(name)
	local entrance = id and T.DungeonIndex[id].entrance
	if not entrance then
		return nil
	end
	return { map = entrance.m, x = entrance.x, y = entrance.y, zone = G.MapName(entrance.m) }
end

-- The levels the group finder suggests: lo, hi, or nil.
function D.Levels(id)
	local world = G.World()
	for _, list in ipairs({ world.dungeons or {}, world.raids or {} }) do
		for _, item in ipairs(list) do
			if D.Find(item.name) == id then
				return item.lo, item.hi
			end
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Where the player is, and which bosses are down.

local current -- { id, name } while inside a dungeon or raid in the index

local function saved()
	local run = T.cdb and T.cdb.dungeonRun
	return type(run) == "table" and type(run.kills) == "table" and run or nil
end

function D.Current()
	return current
end

-- Reads the game once; does nothing in combat (the last answer stands).
function D.Refresh()
	if C.InCombat() then
		return
	end
	local inside, kind = C.Call("IsInInstance")
	inside, kind = C.Plain(inside, false), C.Plain(kind, nil)
	local now
	if inside == true and (kind == "party" or kind == "raid") then
		local name, _, _, _, _, _, _, instanceId = C.Call("GetInstanceInfo")
		name, instanceId = C.Plain(name, nil), C.Plain(instanceId, nil)
		local id = (type(instanceId) == "number" and T.DungeonIndex[instanceId]) and instanceId or D.Find(name)
		if id then
			now = { id = id, name = T.DungeonIndex[id].name }
		end
	end
	local before = current
	current = now
	if (before and before.id) == (now and now.id) then
		return
	end
	local run = saved()
	if before and run and run.id == before.id then
		run.leftAt = time()
	end
	if now then
		if run and run.id == now.id and (not run.leftAt or time() - run.leftAt <= RUN_KEEP) then
			run.leftAt = nil
		elseif T.cdb then
			T.cdb.dungeonRun = { id = now.id, kills = {} }
		end
	end
	T:Fire("TH_DUNGEON_CHANGED")
end

-- Whether a boss of the dungeon you are in has died on this run.
function D.Killed(id, bossName)
	local run = saved()
	return current ~= nil and current.id == id and run ~= nil and run.id == id and run.kills[bossName] == true
end

-- How many bosses are down, and how many there are: killed, total.
function D.Progress(id)
	local entry = T.DungeonIndex[id]
	local killed = 0
	for _, boss in ipairs(entry and entry.bosses or {}) do
		if D.Killed(id, boss.name) then
			killed = killed + 1
		end
	end
	return killed, entry and #(entry.bosses or {}) or 0
end

-- The boss to look for next: the first one in the guide's order that is still alive (an
-- optional one only when nothing else is left), as { name, where, optional }. Nil when the
-- dungeon has no bosses, or all are down.
function D.Next(id)
	local dungeon = D.Get(id)
	if not dungeon then
		return nil
	end
	local order = {}
	local placed = {}
	for _, step in ipairs(dungeon.steps or {}) do
		if step.boss then
			order[#order + 1] = { name = step.boss, where = step.where, optional = step.optional }
			placed[step.boss] = true
		end
	end
	for _, boss in ipairs(dungeon.bosses) do
		if not placed[boss.name] then
			order[#order + 1] = { name = boss.name }
		end
	end
	local spare
	for _, boss in ipairs(order) do
		if not D.Killed(id, boss.name) then
			if not boss.optional then
				return boss
			end
			spare = spare or boss
		end
	end
	return spare
end

local function equalName(a, b)
	return type(a) == "string" and type(b) == "string" and (a:lower() == b:lower() or key(a) == key(b))
end

-- A boss died: tick it when it belongs to the dungeon the player is in.
local function killed(encounterId, name)
	encounterId, name = C.Plain(encounterId, nil), C.Plain(name, nil)
	if not current then
		D.Refresh()
	end
	local run = saved()
	if not current or not run or run.id ~= current.id then
		return
	end
	for _, boss in ipairs(T.DungeonIndex[current.id].bosses or {}) do
		if (type(encounterId) == "number" and boss.id == encounterId) or equalName(boss.name, name) then
			if not run.kills[boss.name] then
				run.kills[boss.name] = true
				T:Fire("TH_DUNGEON_CHANGED")
			end
			return
		end
	end
end

-- The game says "<place> has been reset." to the group when the leader resets the run.
local function resetPattern()
	local text = type(INSTANCE_RESET_SUCCESS) == "string" and INSTANCE_RESET_SUCCESS or "%s has been reset."
	return "^" .. text:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0"):gsub("%%s", "(.+)") .. "$"
end

-- Home's cards follow where you are and how the run is going.
T:On("TH_DUNGEON_CHANGED", function()
	T:Fire("TH_ADVICE_CHANGED")
end)
T:On("PLAYER_ENTERING_WORLD", D.Refresh)
T:On("ZONE_CHANGED_NEW_AREA", D.Refresh)
-- Logging out inside a dungeon never runs the leaving branch of D.Refresh. Without a time
-- stamp, a run from days ago would be taken up again on the next visit to that dungeon.
T:On("PLAYER_LOGOUT", function()
	local run = saved()
	if current and run and run.id == current.id then
		run.leftAt = time()
	end
end)
T:On("BOSS_KILL", killed)
T:On("ENCOUNTER_END", function(encounterId, name, _, _, success)
	if C.Plain(success, 0) == 1 then
		killed(encounterId, name)
	end
end)
T:On("CHAT_MSG_SYSTEM", function(message)
	message = C.Plain(message, nil)
	if type(message) ~= "string" then
		return
	end
	local place = message:match(resetPattern())
	local id = place and D.Find(place)
	local run = saved()
	if id and run and run.id == id then
		T.cdb.dungeonRun = { id = id, kills = {}, leftAt = (not current) and time() or nil }
		T:Fire("TH_DUNGEON_CHANGED")
	end
end)
