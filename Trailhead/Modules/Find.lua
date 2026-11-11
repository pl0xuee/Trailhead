local _, T = ...
local L = T.L
local W = T.Widgets
local Theme = T.Theme
local C = T.Compat
local G = T.Game
local P = T.Places
local R = T.Routes

-- Find it: pick what you need (or type it in the search box) and get every one Trailhead
-- knows about, nearest first, each with a button that puts the game's marker on it.

local Find = T:NewModule("find", { label = L["Find it"], icon = "pin", order = 2 })

local PAGE_W = 778
local PILLS_TOP, PILL_H, PILL_GAP = 36, 28, 8
-- The pills take two or three rows, by the theme's font; the list is sized for three.
local MAX_PILL_ROWS = 3
local function headTop(rows)
	return PILLS_TOP + rows * PILL_H + (rows - 1) * PILL_GAP + 14
end
local LIST_GAP = 34
local LIST_TOP = headTop(MAX_PILL_ROWS) + LIST_GAP
local ROW_H, ROW_GAP = 52, 6
local TEXT_ROOM = 470 -- row width not available to text: the icon, the tag and the two buttons

local ui = { pills = {} }
Find.category = "trainer"
Find.query = ""

local STATES = {
	fit = { L["Right for you"], "go" },
	soon = { L["Almost"], "info" },
	hard = { L["Too dangerous"], "warn" },
	done = { L["Outgrown"], "faint" },
}

-- "240 yards", "1,900 yards": straight-line distance, rounded so it does not flicker.
local function yardsText(yards)
	local rounded = yards < 1000 and math.floor(yards / 10 + 0.5) * 10 or math.floor(yards / 100 + 0.5) * 100
	local text = tostring(rounded)
	if rounded >= 1000 then
		text = text:sub(1, -4) .. "," .. text:sub(-3)
	end
	return L["%s yards"]:format(text)
end
Find.YardsText = yardsText

