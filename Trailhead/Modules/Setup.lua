local _, T = ...
local L = T.L
local W = T.Widgets
local Theme = T.Theme
local C = T.Compat
local G = T.Game

-- Screen setup: a short list of game options that make a first character easier to play.
-- It has no tab of its own (the rail is full): it opens from the welcome panel, Settings,
-- a Home card and the Guide. Every row is a click away from On and from Undo.

local Setup = T:NewModule("setup")
T.Setup = Setup

local ROW_H, ROW_GAP = 56, 4
local LIST_TOP, FOOT = 92, 40
local PAGE_W = 778

local ui = {}

local GROUP_LABEL = {}
for _, group in ipairs(T.Interface.GROUPS) do
	GROUP_LABEL[group.id] = group.label
end

local REASON = {
	combat = L["Not during a fight. Try again when it is over."],
	missing = L["Your game does not have this setting."],
	failed = L["The game did not take the change."],
}

local function say(reason)
	if reason and REASON[reason] then
		T:Print(REASON[reason])
	end
end

-- The game can take a moment to report some changes (the action bars): look again shortly.
local function later()
	C.Call("C_Timer.After", 0.6, function()
		if Setup.built and Setup.page:IsVisible() then
			Setup:Refresh()
		end
	end)
end

local function makeRow(list, width)
	local row = W.Panel(list, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	row:SetSize(width, ROW_H)
	row.name = W.Text(row, "head", 13, "ink")
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -8)
	row.name:SetWidth(210)
	row.where = W.Text(row, "body", 10, "faint")
	row.where:SetPoint("TOPLEFT", row, "TOPLEFT", 232, -10)
	row.where:SetWidth(width - 232 - 130)
	row.why = W.Text(row, "body", 10.5, "muted", { width = width - 14 - 150 })
	row.why:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -26)
	row.why:SetSpacing(2)
	row.why:SetMaxLines(2)
	row.state = W.Text(row, "label", 9, "go")
	row.state:SetJustifyH("RIGHT")
	row.state:SetWidth(40)
	row.button = W.Button(row, "", "ghost", {
		role = "accentText", height = 28, size = 11,
		onClick = function(self)
			local item = row.item
			if not item then
				return
			end
			if item.kind == "manual" then
				if not T.Interface.OpenManual(item.id) then
					say(C.InCombat() and "combat" or "missing")
				end
				return
			end
			local ok, reason
			if self.mode == "undo" then
				ok, reason = T.Interface.Undo(item.id)
			else
				ok, reason = T.Interface.Apply(item.id)
			end
			if not ok then
				say(reason)
			end
			Setup:Refresh(true)
			later()
		end,
	})
	row.button:SetPoint("RIGHT", row, "RIGHT", -12, 0)
	row.state:SetPoint("RIGHT", row.button, "LEFT", -10, 0)

	function row:Fill(item)
		self.name:SetLabel(item.name)
		if item.kind == "manual" then
			-- Explained only: the words get the whole row unless a button opens the game's panel.
			local opens = item.button ~= nil and item.can()
			self.where:SetLabel(item.menu or "")
			self.why:SetWidth(width - 28 - (opens and 174 or 0))
			self.why:SetLabel(item.why)
			self.state:SetLabel("")
			self.button:SetShown(opens)
			self.button.mode = "open"
			self.button:SetKind("ghost", "accentText")
			self.button:SetLabel(item.button or "")
			self.button:SetWidth(150)
			return
		end
		local on = T.Interface.IsOn(item.id)
		self.why:SetWidth(width - 28 - 164) -- clear of the On/Off word and the button
		self.where:SetLabel(GROUP_LABEL[item.group] .. ": " .. item.menu)
		self.why:SetLabel(item.note and (item.why .. " " .. item.note) or item.why)
		self.state:SetLabel(on and L["On"] or L["Off"])
		self.state:SetRole(on and "go" or "faint")
		self.button:Show()
		self.button:SetWidth(90)
		if on then
			self.button.mode = "undo"
			self.button:SetKind("ghost", "muted")
			self.button:SetLabel(L["Undo"])
			self.button:SetEnabled(T.Interface.CanUndo(item.id))
		else
			self.button.mode = "apply"
			self.button:SetKind("primary", "go")
			self.button:SetLabel(L["Turn on"])
			self.button:SetEnabled(true)
		end
	end
	return row
