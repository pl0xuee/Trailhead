local _, T = ...
local L = T.L
local C = T.Compat

-- Interface: a short list of game options that make a first character easier to play, read
-- and set through the game's own settings (CVars and the action bar switch), never by hand
-- editing anything else. Every option here was found in Blizzard's own settings panels for
-- this build (Blizzard_SettingsDefinitions_Frame, Camelot family), and uses the same name the
-- game's menu uses. Nothing changes without a click; the value the player had is saved so
-- Undo puts back exactly that. An option whose setting the client does not have is not offered.

local I = {}
T.Interface = I

-- The game's own word for a menu item, with our text if the client has none.
local function game(tag, fallback)
	local value = C.Resolve(tag)
	if type(value) == "string" and value ~= "" then
		return value
	end
	return fallback
end

local function menu(group, category)
	return ("%s > %s > %s"):format(game("GAMEMENU_OPTIONS", L["Options"]), game(group, group == "SETTING_GROUP_SYSTEM" and L["System"] or L["Gameplay"]), category)
end

local function gameplay(tag, fallback)
	return menu("SETTING_GROUP_GAMEPLAY", game(tag, fallback))
end

I.GROUPS = {
	{ id = "loot", label = L["Looting"] },
	{ id = "fight", label = L["Fighting"] },
	{ id = "bars", label = L["Bars and bags"] },
	{ id = "quest", label = L["Quests"] },
	{ id = "camera", label = L["Camera"] },
}

-- ---------------------------------------------------------------------------
-- Reading and writing

local function readCVar(name)
	local value = C.Plain(C.Call("C_CVar.GetCVar", name), nil)
	return type(value) == "string" and value or nil
end

local function same(a, b)
	local x, y = tonumber(a), tonumber(b)
	if x and y then
		return x == y
	end
	return a == b
end

-- A definition with `cvars = { { name, value }, ... }`: every one must read as the suggested
-- value for the option to count as on. Missing from the client: not offered.
local function cvarAdapter(def)
	def.read = function()
		local have = {}
		for _, pair in ipairs(def.cvars) do
			local value = readCVar(pair[1])
			if value == nil then
				return nil
			end
			have[pair[1]] = value
		end
		return have
	end
	def.isOn = function(have)
		for _, pair in ipairs(def.cvars) do
			if not same(have[pair[1]], pair[2]) then
				return false
			end
		end
		return true
	end
	def.suggested = function()
		local out = {}
		for _, pair in ipairs(def.cvars) do
			out[pair[1]] = pair[2]
		end
		return out
	end
	def.write = function(values)
		for _, pair in ipairs(def.cvars) do
			local value = values[pair[1]]
			if value ~= nil then
				C.Call("C_CVar.SetCVar", pair[1], value)
			end
		end
	end
end

-- Action Bar 2: the game keeps seven yes/no switches for bars 2 to 8 and sets them all at once
-- (the settings panel does the same, see ActionBars.lua). Only the first is read and changed.
local function barsAdapter(def)
	def.read = function()
		if not (C.Has("GetActionBarToggles") and C.Has("SetActionBarToggles")) or C.Call("C_GameRules.IsMultiActionBarVisibilityForced") == true then
			return nil
		end
		local toggles = { C.Call("GetActionBarToggles") }
		if toggles[1] == nil and #toggles == 0 then
			return nil
		end
		return { bar2 = (toggles[1] == true or toggles[1] == 1) }
	end
	def.isOn = function(have)
		return have.bar2 == true
	end
	def.suggested = function()
		return { bar2 = true }
	end
	def.write = function(values)
		local toggles = { C.Call("GetActionBarToggles") }
		local out = {}
		for index = 1, 7 do
			out[index] = toggles[index] and true or false
		end
		out[1] = values.bar2 == true
		C.Call("SetActionBarToggles", unpack(out, 1, 7))
	end
end

-- ---------------------------------------------------------------------------
-- The list

