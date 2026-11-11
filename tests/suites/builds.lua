-- Builds: every class's builds spent point by point on that class's real talent tree, the
-- reasons, the helper at a few levels, the page, the narrow strip, and a mutation check.
local H = ...
local Stub, check = H.Stub, H.check

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

-- Empties the loaded fixture tree so points can be spent from nothing.
local function empty()
	for id in pairs(Stub.world.ranks) do
		Stub.world.ranks[id] = 0
	end
end

-- Spends the first `count` points of a build, checking that the game would take each one.
local function spend(T, build, count)
	local steps = T.BuildGuide.Steps(build)
	Stub.world.talents, Stub.world.talentPoints = true, 1
	for index = 1, count do
		local step = steps[index]
		local node = T.Game.Talents().nodes[step.node]
		if not node or not node.available or node.rank + 1 ~= step.rank or step.rank > node.max then
			return index, step
		end
		Stub.world.ranks[step.node] = step.rank
	end
	return nil
end

H.section("builds: every class and build", function()
	local count = 0
	for _, class in ipairs(CLASSES) do
		local T = H.load({ class = class, level = 60 }, H.checked())
		local B = T.BuildGuide
		local list = B.List()
		check(#list >= 1, class .. " has at least one build")
		local seen = {}
		for _, build in ipairs(list) do
			count = count + 1
			local label = class .. " " .. tostring(build.id)
			check(not seen[build.id] and B.Get(build.id) == build, label .. ": a unique id")
			seen[build.id] = true
			check(type(build.name) == "string" and #build.name > 0 and type(build.suits) == "string" and #build.suits >= 60
				and type(build.gear) == "string" and #build.gear >= 30, label .. ": named, with who it suits and what to look for on gear")
			check(#(build.fight or {}) >= 3, label .. ": fight lines written")

			empty()
			local steps, final = B.Steps(build)
			local at, step = spend(T, build, #steps)
			check(#steps == 51 and at == nil, label .. ": 51 points, and the game takes each in order" .. (at and (": step " .. at .. " node " .. tostring(step.node)) or ""))
			local trees = T.Game.Talents().trees
			local spentTotal = 0
			for _, tree in ipairs(trees) do
				spentTotal = spentTotal + tree.spent
			end
			check(spentTotal == 51, label .. ": 51 points land on the tree")

			local whole = true
			for nodeID, talent in pairs(build.talents) do
				local node = Stub.tree.nodes[nodeID]
				whole = whole and node ~= nil and node.spell == talent.spell and type(talent.why) == "string" and #talent.why >= 12
					and final[nodeID] ~= nil and final[nodeID] <= node.max
			end
			for nodeID in pairs(final) do
				whole = whole and build.talents[nodeID] ~= nil
			end
			check(whole, label .. ": every talent is real, ranked within its maximum, with a reason")
			local progress = B.Progress(build)
			check(progress.finished and progress.done == 51 and progress.problem == nil, label .. ": finished with every point placed")
			for _, line in ipairs(build.fight) do
				check(line.node == nil or build.talents[line.node] ~= nil, label .. ": a fight line only depends on a talent in the build")
			end

			-- the helper at a few levels: after k points the next one is step k+1
			for _, placed in ipairs({ 0, 1, 12, 30, 50 }) do
				empty()
				spend(T, build, placed)
				Stub.world.talents, Stub.world.talentPoints = true, 1
				progress = B.Progress(build)
				local want = steps[placed + 1]
				check(progress.done == placed and progress.next and progress.next.node == want.node and progress.next.rank == want.rank
					and type(progress.next.why) == "string" and progress.unspent == 1,
					label .. ": with " .. placed .. " placed the helper names point " .. (placed + 1))
			end
		end

		-- another class's build cannot be picked
		for _, other in ipairs(CLASSES) do
			if other ~= class then
				for _, foreign in ipairs(T.Builds[other] or {}) do
					if not seen[foreign.id] then
						B.Choose(foreign.id)
						check(T.cdb.build == nil and B.Chosen() == nil, class .. ": the " .. other .. " build " .. foreign.id .. " is refused")
					end
				end
			end
		end
		H.noErrors(T, class .. " builds")
	end
	check(count >= 15, "builds checked: " .. count)
end)

H.section("builds: the page", function()
	for _, class in ipairs(CLASSES) do
		local T = H.load({ class = class, level = 30 }, H.checked())
		local B = T.BuildGuide
		H.slash("")
		for _, build in ipairs(B.List()) do
			Stub.world.talents, Stub.world.talentPoints = false, nil
			empty()
			local at = spend(T, build, 14)
			Stub.world.talents, Stub.world.talentPoints = false, nil
			T.Window:Select("builds")
			T.modules.builds.selected = build.id
			T.modules.builds:Refresh()
			Stub.flush()
			local label = class .. " " .. build.id
			local lines = {}
			for index = 1, math.min(4, #B.Progress(build).fight) do
				lines[index] = B.Progress(build).fight[index]
			end
			check(at == nil and Stub.sees(build.suits) and Stub.sees(build.gear) and Stub.sees("WHAT TO LOOK FOR ON GEAR"), label .. ": the page shows who it suits and the gear")
			check(Stub.sees("14 of 51 points placed") and Stub.sees(B.Progress(build).next.name), label .. ": and the order, with the next point")
			check(#lines > 0 and Stub.sees(table.concat(lines, "\n")), label .. ": and the fight lines")
			check(not build.draft or Stub.sees("Draft: every point is checked against the game's talent data, but we have not played this build through yet."
				.. "\n\nYou spend the points yourself in the game's talent window. Trailhead shows where each one goes."),
				label .. ": a draft says it has not been played through")
		end
	end
end)

H.section("builds: mutations fail safe", function()
	local T = H.load({ class = "WARRIOR", level = 30 }, H.checked())
	local B = T.BuildGuide
	local build = B.List()[1]
	check(B.Progress(build).problem == nil, "unchanged, the build is usable")
	local nodeID, talent = next(build.talents)
	local original = talent.spell
	talent.spell = original + 1
	check(B.Progress(build).problem == "changed", "a talent whose spell differs marks the build changed")
	talent.spell = original
	local copy = build.talents[nodeID]
	build.talents[nodeID] = nil
	check(B.Progress(build).problem == "changed", "a step with no talent entry marks it changed")
	build.talents[nodeID] = copy
	build.talents[999999] = { spell = 1, why = "A made-up talent that is not in the tree." }
	check(B.Progress(build).problem == "changed", "a talent that is not in the game's tree marks it changed")
	build.talents[999999] = nil
	Stub.world.spellChanged = nodeID
	check(B.Progress(build).problem == "changed", "the game changing a talent marks it changed")
	Stub.world.spellChanged = nil
	check(B.Progress(build).problem == nil, "and back, it is usable again")
	-- mutate the order so a point goes in before it is open: the legality check must see it
	empty()
	local steps = B.Steps(build)
	local last = steps[#steps]
	local saved = steps[1]
	steps[1], steps[#steps] = last, saved
	check(spend(T, build, 51) ~= nil, "a build in the wrong order is caught by the legality check")
	steps[1], steps[#steps] = saved, last
	empty()
	check(spend(T, build, 51) == nil, "and with the order restored it is legal again")
end)

H.section("builds: the narrow strip", function()
	local T = H.load({ class = "ROGUE", level = 21 }, H.checked())
	local window, B = T.Window, T.BuildGuide
	H.slash("")
	window:Select("builds")
	Stub.flush()
	B.Choose("levelling")
	Stub.click("Open talents")
	local frame = TrailheadWindow
	check(window:IsBeside() == "PlayerSpellsFrame" and frame:IsShown(), "with room, the full window sits beside the talents")
	local function strip()
		return T.modules.builds:Strip()
	end
	check(strip() == nil or not strip():IsShown(), "and no strip is up")
	-- no room for the full window at its smallest, room for the strip
	PlayerSpellsFrame.rect = { 400, 2600, 1084, 201 }
	window:DockTick()
	local log = window.dockLog[#window.dockLog]
	check(log.side == "strip" and not frame:IsShown() and strip() and strip():IsShown(), "with room for only a strip, the strip replaces the window")
	check(Stub.sees("Efficient Strikes"), "and it names the next talent")
	-- the next point moves on
	Stub.world.ranks[105741] = 2
	Stub.fire("TRAIT_CONFIG_UPDATED")
	Stub.flush()
	check(not Stub.sees("Efficient Strikes") or strip():IsShown(), "the strip follows the build")
	-- room again: the window comes back
	PlayerSpellsFrame.rect = { 16, 1170, 1084, 201 }
	window:DockTick()
	check(frame:IsShown() and not strip():IsShown() and window.dockLog[#window.dockLog].side ~= "strip", "with room again, the full window is back and the strip is gone")
	-- not following a build: no strip, the window stays at home
	B.Choose(nil)
	PlayerSpellsFrame.rect = { 400, 2600, 1084, 201 }
	window:DockTick()
	check(frame:IsShown() and not strip():IsShown(), "without a followed build there is no strip")
	-- closing the game window clears it
	B.Choose("levelling")
	window:DockTick()
	check(strip():IsShown() and not frame:IsShown(), "following again, the strip is back")
	PlayerSpellsFrame:Hide()
	window:DockTick()
	check(window:IsBeside() == nil and not strip():IsShown() and frame:IsShown(), "closing the talents removes the strip and brings the window back")
	H.noErrors(T, "the strip")
end)
