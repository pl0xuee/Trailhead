local _, T = ...
local L = T.L
local W = T.Widgets
local Theme = T.Theme
local C = T.Compat
local G = T.Game
local B = T.BuildGuide

-- Builds: a ready-made way to spend talent points, and the talent helper. The page always
-- answers one question first: where does my next point go? With the game's talent window
-- open, Trailhead sits beside it on this page and moves on as each point is spent.

local Builds = T:NewModule("builds", { label = L["Builds"], icon = "spark", order = 3.5 })

local PAGE_W = 778
local LIST_W, TOP = 214, 44
local PANEL_X = LIST_W + 14
local PANEL_W, PANEL_H = PAGE_W - PANEL_X, 496 - TOP
local INNER = PANEL_W - 40
local ITEM_H, ITEM_GAP = 52, 6
local AFTER_ROWS, AFTER_H = 3, 19
local FIGHT_LINES = 4

local ui = { items = {}, after = {} }

-- ---------------------------------------------------------------------------
-- The list of builds on the left.

local function itemLook(item)
	local on = item.build.id == Builds.selected
	item:SetStyle({ fill = on and "tile" or "card", line = on and "accent" or (item.hover and "accentText" or "cardLine") })
	item.label:SetRole(on and "ink" or "muted")
end

local function makeItem(page, index)
	local item = W.Panel(page, { shape = "card", fill = "card", line = "cardLine" }, "Button")
	item:SetSize(LIST_W, ITEM_H)
	item:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(TOP + (index - 1) * (ITEM_H + ITEM_GAP)))
	item.icon = W.Icon(item, "spark", 18, "accent")
	item.icon:SetPoint("LEFT", item, "LEFT", 14, 0)
	item.label = W.Text(item, "head", 12.5, "muted")
	item.label:SetPoint("TOPLEFT", item, "TOPLEFT", 44, -11)
	item.state = W.Text(item, "label", 8.5, "go")
	item.state:SetPoint("TOPLEFT", item.label, "BOTTOMLEFT", 0, -5)
	item:SetScript("OnEnter", function(self)
		self.hover = true
		itemLook(self)
	end)
	item:SetScript("OnLeave", function(self)
		self.hover = false
		itemLook(self)
	end)
	item:SetScript("OnClick", function(self)
		C.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		Builds.selected = self.build.id
		Builds:Refresh()
	end)
	return item
end

-- ---------------------------------------------------------------------------
-- The page.

