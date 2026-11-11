-- Regression tests from the real-client review.
local H = ...
local Stub = H.Stub

H.section("review: logout inside a dungeon", function()
	local T = H.load()
	local D, world = T.Dungeons, Stub.world
	world.instance = { name = "Wailing Caverns", kind = "party" }
	_G.GetInstanceInfo = function()
		return "Wailing Caverns", "party", 1, "Normal", 5, 0, false, 43
	end
	Stub.fire("PLAYER_ENTERING_WORLD")
	Stub.fire("BOSS_KILL", 585, "Lady Anacondra")
	H.check(D.Killed(43, "Lady Anacondra"), "a boss is ticked")
	Stub.fire("PLAYER_LOGOUT")
	H.check(type(T.cdb.dungeonRun.leftAt) == "number", "logging out inside stamps the run")
	world.instance = nil
	Stub.fire("PLAYER_ENTERING_WORLD")
	T.cdb.dungeonRun.leftAt = time() - 7200
	world.instance = { name = "Wailing Caverns", kind = "party" }
	Stub.fire("PLAYER_ENTERING_WORLD")
	H.check(D.Progress(43) == 0, "a run from long ago is not taken up again")
	H.noErrors(T, "logout")
end)
