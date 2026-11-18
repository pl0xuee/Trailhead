-- Home's advice: the level talents open at (Services/Game.lua, read the way the game's own
-- talent button reads it on Forever) and the cards' buttons.
local H = ...
local Stub, check = H.Stub, H.check

local function findCard(T, id)
	for _, item in ipairs(T.Advisor.Cards(20)) do
		if item.id == id then
			return item
		end
	end
	return nil
end

H.section("advice: talents open at the game's own level", function()
	local T = H.load({ level = 5 }, H.checked(), {})
	local G = T.Game
	check(_G.Constants == nil and G.TalentUnlockLevel() == 10 and G.FIRST_TALENT_LEVEL == 10, "no constants from the game: level 10")

	-- Forever's numbers (build 1.60.1): MIN_TALENT_LEVEL 10, Legacy Adventure tree 1188, node 110298.
	local rank = 0
	_G.Constants = {
		LevelConstsExposed = { MIN_TALENT_LEVEL = 10 },
		LegacyConsts = { LEGACY_TREE_ADVENTURE_ID = 1188, LEGACY_TREE_ADVENTURE_TALENTED_NODE_ID = 110298 },
	}
	local asked = {}
	C_Traits.GetConfigIDByTreeID = function(tree)
		asked.tree = tree
		return tree == 1188 and 4242 or nil
	end
	local realNode = C_Traits.GetNodeInfo
	C_Traits.GetNodeInfo = function(config, node)
		if config == 4242 then
			asked.node = node
			return { ID = node, activeRank = rank }
		end
		return realNode(config, node)
	end
	check(G.TalentUnlockLevel() == 10 and asked.tree == 1188 and asked.node == 110298, "no rank in the Legacy node: still 10, asked of the right tree and node")
	rank = 2
	check(G.TalentUnlockLevel() == 8, "two ranks: talents at 8")
	check(G.FIRST_TALENT_LEVEL == 10, "the kept level waits for the game's word")
	Stub.fire("TRAIT_CONFIG_UPDATED", 4242)
	check(G.FIRST_TALENT_LEVEL == 8, "a change in the trees updates it")
	H.slash("")
	Stub.flush()
	check(Stub.sees("Level 8: first talent point"), "Home's milestone follows")
	local step
	for _, item in ipairs(T.FirstSteps.List()) do
		if item.id == "talent" then
			step = item
		end
	end
	check(step and step.text == "Spend your first talent point (level 8)", "and so does First steps")
	rank = 20
	check(G.TalentUnlockLevel() == 1, "never below level 1")
	rank = Stub.SECRET
	check(G.TalentUnlockLevel() == 10, "a secret rank: the default")
	_G.Constants.LevelConstsExposed.MIN_TALENT_LEVEL = Stub.SECRET
	rank = 0
	check(G.TalentUnlockLevel() == 10, "a secret base level: the default")
	_G.Constants.LevelConstsExposed.MIN_TALENT_LEVEL = 10
	C_Traits.GetConfigIDByTreeID = function() return nil end
	check(G.TalentUnlockLevel() == 10, "no Legacy tree: the game's base level")
	C_Traits.GetConfigIDByTreeID = function() error("no") end
	Stub.fire("PLAYER_LEVEL_UP", 6)
	check(G.FIRST_TALENT_LEVEL == 10, "a failing call leaves the default")
	_G.Constants = nil
	T.db.errors = {}
end)

H.section("advice: the action bars card opens the spellbook", function()
	local T = H.load(nil, H.checked())
	local bars = findCard(T, "bars")
	check(bars and bars.action == "Open spellbook" and bars.secure == "spellbook" and type(bars.run) == "function",
		"the button says what it opens, through the safe opener, with a fallback")
	H.noErrors(T, "bars card")
end)
