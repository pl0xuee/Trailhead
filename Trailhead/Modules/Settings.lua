local _, T = ...
local L = T.L
local W = T.Widgets
local Theme = T.Theme

-- Settings page, opened with the gear in the title bar or /th settings.

local Settings = T:NewModule("settings")

local ROW_H = 60 -- a name, a line of explanation and air around them
local TOP = 84 -- where the rows start, under the title and the section buttons
local ui = { themeButtons = {}, sections = {}, pills = {}, section = "window" }

local SECTIONS = {
	{ id = "window", label = L["Window"] },
	{ id = "vendors", label = L["At vendors"] },
	{ id = "help", label = L["Help and data"] },
}

-- One row: a name and a line of explanation on the left; the caller adds a control on the
-- right at the height returned. Rows sit in a section, so only a handful show at a time.
local function row(section, index, name, hint)
	local y = -((index - 1) * ROW_H)
	local label = W.Text(section, "body", 13.5, "ink")
	label:SetPoint("TOPLEFT", section, "TOPLEFT", 0, y - 11)
	label:SetLabel(name)
	local note = W.Text(section, "body", 11, "muted")
	note:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
	note:SetLabel(hint)
	local rule = W.Fill(section, "tipLine")
	rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", section, "TOPLEFT", 0, y - ROW_H + 1)
	rule:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, y - ROW_H + 1)
	return y - 15, note
end

local function toggle(page, y, get, set)
	local button = W.Button(page, "", "ghost", { width = 96, role = "muted" })
	button:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y)
	button.Sync = function(self)
		local on = get()
		self:SetKind(on and "primary" or "ghost", "muted")
		self:SetLabel(on and L["On"] or L["Off"])
	end
	button.onClick = function(self)
		set(not get())
		self:Sync()
	end
	return button
end

