local _, T = ...
local L = T.L
local C = T.Compat
local G = T.Game

-- First steps: the early milestones a new player should hit, each one read from the game.
-- What the game only shows while it happens (setting the hearthstone, resting, a group, a
-- mount, a dungeon boss) is remembered per character in TrailheadCharDB.firstSteps.
-- A milestone the game cannot tell Trailhead about on this client is left out, never guessed.

local F = {}
T.FirstSteps = F

F.NEW_LEVEL = 5 -- up to this level, a character first seen is taken to be new

-- The skills that count as a profession: every main profession, and these secondary ones
-- (the game's SkillLine table puts riding, Lockpicking and racials in the same list).
local SECONDARY = { [129] = true, [185] = true, [356] = true } -- First Aid, Cooking, Fishing
-- The riding skills of this build (SkillLine, build 1.60.1.70888).
local RIDING = { [148] = true, [149] = true, [150] = true, [152] = true, [533] = true, [553] = true,
	[554] = true, [713] = true, [762] = true, [3011] = true }

-- true or false when the game can tell, nil when it cannot.
local function known(can, value)
	if not can then
		return nil
	end
	return value == true
end

local function memory()
	local cdb = T.cdb
	if not cdb then
		return {}
	end
	if type(cdb.firstSteps) ~= "table" then
		cdb.firstSteps = {}
	end
	return cdb.firstSteps
end

local function guide(id, label)
	return { kind = "guide", label = L["See the %s topic"]:format(label), run = function()
		T.Window:Open("guide", id)
	end }
end

local function find(category, label)
	return { kind = "find", label = label, run = function()
		T.Window:Open("find", category)
	end }
end

-- Whether an extra bag sits in a bag slot; nil when the game will not say.
local function hasBag()
	if not C.Has("C_Container.GetContainerNumSlots") then
		return nil
	end
	for bag = 1, (NUM_BAG_SLOTS or 4) do
		local slots = C.Plain(C.Call("C_Container.GetContainerNumSlots", bag), 0)
		if type(slots) == "number" and slots > 0 then
			return true
		end
	end
	return false
end

-- Whether the character has a profession; nil while the game has not listed the skills.
local function hasProfession(skills)
	for _, skill in ipairs(skills.professions) do
		if not skill.levelBound then
			return true
		end
	end
	for _, skill in ipairs(skills.secondary) do
		if SECONDARY[skill.id] then
			return true
		end
	end
	if not skills.complete then
		return nil
	end
	return false
end

local function hasRiding(skills)
	for id in pairs(RIDING) do
		if skills.byId[id] then
			return true
		end
	end
	return false
end

-- Reads what the game shows right now into the memory. Nothing in combat.
function F.Scan()
	if C.InCombat() or not T.cdb then
		return
	end
	local mem = memory()
	local bind = G.BindLocation()
	if bind then
		-- Records from 0.13.0 have no bindLevel: they are judged once more by the same rule.
		if not mem.bind or (not mem.bound and mem.bindLevel == nil) then
			mem.bind = mem.bind or bind
			mem.bindLevel = G.Level()
			-- Where the stone was first seen set is the start only for a new character. One met
			-- later (Trailhead installed at level 20, say) has long chosen an inn of its own.
			if G.Level() > F.NEW_LEVEL or type(T.cdb.trainer) == "table" then
				mem.bound = true
			end
		end
		if not mem.bound and bind ~= mem.bind then
			mem.bound = true
		end
	end
	if C.Plain(C.Call("IsResting"), false) == true then
		mem.rested = true
	end
	if C.Plain(C.Call("IsInGroup"), false) == true then
		mem.grouped = true
	end
	if C.Plain(C.Call("IsMounted"), false) == true then
		mem.mounted = true
	end
	-- A boss down in a five-player dungeon, as the dungeon service counts them.
	local D = T.Dungeons
	local here = D and D.Current()
	local entry = here and T.DungeonIndex[here.id]
	if entry and entry.kind == "dungeon" and D.Progress(here.id) > 0 then
		mem.dungeon = true
	end
end

-- The milestones, in the order a new player meets them: { id, name, text, done, link, advice }.
function F.List()
	local mem = memory()
	local level, skills = G.Level(), G.Skills()
	local out = {}
	local function add(step)
		if step.done ~= nil then
			out[#out + 1] = step
		end
	end

	add({ id = "trainer", name = L["Class trainer"], text = L["Visit your class trainer for new spells"],
		done = type(T.cdb and T.cdb.trainer) == "table",
		advice = L["Class trainers teach new spells and new ranks of old ones. Visit yours every couple of levels."],
		link = find("trainer", L["Find trainer"]) })
	add({ id = "hearth", name = L["Hearthstone"], text = L["Make an inn your home at its innkeeper"],
		done = known(C.Has("GetBindLocation"), mem.bound),
		advice = L["Ask an innkeeper to make their inn your home."] .. " " .. L["Your hearthstone then takes you back there."],
		link = find("inn", L["Find an inn"]) })
	add({ id = "rest", name = L["Rest"], text = L["Spend time in an inn or a city"],
		done = known(C.Has("IsResting"), mem.rested),
		advice = L["Time in an inn or a city, even logged out, makes you rested: monsters then give extra experience."],
		link = guide("rest", L["Inns and rest"]) })
	local bar2 = T.Interface and T.Interface.IsOn("bar2")
	add({ id = "bar2", name = L["Action Bar 2"], text = L["Turn on a second row of action buttons"],
		done = bar2,
		advice = L["Screen setup turns on Action Bar 2 with one click, and turns it off again."],
		link = { kind = "page", label = L["Open Screen setup"], run = function()
			T.Window:Open("setup")
		end } })
	local talents = G.Talents()
	add({ id = "talent", name = L["Talents"], text = level < G.FIRST_TALENT_LEVEL and L["Spend your first talent point (level %d)"]:format(G.FIRST_TALENT_LEVEL)
		or L["Spend your first talent point"],
		done = known(talents ~= nil, talents and talents.spent > 0),
		advice = level < G.FIRST_TALENT_LEVEL and L["Your first talent point comes at level %d."]:format(G.FIRST_TALENT_LEVEL)
			or L["Open your talents from the game's menu bar. The Builds page says where each point goes."],
		link = guide("talents", L["Talents"]) })
	add({ id = "profession", name = L["Profession"], text = L["Learn a profession from its trainer"],
		done = hasProfession(skills),
		advice = L["Profession trainers in towns and cities teach them. Cooking, First Aid and Fishing are open to everyone."],
		link = find("professions", L["Find a profession trainer"]) })
	add({ id = "bag", name = L["Bags"], text = L["Put a bag in one of your empty bag slots"],
		done = hasBag(),
		advice = L["Each bag slot next to your backpack takes one more bag. Monsters drop them, tailors make them, and the auction house sells them."],
		link = find("auction", L["Find the auction house"]) })
	add({ id = "group", name = L["Group"], text = L["Join a party with other players"],
		done = known(C.Has("IsInGroup"), mem.grouped),
		advice = L["Some quests and every dungeon are made for a group. Ask in chat or use Looking For Group."],
		link = guide("grouping", L["Grouping"]) })
	local best = T.Readiness and T.Readiness.Best(level)
	local first = T.Readiness and T.Readiness.FirstLevel()
	local label, run = T.Readiness and T.Readiness.Opener(best)
	add({ id = "dungeon", name = L["Dungeon"], text = L["Defeat a boss in a dungeon with a group"],
		done = known(T.Dungeons ~= nil, mem.dungeon),
		advice = best and L["%s fits your level now. Find a group of five and go in together."]:format(best.name)
			or first and level < first and L["Your first dungeon opens at level %d."]:format(first)
			or L["Dungeons need a group of five."],
		link = best and { kind = "page", label = label, run = run } or guide("grouping", L["Grouping"]) })
	local facts = T.Known and T.Known.riding
	add({ id = "mount", name = L["Mount"], text = facts and L["Ride a mount (from level %d)"]:format(facts.level) or L["Ride a mount"],
		done = (mem.mounted == true or hasRiding(skills)) or known(C.Has("IsMounted"), false),
		advice = facts and level < facts.level and L["Riding opens at level %d. Start putting gold aside for it now."]:format(facts.level)
			or L["You can learn to ride now. See the Mount topic."],
		link = guide("mount", L["Mount"]) })
	return out
end

-- How many are done, and how many there are.
function F.Counts(list)
	list = list or F.List()
	local done = 0
	for _, step in ipairs(list) do
		if step.done then
			done = done + 1
		end
	end
	return done, #list
end

function F.AllDone()
	local done, total = F.Counts()
	return total > 0 and done == total
end

local function changed()
	F.Scan()
end

T:On("HEARTHSTONE_BOUND", function()
	memory().bound = true
end)
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_UPDATE_RESTING", "GROUP_ROSTER_UPDATE",
	"PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_REGEN_ENABLED", "TH_DUNGEON_CHANGED" }) do
	T:On(event, changed)
end
