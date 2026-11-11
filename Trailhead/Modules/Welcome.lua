local _, T = ...
local L = T.L
local W = T.Widgets
local Theme = T.Theme
local C = T.Compat

-- Welcome: a short panel laid over the window's page the first time the window is opened.
-- It says what Trailhead does, offers a few doors into the right pages and the look picker,
-- and can be skipped. Settings reopens it. It never changes anything but the look, and only
-- when the player clicks a look.

local Welcome = T:NewModule("welcome")
T.Welcome = Welcome

local RAIL, BAR, PAD = 92, 54, 10 -- must match UI/Window.lua

local DOORS = {
	{ L["Find a trainer, vendor, bank or inn"], L["Find it"], "find" },
	{ L["See which spells you can learn and which are not on your bars"], L["Spells"], "spells" },
	{ L["Learn where to level and which dungeons fit you"], L["Zones"], "zones" },
	{ L["Read how the game works, one topic at a time"], L["Guide"], "guide" },
	{ L["Set a few game options that make the first hours easier"], L["Set up my screen"], "setup" },
}

local panel
local lookButtons = {}

function Welcome.IsShown()
	return panel ~= nil and panel:IsShown()
end

local function finish()
	T.db.welcomeDone = true
	if panel then
		panel:Hide()
	end
end

local EDGE = 758 -- from the left of the words to the right edge the buttons share

local function build()
	local frame = T.Window.frame
	panel = W.Panel(frame, { shape = "page", fill = "page", line = "pageLine" }, "Frame", "TrailheadWelcome")
	panel:SetPoint("TOPLEFT", frame, "TOPLEFT", RAIL, -BAR)
	panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
	panel:SetFrameStrata("DIALOG")
	panel:EnableMouse(true) -- the page underneath cannot be clicked through it
	panel:Hide()

	local tile = W.IconTile(panel, "tri", 52, "accent")
	tile:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, -28)
	local title = W.Text(panel, "head", 24, "ink")
	title:SetPoint("TOPLEFT", tile, "TOPRIGHT", 16, -2)
	title:SetLabel(L["Welcome to Trailhead"])
	local sub = W.Text(panel, "body", 12, "muted", { width = 600 })
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	sub:SetLabel(L["Your companion on the road to level 60."])

	local intro = W.Text(panel, "body", 12.5, "ink", { width = 720 })
	intro:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, -104)
	intro:SetSpacing(4)
	intro:SetLabel(L["Trailhead tells you what to do next, shows you where things are, and explains the parts of the game nobody tells you about. It only reads what your game already knows, and it never sends anything anywhere."])

	local heading = W.Text(panel, "head", 15, "ink")
	heading:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -22)
	heading:SetLabel(L["Good places to start"])

	local previous = heading
	for _, door in ipairs(DOORS) do
		local text = W.Text(panel, "body", 12, "ink", { width = 520 })
		text:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, previous == heading and -16 or -20)
		text:SetLabel(door[1])
		local go = W.Button(panel, door[2], "ghost", {
			role = "accentText", height = 28, size = 11.5, width = 150,
			onClick = function()
				finish()
				T.Window:Select(door[3])
			end,
		})
		go:SetPoint("TOPRIGHT", text, "TOPLEFT", EDGE, 7) -- every button ends on the same line
		previous = text
	end

	-- The look picker.
	local lookText = W.Text(panel, "body", 12, "ink")
	lookText:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -34)
	lookText:SetLabel(L["Pick a look. You can change it later in Settings."])
	for index = 1, #Theme.order do
		local id = Theme.order[index]
		local button = W.Button(panel, Theme.defs[id].name, "ghost", {
			width = 96, role = "muted", height = 28, size = 11.5,
			onClick = function()
				Theme:Set(id)
				Welcome.Sync()
			end,
		})
		button:SetPoint("TOPRIGHT", lookText, "TOPLEFT", EDGE - (#Theme.order - index) * 104, 7)
		lookButtons[id] = button
	end

	-- Closing.
	local skip = W.Button(panel, L["Skip"], "ghost", { role = "muted", width = 100, onClick = finish })
	skip:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 30, 24)
	local start = W.Button(panel, L["Start using Trailhead"], "primary", { width = 210, onClick = finish })
	start:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 24)
	local again = W.Text(panel, "body", 10.5, "faint")
	again:SetPoint("BOTTOM", panel, "BOTTOM", 0, 32)
	again:SetJustifyH("CENTER")
	again:SetLabel(L["Reopen this from Settings any time."])
end

function Welcome.Sync()
	for id, button in pairs(lookButtons) do
		button:SetKind(Theme.current.id == id and "primary" or "ghost", "muted")
	end
end

-- Shows the panel over the window, opening the window first if needed.
function Welcome.Show()
	if C.InCombat() then
		return false
	end
	if not T.Window:IsOpen() then
		T.Window:Open() -- fires TH_WINDOW_OPENED, which would show it a second time; harmless
	end
	if not panel then
		build()
	end
	Welcome.Sync()
	panel:Show()
	return true
end

-- The first time the window opens on an account.
T:On("TH_WINDOW_OPENED", function()
	if T.db and not T.db.welcomeDone and not Welcome.IsShown() and T.Window:IsOpen() then
		Welcome.Show()
	end
end)

T:On("TH_THEME_CHANGED", function()
	if panel then
		Welcome.Sync()
	end
end)