function Settings:Build(page)
	local title = W.Text(page, "head", 20, "ink")
	title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	title:SetLabel(L["Settings"])

	-- Three sections, one shown at a time, chosen with the buttons under the title.
	local last
	for _, def in ipairs(SECTIONS) do
		local pill = W.Pill(page, def.label, nil, function()
			ui.section = def.id
			Settings:Refresh()
		end)
		if last then
			pill:SetPoint("LEFT", last, "RIGHT", 8, 0)
		else
			pill:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -38)
		end
		last = pill
		ui.pills[def.id] = pill
		local section = W.Panel(page)
		section:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -TOP)
		section:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 20)
		ui.sections[def.id] = section
	end
	local window, vendors, help = ui.sections.window, ui.sections.vendors, ui.sections.help

	-- Look.
	local y = row(window, 1, L["Look"], L["Three looks for the same window. Changes at once."])
	local anchor
	for index = #Theme.order, 1, -1 do
		local id = Theme.order[index]
		local button = W.Button(window, Theme.defs[id].name, "ghost", {
			width = 96, role = "muted",
			onClick = function()
				Theme:Set(id)
			end,
		})
		if anchor then
			button:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
		else
			button:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, y)
		end
		anchor = button
		ui.themeButtons[id] = button
	end

	-- Size.
	y = row(window, 2, L["Window size"], L["Make the whole window larger or smaller."])
	local plus = W.IconButton(window, "plus", 30, "ink", function()
		T.Window:SetScale(T.db.scale + T.SCALE_STEP)
		Settings:Refresh()
	end)
	plus:SetStyle({ line = "muted" })
	plus:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, y)
	ui.scale = W.Text(window, "body", 13, "ink")
	ui.scale:SetWidth(56)
	ui.scale:SetJustifyH("CENTER")
	ui.scale:SetPoint("RIGHT", plus, "LEFT", -4, 0)
	local minus = W.IconButton(window, "minus", 30, "ink", function()
		T.Window:SetScale(T.db.scale - T.SCALE_STEP)
		Settings:Refresh()
	end)
	minus:SetStyle({ line = "muted" })
	minus:SetPoint("RIGHT", ui.scale, "LEFT", -4, 0)
	plus.hoverRole, minus.hoverRole = "ghostHover", "ghostHover"

	-- Position.
	y = row(window, 3, L["Window position"], L["Drag the title bar to move the window. This puts it back in the middle."])
	local reset = W.Button(window, L["Reset position"], "ghost", {
		role = "muted",
		onClick = function()
			T.Window:ResetPosition()
		end,
	})
	reset:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, y)

	-- Beside game windows.
	y = row(window, 4, L["Beside game windows"], L["When Trailhead opens your spellbook, talents or map, it moves next to them."])
	ui.dock = toggle(window, y, function()
		return T.db.dock ~= false
	end, function(value)
		T.db.dock = value
		if not value then
			T.Window:Undock()
		end
	end)

	-- Combat.
	y = row(window, 5, L["Hide in combat"], L["Close the window when a fight starts and bring it back afterwards."])
	ui.combat = toggle(window, y, function()
		return T.db.hideInCombat
	end, function(value)
		T.db.hideInCombat = value
	end)

	-- Minimap button.
	y = row(window, 6, L["Minimap button"], L["The round Trailhead button on the edge of the minimap."])
	ui.minimap = toggle(window, y, function()
		return T.db.minimap.show
	end, function(value)
		T.db.minimap.show = value
		T:UpdateMinimapButton()
	end)

	-- Vendors.
	y = row(vendors, 1, L["Extra vendor buttons"], L["The game has its own Sell All Junk and Repair buttons. This adds a second pair that shows the price first."])
	ui.merchantBar = toggle(vendors, y, function()
		return T.db.merchantBar == true
	end, function(value)
		T.db.merchantBar = value
		T.Merchant.Refresh()
	end)
	y = row(vendors, 2, L["Sell grey items by itself"], L["Sells grey junk the moment a vendor window opens. Off unless you turn it on."])
	ui.autoSell = toggle(vendors, y, function()
		return T.db.autoSellJunk == true
	end, function(value)
		T.db.autoSellJunk = value
	end)
	y = row(vendors, 3, L["Repair by itself"], L["Repairs all gear at a vendor that can, if you can afford it. Off unless you turn it on."])
	ui.autoRepair = toggle(vendors, y, function()
		return T.db.autoRepair == true
	end, function(value)
		T.db.autoRepair = value
	end)

	-- Help: the screen setup page and the welcome each get their own row.
	y = row(help, 1, L["Screen setup"], L["Game options that make a first character easier to play, one click each."])
	local screen = W.Button(help, L["Set up my screen"], "ghost", {
		role = "accentText", width = 150,
		onClick = function()
			T.Window:Select("setup")
		end,
	})
	screen:SetPoint("TOPRIGHT", help, "TOPRIGHT", 0, y)
	y = row(help, 2, L["Welcome"], L["Show the welcome panel again, with its doors into the main pages."])
	local welcome = W.Button(help, L["Show welcome"], "ghost", {
		role = "muted", width = 130,
		onClick = function()
			T.Welcome.Show()
		end,
	})
	welcome:SetPoint("TOPRIGHT", help, "TOPRIGHT", 0, y)

	-- Advice.
	y = row(help, 3, L["Advice cards"], L["Bring back the advice you closed on the Home page."])
	local advice = W.Button(help, L["Bring back"], "ghost", {
		role = "muted",
		onClick = function()
			T.Advisor.Reset()
			T:Print(L["Your advice cards are back."])
		end,
	})
	advice:SetPoint("TOPRIGHT", help, "TOPRIGHT", 0, y)

	-- Found places.
	y, note = row(help, 4, L["Found places"], "")
	ui.placesNote = note
	ui.forget = W.Button(help, L["Forget all"], "ghost", {
		role = "muted",
		onClick = function(self)
			-- Asks once more before throwing the list away.
			if self.sure then
				self.sure = false
				T.Places.Forget()
			else
				self.sure = true
			end
			Settings:Refresh()
		end,
	})
	ui.forget:SetPoint("TOPRIGHT", help, "TOPRIGHT", 0, y)

	-- Game check.
	local note
	y, note = row(help, 5, L["Game check"], "")
	ui.checkNote = note
	local check = W.Button(help, L["Run check"], "ghost", {
		role = "accentText",
		onClick = function()
			T.Probe:Run()
			Settings:Refresh()
		end,
	})
	check:SetPoint("TOPRIGHT", help, "TOPRIGHT", 0, y)

	local version = W.Text(page, "body", 10.5, "faint")
	version:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
	version:SetLabel("Trailhead " .. T.version)

	T:On("TH_THEME_CHANGED", function()
		if page:IsVisible() then
			Settings:Refresh()
		end
	end)
	self.built = true
end

function Settings:Refresh()
	if not self.built then
		return
	end
	for id, section in pairs(ui.sections) do
		section:SetShown(id == ui.section)
		ui.pills[id]:SetOn(id == ui.section)
	end
	for id, button in pairs(ui.themeButtons) do
		button:SetKind(Theme.current.id == id and "primary" or "ghost", "muted")
	end
	ui.scale:SetLabel(("%d%%"):format(math.floor(T.db.scale * 100 + 0.5)))
	ui.minimap:Sync()
	ui.combat:Sync()
	ui.dock:Sync()
	ui.merchantBar:Sync()
	ui.autoSell:Sync()
	ui.autoRepair:Sync()
	local count = T.Places.Count()
	ui.placesNote:SetLabel(count == 1 and L["Trailhead remembers 1 place you have found."]
		or L["Trailhead remembers %d places you have found."]:format(count))
	ui.forget:SetKind("ghost", ui.forget.sure and "warn" or "muted")
	ui.forget:SetLabel(ui.forget.sure and L["Really forget?"] or L["Forget all"])
	ui.forget:SetEnabled(count > 0)
	local last = T.Probe:LastRun()
	if last then
		ui.checkNote:SetLabel(L["Last run: %s. Reload the interface afterwards so it is saved."]:format(date("%d %b %H:%M", last)))
	else
		ui.checkNote:SetLabel(L["Records what this version of the game can tell Trailhead. Not run yet."])
	end
end