end

function Setup:Build(page)
	self.page = page
	local title = W.Text(page, "head", 20, "ink")
	title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	title:SetLabel(L["Screen setup"])
	local sub = W.Text(page, "body", 11.5, "muted", { width = PAGE_W })
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	sub:SetSpacing(2)
	sub:SetLabel(L["A few game options that make a first character easier to play. Nothing changes until you click, each one has an Undo that puts back what you had, and every name is the one the game's own Options menu uses."])

	ui.count = W.Text(page, "head", 13, "ink")
	ui.count:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -62)
	ui.undoAll = W.Button(page, L["Undo all"], "ghost", {
		role = "muted", height = 28, size = 11.5, width = 110,
		onClick = function()
			local changed, reason = T.Interface.UndoAll()
			say(reason)
			Setup:Refresh(true)
			later()
			return changed
		end,
	})
	ui.undoAll:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -56)
	ui.useAll = W.Button(page, L["Use all suggested settings"], "primary", {
		height = 28, size = 11.5, width = 230,
		onClick = function()
			local changed, reason = T.Interface.ApplyAll()
			say(reason)
			Setup:Refresh(true)
			later()
			return changed
		end,
	})
	ui.useAll:SetPoint("RIGHT", ui.undoAll, "LEFT", -8, 0)

	ui.list = W.List(page, PAGE_W, 496 - LIST_TOP - FOOT, ROW_H, ROW_GAP, makeRow)
	ui.list:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -LIST_TOP)

	-- Shown beside the count when the game offers nothing to set; the two buttons step aside.
	ui.empty = W.Text(page, "body", 11, "muted", { width = 540 })
	ui.empty:SetPoint("TOPLEFT", ui.count, "TOPRIGHT", 14, -1)

	-- The bars: the Spells page already knows which spells are not on one.
	ui.bars = W.Text(page, "body", 11, "muted", { width = 560 })
	ui.bars:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 8)
	ui.spells = W.Button(page, L["Open Spells"], "ghost", {
		role = "accentText", height = 28, size = 11.5, width = 150,
		onClick = function()
			T.Window:Select("spells")
		end,
	})
	ui.spells:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 2)

	T:On("TH_INTERFACE_CHANGED", function()
		if page:IsVisible() then
			Setup:Refresh(true)
		end
	end)
	self.built = true
end

function Setup:Refresh(keep)
	if not self.built then
		return
	end
	local offered = T.Interface.Offered()
	local items = {}
	for _, def in ipairs(offered) do
		items[#items + 1] = { kind = "set", id = def.id, group = def.group, name = def.name,
			menu = def.menu, why = def.why, note = def.note }
	end
	for _, item in ipairs(T.Interface.manual) do
		items[#items + 1] = { kind = "manual", id = item.id, name = item.name, menu = item.menu,
			why = item.why, button = item.button, can = item.can or function() return false end }
	end
	ui.list:SetItems(items, keep)

	local set, total = T.Interface.Counts()
	if total == 0 then
		ui.count:SetLabel(L["Nothing to set here"])
		ui.empty:SetLabel(L["Trailhead cannot read these options in your game. The Options menu in the game menu has them all."])
		ui.empty:Show()
	else
		ui.count:SetLabel(L["%d of %d are set the suggested way"]:format(set, total))
		ui.empty:Hide()
	end
	ui.useAll:SetShown(total > 0)
	ui.undoAll:SetShown(total > 0)
	ui.useAll:SetEnabled(set < total)
	local any = false
	for _, def in ipairs(T.Interface.defs) do
		any = any or T.Interface.CanUndo(def.id)
	end
	ui.undoAll:SetEnabled(any)

	local off = G.SpellsOffBars and #G.SpellsOffBars() or 0
	if off > 0 then
		ui.bars:SetLabel(off == 1 and L["1 spell is not on your action bars. The Spells page shows which."]
			or L["%d spells are not on your action bars. The Spells page shows which."]:format(off))
	else
		ui.bars:SetLabel(L["Trailhead never moves your spells. The Spells page lists any that are not on a bar."])
	end
end

-- From the page's own refresh: a game option can change outside Trailhead.
T:On("CVAR_UPDATE", function()
	if Setup.built and Setup.page:IsVisible() then
		Setup:Refresh(true)
	end
end)
