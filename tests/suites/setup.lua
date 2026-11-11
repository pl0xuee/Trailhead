-- Screen setup: the suggestions (read, set once, remember, undo), the combat guard, the page,
-- the ways into it and the Home card.
local H = ...
local Stub, check = H.Stub, H.check

local function options(extra)
	local cvars = {
		autoLootDefault = "0", showTargetOfTarget = "0", nameplateShowEnemies = "0",
		statusTextDisplay = "NUMERIC", statusText = "1", lockActionBars = "0", combinedBags = "0",
		displayFreeBagSlots = "0", instantQuestText = "0", questPOI = "0", cameraDistanceMaxZoomFactor = "1.3",
	}
	local opts = { cvars = cvars, bars = { false, false, true, false, false, false, false }, panels = true }
	for key, value in pairs(extra or {}) do
		opts[key] = value
	end
	return opts
end

local TOTAL = 11

local function ids(list)
	local out = {}
	for index, def in ipairs(list) do
		out[index] = def.id
	end
	return table.concat(out, ",")
end

H.section("setup: a bare client offers nothing and breaks nothing", function()
	local T = H.load({ bare = true }, H.checked())
	check(#T.Interface.Offered() == 0, "no options offered without C_CVar")
	local set, total = T.Interface.Counts()
	check(set == 0 and total == 0, "counts are zero")
	check(T.Interface.IsOn("autoloot") == nil, "state unknown")
	check(select(2, T.Interface.Apply("autoloot")) == "missing", "apply says missing")
	check(T.Interface.ApplyAll() == 0 and T.Interface.UndoAll() == 0, "all-buttons do nothing")
	T.Window:Open("setup")
	check(Stub.sees("Screen setup") and Stub.sees("Nothing to set here"), "the page says there is nothing to set")
	check(not T.Advisor.Cards(20)[1] or H.cardIds(T):find("screen") == nil, "no Home card")
	H.noErrors(T, "setup on a bare client")
end)

H.section("setup: options missing from the client are not offered", function()
	local opts = options()
	opts.cvars.questPOI = nil
	opts.cvars.statusText = nil
	local T = H.load(opts, H.checked())
	local offered = ids(T.Interface.Offered())
	check(not offered:find("questpoi") and not offered:find("statustext"), "missing cvars drop their option")
	check(offered:find("autoloot") and offered:find("bar2"), "the others stay")
	local T2 = H.load(options({ barsForced = true }), H.checked())
	check(not ids(T2.Interface.Offered()):find("bar2"), "bars the game forces on are not offered")
	local nobars = options()
	nobars.bars = nil
	local T3 = H.load(nobars, H.checked())
	check(not ids(T3.Interface.Offered()):find("bar2"), "no action bar switch, no bar option")
	H.noErrors(T, "missing options")
end)

H.section("setup: reading state, setting once, undo", function()
	local T = H.load(options(), H.checked())
	local I = T.Interface
	check(#I.Offered() == TOTAL, "all eleven are offered")
	check(I.IsOn("autoloot") == false and I.IsOn("statustext") == false and I.IsOn("bar2") == false, "all start off")
	Stub.cvars.statusTextDisplay, Stub.cvars.statusText = "BOTH", "0"
	check(I.IsOn("statustext") == false, "both status cvars must match")
	Stub.cvars.statusText = "1"
	check(I.IsOn("statustext") == true, "reads on when both match")
	Stub.cvars.statusTextDisplay = "NUMERIC"

	check(I.Apply("autoloot") == true, "a click sets the option")
	check(Stub.cvars.autoLootDefault == "1" and #Stub.cvarLog == 1 and Stub.cvarLog[1] == "autoLootDefault", "exactly that one cvar, once")
	check(T.db.interface.prev.autoloot.autoLootDefault == "0", "the old value is remembered in saved variables")
	local again, why = I.Apply("autoloot")
	check(again == false and why == "already" and #Stub.cvarLog == 1, "a second click changes nothing")
	check(T.db.interface.prev.autoloot.autoLootDefault == "0", "and does not overwrite the old value")
	check(I.Undo("autoloot") == true and Stub.cvars.autoLootDefault == "0", "undo restores it")
	check(T.db.interface.prev.autoloot == nil and select(2, I.Undo("autoloot")) == "nothing", "nothing left to undo")

	-- Two cvars and a value the player chose: both come back exactly.
	I.Apply("statustext")
	check(Stub.cvars.statusTextDisplay == "BOTH" and Stub.cvars.statusText == "1", "status text set")
	Stub.cvars.statusText = "0"
	I.Undo("statustext")
	check(Stub.cvars.statusTextDisplay == "NUMERIC" and Stub.cvars.statusText == "1", "undo restores the earlier values")
	I.Apply("camera")
	check(Stub.cvars.cameraDistanceMaxZoomFactor == "2", "camera set")
	I.Undo("camera")
	check(Stub.cvars.cameraDistanceMaxZoomFactor == "1.3", "the player's own camera value comes back")
	-- 2 and 2.0 are the same distance.
	Stub.cvars.cameraDistanceMaxZoomFactor = "2.0"
	check(I.IsOn("camera") == true and select(2, I.Apply("camera")) == "already", "numbers compare as numbers")

	-- Action bar 2: only the first switch changes.
	Stub.barLog = {}
	check(I.Apply("bar2") == true, "bar 2 set")
	local sent = Stub.barLog[1]
	check(#Stub.barLog == 1 and sent[1] == true and sent[2] == false and sent[3] == true, "other bar switches keep their values")
	check(I.Undo("bar2") == true and Stub.bars[1] == false and Stub.bars[3] == true, "undo puts bar 2 back and leaves bar 4")
	H.noErrors(T, "setup service")
end)

H.section("setup: use all, undo all", function()
	local T = H.load(options(), H.checked())
	local I = T.Interface
	check(I.ApplyAll() == TOTAL, "use all changes all eleven")
	local set, total = I.Counts()
	check(set == TOTAL and total == TOTAL, "all counted as set")
	check(I.ApplyAll() == 0, "using all again changes nothing")
	Stub.cvars.lockActionBars = "0" -- the player turned one off by hand: it is theirs again
	check(I.Counts() == TOTAL - 1, "counts follow the game")
	check(I.UndoAll() == TOTAL, "undo all puts back every remembered value")
	check(Stub.cvars.autoLootDefault == "0" and Stub.cvars.cameraDistanceMaxZoomFactor == "1.3" and Stub.bars[1] == false, "values are the originals")
	check(I.Counts() == 0, "nothing set again")
	H.noErrors(T, "all buttons")
end)

H.section("setup: nothing happens in combat", function()
	local T = H.load(options(), H.checked())
	local I = T.Interface
	I.Apply("nameplates")
	Stub.cvarLog = {}
	Stub.combat = true
	local ok, why = I.Apply("autoloot")
	check(ok == false and why == "combat" and Stub.cvars.autoLootDefault == "0" and #Stub.cvarLog == 0, "apply refuses in combat")
	ok, why = I.Undo("nameplates")
	check(ok == false and why == "combat" and Stub.cvars.nameplateShowEnemies == "1" and #Stub.cvarLog == 0, "undo refuses in combat")
	check(I.ApplyAll() == 0 and I.UndoAll() == 0 and #Stub.cvarLog == 0 and #Stub.barLog == 0, "the all-buttons refuse in combat")
	check(I.OpenManual("morebars") == false and #Stub.panelOpened == 0, "no game panel opens in combat")
	check(H.cardIds(T):find("screen") == nil, "no Home card in combat")
	Stub.combat = false
	check(I.Undo("nameplates") == true and Stub.cvars.nameplateShowEnemies == "0", "after the fight it works, with the old value kept")
	H.noErrors(T, "combat")
end)

H.section("setup: the page", function()
	local T = H.load(options(), H.checked())
	T.Window:Open("setup")
	check(T.Window.current == "setup", "the window shows the page")
	check(Stub.sees("Screen setup") and Stub.sees("0 of 11 are set the suggested way"), "title and count")
	check(Stub.sees("Auto Loot") and Stub.sees("OFF"), "first rows show the game's name and state")
	check(Stub.sees("Undo all") and Stub.sees("Use all suggested settings"), "both buttons are there")
	Stub.click("Turn on", 1)
	check(Stub.cvars.autoLootDefault == "1" and Stub.sees("1 of 11 are set the suggested way"), "a row click sets one option and the count follows")
	check(Stub.sees("ON") and Stub.sees("Undo"), "the row now reads On with an Undo")
	Stub.click("Undo", 1)
	check(Stub.cvars.autoLootDefault == "0" and Stub.sees("0 of 11 are set the suggested way"), "row undo")
	Stub.click("Use all suggested settings")
	check(Stub.sees("11 of 11 are set the suggested way") and Stub.cvars.questPOI == "1", "use all sets everything")
	Stub.click("Undo all")
	check(Stub.sees("0 of 11 are set the suggested way") and Stub.cvars.questPOI == "0", "undo all")
	check(Stub.sees("2 spells are not on your action bars. The Spells page shows which."), "the bars line points to Spells")
	Stub.click("Open Spells")
	check(T.Window.current == "spells", "and opens the Spells page")
	T.Window:Select("setup")
	Stub.combat = true
	Stub.click("Use all suggested settings")
	check(Stub.cvars.autoLootDefault == "0", "the button does nothing in combat")
	Stub.combat = false
	H.noErrors(T, "setup page")
end)

H.section("setup: the ways in", function()
	-- The welcome door.
	local T = H.load(options(), { firstRun = false })
	T.Window:Open()
	check(T.Welcome.IsShown(), "the welcome shows on a first open")
	Stub.click("Set up my screen")
	check(T.Window.current == "setup" and not T.Welcome.IsShown(), "the welcome door opens the page")
	-- Settings.
	T.Window:Select("settings")
	Stub.click("Help and data")
	Stub.click("Set up my screen")
	check(T.Window.current == "setup", "the settings row opens the page")
	-- The Guide topic.
	local info = T.modules.guide.Read("screen")
	check(info and #info.rows >= 3 and info.attention == 1 and info.action, "the Guide topic reads and offers the page")
	T.Window:Select("guide")
	info.action.run()
	check(T.Window.current == "setup", "the Guide topic button opens the page")
	T.Interface.ApplyAll()
	check(T.modules.guide.Read("screen").attention == 0, "the Guide topic is calm once all is set")
	-- The game's own panels.
	local I = T.Interface
	check(I.OpenManual("morebars") and Stub.panelOpened[1] == 7, "Action Bars panel opens by its category id")
	check(I.OpenManual("keys") and Stub.panelOpened[2] == 9, "Key Bindings panel opens")
	check(I.OpenManual("editmode") == false and #Stub.panelOpened == 2, "Edit Mode is explained only, never opened by the addon")
	check(I.OpenManual("preset") == false, "the preset has no opener, it is explained only")
	H.noErrors(T, "ways in")
end)

H.section("setup: the Home card", function()
	local T = H.load(options(), H.checked())
	local ids1 = H.cardIds(T)
	check(ids1:find("screen"), "the card shows for a character with several unset")
	local card
	for _, c in ipairs(T.Advisor.Cards(20)) do
		if c.id == "screen" then card = c end
	end
	check(card.title == "Set up your screen" and card.body:find("^11 quick settings"), "card text counts the open ones")
	card.run()
	check(T.Window.current == "setup", "the card button opens the page")
	T.Advisor.Dismiss(card)
	check(not H.cardIds(T):find("screen"), "dismissing hides the card")
	T.Advisor.Reset()
	check(H.cardIds(T):find("screen"), "reset brings it back")
	-- Two left is not enough to nag about.
	T.Interface.ApplyAll()
	Stub.cvars.autoLootDefault, Stub.cvars.showTargetOfTarget = "0", "0"
	check(not H.cardIds(T):find("screen"), "with two open the card stays away")
	Stub.cvars.nameplateShowEnemies = "0"
	check(H.cardIds(T):find("screen"), "with three open it returns")
	T.Interface.ApplyAll()
	check(not H.cardIds(T):find("screen"), "the card goes away once the options are set")
	H.noErrors(T, "home card")
end)