local DEFS = {
	{ id = "autoloot", group = "loot", cvars = { { "autoLootDefault", "1" } },
		name = game("AUTO_LOOT_DEFAULT_TEXT", "Auto Loot"),
		menu = gameplay("CONTROLS_LABEL", "Controls"),
		why = L["One click on a defeated enemy picks up everything, so you never miss loot."] },
	{ id = "totarget", group = "fight", cvars = { { "showTargetOfTarget", "1" } },
		name = game("SHOW_TARGET_OF_TARGET_TEXT", "Target of Target"),
		menu = gameplay("COMBAT_LABEL", "Combat"),
		why = L["Shows who your enemy is attacking, so you can tell if it is coming for you."] },
	{ id = "nameplates", group = "fight", cvars = { { "nameplateShowEnemies", "1" } },
		name = game("UNIT_NAMEPLATES_SHOW_ENEMIES", "Enemy Unit Nameplate"),
		menu = gameplay("NAMEPLATE_OPTIONS_LABEL", "Nameplates"),
		why = L["Puts a small health bar over each enemy, so you can see how a fight is going."] },
	{ id = "statustext", group = "fight", cvars = { { "statusTextDisplay", "BOTH" }, { "statusText", "1" } },
		name = game("STATUSTEXT_LABEL", "Status Text") .. ": " .. game("STATUS_TEXT_BOTH", "Both"),
		menu = gameplay("INTERFACE_LABEL", "Interface"),
		why = L["Writes your health and mana as numbers and percentages on the bars."] },
	{ id = "bar2", group = "bars", bars = true,
		name = (game("OPTION_SHOW_ACTION_BAR", "Action Bar %d")):format(2),
		menu = gameplay("ACTIONBARS_LABEL", "Action Bars"),
		why = L["A second row of buttons for your spells. Empty at first: you fill it from your spellbook."],
		note = L["The Spells page lists spells that are not on any bar yet."],
		link = "spells" },
	{ id = "lockbars", group = "bars", cvars = { { "lockActionBars", "1" } },
		name = game("LOCK_ACTIONBAR_TEXT", "Lock Action Bars"),
		menu = gameplay("ACTIONBARS_LABEL", "Action Bars"),
		why = L["Stops you from dragging spells off your bars by accident. Hold the pick up key (Shift unless you changed it) to move one."] },
	{ id = "combinedbags", group = "bars", cvars = { { "combinedBags", "1" } },
		name = game("USE_COMBINED_BAGS_TEXT", "Combine Bags"),
		menu = menu("SETTING_GROUP_SYSTEM", game("PRESET_LABEL", "Preset")),
		why = L["Shows all your bags as one window, so there is only one place to look."] },
	{ id = "freebags", group = "bars", cvars = { { "displayFreeBagSlots", "1" } },
		name = game("DISPLAY_FREE_BAG_SLOTS", "Show Free Bag Space"),
		menu = gameplay("INTERFACE_LABEL", "Interface"),
		why = L["Shows how many bag slots are left on the backpack button, so you know when to sell."] },
	{ id = "instanttext", group = "quest", cvars = { { "instantQuestText", "1" } },
		name = game("SHOW_QUEST_FADING_TEXT", "Instant Quest Text"),
		menu = gameplay("INTERFACE_LABEL", "Interface"),
		why = L["Quest text appears all at once instead of letter by letter, so you can read at your own speed."] },
	{ id = "questpoi", group = "quest", cvars = { { "questPOI", "1" } },
		name = game("OPTIONS_MENU_QUEST_POIS_TEXT", "Show Quest POIs & Blobs"),
		menu = menu("SETTING_GROUP_SYSTEM", game("PRESET_LABEL", "Preset")),
		why = L["Marks where your quest objectives are on the map and the minimap."] },
	{ id = "camera", group = "camera", cvars = { { "cameraDistanceMaxZoomFactor", "2" } },
		name = game("MAX_FOLLOW_DIST", "Max Camera Distance"),
		menu = gameplay("CONTROLS_LABEL", "Controls"),
		why = L["Lets you zoom the camera out further, so you see enemies before they see you."] },
}