local function makeRow(list, width)
	local row = W.Panel(list, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	row:SetSize(width, ROW_H)
	row.tile = W.IconTile(row, "pin", 34, "accent")
	row.tile:SetPoint("LEFT", row, "LEFT", 10, 0)
	row.title = W.Text(row, "head", 13, "ink")
	row.title:SetPoint("TOPLEFT", row.tile, "TOPRIGHT", 12, -1)
	row.title:SetWidth(width - TEXT_ROOM) -- a fixed width cuts a long name short with "..."
	row.detail = W.Text(row, "body", 10.5, "muted")
	row.detail:SetPoint("BOTTOMLEFT", row.tile, "BOTTOMRIGHT", 12, 2)
	row.detail:SetWidth(width - TEXT_ROOM)
	row.button = W.Button(row, L["Set marker"], "ghost", {
		role = "accentText", height = 28, size = 11,
		onClick = function()
			local item = row.item
			if not item then
				return
			elseif item.kind == "category" then
				T.Window:Select("find", item.category)
			elseif item.kind == "dungeon" then
				T.Window:Select("dungeon", item.title)
			elseif item.kind == "zone" then
				P.ShowMap(item.map)
			else
				-- Set the marker and show it: the game's map opens on the place.
				local _, mapID = P.Go(item)
				P.ShowMap(mapID)
				Find:Refresh(true) -- show "Remove marker" at once
			end
		end,
	})
	row.button:SetPoint("RIGHT", row, "RIGHT", -12, 0)
	row.route = W.Button(row, L["How to get there"], "ghost", {
		role = "muted", height = 28, size = 11,
		onClick = function()
			local target = row.item and R.ForResult(row.item)
			if target then
				R.Show(target)
			end
		end,
	})
	row.tag = W.Text(row, "label", 8.5, "go")
	row.tag:SetJustifyH("RIGHT")

	function row:Fill(item)
		self.tile.icon:SetTexture(Theme.MEDIA .. "icon-" .. (item.icon or "pin"))
		self.title:SetLabel(item.title)
		local detail = item.where or ""
		if item.note then
			detail = detail ~= "" and (detail .. "  \194\183  " .. item.note) or item.note
		end
		self.detail:SetLabel(detail)
		local state = item.state and STATES[item.state]
		if state then
			self.tag:SetLabel(state[1])
			self.tag:SetRole(state[2])
		elseif item.yards and (item.kind == "place" or item.kind == "flight") then
			-- How far it is, so the order of the list explains itself; green when it is in this zone.
			self.tag:SetLabel(yardsText(item.yards))
			self.tag:SetRole(item.here and "go" or "muted")
		elseif item.here and (item.kind == "place" or item.kind == "flight") then
			self.tag:SetLabel(L["In this zone"])
			self.tag:SetRole("go")
		else
			self.tag:SetLabel("")
		end
		-- A dungeon the index knows has a route page; its button sits where "Set marker" would.
		local routed = item.kind == "dungeon" and T.Dungeons.Has(item.title)
		self.button:SetShown(item.kind ~= "dungeon" or routed)
		-- The route button sits left of the main one, or in its place when there is none.
		self.route:SetShown(item.kind ~= "category")
		self.route:ClearAllPoints()
		self.tag:ClearAllPoints()
		if item.kind == "dungeon" and not routed then
			self.route:SetPoint("RIGHT", self, "RIGHT", -12, 0)
		else
			self.route:SetPoint("RIGHT", self.button, "LEFT", -8, 0)
		end
		self.tag:SetPoint("RIGHT", item.kind == "category" and self.button or self.route, "LEFT", -12, 0)
		if item.kind == "category" then
			self.button:SetLabel(L["Show"])
		elseif routed then
			self.button:SetLabel(L["Route"])
		elseif item.kind == "zone" then
			self.button:SetLabel(L["Open map"])
		else
			self.button:SetLabel(L["Set marker"])
		end
	end
	return row
end

-- Pills wrap onto a second row; their widths follow the theme's font.
local function layoutPills()
	local x, y = 0, 0
	for _, pill in ipairs(ui.pills) do
		local width = pill:GetWidth()
		if x > 0 and x + width > PAGE_W then
			x, y = 0, y + PILL_H + PILL_GAP
		end
		pill:ClearAllPoints()
		pill:SetPoint("TOPLEFT", ui.page, "TOPLEFT", x, -(PILLS_TOP + y))
		x = x + width + PILL_GAP
	end
	-- Everything under the pills follows the number of rows they took.
	local rows = math.floor(y / (PILL_H + PILL_GAP) + 0.5) + 1
	ui.pillRows = rows
	if ui.list then
		local top = headTop(math.min(rows, MAX_PILL_ROWS))
		ui.title:ClearAllPoints()
		ui.title:SetPoint("TOPLEFT", ui.page, "TOPLEFT", 0, -top)
		ui.track:ClearAllPoints()
		ui.track:SetPoint("TOPRIGHT", ui.page, "TOPRIGHT", 0, -(top - 5))
		ui.list:ClearAllPoints()
		ui.list:SetPoint("TOPLEFT", ui.page, "TOPLEFT", 0, -(top + LIST_GAP))
		ui.list:Resize(496 - (top + LIST_GAP)) -- fewer lines of buttons, more rows of places
		ui.emptyTile:ClearAllPoints()
		ui.emptyTile:SetPoint("TOP", ui.page, "TOP", 0, -(top + LIST_GAP + 50))
	end
end

-- How many rows the category buttons took, and how many buttons there are.
function Find.Layout()
	return ui.pillRows, #ui.pills
end

function Find:Build(page)
	ui.page = page
	local heading = W.Text(page, "head", 18, "ink")
	heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	heading:SetLabel(L["Find it"])
	local sub = W.Text(page, "body", 11, "muted")
	sub:SetPoint("BOTTOMLEFT", heading, "BOTTOMRIGHT", 10, 2)
	sub:SetLabel(L["Pick what you need, or type it in the search box above."])

	ui.unmark = W.Button(page, L["Remove marker"], "ghost", {
		role = "muted", height = 24, size = 10.5,
		onClick = function()
			P.ClearMarker()
			Find:Refresh(true)
		end,
	})
	ui.unmark:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 2)

	for _, category in ipairs(T.Categories) do
		if not category.hidden then
			local pill = W.Pill(page, category.label, category.icon, function()
				T.Window:Select("find", category.id)
			end)
			pill.category = category.id
			ui.pills[#ui.pills + 1] = pill
		end
	end
	Theme:Track({ Restyle = function() end, AfterRestyle = layoutPills })

	ui.title = W.Text(page, "head", 14, "ink")
	ui.note = W.Text(page, "body", 10.5, "muted")
	ui.note:SetPoint("BOTTOMLEFT", ui.title, "BOTTOMRIGHT", 10, 1)
	ui.track = W.Button(page, L["Show on the minimap"], "ghost", {
		role = "accentText", height = 26, size = 10.5,
		onClick = function()
			local _, on = P.Tracking(Find.category)
			P.SetTracking(Find.category, not on)
			Find:Refresh()
		end,
	})

	ui.list = W.List(page, PAGE_W, 496 - LIST_TOP, ROW_H, ROW_GAP, makeRow)

	ui.emptyTile = W.IconTile(page, "pin", 56, "accent")
	ui.emptyTitle = W.Text(page, "head", 15, "ink")
	ui.emptyTitle:SetPoint("TOP", ui.emptyTile, "BOTTOM", 0, -16)
	ui.emptyTitle:SetJustifyH("CENTER")
	ui.emptyText = W.Text(page, "body", 12, "muted", { width = 500 })
	ui.emptyText:SetPoint("TOP", ui.emptyTitle, "BOTTOM", 0, -10)
	ui.emptyText:SetJustifyH("CENTER")
	ui.emptyText:SetSpacing(4)
	layoutPills()
	self.built = true
end

-- Chooses a category (from Home's tiles, an advice card or a pill).
function Find:Goto(categoryId)
	if T.CategoryById[categoryId] and not T.CategoryById[categoryId].hidden then
		self.category = categoryId
		self.query = ""
		T.Window:ClearSearch()
	end
end

-- Called as the player types in the search box.
function Find:SetQuery(text)
	self.query = (text or ""):match("^%s*(.-)%s*$")
	self:Refresh()
end

local function showEmpty(icon, title, text)
	ui.emptyTile.icon:SetTexture(Theme.MEDIA .. "icon-" .. icon)
	ui.emptyTitle:SetLabel(title)
	ui.emptyText:SetLabel(text)
	ui.emptyTile:Show()
	ui.emptyTitle:Show()
	ui.emptyText:Show()
end

function Find:Refresh(keep)
	if not self.built then
		return
	end
	local searching = self.query ~= ""
	local category = T.CategoryById[self.category] or T.Categories[1]
	for _, pill in ipairs(ui.pills) do
		pill:SetOn(not searching and pill.category == category.id)
	end
	ui.unmark:SetShown(P.HasMarker())

	local items
	if searching then
		items = P.Search(self.query)
		ui.title:SetLabel(L["Search results"])
		ui.note:SetLabel(#items == 1 and L["1 match"] or L["%d matches"]:format(#items))
	else
		items = P.Find(category.id)
		ui.title:SetLabel(category.label)
		if category.id == "flight" then
			ui.note:SetLabel(L["Flight points for your side, nearest first"])
		elseif #items == 0 then
			ui.note:SetLabel("")
		else
			local builtIn = false
			for _, item in ipairs(items) do
				builtIn = builtIn or item.shipped == true
			end
			-- The built-in list is capped: say that places you find are added to it.
			ui.note:SetLabel(builtIn and L["%d places, nearest first. Places you find yourself are added."]:format(#items)
				or #items == 1 and L["1 place known"] or L["%d places known, nearest first"]:format(#items))
		end
	end

	local index, on = nil, false
	if not searching then
		index, on = P.Tracking(category.id)
	end
	ui.track:SetShown(index ~= nil)
	if index then
		ui.track:SetKind("ghost", on and "go" or "accentText")
		ui.track:SetLabel(on and L["Shown on the minimap"] or L["Show on the minimap"])
	end

	ui.list:SetItems(items, keep)
	ui.emptyTile:Hide()
	ui.emptyTitle:Hide()
	ui.emptyText:Hide()
	if #items == 0 then
		if searching then
			showEmpty("search", L["Nothing found"],
				L["Trailhead knows nothing called \"%s\" yet. It searches places you have found, flight points, zones and dungeons."]:format(self.query))
		elseif category.id == "flight" then
			showEmpty("wing", L["No flight points listed"],
				L["The game has no flight points to show for where you are standing. Try again outside."])
		else
			local text = L["Trailhead remembers every one you use, for all your characters. In a city, ask a guard for directions: Trailhead keeps those too."]
			if index then
				text = text .. "\n\n" .. L["Until then, press \"Show on the minimap\" and the game marks any that are close to you."]
			end
			showEmpty(category.icon, L["None found yet"], text)
		end
	end
end

local queued = false
local function queue()
	if queued or not Find.built or not Find.page:IsVisible() then
		return
	end
	queued = true
	C_Timer.After(0.25, function()
		queued = false
		if Find.page:IsVisible() and not C.InCombat() then
			Find:Refresh(true)
		end
	end)
end

function Find:OnInit()
	for _, event in ipairs({
		"TH_PLACES_CHANGED", "TH_MARKER_CHANGED", "TH_TRACKING_CHANGED", "USER_WAYPOINT_UPDATED",
		"MINIMAP_UPDATE_TRACKING", "ZONE_CHANGED_NEW_AREA",
	}) do
		T:On(event, queue)
	end
end
