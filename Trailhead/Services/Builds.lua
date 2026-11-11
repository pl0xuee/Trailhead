local _, T = ...
local L = T.L
local C = T.Compat
local G = T.Game

-- Builds: ready-made ways to spend talent points (Data/Builds/<CLASS>.lua), compared with
-- the talents the character really has. Nothing here spends a point: the player clicks in
-- the game's own talent window and Trailhead says where the next one goes.

local B = {}
T.BuildGuide = B
T.Builds = T.Builds or {}

-- The builds written for this character's class (an empty list when there are none).
function B.List()
	return T.Builds[G.ClassFile() or ""] or {}
end

function B.Get(id)
	for _, build in ipairs(B.List()) do
		if build.id == id then
			return build
		end
	end
	return nil
end

-- The build this character follows, or nil.
function B.Chosen()
	return B.Get(T.cdb.build)
end

function B.Choose(id)
	T.cdb.build = B.Get(id) and id or nil
	T:Fire("TH_BUILD_CHANGED")
	T:Fire("TH_ADVICE_CHANGED")
end

-- A build's order as single points: { {node, rank} ... }, and the rank each talent ends at.
local function steps(build)
	if not build.steps then
		build.steps, build.final = {}, {}
		for _, item in ipairs(build.order) do
			for _ = 1, item[2] do
				build.final[item[1]] = (build.final[item[1]] or 0) + 1
				build.steps[#build.steps + 1] = { node = item[1], rank = build.final[item[1]] }
			end
		end
	end
	return build.steps, build.final
end
B.Steps = steps

-- Where the character stands in a build:
--   { problem = "notalents" | "changed" }  the game gave no tree / the tree no longer matches
--   { total, done, unspent, nextLevel, finished,
--     next = { node, name, icon, rank, max, why, text, locked, tree, row },
--     after = { {name, from, to, max} ... },  outside = { {name, points} ... }, outsidePoints,
--     fight = { text ... } }
function B.Progress(build)
	local info = G.Talents()
	if not info then
		return { problem = "notalents" }
	end
	local list, final = steps(build)
	for nodeID, want in pairs(build.talents) do
		local node = info.nodes[nodeID]
		if not node or G.TalentSpell(info, node).spell ~= want.spell or node.max < (final[nodeID] or 0) or not node.name then
			return { problem = "changed" }
		end
	end
	for nodeID in pairs(final) do
		if not build.talents[nodeID] then
			return { problem = "changed" }
		end
	end

	local out = { total = #list, done = 0, unspent = info.unspent, nextLevel = G.NextTalentLevel(info), after = {}, outside = {},
		outsidePoints = 0, fight = {} }
	local upcoming = {}
	for _, step in ipairs(list) do
		if info.nodes[step.node].rank >= step.rank then
			out.done = out.done + 1
		else
			upcoming[#upcoming + 1] = step
		end
	end
	-- With a point to spend, prefer the first step the game will take right now.
	local pick = 1
	if info.unspent > 0 then
		for index, step in ipairs(upcoming) do
			if info.nodes[step.node].available then
				pick = index
				break
			end
		end
	end
	local step = table.remove(upcoming, pick)
	if step then
		local node = info.nodes[step.node]
		out.next = {
			node = node.id, name = node.name, icon = node.icon, rank = step.rank, max = node.max,
			why = build.talents[step.node].why, text = G.TalentText(node.entry, step.rank), locked = not node.available,
			tree = node.tree.name, row = G.TalentRow(info, node),
		}
	else
		out.finished = true
	end
	-- The points after that, with a run of points in one talent shown as one line.
	for _, later in ipairs(upcoming) do
		local last = out.after[#out.after]
		if last and last.node == later.node and last.to + 1 == later.rank then
			last.to = later.rank
		else
			local node = info.nodes[later.node]
			out.after[#out.after + 1] = { node = later.node, name = node.name, from = later.rank, to = later.rank, max = node.max }
		end
	end
	-- Points the build does not use. They are not lost; the build just ends that many short.
	for nodeID, node in pairs(info.nodes) do
		local extra = node.rank - (final[nodeID] or 0)
		if extra > 0 then
			out.outside[#out.outside + 1] = { name = G.TalentSpell(info, node).name or "?", points = extra }
			out.outsidePoints = out.outsidePoints + extra
		end
	end
	table.sort(out.outside, function(a, b)
		return a.name < b.name
	end)
	for _, line in ipairs(build.fight or {}) do
		if not line.node or (info.nodes[line.node] and info.nodes[line.node].rank > 0) then
			out.fight[#out.fight + 1] = line.text
		end
	end
	return out
end

-- True when at least one build for this class matches the talent tree the game reports, so
-- that offering builds (on Home) never leads to a page that cannot suggest anything.
function B.Usable()
	for _, build in ipairs(B.List()) do
		local progress = B.Progress(build)
		if not progress.problem then
			return true
		end
	end
	return false
end

-- Progress in the chosen build, or nil when none is chosen or it cannot be read.
function B.Following()
	local build = B.Chosen()
	if not build or C.InCombat() then
		return nil
	end
	local progress = B.Progress(build)
	return not progress.problem and progress or nil
end

-- Opens the Builds page with the game's talent window beside it.
function B.Open()
	if C.InCombat() then
		return
	end
	if #B.List() > 0 and B.Usable() then
		T.Window:Open("builds")
	end
	G.OpenTalents()
end
