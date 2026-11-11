-- Dungeon route helper: the shipped index and guides, name matching, the shipped door,
-- where the player is, boss ticks, the page, the Home card.
local H = ...
local Stub = H.Stub

local function inside(world, name, id, kind)
	world.instance = { name = name, kind = kind or "party" }
	_G.GetInstanceInfo = function()
		return name, kind or "party", 1, "Normal", 5, 0, false, id
	end
end

H.section("dungeons: shipped data", function()
	local T = H.load()
	local D = T.Dungeons
	local index, guides = T.DungeonIndex, T.DungeonGuides
	local count = 0
	for id, entry in pairs(index) do
		count = count + 1
		H.check(type(entry.name) == "string" and (entry.kind == "dungeon" or entry.kind == "raid") and type(entry.size) == "number"
			and type(entry.bosses) == "table", "index entry " .. id .. " is well formed")
		if entry.entrance then
			local e = entry.entrance
			H.check(type(e.m) == "number" and e.x >= 0 and e.x <= 1 and e.y >= 0 and e.y <= 1, entry.name .. ": the door is on its zone map")
		end
	end
	H.check(count >= 30 and index[389] and index[43] and index[389].entrance.m == 1454, "the index holds the game's dungeons and raids")
	local guided = 0
	for id, guide in pairs(guides) do
		guided = guided + 1
		local entry = index[id]
		H.check(entry ~= nil, "guide " .. id .. " belongs to an index entry")
		if entry then
			local name = entry.name
			local known, seen = {}, {}
			for _, boss in ipairs(entry.bosses) do
				known[boss.name] = true
			end
			H.check(type(guide.summary) == "string" and #guide.summary <= 200, name .. ": summary fits")
			H.check(guide.door == nil or (type(guide.door) == "string" and #guide.door <= 200), name .. ": door fits")
			H.check(#(guide.tips or {}) <= 3, name .. ": at most three tips")
			for _, tip in ipairs(guide.tips or {}) do
				H.check(#tip <= 140, name .. ": tip fits: " .. tip)
			end
			H.check(type(guide.steps) == "table" and #guide.steps > 0, name .. ": has steps")
			local all = { guide.summary or "", guide.door or "" }
			for _, tip in ipairs(guide.tips or {}) do
				all[#all + 1] = tip
			end
			for _, step in ipairs(guide.steps or {}) do
				if step.boss then
					H.check(known[step.boss], name .. ": boss in the index: " .. step.boss)
					H.check(not seen[step.boss], name .. ": boss once: " .. step.boss)
					seen[step.boss] = true
					H.check(type(step.where) == "string" and #step.where <= 140, name .. ": where fits for " .. step.boss)
					H.check(step.tip == nil or #step.tip <= 140, name .. ": tip fits for " .. step.boss)
					all[#all + 1] = (step.where or "") .. (step.tip or "")
				else
					H.check(type(step.text) == "string" and #step.text <= 170, name .. ": step fits: " .. tostring(step.text))
					all[#all + 1] = step.text or ""
				end
			end
			for _, boss in ipairs(entry.bosses) do
				H.check(seen[boss.name], name .. ": index boss in the steps: " .. boss.name)
			end
			for _, text in ipairs(all) do
				H.check(not text:find("\226\128\148", 1, true), name .. ": no em dash")
			end
		end
	end
	H.check(guided >= 11, "the lower dungeons are guided")
	H.noErrors(T, "dungeon data")
end)

H.section("dungeons: names and doors", function()
	local T = H.load()
	local D, G = T.Dungeons, T.Game
	local cases = {
		["Stormwind Stockades"] = 34, ["Stormwind Stockade"] = 34, ["The Stockade"] = 34, ["Zul'Farak"] = 209, ["Zul'Farrak"] = 209,
		["Dire Maul - East"] = 429, ["Dire Maul - North"] = 429, ["Lower Blackrock Spire"] = 229, ["Upper Blackrock Spire"] = 229,
		["Onyxia"] = 249, ["Onyxia's Lair"] = 249, ["The Deadmines"] = 36, ["Deadmines"] = 36, ["Scarlet Monastery: Library"] = 189,
		["Scarlet Monastery"] = 189, ["Temple of Atal'Hakkar"] = 109, ["The Temple of Atal'Hakkar"] = 109, ["Ragefire Chasm"] = 389,
		["Molten Core"] = 409, ["Excavation Site: Wetlands"] = 2998, ["Ruins of Ahn'Qiraj"] = 509,
	}
	for name, id in pairs(cases) do
		H.check(D.Find(name) == id, "group finder name " .. name .. " finds " .. id)
	end
	H.check(D.Has("The Deadmines") and not D.Has("Warsong Gulch") and not D.Has("") and not D.Has(nil) and not D.Has("Black"), "Has says yes only for a dungeon")
	local got = D.Get("Wailing Caverns")
	H.check(got and got.id == 43 and got.guide and got.summary and #got.bosses == 8 and got.steps and got.entrance.m == 1413, "Get merges index and guide")
	local bare = D.Get("Manor Mistmantle")
	H.check(bare and not bare.guide and bare.steps == nil and #bare.tips == 0 and bare.bosses ~= nil, "a dungeon without a guide still comes from the index")
	H.check(D.Get(43).name == "Wailing Caverns" and D.Get("Nowhere") == nil, "Get takes an id too")
	-- the shipped door is the fallback; a door the player has seen wins
	local door = G.Entrance("The Deadmines")
	H.check(door and door.map == 1436 and door.x > 0.37 and door.x < 0.39, "the shipped door answers when nobody has walked in")
	H.check(G.Entrance("Zul'Farak") ~= nil and G.Entrance("Nowhere") == nil and G.Entrance(nil) == nil, "by group finder spelling, and nothing for nothing")
	T.db.entrances = { deadmines = { n = "The Deadmines", k = "party", spots = { { m = 52, x = 0.56, y = 0.47, c = 1 } } } }
	door = G.Entrance("The Deadmines")
	H.check(door.map == 52 and door.x == 0.56, "a door the player has seen wins over the shipped one")
	H.check(G.Entrance("Ragefire Chasm").map == 1454, "other dungeons still use the shipped door")
	T.DungeonIndex = {}
	H.check(not D.Has("The Deadmines") and G.Entrance("Ragefire Chasm") == nil, "without an index there is nothing, and no error")
	H.noErrors(T, "dungeon names")
end)

H.section("dungeons: the run", function()
	local T = H.load()
	local D, world = T.Dungeons, Stub.world
	H.check(D.Current() == nil, "not in a dungeon to begin with")
	inside(world, "Wailing Caverns", 43)
	Stub.fire("PLAYER_ENTERING_WORLD")
	local here = D.Current()
	H.check(here and here.id == 43 and here.name == "Wailing Caverns", "walking in is noticed")
	H.check(D.Progress(43) == 0 and D.Next(43).name == "Lady Anacondra", "no boss down, the first is next")
	Stub.fire("BOSS_KILL", 585, "Lady Anacondra")
	H.check(D.Killed(43, "Lady Anacondra") and not D.Killed(43, "Lord Cobrahn"), "a boss kill ticks the boss")
	H.check(D.Next(43).name == "Lord Cobrahn", "the next boss moves on")
	Stub.fire("ENCOUNTER_END", 586, "Lord Cobrahn", 1, 5, 0)
	H.check(not D.Killed(43, "Lord Cobrahn"), "a wipe ticks nothing")
	Stub.fire("ENCOUNTER_END", 586, "Lord Cobrahn", 1, 5, 1)
	H.check(D.Killed(43, "Lord Cobrahn"), "a won encounter ticks the boss")
	Stub.fire("BOSS_KILL", 99999, "Somebody Else")
	Stub.fire("BOSS_KILL", 1, "Kresh")
	H.check(select(1, D.Progress(43)) == 3, "a boss of another place changes nothing, one by name counts")
	H.check(D.Next(43).name == "Lord Pythas", "an optional boss is not next while others are alive")
	-- out and back in: the ticks stay, as after a wipe and a corpse run
	world.instance = nil
	Stub.fire("PLAYER_ENTERING_WORLD")
	H.check(D.Current() == nil and not D.Killed(43, "Kresh"), "outside, nothing is ticked")
	inside(world, "Wailing Caverns", 43)
	Stub.fire("PLAYER_ENTERING_WORLD")
	H.check(D.Killed(43, "Lady Anacondra"), "walking back in soon after keeps the ticks")
	-- the leader resets it
	world.instance = nil
	Stub.fire("PLAYER_ENTERING_WORLD")
	Stub.fire("CHAT_MSG_SYSTEM", "Wailing Caverns has been reset.")
	inside(world, "Wailing Caverns", 43)
	Stub.fire("PLAYER_ENTERING_WORLD")
	H.check(D.Progress(43) == 0, "a reset message starts the run again")
	Stub.fire("BOSS_KILL", 585, "Lady Anacondra")
	-- too long away
	world.instance = nil
	Stub.fire("PLAYER_ENTERING_WORLD")
	T.cdb.dungeonRun.leftAt = time() - 7200
	inside(world, "Wailing Caverns", 43)
	Stub.fire("PLAYER_ENTERING_WORLD")
	H.check(D.Progress(43) == 0, "after a long time away the run starts again")
	-- another place
	inside(world, "The Deadmines", 36)
	Stub.fire("PLAYER_ENTERING_WORLD")
	H.check(D.Current().id == 36 and not D.Killed(36, "Rhahk'Zor"), "another dungeon, another run")
	-- found by name when the game gives no id; unknown places are ignored
	_G.GetInstanceInfo = function() return "Dire Maul - East", "party" end
	world.instance = { name = "Dire Maul - East", kind = "party" }
	Stub.fire("PLAYER_ENTERING_WORLD")
	H.check(D.Current() and D.Current().id == 429, "found by name without an id")
	inside(world, "Some Scenario", 99999, "scenario")
	Stub.fire("PLAYER_ENTERING_WORLD")
	H.check(D.Current() == nil, "a scenario is not a dungeon")
	H.noErrors(T, "dungeon run")
end)

H.section("dungeons: nothing in combat", function()
	local T = H.load()
	local D, world = T.Dungeons, Stub.world
	inside(world, "Wailing Caverns", 43)
	Stub.combat = true
	Stub.fire("PLAYER_ENTERING_WORLD")
	H.check(D.Current() == nil, "walking in during combat is not read")
	Stub.combat = false
	Stub.fire("PLAYER_ENTERING_WORLD")
	H.check(D.Current() and D.Current().id == 43, "and is read afterwards")
	Stub.combat = true
	Stub.fire("BOSS_KILL", 585, "Lady Anacondra")
	Stub.combat = false
	H.check(D.Killed(43, "Lady Anacondra"), "a kill that ends a fight still counts")
	-- the page leaves itself alone while fighting
	T.Window:Open("dungeon", "Wailing Caverns")
	Stub.flush()
	local count = 0
	local refresh = T.modules.dungeon.Refresh
	T.modules.dungeon.Refresh = function(...)
		count = count + 1
		return refresh(...)
	end
	Stub.combat = true
	Stub.fire("BOSS_KILL", 586, "Lord Cobrahn")
	Stub.flush()
	H.check(count == 0, "the page does not redraw in combat")
	Stub.combat = false
	H.noErrors(T, "dungeon combat")
end)

H.section("dungeons: the page", function()
	local T = H.load(nil, H.checked())
	local D, world = T.Dungeons, Stub.world
	T.Window:Open("home")
	T.Window:Select("dungeon", "Wailing Caverns")
	H.check(T.Window.current == "dungeon" and T.modules.dungeon.page:IsVisible(), "the page opens by group finder name")
	H.check(Stub.sees("Wailing Caverns") and Stub.sees("A group of 5  \194\183  8 bosses"), "the name, size and bosses show")
	H.check(Stub.sees(T.DungeonGuides[43].summary), "the summary shows")
	H.check(Stub.sees("Inside the dungeon, this page ticks off each boss as it falls."), "outside, it says what it does inside")
	H.check(Stub.sees("Set marker") and Stub.sees("How to get there"), "the door has its buttons")
	Stub.click("Set marker")
	H.check(T.Window.current == "dungeon", "the marker button works")
	Stub.click("Back")
	H.check(T.Window.current == "home", "Back returns")
	-- inside: the next boss is named and the page starts on it
	inside(world, "Wailing Caverns", 43)
	Stub.fire("PLAYER_ENTERING_WORLD")
	Stub.flush()
	T.Window:Select("dungeon", "Wailing Caverns")
	H.check(Stub.sees("Next boss: Lady Anacondra  (0 of 8 down)"), "inside, the next boss is named")
	H.check(Stub.sees("Lady Anacondra") and (Stub.sees("Next") or Stub.sees("NEXT")), "and marked in the list")
	Stub.fire("BOSS_KILL", 585, "Lady Anacondra")
	Stub.flush()
	H.check(Stub.sees("Next boss: Lord Cobrahn  (1 of 8 down)") and (Stub.sees("Down") or Stub.sees("DOWN")), "after the kill the page ticks the boss and moves on")
	for _, name in ipairs({ "Lord Cobrahn", "Kresh", "Lord Pythas", "Skum", "Lord Serpentis", "Verdan the Everliving", "Mutanus the Devourer" }) do
		Stub.fire("BOSS_KILL", 0, name)
	end
	Stub.flush()
	H.check(Stub.sees("Every boss is down. Well done!"), "when all are down it says so")
	-- no guide: the index alone
	T.Window:Select("dungeon", "Manor Mistmantle")
	H.check(Stub.sees("Trailhead has no written route for this place yet. The bosses are listed below, in the order the game lists them."), "a dungeon without a guide still gets a page")
	-- unknown name changes nothing
	T.Window:Select("dungeon", "Nowhere")
	H.check(T.Window.current == "dungeon" and Stub.sees("Manor Mistmantle"), "an unknown name keeps the page as it was")
	-- search offers the route
	world.instance = nil
	Stub.fire("PLAYER_ENTERING_WORLD")
	T.Window:Select("find")
	T.modules.find:SetQuery("deadmines")
	Stub.flush()
	Stub.click("Route")
	H.check(T.Window.current == "dungeon" and Stub.sees("Deadmines"), "a search result opens the route")
	H.noErrors(T, "dungeon page")
end)

H.section("dungeons: the Home card", function()
	local T = H.load(nil, H.checked())
	local world = Stub.world
	local function ids()
		return H.cardIds(T)
	end
	H.check(not ids():find("indungeon", 1, true), "no card outside a dungeon")
	inside(world, "Wailing Caverns", 43)
	Stub.fire("PLAYER_ENTERING_WORLD")
	Stub.flush()
	local card
	for _, c in ipairs(T.Advisor.Cards(20)) do
		card = c.id == "indungeon" and c or card
	end
	H.check(card and card.title == "You are in Wailing Caverns" and card.action == "Open the route"
		and card.body:find("Lady Anacondra", 1, true), "inside, a card offers the route and names the next boss")
	card.run()
	H.check(T.Window.current == "dungeon", "the card opens the route")
	world.instance = nil
	Stub.fire("PLAYER_ENTERING_WORLD")
	H.check(not ids():find("indungeon", 1, true), "the card goes when you leave")
	inside(world, "Test Place", 99999)
	Stub.fire("PLAYER_ENTERING_WORLD")
	H.check(not ids():find("indungeon", 1, true), "and there is none for a place the index lacks")
	H.noErrors(T, "dungeon card")
end)
