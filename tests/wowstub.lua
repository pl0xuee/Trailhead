-- A small, strict fake of the parts of the WoW API that Trailhead uses, for running the
-- addon under plain Lua 5.1. Strict means: calling a widget method that is not listed
-- here is an error, so a mistyped method name fails the tests instead of passing quietly.

local Stub = { textures = {}, timers = {}, chat = {}, errors = {}, fontstrings = {}, combat = false, sounds = 0 }

-- True if any visible-or-not text on screen currently reads exactly `wanted`.
function Stub.hasText(wanted)
	for _, text in ipairs(Stub.fontstrings) do
		if text.text == wanted then
			return true
		end
	end
	return false
end

local function noop() end

local common = {}
for _, name in ipairs({
	"SetPoint", "ClearAllPoints", "SetAllPoints", "SetAlpha", "SetScale", "SetParent",
	"SetFrameStrata", "SetFrameLevel", "SetToplevel", "SetClampedToScreen", "SetMovable",
	"EnableMouse", "RegisterForDrag", "RegisterForClicks", "StartMoving", "StopMovingOrSizing",
	"SetTexCoord", "SetVertexColor", "SetColorTexture", "SetSnapToPixelGrid", "SetTexelSnappingBias",
	"SetHorizTile", "SetVertTile", "SetFontObject", "SetTextColor", "SetShadowColor",
	"SetShadowOffset", "SetJustifyH", "SetJustifyV", "SetWordWrap", "SetSpacing", "AddMessage",
	"SetOwner", "AddLine", "EnableMouseWheel", "SetMaxLines", "SetAutoFocus", "SetMaxLetters",
}) do
	-- Does nothing, but remembers its last arguments so the layout tool (tests/layout.lua) can
	-- draw the page. SetPoint and ClearAllPoints have real versions further down.
	common[name] = function(self, ...)
		local rec = rawget(self, "rec")
		if not rec then
			rec = {}
			rawset(self, "rec", rec)
		end
		rec[name] = { ... }
	end
end

local ALLOWED = {
	Frame = { "SetPoint", "ClearAllPoints", "SetAllPoints", "SetAlpha", "SetScale", "SetParent",
		"SetFrameStrata", "SetFrameLevel", "SetToplevel", "SetClampedToScreen", "SetMovable",
		"EnableMouse", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetSize", "SetWidth",
		"SetHeight", "GetWidth", "GetHeight", "Show", "Hide", "SetShown", "IsShown", "IsVisible",
		"GetPoint", "CreateTexture", "CreateFontString", "SetScript", "GetScript", "RegisterEvent",
		"GetFrameLevel", "GetCenter", "GetEffectiveScale", "EnableMouseWheel", "IsMouseOver",
		"GetLeft", "GetRight", "GetTop", "GetBottom", "GetScale" },
	Texture = { "SetPoint", "ClearAllPoints", "SetAllPoints", "SetAlpha", "SetSize", "SetWidth",
		"SetHeight", "GetWidth", "GetHeight", "Show", "Hide", "SetShown", "IsShown", "SetTexture",
		"SetTexCoord", "SetVertexColor", "SetColorTexture", "SetSnapToPixelGrid",
		"SetTexelSnappingBias", "SetHorizTile", "SetVertTile" },
	FontString = { "SetPoint", "ClearAllPoints", "SetAlpha", "SetWidth", "GetWidth", "Show", "Hide",
		"SetShown", "IsShown", "SetFont", "GetFont", "SetFontObject", "SetText", "GetText",
		"SetTextColor", "SetShadowColor", "SetShadowOffset", "SetJustifyH", "SetJustifyV",
		"SetWordWrap", "SetSpacing", "GetStringWidth", "GetStringHeight", "SetMaxLines" },
}
ALLOWED.EditBox = { "SetAutoFocus", "SetMaxLetters", "SetFontObject", "SetFont", "SetTextColor", "SetText",
	"GetText", "SetFocus", "ClearFocus", "HasFocus" }
