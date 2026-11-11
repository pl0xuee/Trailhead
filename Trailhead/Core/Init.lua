local ADDON, T = ...
local L = T.L

-- Trailhead, the new player companion for World of Warcraft: Forever.
-- This file: the shared namespace, the event and message bus, the module registry and the
-- ways in (slash command, key binding, addon compartment).

_G.Trailhead = T
T.addon = ADDON
T.version = "dev"
T.modules = {} -- id -> module
T.moduleList = {} -- in the order they registered
T.missingEvents = {} -- game events this client does not know

do
	local get = C_AddOns and C_AddOns.GetAddOnMetadata
	local ok, version = pcall(function()
		return get and get(ADDON, "Version")
	end)
	if ok and type(version) == "string" then
		T.version = version
	end
end

function T:Print(text)
	local frame = DEFAULT_CHAT_FRAME
	if frame and frame.AddMessage then
		frame:AddMessage("|cfff6bd55Trailhead|r: " .. tostring(text))
	end
end

-- Errors are kept in the saved variables (newest 40) so they can be read from disk later,
-- and are also handed to the game's error handler so they show while developing.
function T:LogError(where, err)
	local text = tostring(err)
	local db = TrailheadDB
	if type(db) ~= "table" then
		return
	end
	if type(db.errors) ~= "table" then
		db.errors = {}
	end
	local list = db.errors
	local last = list[#list]
	if last and last.err == text and last.where == where then
		last.count = (last.count or 1) + 1
		return
	end
	list[#list + 1] = { at = time(), where = tostring(where), err = text, v = T.version }
	while #list > 40 do
		table.remove(list, 1)
	end
end

local function fail(where, err)
	T:LogError(where, err)
	local handler = geterrorhandler and geterrorhandler()
	if handler then
		pcall(handler, err)
	end
end

-- Runs fn; a failure is logged and never breaks the caller.
function T.SafeCall(where, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		fail(where, err)
	end
	return ok
end
local safecall = T.SafeCall

-- Event and message bus. Names starting with TH_ are Trailhead's own messages; everything
-- else is a game event and is registered with the client on first use.
local bus = CreateFrame("Frame")
local handlers = {}

function T:On(event, fn)
	local list = handlers[event]
	if not list then
		list = {}
		handlers[event] = list
		if event:sub(1, 3) ~= "TH_" then
			if not pcall(bus.RegisterEvent, bus, event) then
				T.missingEvents[event] = true
			end
		end
	end
	list[#list + 1] = fn
end

function T:Fire(event, ...)
	local list = handlers[event]
	if not list then
		return
	end
	for i = 1, #list do
		safecall(event, list[i], ...)
	end
end

bus:SetScript("OnEvent", function(_, event, ...)
	T:Fire(event, ...)
end)

-- A module is one feature. One with a `tab` gets a button on the window's rail.
-- Contract (all optional): OnInit() once at login, Build(page) the first time its page is
-- shown, Refresh() every time its page is shown or its data changes.
function T:NewModule(id, tab)
	local module = { id = id, tab = tab }
	T.modules[id] = module
	T.moduleList[#T.moduleList + 1] = module
	return module
end

function T:ToggleWindow()
	T.Window:Toggle()
end

T:On("ADDON_LOADED", function(name)
	if name ~= ADDON then
		return
	end
	T:InitDB()
	T.Theme:Set(T.db.theme, true)
end)

T:On("PLAYER_LOGIN", function()
	for _, module in ipairs(T.moduleList) do
		if module.OnInit then
			safecall(module.id .. ".OnInit", module.OnInit, module)
		end
	end
	T:UpdateMinimapButton()
	if T.db.firstRun then
		T.db.firstRun = false
		T:Print(L["Welcome! Click the minimap button or type /th to open Trailhead."])
	end
	T:Fire("TH_READY")
end)

-- Slash commands.
local function help()
	T:Print(L["Commands:"])
	T:Print("  /th  -  " .. L["open or close Trailhead"])
	T:Print("  /th settings  -  " .. L["open the settings"])
	T:Print("  /th theme night | journal | ember  -  " .. L["change the look"])
	T:Print("  /th find bank  -  " .. L["search for a place, a zone or a dungeon"])
	T:Print("  /th clear  -  " .. L["remove the map marker"])
	T:Print("  /th check  -  " .. L["run the game check"])
	T:Print("  /th reset  -  " .. L["move the window back to the middle"])
end

SLASH_TRAILHEAD1 = "/trailhead"
SLASH_TRAILHEAD2 = "/th"
SlashCmdList["TRAILHEAD"] = function(message)
	local command, rest = (message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if command == "" then
		T.Window:Toggle()
	elseif command == "settings" or command == "config" or command == "options" then
		T.Window:Open("settings")
	elseif command == "theme" then
		if T.Theme.defs[rest] then
			T.Theme:Set(rest)
		else
			T:Print(L["Themes: night, journal, ember"])
		end
	elseif command == "check" or command == "probe" then
		T.Probe:Run()
	elseif command == "clear" then
		T.Places.ClearMarker()
		T:Print(L["Marker removed."])
	elseif command == "find" or command == "search" then
		if rest ~= "" then
			T.Window:Search(rest)
		else
			T.Window:Open("find")
		end
	elseif command == "reset" then
		T.Window:ResetPosition()
	elseif command == "errors" then
		local list = T.db and T.db.errors or {}
		T:Print(#list .. " " .. L["errors recorded"])
		local last = list[#list]
		if last then
			T:Print(last.where .. ": " .. last.err)
		end
	else
		help()
	end
end

-- Addon compartment (the menu under the minimap): left click opens, right click settings.
function Trailhead_OnAddonCompartmentClick(_, button)
	if button == "RightButton" then
		T.Window:Open("settings")
	else
		T.Window:Toggle()
	end
end

BINDING_HEADER_TRAILHEAD = "Trailhead"
BINDING_NAME_TRAILHEAD_TOGGLE = L["Open or close Trailhead"]