I.defs = {}
I.byId = {}
for _, def in ipairs(DEFS) do
	if def.bars then
		barsAdapter(def)
	else
		cvarAdapter(def)
	end
	I.defs[#I.defs + 1] = def
	I.byId[def.id] = def
end

-- Things the addon leaves to the game's own screens, each with a short instruction.
-- `open` is the game's panel it can bring up, when there is one.
local function openSettings(key)
	return function()
		local id = C.Resolve("Settings." .. key)
		if type(id) == "number" and C.Has("Settings.OpenToCategory") then
			C.Call("Settings.OpenToCategory", id)
			return true
		end
		return false
	end
end

-- Edit Mode is explained, never opened from here: a panel opened by an addon runs as addon
-- code, and Edit Mode then blocks protected actions (the game's "interface action failed").
I.manual = {
	{ id = "editmode", name = game("HUD_EDIT_MODE_MENU", "Edit Mode"), menu = L["Game Menu > Edit Mode"],
		why = L["Move and resize the bars, the minimap and the chat window. Press Escape and choose Edit Mode; Trailhead cannot do this for you."] },
	{ id = "morebars", name = game("ACTIONBARS_LABEL", "Action Bars"), menu = gameplay("ACTIONBARS_LABEL", "Action Bars"),
		why = L["Switch on Action Bars 3 to 8 here when you have more spells than room."],
		button = L["Open Action Bars"], open = openSettings("ACTION_BAR_CATEGORY_ID"),
		can = function() return type(C.Resolve("Settings.ACTION_BAR_CATEGORY_ID")) == "number" and C.Has("Settings.OpenToCategory") end },
	{ id = "keys", name = game("KEY_BINDINGS", "Key Bindings"), menu = game("GAMEMENU_OPTIONS", L["Options"]) .. " > " .. game("KEY_BINDINGS", "Key Bindings"),
		why = L["Choose which key does what. Trailhead does not change keys."],
		button = L["Open Key Bindings"], open = openSettings("KEYBINDINGS_CATEGORY_ID"),
		can = function() return type(C.Resolve("Settings.KEYBINDINGS_CATEGORY_ID")) == "number" and C.Has("Settings.OpenToCategory") end },
	{ id = "preset", name = game("PRESET_LABEL", "Preset"), menu = menu("SETTING_GROUP_SYSTEM", game("PRESET_LABEL", "Preset")),
		why = L["Classic or Enhanced: two ready-made sets of settings for how the game looks and plays. Read the buttons there before you pick."] },
}

function I.OpenManual(id)
	if C.InCombat() then
		return false
	end
	for _, item in ipairs(I.manual) do
		if item.id == id and item.open then
			return item.open() and true or false
		end
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Remembered values

local function store()
	local db = T.db
	if type(db.interface) ~= "table" then
		db.interface = {}
	end
	if type(db.interface.prev) ~= "table" then
		db.interface.prev = {}
	end
	return db.interface.prev
end

-- The options this client can read, in list order.
function I.Offered()
	local out = {}
	for _, def in ipairs(I.defs) do
		local ok, have = pcall(def.read)
		if ok and have then
			out[#out + 1] = def
		end
	end
	return out
end

-- true when set the suggested way, false when not, nil when the client cannot say.
function I.IsOn(id)
	local def = I.byId[id]
	if not def then
		return nil
	end
	local ok, have = pcall(def.read)
	if not ok or not have then
		return nil
	end
	return def.isOn(have)
end

-- Whether an old value is saved, so Undo has something to put back.
function I.CanUndo(id)
	return store()[id] ~= nil
end

-- Sets one option the suggested way. Returns true, or false and a reason:
-- "combat", "missing", "already" or "failed".
function I.Apply(id)
	if C.InCombat() then
		return false, "combat"
	end
	local def = I.byId[id]
	local ok, have = pcall(def and def.read or function() end)
	if not def or not ok or not have then
		return false, "missing"
	end
	if def.isOn(have) then
		return false, "already"
	end
	store()[id] = have
	def.write(def.suggested())
	T:Fire("TH_INTERFACE_CHANGED", id)
	T:Fire("TH_ADVICE_CHANGED")
	return true
end

-- Puts back what the player had. Same results as Apply, with "nothing" when nothing is saved.
function I.Undo(id)
	if C.InCombat() then
		return false, "combat"
	end
	local def = I.byId[id]
	local prev = store()[id]
	if not def then
		return false, "missing"
	elseif not prev then
		return false, "nothing"
	end
	def.write(prev)
	store()[id] = nil
	T:Fire("TH_INTERFACE_CHANGED", id)
	T:Fire("TH_ADVICE_CHANGED")
	return true
end

-- Every offered option that is not set yet. Returns how many changed.
function I.ApplyAll()
	if C.InCombat() then
		return 0, "combat"
	end
	local changed = 0
	for _, def in ipairs(I.Offered()) do
		if I.Apply(def.id) then
			changed = changed + 1
		end
	end
	return changed
end

function I.UndoAll()
	if C.InCombat() then
		return 0, "combat"
	end
	local changed = 0
	for _, def in ipairs(I.defs) do
		if I.CanUndo(def.id) and I.Undo(def.id) then
			changed = changed + 1
		end
	end
	return changed
end

-- set: how many offered options are already the suggested way; total: how many are offered.
function I.Counts()
	local set, total = 0, 0
	for _, def in ipairs(I.Offered()) do
		total = total + 1
		if I.IsOn(def.id) then
			set = set + 1
		end
	end
	return set, total
end

function I.Open()
	T.Window:Open("setup")
end