function Builds:Build(page)
	local heading = W.Text(page, "head", 18, "ink")
	heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	heading:SetLabel(L["Builds"])
	local sub = W.Text(page, "body", 11, "muted")
	sub:SetPoint("BOTTOMLEFT", heading, "BOTTOMRIGHT", 10, 2)
	sub:SetLabel(L["Where your talent points go, one point at a time."])

	ui.page = page
	-- Under the list: what to look for on gear, then the notes about the build.
	ui.gearLabel = W.Text(page, "label", 9, "accentText")
	ui.gearLabel:SetLabel(L["What to look for on gear"])
	ui.gear = W.Text(page, "body", 10.5, "muted", { width = LIST_W - 12 })
	ui.gear:SetSpacing(3)
	ui.note = W.Text(page, "body", 10.5, "faint", { width = LIST_W - 12 })
	ui.note:SetSpacing(3)

	local panel = W.Panel(page, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	panel:SetSize(PANEL_W, PANEL_H)
	panel:SetPoint("TOPLEFT", page, "TOPLEFT", PANEL_X, -TOP)
	ui.panel = panel
	ui.tile = W.IconTile(panel, "spark", 38, "accent")
	ui.tile:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -18)
	ui.title = W.Text(panel, "head", 17, "ink")
	ui.title:SetPoint("LEFT", ui.tile, "RIGHT", 14, 0)
	ui.follow = W.Button(panel, "", "primary", {
		height = 28, size = 11,
		onClick = function()
			local build = B.Get(Builds.selected)
			if not build then
				return
			elseif B.Chosen() == build then
				B.Choose(nil)
			else
				B.Choose(build.id)
			end
		end,
	})
	ui.follow:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -23)

	-- Shown instead of everything below when there is nothing to show.
	ui.empty = W.Text(panel, "body", 11.5, "muted", { width = INNER })
	ui.empty:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -72)
	ui.empty:SetSpacing(4)

	local body = CreateFrame("Frame", nil, panel)
	body:SetAllPoints(panel)
	ui.body = body

	ui.suits = W.Text(body, "body", 11.5, "muted", { width = INNER })
	ui.suits:SetPoint("TOPLEFT", body, "TOPLEFT", 20, -68)
	ui.suits:SetSpacing(4)

	ui.bar = W.Bar(body, 220, 8, "accent", "accent")
	ui.bar:SetPoint("TOPLEFT", body, "TOPLEFT", 20, -112)
	ui.placed = W.Text(body, "body", 11, "muted")
	ui.placed:SetPoint("LEFT", ui.bar, "RIGHT", 12, 0)

	ui.nextLabel = W.Text(body, "label", 9, "accentText")
	ui.nextLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 20, -138)
	ui.nextLabel:SetLabel(L["Next point"])
	ui.when = W.Text(body, "body", 10.5, "faint")
	ui.when:SetPoint("LEFT", ui.nextLabel, "RIGHT", 10, 0)

	local card = W.Panel(body, { shape = "card", fill = "tile", line = "tileLine" })
	card:SetSize(INNER, 84)
	card:SetPoint("TOPLEFT", body, "TOPLEFT", 20, -158)
	ui.card = card
	ui.icon = W.GameIcon(card, 40)
	ui.icon:SetPoint("LEFT", card, "LEFT", 14, 0)
	ui.open = W.Button(body, L["Open talents"], "ghost", {
		role = "accentText", height = 24, size = 10.5,
		onClick = function()
			B.Open()
		end,
	})
	ui.open:SetPoint("BOTTOMRIGHT", card, "TOPRIGHT", 0, 5)
	ui.name = W.Text(card, "head", 14, "ink")
	ui.name:SetPoint("TOPLEFT", card, "TOPLEFT", 66, -11)
	ui.rank = W.Text(card, "body", 11, "accentText")
	ui.rank:SetPoint("BOTTOMLEFT", ui.name, "BOTTOMRIGHT", 10, 1)
	-- Where to look for it in the talent window.
	ui.where = W.Text(card, "body", 10.5, "muted")
	ui.where:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -14)
	ui.why = W.Text(card, "body", 11.5, "ink", { width = INNER - 66 - 14 })
	ui.why:SetPoint("TOPLEFT", ui.name, "BOTTOMLEFT", 0, -5)
	ui.says = W.Text(card, "body", 10, "faint", { width = INNER - 66 - 14 })
	ui.says:SetPoint("TOPLEFT", ui.why, "BOTTOMLEFT", 0, -4)
	ui.says:SetSpacing(2)
	if ui.says.SetMaxLines then
		ui.says:SetMaxLines(2)
		ui.why:SetMaxLines(1)
	end

	ui.afterLabel = W.Text(body, "label", 9, "accentText")
	ui.afterLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 20, -254)
	ui.afterLabel:SetLabel(L["After that"])
	for index = 1, AFTER_ROWS do
		local row = CreateFrame("Frame", nil, body)
		row:SetSize(INNER, AFTER_H)
		row:SetPoint("TOPLEFT", body, "TOPLEFT", 20, -(270 + (index - 1) * AFTER_H))
		row.name = W.Text(row, "body", 11.5, "ink")
		row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.value = W.Text(row, "body", 11, "muted")
		row.value:SetPoint("LEFT", row, "LEFT", 230, 0)
		ui.after[index] = row
	end

	ui.fightLabel = W.Text(body, "label", 9, "accentText")
	ui.fightLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 20, -338)
	ui.fightLabel:SetLabel(L["In a fight"])
	ui.fight = W.Text(body, "body", 11.5, "muted", { width = INNER })
	ui.fight:SetPoint("TOPLEFT", ui.fightLabel, "BOTTOMLEFT", 0, -6)
	ui.fight:SetSpacing(5)

	ui.outside = W.Text(body, "body", 10.5, "faint", { width = INNER })
	ui.outside:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 20, 14)
	if ui.outside.SetMaxLines then
		ui.outside:SetMaxLines(1)
	end
	self.built = true
end

-- Chooses which build the page shows (from a card or a link).
function Builds:Goto(id)
	if B.Get(id) then
		self.selected = id
	end
end

local function showEmpty(title, text)
	ui.title:SetLabel(title)
	ui.empty:SetLabel(text)
	ui.empty:Show()
	ui.body:Hide()
end

local function points(count)
	return count == 1 and L["1 point"] or L["%d points"]:format(count)
end