for _, name in ipairs(ALLOWED.Frame) do
	ALLOWED.EditBox[#ALLOWED.EditBox + 1] = name
end
ALLOWED.Button = { "RegisterForClicks", "SetHighlightTexture", "IsEnabled", "SetEnabled", "Enable", "Disable" }
for _, name in ipairs(ALLOWED.Frame) do
	ALLOWED.Button[#ALLOWED.Button + 1] = name
end

local methods = {}
function methods:SetSize(w, h) self.w, self.h = w, h; self:_resized() end
function methods:SetWidth(w) self.w = w; self:_resized() end
function methods:SetHeight(h) self.h = h; self:_resized() end
function methods:GetWidth() return self.w or 0 end
function methods:GetHeight() return self.h or 0 end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:SetShown(shown)
	shown = shown and true or false
	if self.shown == shown then return end
	self.shown = shown
	local script = self.scripts and self.scripts[shown and "OnShow" or "OnHide"]
	if script then script(self) end
end
function methods:IsShown() return self.shown end
function methods:IsVisible()
	local node = self
	while node do
		if not node.shown then return false end
		node = node.parent
	end
	return true
end
function methods:GetPoint() return "CENTER", UIParent, "CENTER", 0, 0 end
-- Placement is recorded so tests can see where a frame was put. A frame given a `rect`
-- ({ left, right, top, bottom }) reports those edges, as a game window would.
function methods:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints()
	self.points = {}
	local rec = rawget(self, "rec")
	if rec then rec.SetAllPoints = nil end
end
function methods:SetScale(scale) self.scale = scale end
function methods:GetScale() return self.scale or 1 end
function methods:GetLeft() return self.rect and self.rect[1] end
function methods:GetRight() return self.rect and self.rect[2] end
function methods:GetTop() return self.rect and self.rect[3] end
function methods:GetBottom() return self.rect and self.rect[4] end
function methods:GetCenter() return 100, 100 end
function methods:GetEffectiveScale() return self.effective or 1 end
function methods:GetFrameLevel() return 1 end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:GetScript(name) return self.scripts[name] end
function methods:RegisterEvent(event)
	if Stub.unknownEvents[event] then error("Attempt to register unknown event " .. event) end
	self.events[event] = true
	Stub.eventFrames[self] = true
end
function methods:CreateTexture(_, layer, _, sublevel)
	local texture = Stub.new("Texture", self, layer)
	texture.sub = sublevel
	return texture
end
function methods:CreateFontString(_, layer)
	local text = Stub.new("FontString", self, layer)
	Stub.fontstrings[#Stub.fontstrings + 1] = text
	return text
end
function methods:SetTexture(path, ...)
	self.texture = path
	if type(path) == "string" then Stub.textures[path] = true end
	local rec = rawget(self, "rec")
	if rec then rec.SetColorTexture = nil end
end
function methods:SetHighlightTexture(path) end
function methods:SetFont(file, size, flags)
	assert(type(file) == "string" and type(size) == "number", "SetFont(file, size)")
	self.font = { file, size, flags }
	return true
end
function methods:GetFont() if self.font then return unpack(self.font) end return "Fonts\\FRIZQT__.TTF", 12, "" end
function methods:SetText(text)
	assert(self.font, "SetText before a font was set")
	assert(text == nil or type(text) == "string" or type(text) == "number", "SetText needs a string")
	self.text = text and tostring(text) or ""
	if self._kind == "EditBox" and self.scripts.OnTextChanged then
		self.scripts.OnTextChanged(self, false)
	end
end
function methods:SetFocus()
	self.focus = true
	if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
end
function methods:ClearFocus()
	local had = self.focus
	self.focus = false
	if had and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function methods:HasFocus() return self.focus == true end
function methods:IsMouseOver() return Stub.mouseOver == self end
function methods:GetText() return self.text end
function methods:GetStringWidth()
	if Stub.measure then -- the layout tool measures with real letter widths
		return Stub.measure(self.text or "", self.font and self.font[2] or 12)
	end
	return #(self.text or "") * (self.font and self.font[2] or 12) * 0.5
end
-- Wrapped height: words fill the width one line at a time, the way the game lays text out.
function methods:GetStringHeight()
	local size = self.font and self.font[2] or 12
	local rec = rawget(self, "rec") or {}
	local wrap = rec.SetWordWrap and rec.SetWordWrap[1]
	local width = self.w or 0
	local lines = 1
	if wrap and width > 0 then
		local measure = Stub.measure or function(text, points) return #text * points * 0.5 end
		local used = 0
		for word in (self.text or ""):gmatch("%S+") do
			local w = measure(word, size)
			if used > 0 and used + measure(" ", size) + w > width then
				lines, used = lines + 1, w
			else
				used = used > 0 and used + measure(" ", size) + w or w
			end
		end
		for _ in (self.text or ""):gmatch("\n") do
			lines = lines + 1
		end
	end
	local max = rec.SetMaxLines and rec.SetMaxLines[1]
	if max and max > 0 and lines > max then
		lines = max
	end
	local spacing = rec.SetSpacing and rec.SetSpacing[1] or 0
	return lines * size + (lines - 1) * spacing
end
function methods:IsEnabled() return self.enabled ~= false end
function methods:SetEnabled(on) self.enabled = on and true or false end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:_resized()
	local script = self.scripts and self.scripts.OnSizeChanged
	if script then script(self, self.w or 0, self.h or 0) end
end

function Stub.new(kind, parent, layer)
	local allowed = {}
	for _, name in ipairs(ALLOWED[kind] or ALLOWED.Frame) do
		allowed[name] = true
	end
	local object = { _kind = kind, parent = parent, shown = true, scripts = {}, events = {}, layer = layer }
	if Stub.all then -- only kept while the layout tool runs
		Stub.all[#Stub.all + 1] = object
	end
	return setmetatable(object, {
		__index = function(_, key)
			if key == "_resized" then return methods._resized end
			if allowed[key] then
				return methods[key] or common[key] or error("stub is missing " .. kind .. ":" .. key)
			end
			if type(key) == "string" and key:match("^[A-Z]") and (methods[key] or common[key] or key:match("^[SG]et") or key:match("^Is")) then
				error(kind .. " has no method " .. key, 2)
			end
			return nil
		end,
	})
end

-- Fires a game event to every frame that registered it.
function Stub.fire(event, ...)
	for frame in pairs(Stub.eventFrames) do
		if frame.events[event] and frame.scripts.OnEvent then
			frame.scripts.OnEvent(frame, event, ...)
		end
	end
end

-- Types into an edit box the way a player does.
function Stub.type(edit, text)
	edit.text = text
	if edit.scripts.OnTextChanged then
		edit.scripts.OnTextChanged(edit, true)
	end
end

-- Clicks the button whose label reads `label` (the last one made, or the nth).
-- What the game does when a centred window opens: hides every frame named in UISpecialFrames.
function Stub.closeSpecial()
	for _, name in pairs(UISpecialFrames) do
		local frame = _G[name]
		if frame and frame:IsShown() then frame:Hide() end
	end
end

function Stub.click(label, nth)
	local found = {}
	for _, text in ipairs(Stub.fontstrings) do
		if text.text == label and text.parent and text.parent._kind == "Button" and text.parent:IsVisible() then
			found[#found + 1] = text.parent
		end
	end
	local button = found[nth or #found]
	assert(button, "no visible button labelled " .. label)
	button.scripts.OnClick(button)
	return button
end

-- True if a visible text on screen reads exactly `wanted`.
function Stub.sees(wanted)
	for _, text in ipairs(Stub.fontstrings) do
		if text.text == wanted and text.shown then
			local node, visible = text.parent, true
			while node do
				if not node.shown then visible = false break end
				node = node.parent
			end
			if visible then return true end
		end
	end
	return false
end

-- Runs every pending C_Timer.After callback.
function Stub.flush()
	local guard = 0
	while #Stub.timers > 0 do
		table.remove(Stub.timers, 1)()
		guard = guard + 1
		assert(guard < 1000, "timers never settle")
	end
end

local SECRET = setmetatable({}, { __tostring = function() error("read a secret value") end,
	__concat = function() error("concatenated a secret value") end })
Stub.SECRET = SECRET

-- Installs the fake globals. opts.bare = true leaves out everything optional, which is how
-- the addon must behave on a client that lacks those APIs. opts.secretName makes the
-- player's name a secret value.
function Stub.install(opts)
	opts = opts or {}
	Stub.eventFrames, Stub.unknownEvents = {}, { HEARTHSTONE_BOUND = opts.bare or nil }
	Stub.textures, Stub.timers, Stub.chat, Stub.errors, Stub.combat, Stub.sounds = {}, {}, {}, {}, false, 0
	Stub.waypoint, Stub.fontstrings, Stub.mapOpened, Stub.opened = nil, {}, nil, {}
	-- The fake game's state. Tests change it and fire the matching event.
	local world = {
		level = opts.level or 14, noActivities = opts.noActivities, map = 52, x = 0.56, y = 0.47, npc = "Innkeeper Farley",
		bind = "Goldshire", talents = true, free = { [0] = 5, 1, 1, 1, 1 }, durability = {},
		repair = false, trainer = nil, gossip = {}, poi = nil,
		onBars = { [116] = true, [122] = true, [12051] = true },
		known = { [116] = true, [2139] = true, [1953] = true },
		levelSpells = { [14] = { 120 }, [16] = { 2120, 1449 }, [20] = { 12051 } },
		tracking = {
			{ name = "Repair", texture = 136465, active = false },
			{ name = "Innkeeper", texture = 136458, active = false },
			{ name = "Class Trainer", texture = 136455, active = false },
			{ name = "Mailbox", texture = 136459, active = true },
		},
	}
	Stub.world = world

	local G = {}
	G.CreateFrame = function(kind, name, parent)
		local frame = Stub.new((kind == "Button" or kind == "EditBox") and kind or "Frame", parent)
		if name then _G[name] = frame end
		return frame
	end
	G.UIParent = Stub.new("Frame")
	G.UIParent.w, G.UIParent.h = 2968, 1200 -- a wide screen, in the game's own units
	-- The game's own windows that Trailhead can open: closed until something opens them.
	for _, name in ipairs({ "PlayerSpellsFrame", "WorldMapFrame" }) do
		G[name] = Stub.new("Frame")
		G[name].shown = false
	end
	G.PlayerSpellsFrame.rect = { 16, 1170, 1084, 201 }
	G.WorldMapFrame.rect = { 16, 1040, 1084, 316 }
	G.Minimap = Stub.new("Frame")
	G.Minimap.w, G.Minimap.h = 140, 140
	G.GameTooltip = setmetatable({}, { __index = function() return noop end })
	G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) Stub.chat[#Stub.chat + 1] = text end }
	local function fontObject(file) return { GetFont = function() return file, 12, "" end } end
	G.GameFontNormal = fontObject("Fonts\\FRIZQT__.TTF")
	G.GameFontHighlight = fontObject("Fonts\\FRIZQT__.TTF")
	G.QuestTitleFont = not opts.bare and fontObject("Fonts\\MORPHEUS.TTF") or nil
	G.UISpecialFrames, G.SlashCmdList = {}, {}
	G.tinsert = table.insert
	Stub.skew = 0
	G.time = function() return os.time() + Stub.skew end
	G.date = os.date
	G.geterrorhandler = function() return function(err) Stub.errors[#Stub.errors + 1] = tostring(err) end end
	G.GetBuildInfo = function() return "1.60.1", "70888", "Nov  3 2026", 16001 end
	G.GetLocale = function() return "enUS" end
	G.WOW_PROJECT_ID = 1
	G.InCombatLockdown = function() return Stub.combat end
	G.GetCursorPosition = function() return 500, 400 end
	G.UnitName = function(unit)
		if unit == "npc" then return Stub.world.npc end
		if opts.secretName then return SECRET end
		return "Aeloria", nil
	end
	G.UnitClass = function()
		local known = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }
		if opts.class and known[opts.class] then
			return opts.class:sub(1, 1) .. opts.class:sub(2):lower(), opts.class, known[opts.class]
		end
		return "Mage", "MAGE", 8
	end
	-- world.race = { name, file }, world.faction = "Horde": a human of the Alliance by default.
	G.UnitRace = function()
		local race = Stub.world.race or { "Human", "Human" }
		return race[1], race[2], 1
	end
	G.UnitFactionGroup = function() return Stub.world.faction or "Alliance", Stub.world.faction or "Alliance" end
	-- world.dead = "dead" or "ghost"; world.sick = true for Resurrection Sickness.
	G.UnitIsGhost = function() return Stub.world.dead == "ghost" end
	G.UnitIsDeadOrGhost = function() return Stub.world.dead ~= nil end
	G.C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return id == 15007 and Stub.world.sick and { spellId = id } or nil end }
	G.UnitLevel = function() return Stub.world.level end
	G.UnitXP = function() return 6200 end
	G.UnitXPMax = function() return opts.level == 60 and 0 or 10000 end
	G.GetMoney = function() return Stub.world.money or 341250 end
	G.GetRealZoneText = function() return "Westfall" end
	G.GetSubZoneText = function() return "Sentinel Hill" end
	G.NUM_BAG_SLOTS = 4
	G.issecretvalue = function(value) return value == SECRET end
	Stub.tickers = {}
	G.C_Timer = {
		After = function(_, fn) Stub.timers[#Stub.timers + 1] = fn end,
		NewTicker = not opts.bare and function(_, fn) Stub.tickers[#Stub.tickers + 1] = fn end or nil,
	}
	G.RAIDS = "Raids"
	G.IsInInstance = function()
		if world.instance then return true, world.instance.kind end
		return false, "none"
	end
	G.GetInstanceInfo = function()
		if world.instance then return world.instance.name, world.instance.kind end
		return "Eastern Kingdoms", "none"
	end
	G.SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856, IG_CHARACTER_INFO_TAB = 841,
		IG_CHARACTER_INFO_OPEN = 839, IG_CHARACTER_INFO_CLOSE = 840 }
	G.PlaySound = function() Stub.sounds = Stub.sounds + 1 end
	G.C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Version" and "0.12.0" or nil end }
	G.ReloadUI = function() Stub.reloaded = true end

	-- Game options, only when a test brings them: opts.cvars = { name = "value" } makes C_CVar
	-- exist (Stub.cvars is the live table, Stub.cvarLog the names set, in order);
	-- opts.bars = { true, false, ... } makes the action bar switches exist;
	-- opts.panels = true adds the settings panel and Edit Mode openers (Stub.panelOpened).
	Stub.cvars, Stub.cvarLog, Stub.barLog, Stub.panelOpened = opts.cvars, {}, {}, {}
	if opts.cvars then
		G.C_CVar = {
			GetCVar = function(name) return Stub.cvars[name] end,
			SetCVar = function(name, value)
				Stub.cvarLog[#Stub.cvarLog + 1] = name
				Stub.cvars[name] = tostring(value)
				return true
			end,
		}
	end
	if opts.bars then
		Stub.bars = opts.bars
		G.GetActionBarToggles = function() return unpack(Stub.bars, 1, 7) end
		G.SetActionBarToggles = function(...)
			Stub.barLog[#Stub.barLog + 1] = { ... }
			Stub.bars = { ... }
		end
		Stub.barsForced = opts.barsForced == true
	end
	if opts.panels then
		G.Settings = { ACTION_BAR_CATEGORY_ID = 7, KEYBINDINGS_CATEGORY_ID = 9,
			OpenToCategory = function(id) Stub.panelOpened[#Stub.panelOpened + 1] = id end }
		G.EditModeManagerFrame = { CanEnterEditMode = function() return true end }
		G.ShowUIPanel = function(frame) Stub.panelOpened[#Stub.panelOpened + 1] = frame end
	end

	if not opts.bare then
		-- world.rested (bonus experience left), world.resting, world.rest = { id, name, multiplier },
		-- world.stones (hearthstones carried), world.stoneCooldown = { start, duration }, world.now.
		G.GetXPExhaustion = function()
			if world.rested == nil then return 2100 end
			return world.rested > 0 and world.rested or nil
		end
		G.IsResting = function() return world.resting == true end
		G.GetTime = function() return world.now or 1000 end
		G.GetBindLocation = function() return world.bind end
		G.GetMaxPlayerLevel = function() return 60 end
		-- world.carried = { { itemID, count, name, classID, subClassID } ... } fills the first bag.
		G.C_Container = {
			GetContainerNumFreeSlots = function(bag) return world.free[bag] or 0 end,
			GetContainerNumSlots = function() return 16 end,
			GetContainerItemInfo = function(bag, slot)
				local item = bag == 0 and world.carried and world.carried[slot]
				return item and { itemID = item[1], stackCount = item[2], itemName = item[3] } or nil
			end,
			GetItemCooldown = function()
				local cooldown = world.stoneCooldown
				return cooldown and cooldown[1] or 0, cooldown and cooldown[2] or 0, 1
			end,
		}
		G.GetInventoryItemDurability = function(slot)
			local worn = world.durability[slot]
			if worn then return worn[1], worn[2] end
			if slot <= 3 then return 40, 40 end
			return nil
		end
		G.Enum = {
			UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3 },
			SpellBookSpellBank = { Player = 0, Pet = 1 },
			SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 },
			TrainerType = { General = 0, TalentsObsolete = 1, Tradeskills = 2, Pet = 3 },
			FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 },
			PlayerInteractionType = { Merchant = 5, TaxiNode = 6, Trainer = 7, Banker = 8, MailInfo = 17,
				Binder = 20, Auctioneer = 21, StableMaster = 22, CharacterBanker = 67 },
		}
		local maps = {
			[947] = { mapID = 947, name = "Azeroth", mapType = 1, parentMapID = 0 },
			[13] = { mapID = 13, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 },
			[12] = { mapID = 12, name = "Kalimdor", mapType = 2, parentMapID = 947 },
			[52] = { mapID = 52, name = "Westfall", mapType = 3, parentMapID = 13 },
			[37] = { mapID = 37, name = "Elwynn Forest", mapType = 3, parentMapID = 13 },
			[47] = { mapID = 47, name = "Duskwood", mapType = 3, parentMapID = 13 },
			[50] = { mapID = 50, name = "Stranglethorn Vale", mapType = 3, parentMapID = 13 },
			[26] = { mapID = 26, name = "The Hinterlands", mapType = 3, parentMapID = 13 },
			[84] = { mapID = 84, name = "Stormwind City", mapType = 3, parentMapID = 13 },
			[10] = { mapID = 10, name = "The Barrens", mapType = 3, parentMapID = 12 },
			[55] = { mapID = 55, name = "Deadmines Entrance", mapType = 6, parentMapID = 52 }, -- a cave with its own map
		}
		local zoneOrder = { 52, 37, 47, 50, 26, 84, 10 }
		-- opts.real (tests/layout_world.lua): the game's whole map list instead, for the layout review.
		local real = opts.real
		if real then
			maps, zoneOrder = {}, {}
			for _, row in ipairs(real.maps) do
				maps[row[1]] = { mapID = row[1], name = row[2], mapType = row[3], parentMapID = row[4] }
				if row[3] == 3 then zoneOrder[#zoneOrder + 1] = row[1] end
			end
			world.map = 1436
		end
		G.C_Map = {
			GetBestMapForUnit = function() return world.map end,
			GetMapInfo = function(id) return maps[id] end,
			-- The real game answers 0 for every zone; one zone has a range here so the
			-- fallback is exercised (Stormwind has no group finder entry).
			GetMapLevels = function(id) if id == 84 then return 1, 60, 0, 0 end return 0, 0, 0, 0 end,
			GetMapChildrenInfo = function()
				local out = {}
				for _, id in ipairs(zoneOrder) do out[#out + 1] = maps[id] end
				return out
			end,
			GetPlayerMapPosition = function(id)
				if world.x == nil then return nil end
				local x, y = world.x, world.y
				-- Any other map: where the player is on the continent (tests move it with cx, cy).
				if id ~= world.map then x, y = world.cx or 0.40, world.cy or 0.78 end
				return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
			end,
			CanSetUserWaypointOnMap = function(id) return id ~= 84 or world.cityMarkers == true end,
			HasUserWaypoint = function() return Stub.waypoint ~= nil end,
			SetUserWaypoint = function(point) Stub.waypoint = point end,
			ClearUserWaypoint = function() Stub.waypoint = nil end,
		}
		G.UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { uiMapID = map, position = { x = x, y = y } } end }
		G.C_SuperTrack = {
			SetSuperTrackedUserWaypoint = noop,
			IsSuperTrackingUserWaypoint = function() return true end,
		}
		G.OpenWorldMap = function(id) Stub.mapOpened = id; WorldMapFrame:Show() end
		local function node(id, name, faction, x, y)
			return { nodeID = id, name = name, faction = faction, position = { x = x, y = y }, isUndiscovered = false }
		end
		local taxi = {
			[13] = {
				node(4, "Sentinel Hill, Westfall", 2, 0.41, 0.80), node(2, "Stormwind, Elwynn", 2, 0.43, 0.70),
				node(12, "Darkshire, Duskwood", 2, 0.49, 0.80), node(20, "Grom'gol, Stranglethorn", 1, 0.44, 0.90),
				node(19, "Booty Bay, Stranglethorn", 0, 0.43, 0.97), node(76, "Revantusk Village, The Hinterlands", 1, 0.60, 0.30),
				node(99, "zzOLD Test Node, Westfall", 2, 0.40, 0.79),
			},
			[12] = { node(25, "Crossroads, The Barrens", 1, 0.5, 0.5) },
			-- A zone map lists every node, placed where it falls on that map (often outside it).
			[52] = { node(4, "Sentinel Hill, Westfall", 2, 0.56, 0.52), node(2, "Stormwind, Elwynn", 2, 0.9, -0.6) },
			[47] = { node(12, "Darkshire, Duskwood", 2, 1.2, 0.5) }, -- a position that is off its zone map
			[84] = { node(2, "Stormwind, Elwynn", 2, 0.71, 0.73) }, -- a city's own map
			[37] = { node(2, "Stormwind, Elwynn", 2, 0.25, 0.02) }, -- and the same point on the edge of the zone around it
		}
		-- What a flight master's own map lists: world.taxiAll for the new map, world.taxiFrame
		-- for the old window.
		G.C_TaxiMap = {
			GetTaxiNodesForMap = function(id) return taxi[id] or {} end,
			GetAllTaxiNodes = function() return world.taxiAll or {} end,
		}
		G.GetTaxiMapID = function() return world.map end
		G.NumTaxiNodes = function() return world.taxiFrame and #world.taxiFrame or 0 end
		G.TaxiNodeName = function(i) return world.taxiFrame[i][1] end
		G.TaxiNodeGetType = function(i) return world.taxiFrame[i][2] end
		-- Where each zone sits on its continent's map, and how big the continents are.
		local rects = {
			[52] = { 0.36, 0.44, 0.74, 0.84 }, [37] = { 0.40, 0.52, 0.66, 0.76 }, [47] = { 0.44, 0.52, 0.76, 0.86 },
			[50] = { 0.38, 0.50, 0.84, 1.00 }, [26] = { 0.55, 0.67, 0.25, 0.37 }, [84] = { 0.40, 0.45, 0.66, 0.72 },
			[10] = { 0.40, 0.60, 0.40, 0.60 },
		}
		if real then
			rects = {}
			for _, row in ipairs(real.maps) do
				if row[5] then rects[row[1]] = { row[5], row[6], row[7], row[8] } end
			end
		end
		G.C_Map.GetMapRectOnMap = function(id, top)
			local rect = rects[id]
			if world.noRects or not rect or top ~= maps[id].parentMapID then return nil end
			return rect[1], rect[2], rect[3], rect[4]
		end
		G.C_Map.GetMapWorldSize = function(id)
			if world.noYards or maps[id].mapType ~= 2 then return nil end
			if real and real.yards[id] then return real.yards[id][1], real.yards[id][2] end
			return 30000, 20000
		end
		G.C_EncounterJournal = { GetDungeonEntrancesForMap = function(id)
			if id == 52 then return { { name = "The Deadmines", journalInstanceID = 63, position = { x = 0.42, y = 0.71 } } } end
			return {}
		end }
		G.C_Minimap = {
			GetNumTrackingTypes = function() return #world.tracking end,
			GetTrackingInfo = function(i) return world.tracking[i] end,
			SetTracking = function(i, on) world.tracking[i].active = on end,
		}
		local names = { [6603] = "Attack", [116] = "Frostbolt", [122] = "Frost Nova", [2139] = "Counterspell",
			[1953] = "Blink", [133] = "Fireball", [120] = "Cone of Cold", [2120] = "Flamestrike",
			[1449] = "Arcane Explosion", [12051] = "Evocation", [6117] = "Mage Armor" }
		local book = {
			{ actionID = 6603, spellID = 6603, itemType = 1, isPassive = false, isOffSpec = false },
			{ actionID = 116, spellID = 116, itemType = 1, isPassive = false, isOffSpec = false },
			{ actionID = 122, spellID = 122, itemType = 2, isPassive = false },
			{ actionID = 2139, spellID = 2139, itemType = 1, isPassive = false, isOffSpec = false },
			{ actionID = 133, spellID = 133, itemType = 1, isPassive = false, isOffSpec = false, lowRank = true },
			{ actionID = 1953, spellID = 1953, itemType = 1, isPassive = false, isOffSpec = false },
			{ actionID = 6117, spellID = 6117, itemType = 1, isPassive = true, isOffSpec = false },
		}
		for _, item in ipairs(book) do item.name, item.iconID = names[item.spellID], 135000 + item.spellID end
		G.C_SpellBook = {
			GetNumSpellBookSkillLines = function() return 2 end,
			GetSpellBookSkillLineInfo = function(line)
				if line == 1 then return { name = "General", itemIndexOffset = 0, numSpellBookItems = 1 } end
				return { name = "Frost", itemIndexOffset = 1, numSpellBookItems = #book - 1 }
			end,
			GetSpellBookItemInfo = function(slot) return book[slot] end,
			GetSpellBookItemLevelLearned = function() return 10 end,
			IsSpellBookItemLowRank = function(slot) return book[slot] and book[slot].lowRank == true end,
			GetCurrentLevelSpells = function(level) return world.levelSpells[level] or {} end,
			IsSpellKnown = function(id) return world.known[id] == true end,
		}
		G.C_Spell = {
			GetSpellName = function(id) return names[id] end,
			-- Frostbolt's text is ready at once; anything else arrives after it is asked for.
			GetSpellDescription = function(id)
				if id == 116 and (not world.slowText or world.textReady) then return "Launches a bolt of frost." end
				return ""
			end,
			RequestLoadSpellData = function()
				Stub.timers[#Stub.timers + 1] = function() world.textReady = true end
			end,
			GetSpellTexture = function(id) return 135000 + id end,
			GetSpellLevelLearned = function() return 10 end,
		}
		G.ActionButtonUtil = { GetActionBarStatusForSpell = function(id) return world.onBars[id] and 1 or 2 end }
		G.PlayerSpellsUtil = {
			ToggleSpellBookFrame = function() Stub.opened.spellbook = true; PlayerSpellsFrame:SetShown(not PlayerSpellsFrame:IsShown()) end,
			-- The talents are a centred window: showing one closes every window Escape closes.
			ToggleClassTalentFrame = function()
				Stub.opened.talents = true
				if PlayerSpellsFrame:IsShown() then PlayerSpellsFrame:Hide() return end
				Stub.closeSpecial()
				PlayerSpellsFrame:Show()
			end,
			OpenToClassTalentsTab = function()
				Stub.opened.talents = true
				Stub.closeSpecial()
				PlayerSpellsFrame:Show()
			end,
		}
		G.C_ClassTalents = { HasUnspentTalentPoints = function() return world.talents end }
		-- The talent tree, the way the game's own talent window reads it.
		G.C_SpecializationInfo = {
			GetActiveSpecGroup = function() return 1 end,
			GetCombatConfigIDForSpecGroup = function(group) return group == 1 and 77 or nil end,
		}
		G.C_Traits = {
			GetConfigInfo = function(id) return id == 77 and { ID = 77, treeIDs = { 900 } } or nil end,
			GetTreeNodes = function(id) return id == 900 and { 1, 2 } or {} end,
			GetNodeInfo = function(config, id)
				return { ID = id, posX = id * 600, posY = 1200, maxRanks = 5, ranksPurchased = id == 1 and 2 or 0, groupIDs = { 31 },
					entryIDs = { 500 + id }, isAvailable = id == 1, isVisible = true, type = 0, conditionIDs = id == 2 and { 9001 } or {},
					visibleEdges = id == 1 and { { targetNode = 2 } } or {} }
			end,
			GetEntryInfo = function(config, id) return { definitionID = id + 200, maxRanks = 5 } end,
			GetDefinitionInfo = function(id) return id == 701 and { spellID = 116 } or { overrideName = "Ice | Shards" } end,
			GetGroupDisplayInfoByTreeID = function()
				return { { groupID = 31, displayName = "Frost", orderIndex = 2 }, { groupID = 30, displayName = "Fire", orderIndex = 1 } }
			end,
			PurchaseRank = noop,
			GetTreeInfo = function(config, id) return { ID = id, gates = { { topLeftNodeID = 2, conditionID = 9001 } } } end,
			GetConditionInfo = function(config, id)
				return { condID = id, isMet = false, isGate = true, type = 1, traitCurrencyID = 3820, spentAmountRequired = 5 }
			end,
			GetNodeCost = function() return { { ID = 3820, amount = 1 } } end,
			GetTreeCurrencyInfo = function()
				if world.noCurrency then return nil end
				local left = world.talents and (world.talentPoints or 1) or 0
				return { { traitCurrencyID = 3820, quantity = left, spent = 2, maxQuantity = 2 + left } }
			end,
		}
		-- The talent tooltip, as the game's own talent button asks for it. Text arrives late
		-- when world.slowText is set, like spell descriptions.
		G.C_TooltipInfo = {
			GetItemByID = function(id)
				if id == 6948 then
					return { lines = { { leftText = "Hearthstone" }, { leftText = "Use: Returns you to your inn." } } }
				end
				for _, carried in ipairs(world.carried or {}) do
					if carried[1] == id and carried[7] then
						return { lines = { { leftText = carried[3] }, { leftText = carried[7] } } }
					end
				end
				return nil
			end,
			GetSpellByID = function(id)
				local tip = world.spellTips and world.spellTips[id]
				return tip and { lines = { { leftText = tip[1] }, { leftText = tip[2] } } } or { lines = {} }
			end,
			GetMerchantItem = function(i)
				local item = world.merchant and world.merchant[i]
				return item and { lines = { { leftText = item[1] }, { leftText = item[5] or "" } } } or nil
			end,
			GetTraitEntry = function(entryID, rank)
				if world.slowText and not world.textReady then return { lines = {} } end
				return { lines = { { leftText = "Entry " .. entryID .. " at rank " .. tostring(rank) }, { leftText = "" } } }
			end,
		}
		-- opts.class = "ROGUE": the real rogue tree as game check 6 recorded it. world.ranks holds
		-- the points in each talent (the recorded character's by default); a talent is open when
		-- its tree has 5 points for every row above it and the talents leading to it are full.
		local treeFile = opts.class and ("tests/fixtures/" .. opts.class:lower() .. "_tree.lua")
		local treeHandle = treeFile and io.open(treeFile)
		if treeHandle then
			treeHandle:close()
			local fixture = dofile(treeFile)
			local nodes, ids, leadsTo = {}, {}, {}
			world.ranks, world.talents = {}, false
			for _, row in ipairs(fixture.nodes) do
				local id, x, y, max, ranks, groups, spell, name, edges = row:match("^(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|([^|]*)|(%d+)|([^|]*)|(.*)$")
				local node = { id = tonumber(id), x = tonumber(x), y = tonumber(y), max = tonumber(max), spell = tonumber(spell), name = name,
					groups = {}, edges = {}, row = fixture.rows and fixture.rows[tonumber(id)] or (tonumber(y) - 2130) / 600 }
				for group in groups:gmatch("%d+") do
					node.groups[#node.groups + 1] = tonumber(group)
					for _, tree in ipairs(fixture.groups) do
						if tree.groupID == tonumber(group) then node.tree = tree.groupID end
					end
				end
				for target in edges:gmatch("%d+") do
					node.edges[#node.edges + 1] = { targetNode = tonumber(target) }
					leadsTo[tonumber(target)] = leadsTo[tonumber(target)] or {}
					table.insert(leadsTo[tonumber(target)], node.id)
				end
				nodes[node.id], ids[#ids + 1] = node, node.id
				world.ranks[node.id] = tonumber(ranks)
				names[node.spell] = name
			end
			Stub.rogue = { nodes = nodes, ids = ids, leadsTo = leadsTo }
			Stub.tree = Stub.rogue
			local function inTree(tree)
				local sum = 0
				for id, node in pairs(nodes) do
					if node.tree == tree then sum = sum + (world.ranks[id] or 0) end
				end
				return sum
			end
			local function spent()
				local sum = 0
				for _, ranks in pairs(world.ranks) do sum = sum + ranks end
				return sum
			end
			local function open(node)
				if inTree(node.tree) < node.row * 5 then return false end
				for _, from in ipairs(leadsTo[node.id] or {}) do
					if (world.ranks[from] or 0) < nodes[from].max then return false end
				end
				return true
			end
			G.C_Traits = {
				GetConfigInfo = function(id) return id == 77 and { ID = 77, treeIDs = { fixture.tree } } or nil end,
				GetTreeNodes = function(id) return id == fixture.tree and ids or {} end,
				GetNodeInfo = function(config, id)
					local node = nodes[id]
					if not node then return nil end
					return { ID = id, posX = node.x, posY = node.y, maxRanks = node.max, ranksPurchased = world.ranks[id] or 0,
						groupIDs = node.groups, entryIDs = { id + 1000000 }, isAvailable = open(node), isVisible = true, type = 0,
						conditionIDs = node.row > 0 and { 9000 + node.row * 10 + (node.tree % 10) } or {}, visibleEdges = node.edges }
				end,
				GetEntryInfo = function(config, id) return nodes[id - 1000000] and { definitionID = id + 1000000, maxRanks = nodes[id - 1000000].max } or nil end,
				GetDefinitionInfo = function(id)
					local node = nodes[id - 2000000]
					return node and { spellID = world.spellChanged == node.id and 1 or node.spell } or nil
				end,
				GetGroupDisplayInfoByTreeID = function() return fixture.groups end,
				PurchaseRank = noop,
				GetTreeInfo = function(config, id) return { ID = id, gates = {}, cannotRefund = true } end,
				GetConditionInfo = function(config, id)
					return { condID = id, isMet = false, isGate = false, traitCurrencyID = 3820, spentAmountRequired = math.floor((id - 9000) / 10) * 5 }
				end,
				GetNodeCost = function() return { { ID = 3820, amount = 1 } } end,
				GetTreeCurrencyInfo = function()
					if world.noCurrency then return nil end
					local left = world.talents and (world.talentPoints or 1) or 0
					return { { traitCurrencyID = 3820, quantity = left, spent = spent(), maxQuantity = spent() + left } }
				end,
			}
		end
		-- The skill list as the game gives it: headings carry the id their rows use as a
		-- category, and a profession also appears as a child row (parent ~= 0).
		local function skillLines()
			if world.noSkills then return {} end
			local function head(name, id, collapsed)
				return { name = name, skillID = id, isHeader = true, isCollapsed = collapsed == true, rank = 0, maxRank = 0, modifier = 0,
					skillLineCategoryID = 0, parentSkillLineID = 0 }
			end
			local function line(name, id, rank, max, category, parent)
				return { name = name, skillID = id, isHeader = false, isCollapsed = false, rank = rank, maxRank = max, modifier = 0,
					skillLineCategoryID = category, parentSkillLineID = parent or 0, description = id == 136 and "Skill with staves." or "" }
			end
			local cap = world.level * 5
			local list = { head("Class Skills", 7), line("Frost", 6, 0, 0, 7), head("Professions", 11) }
			for _, item in ipairs(world.professions or {}) do
				list[#list + 1] = line(item[1], item[2], item[3], item[4], 11)
				list[#list + 1] = line(item[1], item[2] + 2000, item[3], item[4], 11, item[2])
			end
			list[#list + 1] = head("Secondary Skills", 9)
			for _, item in ipairs(world.secondary or {}) do
				list[#list + 1] = line(item[1], item[2], item[3], item[4], 9)
			end
			list[#list + 1] = head("Weapon Skills", 6, world.weaponsFolded)
			if not world.weaponsFolded then
				for _, item in ipairs(world.weapons or { { "Defense", 95, 66 }, { "Staves", 136, 61 }, { "Unarmed", 162, 4 }, { "Wands", 228, 1 } }) do
					list[#list + 1] = line(item[1], item[2], item[3], cap, 6)
				end
			end
			-- world.armor = the kinds of armor the character can wear; cloth only by default.
			list[#list + 1] = head("Armor Proficiencies", 8, world.armorFolded)
			if not world.armorFolded then
				for index, name in ipairs(world.armor or { "Cloth" }) do
					list[#list + 1] = line(name, 414 + index, 1, 1, 8)
				end
			end
			list[#list + 1] = head("Languages", 10)
			list[#list + 1] = line("Common", 98, 300, 300, 10)
			return list
		end
		G.C_SkillInfo = {
			GetNumSkillLines = function() return #skillLines() end,
			GetSkillLineInfo = function(index) return skillLines()[index] end,
		}
		-- world.hands[slot] = { itemID, subclass, name }; a staff in the main hand by default.
		local function hand(slot)
			local hands = world.hands or { [16] = { 2092, 10, "Gnarled Staff" } }
			return hands[slot]
		end
		-- world.worn[slot] = { itemID, name, classID, subClassID, subType }: armor and the rest.
		local function wornItem(id)
			for _, item in pairs(world.worn or {}) do
				if item[1] == id then return item end
			end
		end
		local function inSlot(_, slot)
			local worn = world.worn and world.worn[slot]
			return worn and worn[1] or hand(slot) and hand(slot)[1] or nil
		end
		G.GetInventoryItemID = inSlot
		local held = function(id)
			for slot = 16, 18 do
				if hand(slot) and hand(slot)[1] == id then return hand(slot) end
			end
		end
		G.C_Item = {
			GetItemCount = function(id) return id == 6948 and (world.stones or 1) or 0 end,
			GetItemInfoInstant = function(id)
				for _, carried in ipairs(world.carried or {}) do
					if carried[1] == id then return id, "Consumable", carried[6] or "Food & Drink", "", 1, carried[4], carried[5] end
				end
				for _, sold in ipairs(world.merchant or {}) do
					if sold[4] == id then return id, "Miscellaneous", "Mount", "", 1, 15, 5 end
				end
				local worn = wornItem(id)
				if worn then return id, "Armor", worn[5], "", 1, worn[3], worn[4] end
				local item = held(id)
				if not item then return nil end
				return id, "Weapon", "?", "INVTYPE_WEAPON", 135145, 2, item[2]
			end,
			GetItemNameByID = function(id)
				return wornItem(id) and wornItem(id)[2] or held(id) and held(id)[3] or nil
			end,
		}
		G.C_AreaPoiInfo = {
			GetAreaPOIForMap = function(id) return id == 52 and { 7001 } or {} end,
			GetAreaPOIInfo = function() return { name = "The Deadmines", atlasName = "Dungeon", position = { x = 0.42, y = 0.71 } } end,
		}
		local activities = {
			[801] = { fullName = "Deadmines", minLevelSuggestion = 17, maxLevelSuggestion = 26, categoryID = 2, mapID = 36 },
			[802] = { fullName = "Ragefire Chasm", minLevelSuggestion = 13, maxLevelSuggestion = 18, categoryID = 2 },
			[803] = { fullName = "The Stockade", minLevelSuggestion = 22, maxLevelSuggestion = 30, categoryID = 2 },
			[901] = { fullName = "Westfall", minLevelSuggestion = 10, maxLevelSuggestion = 20, categoryID = 116 },
			[902] = { fullName = "Elwynn Forest", minLevelSuggestion = 1, maxLevelSuggestion = 10, categoryID = 116 },
			[903] = { fullName = "Duskwood", minLevelSuggestion = 18, maxLevelSuggestion = 30, categoryID = 116 },
			[904] = { fullName = "Hinterlands", minLevelSuggestion = 40, maxLevelSuggestion = 50, categoryID = 116 },
			[905] = { fullName = "Stranglethorn Vale", minLevelSuggestion = 30, maxLevelSuggestion = 45, categoryID = 116 },
			[906] = { fullName = "The Barrens", minLevelSuggestion = 15, maxLevelSuggestion = 30, categoryID = 116 },
			[907] = { fullName = "Warsong Gulch", minLevelSuggestion = 10, maxLevelSuggestion = 60, categoryID = 118 },
			[908] = { fullName = "Broken Entry", minLevelSuggestion = 0, maxLevelSuggestion = 0, categoryID = 2 },
			-- Raids, once the game lists them: one under the old category number, one under
			-- a category only its name gives away.
			[950] = { fullName = "Molten Core", minLevelSuggestion = 60, maxLevelSuggestion = 60, categoryID = 114 },
			[951] = { fullName = "Onyxia's Lair", minLevelSuggestion = 60, maxLevelSuggestion = 60, categoryID = 119 },
		}
		G.C_LFGList = {
			GetAvailableActivities = function()
				if world.noActivities then return {} end
				local ids = { 801, 802, 803, 901, 902, 903, 904, 905, 906, 907, 908 }
				if real then
					ids = {}
					for index in ipairs(real.activities) do ids[index] = 5000 + index end
					return ids
				end
				if world.raids then ids[#ids + 1] = 950; ids[#ids + 1] = 951 end
				return ids
			end,
			GetActivityInfoTable = function(id)
				local row = real and real.activities[id - 5000]
				if row then
					return { fullName = row[1], categoryID = row[2], minLevelSuggestion = row[3], maxLevelSuggestion = row[4] }
				end
				return activities[id]
			end,
			GetLfgCategoryInfo = function(id)
				return { name = ({ [2] = "Dungeons", [116] = "Questing & Zones", [118] = "Battlegrounds", [119] = "Raids", [114] = "Raids" })[id] }
			end,
		}
		-- Trainers, vendors and guards.
		-- The trainer window lists only what its filter lets through. world.filter is what
		-- the game reports; world.shown is what the list is really filtered by, which lags
		-- behind when world.filterLag is set ("silent": it catches up without an event).
		world.filter = { available = true, unavailable = false, used = false }
		world.shown = { available = true, unavailable = false, used = false }
		world.filterSets = 0
		local function services()
			local out = {}
			if world.trainer and not world.trainerLate then
				for _, service in ipairs(world.trainer.services) do
					-- As in the game: a later rank it calls "available" is filtered as unavailable.
					local state = service.state
					if state == "available" and type(world.level) == "number" and service.level > world.level then
						state = "unavailable"
					end
					if service.state == "header" or world.shown[state] then out[#out + 1] = service end
				end
			end
			return out
		end
		G.GetNumTrainerServices = function() return #services() end
		G.GetTrainerServiceInfo = function(i)
			local service = services()[i]
			if not service then return nil end
			return service.name, service.state, 135000 + i, service.level, service.sub, world.trainer.group
		end
		G.GetTrainerServiceCost = function(i)
			local service = services()[i]
			return service and service.cost or 0, false
		end
		G.GetTrainerServiceTypeFilter = function(kind) return world.filter[kind] end
		G.SetTrainerServiceTypeFilter = function(kind, on)
			world.filter[kind] = on and true or false
			world.filterSets = world.filterSets + 1
			if not world.filterLag then world.shown[kind] = world.filter[kind] end
			-- The game answers a moment later with TRAINER_UPDATE.
			Stub.timers[#Stub.timers + 1] = function()
				world.shown[kind] = world.filter[kind]
				if world.filterLag ~= "silent" and world.trainer then Stub.fire("TRAINER_UPDATE") end
			end
		end
		G.C_Trainer = { GetTrainerType = function() return world.trainer and world.trainer.kind or 0 end }
		G.RANK = "Rank"
		G.IsTradeskillTrainer = function() return world.trainer ~= nil and world.trainer.tradeskill == true end
		G.CanMerchantRepair = function() return world.repair end
		-- world.merchant = { { name, price, stack, itemID, "tooltip line" } ... }: an open vendor window.
		G.GetMerchantNumItems = function() return world.merchant and #world.merchant or 0 end
		G.GetMerchantItemID = function(i) return world.merchant and world.merchant[i] and world.merchant[i][4] or nil end
		G.C_MerchantFrame = {
			GetItemInfo = function(i)
				local item = world.merchant and world.merchant[i]
				if not item then return nil end
				return { name = item[1], price = item[2], stackCount = item[3], isUsable = true, isPurchasable = true, texture = 1 }
			end,
		}
		-- world.mounts = { { id, name, spell, usable, source } ... }
		G.C_MountJournal = {
			GetNumMounts = function() return #(world.mounts or {}) end,
			GetMountIDs = function()
				local ids = {}
				for _, mount in ipairs(world.mounts or {}) do ids[#ids + 1] = mount[1] end
				return ids
			end,
			GetMountInfoByID = function(id)
				for _, mount in ipairs(world.mounts or {}) do
					if mount[1] == id then return mount[2], mount[3], 132261, false, mount[4], 2, false, true, 0, false, mount[6] == true, id end
				end
			end,
			GetMountInfoExtraByID = function(id)
				for _, mount in ipairs(world.mounts or {}) do
					if mount[1] == id then return 2404, "A sturdy wolf.", mount[5], false, 230 end
				end
			end,
		}
		G.IsMounted = function() return false end
		G.TUTORIAL1 = "Quest givers have an exclamation mark over their heads."
		G.NEWBIE_TOOLTIP_XPBAR = "The amount of experience (XP) you have earned."
		G.REPAIR_COST = "Repair Cost:"
		G.HEADSLOT, G.NECKSLOT, G.TRINKET0SLOT, G.TRINKET1SLOT = "Head", "Neck", "Trinket", "Trinket"
		G.GetRestState = function()
			local rest = world.rest or { 1, "Rested", 2 }
			return rest[1], rest[2], rest[3]
		end
		G.GetInventoryItemID = inSlot
		G.C_GossipInfo = {
			GetText = function() return world.said end,
			GetOptions = function() return world.gossip end,
			SelectOption = function(id) world.selected = id end,
			SelectOptionByIndex = function(index) world.selected = index end,
			GetPoiForUiMapID = function() return world.poi and world.poi.id end,
			GetPoiInfo = function()
				local poi = world.poi
				return poi and { name = poi.name, textureIndex = 7, position = { x = poi.x, y = poi.y }, inBattleMap = false }
			end,
		}
		G.hooksecurefunc = function(owner, name, hook)
			local original = owner[name]
			assert(type(original) == "function", "hooksecurefunc: no function " .. tostring(name))
			owner[name] = function(...)
				local a, b, c = original(...)
				hook(...)
				return a, b, c
			end
		end
		G.C_GameRules = { GetForeverExperiencePreset = function() error("not available here") end,
			IsMultiActionBarVisibilityForced = opts.bars and function() return Stub.barsForced end or nil }
		G.C_UI = { Reload = function() Stub.reloaded = true end }
	end

	for name, value in pairs(G) do
		_G[name] = value
	end
	Stub.globals = G
end

-- Removes the fake globals and the addon's own, so the next run starts clean.
function Stub.uninstall()
	for name in pairs(Stub.globals or {}) do
		_G[name] = nil
	end
	for _, name in ipairs({ "Trailhead", "TrailheadDB", "TrailheadCharDB", "TrailheadWindow",
		"TrailheadMinimapButton", "TrailheadMerchantBar", "TrailheadWelcome", "SLASH_TRAILHEAD1", "SLASH_TRAILHEAD2", "Trailhead_OnAddonCompartmentClick",
		"BINDING_HEADER_TRAILHEAD", "BINDING_NAME_TRAILHEAD_TOGGLE" }) do
		_G[name] = nil
	end
end

return Stub
