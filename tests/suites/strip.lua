-- The narrow strip: with no room beside the talents or the spellbook for the full window even
-- at its smallest size, Trailhead shows a small strip with only what belongs to that window.
local H = ...
local Stub, check = H.Stub, H.check

local ROOMY = { 16, 1170, 1084, 201 } -- room on the right for the whole window
local NARROW = { 400, 2600, 1084, 201 } -- 376 to its left: too little for the window, enough for the strip
local NONE = { 250, 2750, 1084, 201 } -- not even room for the strip

local function texts(frame)
	local out = {}
	for _, text in ipairs(Stub.fontstrings) do
		local parent, visible = text.parent, text.shown
		while parent and parent ~= frame do
			visible = visible and parent.shown
			parent = parent.parent
		end
		if parent and visible and frame.shown and text.text and text.text ~= "" then
			out[#out + 1] = text.text
		end
	end
	return table.concat(out, " | ")
end

local function shows(T, wanted)
	local strip = T.Window:Strip()
	return strip ~= nil and texts(strip):lower():find(wanted:lower(), 1, true) ~= nil
end

H.section("strip: beside the talents, following a build", function()
	local T = H.load({ class = "ROGUE", level = 21 }, H.checked())
	local window, B = T.Window, T.BuildGuide
	local frame
	H.slash("")
	frame = TrailheadWindow
	window:Select("builds")
	Stub.flush()
	B.Choose("levelling")
	Stub.click("Open talents")
	check(window:IsBeside() == "PlayerSpellsFrame" and frame:IsShown() and window:Strip() == nil,
		"with room, the full window sits beside the talents and there is no strip")

	PlayerSpellsFrame.rect = NARROW
	window:DockTick()
	local log = window.dockLog[#window.dockLog]
	local strip = window:Strip()
	check(log.side == "strip" and not frame:IsShown() and strip ~= nil, "with room for only a strip, the strip replaces the window")
	check(shows(T, "Next talent point") and shows(T, "Efficient Strikes") and shows(T, "2 of 2") and shows(T, "row 1 from the top"), "it names the next point of the build")
	local point, parent, relPoint, x, y = unpack(strip.points[#strip.points])
	check(point == "TOPLEFT" and parent == UIParent and relPoint == "BOTTOMLEFT" and x == 2600 + 12 and y == 1084,
		"it sits on the side with room, tops lined up")
	check(frame:GetScale() == T.db.scale, "the full window keeps the player's size")
	PlayerSpellsFrame.rect = { 500, 2800, 1084, 201 }
	window:DockTick()
	point, parent, relPoint, x, y = unpack(strip.points[#strip.points])
	check(window:Strip() and x == 500 - 12 - window.STRIP_W and y == 1084, "with the room on the left, it sits on the left")
	PlayerSpellsFrame.rect = NARROW
	window:DockTick()

	-- a point is spent: the strip moves on
	Stub.world.ranks[105741] = 2
	Stub.fire("TRAIT_CONFIG_UPDATED")
	Stub.flush()
	window:DockTick()
	check(window:Strip() and not shows(T, "Efficient Strikes"), "the strip follows the build")

	-- room again: back to the full window
	PlayerSpellsFrame.rect = ROOMY
	window:DockTick()
	check(frame:IsShown() and window:Strip() == nil and window.dockLog[#window.dockLog].side == "right",
		"with room again, the full window is back and the strip is gone")

	-- no build followed: the talent summary
	B.Choose(nil)
	PlayerSpellsFrame.rect = NARROW
	window:DockTick()
	check(window:Strip() and not frame:IsShown() and shows(T, "Your talents") and shows(T, "Combat"),
		"without a followed build the strip shows where the points are")

	-- the game window closes: back home, no strip
	PlayerSpellsFrame:Hide()
	window:DockTick()
	check(window:IsBeside() == nil and window:Strip() == nil and frame:IsShown(), "closing the talents removes the strip and brings the window back")
	H.noErrors(T, "strip: talents")
end)

H.section("strip: beside the spellbook", function()
	local T = H.load(nil, H.checked())
	local window = T.Window
	H.slash("")
	local frame = TrailheadWindow
	window:Select("spells")
	PlayerSpellsFrame.rect = NARROW
	Stub.click("Open spellbook")
	check(window:IsBeside() == "PlayerSpellsFrame" and not frame:IsShown() and window:Strip(), "no room beside the spellbook: the strip")
	check(shows(T, "Not on your action bars") and shows(T, "Counterspell") and shows(T, "Blink") and not shows(T, "Frostbolt"),
		"it lists the spells that are on no bar")
	check(not shows(T, "Next talent point") and not shows(T, "Your talents"), "and nothing about talents")

	-- a spell goes onto a bar
	Stub.world.onBars[2139] = true
	Stub.fire("ACTIONBAR_SLOT_CHANGED")
	window:DockTick()
	check(shows(T, "Blink") and not shows(T, "Counterspell"), "a spell put on a bar leaves the strip")
	Stub.world.onBars[1953] = true
	Stub.fire("ACTIONBAR_SLOT_CHANGED")
	window:DockTick()
	check(shows(T, "Every class spell you know is on a bar. Nothing to do here."), "with every spell on a bar it says so")

	-- the player turns to the talents tab in the game's window: the strip follows
	PlayerSpellsFrame.tab = 2
	window:DockTick()
	check(shows(T, "Your talents") and not shows(T, "Not on your action bars"), "turning to the talents tab swaps the strip")
	PlayerSpellsFrame.tab = 3
	window:DockTick()
	check(shows(T, "Not on your action bars"), "and back")

	-- a game window that does not show its tabs: the button's own ask decides
	local talents, book = PlayerSpellsFrame.TalentsFrame, PlayerSpellsFrame.SpellBookFrame
	PlayerSpellsFrame.TalentsFrame, PlayerSpellsFrame.SpellBookFrame = nil, nil
	window:Beside("PlayerSpellsFrame", "talents")
	check(shows(T, "Your talents"), "without tabs to measure, the part asked for is shown")
	window:Beside("PlayerSpellsFrame", "spellbook")
	check(shows(T, "Not on your action bars"), "(spellbook)")
	PlayerSpellsFrame.TalentsFrame, PlayerSpellsFrame.SpellBookFrame = talents, book

	-- not even room for the strip: the window stays at home
	PlayerSpellsFrame.rect = NONE
	window:DockTick()
	check(frame:IsShown() and window:Strip() == nil and window.dockLog[#window.dockLog].side == "no room", "no room for the strip either: the window stays at home")
	PlayerSpellsFrame.rect = NARROW
	window:DockTick()
	check(window:Strip() and not frame:IsShown(), "(strip again)")

	-- opening Trailhead while the strip is up brings the full window back home
	H.slash("")
	check(frame:IsShown() and window:Strip() == nil and window:IsBeside() == nil, "opening Trailhead takes down the strip")
	PlayerSpellsFrame:Hide()
	window:DockTick()

	-- the strip's close button closes Trailhead
	PlayerSpellsFrame.rect = NARROW
	Stub.click("Open spellbook")
	check(window:Strip(), "(strip up)")
	window:Close()
	check(not frame:IsShown() and window:Strip() == nil and window:IsBeside() == nil, "closing from the strip closes Trailhead and it stays closed")
	window:DockTick()
	check(not frame:IsShown(), "(still closed)")
	PlayerSpellsFrame:Hide()
	PlayerSpellsFrame.rect = ROOMY
	H.noErrors(T, "strip: spellbook")
end)

H.section("strip: a fight, the switch, the map", function()
	local T = H.load(nil, H.checked())
	local window = T.Window
	H.slash("")
	local frame = TrailheadWindow
	window:Select("spells")
	PlayerSpellsFrame.rect = NARROW
	Stub.click("Open spellbook")
	local strip = window:Strip()
	check(strip and not frame:IsShown(), "(strip up)")

	-- a fight takes the strip down; nothing is shown or moved until it ends
	Stub.combat = true
	Stub.fire("PLAYER_REGEN_DISABLED")
	check(window:Strip() == nil and window:IsBeside() == nil and not frame:IsShown(), "a fight takes the strip down")
	local points = #strip.points
	window:DockTick()
	check(window:Beside("PlayerSpellsFrame", "spellbook") == false and window:Strip() == nil and #strip.points == points and not frame:IsShown(),
		"in a fight nothing docks, shows or moves")
	window:RefreshStrip()
	Stub.fire("ACTIONBAR_SLOT_CHANGED")
	check(window:Strip() == nil and #strip.points == points, "and a changed bar does not bring it back")
	Stub.combat = false
	Stub.fire("PLAYER_REGEN_ENABLED")
	check(frame:IsShown(), "after the fight Trailhead comes back")
	PlayerSpellsFrame:Hide()
	window:DockTick()

	-- docking switched off: no strip either
	T.db.dock = false
	PlayerSpellsFrame.rect = NARROW
	Stub.click("Open spellbook")
	check(window:IsBeside() == nil and window:Strip() == nil and frame:IsShown(), "with docking switched off there is no strip")
	PlayerSpellsFrame:Hide()
	T.db.dock = true
	Stub.click("Open spellbook")
	check(window:Strip(), "(switched on again)")
	-- switching it off in Settings while the strip is up brings the window back
	window:Open("settings")
	check(frame:IsShown() and window:Strip() == nil, "(opening the window takes the strip down)")
	window:Beside("PlayerSpellsFrame", "spellbook")
	check(window:Strip(), "(strip again)")
	T.db.dock = false
	window:Undock()
	check(frame:IsShown() and window:Strip() == nil, "switched off while up, the strip goes and the window is back")
	T.db.dock = true
	PlayerSpellsFrame:Hide()
	PlayerSpellsFrame.rect = ROOMY

	-- the map has no strip: a narrow room leaves the window at home, a full-screen map hides it
	WorldMapFrame.rect = { 300, 2700, 1084, 316 }
	T.Places.ShowMap(52)
	check(window:IsBeside() == "WorldMapFrame" and frame:IsShown() and window:Strip() == nil, "beside the map there is no strip")
	WorldMapFrame.rect = { 0, 2968, 1200, 0 }
	window:DockTick()
	check(not frame:IsShown() and window:Strip() == nil, "a full-screen map hides Trailhead")
	WorldMapFrame:Hide()
	window:DockTick()
	check(frame:IsShown(), "and it is back when the map closes")
	WorldMapFrame.rect = { 16, 1040, 1084, 316 }
	H.noErrors(T, "strip: fight, switch, map")
end)