local function showProgress(build, progress)
	ui.empty:Hide()
	ui.body:Show()
	ui.suits:SetLabel(build.suits)
	ui.bar:Set(progress.total > 0 and progress.done / progress.total or 0)
	ui.placed:SetLabel(L["%d of %d points placed"]:format(progress.done, progress.total))

	local nextPoint = progress.next
	ui.when:SetLabel(progress.unspent > 0 and (progress.unspent == 1 and L["you have 1 point to spend"]
			or L["you have %d points to spend"]:format(progress.unspent))
		or nextPoint and progress.nextLevel and L["comes at level %d"]:format(progress.nextLevel) or "")
	if nextPoint then
		ui.icon:SetIcon(nextPoint.icon)
		ui.icon:Show()
		ui.name:SetLabel(nextPoint.name)
		ui.rank:SetLabel(L["%d of %d"]:format(nextPoint.rank, nextPoint.max))
		ui.where:SetLabel(nextPoint.row and L["%s, row %d from the top"]:format(nextPoint.tree, nextPoint.row) or nextPoint.tree)
		ui.why:SetLabel(nextPoint.locked and progress.unspent > 0 and L["Not open yet: it needs more points in its tree first."] or nextPoint.why)
		ui.says:SetLabel(nextPoint.text and L["The game says: %s"]:format(nextPoint.text) or "")
	else
		ui.icon:Hide()
		ui.name:SetLabel(L["Build complete"])
		ui.rank:SetLabel("")
		ui.where:SetLabel("")
		ui.why:SetLabel(L["Every point in this build is placed."])
		ui.says:SetLabel("")
	end

	for index, row in ipairs(ui.after) do
		local item = progress.after[index]
		row:SetShown(item ~= nil)
		if item then
			row.name:SetLabel(item.name)
			row.value:SetLabel(item.from == item.to and L["%d of %d"]:format(item.to, item.max)
				or L["%d to %d of %d"]:format(item.from, item.to, item.max))
		end
	end
	ui.afterLabel:SetShown(#progress.after > 0)

	local lines = {}
	for index = 1, math.min(#progress.fight, FIGHT_LINES) do
		lines[index] = progress.fight[index]
	end
	ui.fight:SetLabel(table.concat(lines, "\n"))
	ui.fightLabel:SetShown(#lines > 0)

	if progress.outsidePoints > 0 then
		local names = {}
		for index = 1, math.min(#progress.outside, 3) do
			names[index] = progress.outside[index].name
		end
		ui.outside:SetLabel(L["%s outside this build (%s). Nothing is lost: carry on from here."]
			:format(points(progress.outsidePoints), table.concat(names, ", ") .. (#progress.outside > 3 and ", ..." or "")))
	else
		ui.outside:SetLabel("")
	end
end

function Builds:Refresh()
	if not self.built then
		return
	end
	local list = B.List()
	local chosen = B.Chosen()
	if not B.Get(self.selected) then
		self.selected = chosen and chosen.id or (list[1] and list[1].id) or nil
	end
	local build = B.Get(self.selected)

	for index, item in ipairs(list) do
		ui.items[index] = ui.items[index] or makeItem(ui.page, index)
		local button = ui.items[index]
		button.build = item
		button.icon:SetTexture(Theme.MEDIA .. "icon-" .. (item.icon or "spark"))
		button.label:SetLabel(item.name)
		button.state:SetLabel(item == chosen and L["Following"] or item.draft and L["Draft"] or "")
		button.state:SetRole(item == chosen and "go" or "faint")
		button:Show()
		itemLook(button)
	end
	for index = #list + 1, #ui.items do
		ui.items[index]:Hide()
	end
	local below = TOP + #list * (ITEM_H + ITEM_GAP) + 8
	ui.gearLabel:ClearAllPoints()
	ui.gearLabel:SetPoint("TOPLEFT", ui.page, "TOPLEFT", 6, -below)
	ui.gear:ClearAllPoints()
	ui.gear:SetPoint("TOPLEFT", ui.gearLabel, "BOTTOMLEFT", 0, -5)
	ui.note:ClearAllPoints()

	ui.follow:SetShown(build ~= nil)
	if not build then
		ui.note:SetPoint("TOPLEFT", ui.page, "TOPLEFT", 6, -below)
		ui.note:SetLabel("")
		ui.gearLabel:Hide()
		ui.gear:SetLabel("")
		showEmpty(L["No build for your class yet"],
			L["Builds are written from the game's own talent texts. Your class has none yet."]
			.. "\n\n" .. L["Until then, the Guide's Talents topic shows where your points are."])
		return
	end
	local hasGear = build.gear ~= nil and build.gear ~= ""
	ui.gearLabel:SetShown(hasGear)
	ui.gear:SetLabel(hasGear and build.gear or "")
	if hasGear then
		ui.note:SetPoint("TOPLEFT", ui.gear, "BOTTOMLEFT", 0, -16)
	else
		ui.note:SetPoint("TOPLEFT", ui.page, "TOPLEFT", 6, -below)
	end
	-- Draft builds are checked against the game's talent data by a tool, not played through.
	ui.note:SetLabel((build.draft and L["Draft: every point is checked against the game's talent data, but we have not played this build through yet."] .. "\n\n" or "")
		.. L["You spend the points yourself in the game's talent window. Trailhead shows where each one goes."])
	ui.tile.icon:SetTexture(Theme.MEDIA .. "icon-" .. (build.icon or "spark"))
	ui.follow:SetKind(build == chosen and "ghost" or "primary", build == chosen and "muted" or "accentText")
	ui.follow:SetLabel(build == chosen and L["Stop following"] or L["Follow this build"])

	if C.InCombat() then
		showEmpty(build.name, L["Talents cannot be read in combat. This page fills in after the fight."])
		return
	end
	local progress = B.Progress(build)
	if progress.problem == "changed" then
		ui.follow:Hide()
		showEmpty(build.name, L["The game's talents have changed since this build was written, so Trailhead will not suggest points from it. An update will bring it back."])
	elseif progress.problem then
		showEmpty(build.name, L["The game has not listed your talents yet. Try again in a moment."])
	else
		ui.title:SetLabel(build.name)
		showProgress(build, progress)
	end
end

-- ---------------------------------------------------------------------------
-- The narrow strip: when the screen has no room for the whole window beside the talents,
-- Window shows this instead, with just the next point.

local STRIP_W, STRIP_H = 230, 86

local function fillStrip()
	if not ui.strip or not ui.strip:IsShown() then
		return
	end
	local progress = B.Following()
	local nextPoint = progress and progress.next
	if nextPoint then
		ui.stripIcon:SetIcon(nextPoint.icon)
		ui.stripIcon:Show()
		ui.stripName:SetLabel(nextPoint.name)
		ui.stripLine:SetLabel(nextPoint.locked and L["Not open yet"] or L["%d of %d"]:format(nextPoint.rank, nextPoint.max))
	else
		ui.stripIcon:Hide()
		ui.stripName:SetLabel(L["Build complete"])
		ui.stripLine:SetLabel("")
	end
end

local function buildStrip()
	local strip = W.Panel(UIParent, { shape = "card", fill = "tile", line = "tileLine" })
	strip:SetSize(STRIP_W, STRIP_H)
	strip:SetFrameStrata("HIGH")
	strip:Hide()
	ui.strip = strip
	local label = W.Text(strip, "label", 9, "accentText")
	label:SetPoint("TOPLEFT", strip, "TOPLEFT", 12, -10)
	label:SetLabel(L["Next point"])
	ui.stripIcon = W.GameIcon(strip, 36)
	ui.stripIcon:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 12, 12)
	ui.stripName = W.Text(strip, "body", 12, "text", { width = STRIP_W - 66 })
	ui.stripName:SetPoint("TOPLEFT", ui.stripIcon, "TOPRIGHT", 10, -2)
	ui.stripLine = W.Text(strip, "body", 10.5, "faint")
	ui.stripLine:SetPoint("TOPLEFT", ui.stripName, "BOTTOMLEFT", 0, -3)
end

function Builds:Strip()
	return ui.strip
end

local queued = false
local function queue()
	fillStrip()
	if queued or not Builds.built or not Builds.page:IsVisible() then
		return
	end
	queued = true
	C_Timer.After(0.2, function()
		queued = false
		if Builds.page:IsVisible() then
			Builds:Refresh()
		end
	end)
end

function Builds:OnInit()
	T.Window:SetStrip("PlayerSpellsFrame", {
		width = STRIP_W,
		height = STRIP_H,
		ready = function()
			return B.Following() ~= nil
		end,
		show = function(x, y)
			if not ui.strip then
				buildStrip()
			end
			ui.strip:ClearAllPoints()
			ui.strip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
			ui.strip:Show()
			fillStrip()
		end,
		hide = function()
			if ui.strip then
				ui.strip:Hide()
			end
		end,
	})
	for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "PLAYER_LEVEL_UP",
		"PLAYER_REGEN_ENABLED", "TH_BUILD_CHANGED" }) do
		T:On(event, queue)
	end
end
