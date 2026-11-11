local _, T = ...
local L = T.L
local W = T.Widgets
local Theme = T.Theme
local C = T.Compat
local G = T.Game
local R = T.Routes
local D = T.Dungeons

-- The route through a dungeon or raid: the door, a tip or two, then the way in order with
-- each boss, where it stands and one plain tip. Bosses are ticked off as they die while the
-- player is inside. This game has no maps inside dungeons, so the route is in words.
-- Opened with T.Window:Select("dungeon", name); it has no tab of its own.

local Dungeon = T:NewModule("dungeon")

local PAGE_W = 778
local LIST_TOP = 98
local ROW_H, ROW_GAP = 72, 6
local TILE = 34
local TEXT_LEFT = 12 + TILE + 12

local ui = {}

local ICONS = { summary = "scroll", door = "gate", tip = "bulb", step = "arrow", boss = "sword" }

local function makeRow(list, width)
	local row = W.Panel(list, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	row:SetSize(width, ROW_H)
	row.tile = W.IconTile(row, "arrow", TILE, "accent")
	row.tile:SetPoint("LEFT", row, "LEFT", 12, 0)
	row.title = W.Text(row, "head", 13, "ink")
	row.body = W.Text(row, "body", 11, "muted", { width = width - TEXT_LEFT - 20 })
	row.body:SetSpacing(2)
	row.tag = W.Text(row, "label", 8.5, "go")
	row.tag:SetJustifyH("RIGHT")
	row.tag:SetPoint("RIGHT", row, "RIGHT", -14, 0)
	row.mark = W.Button(row, L["Set marker"], "ghost", {
		role = "accentText", height = 26, size = 10.5,
		onClick = function()
			local spot = row.item and row.item.spot
			if spot then
				R.Mark({ map = spot.map, x = spot.x, y = spot.y, mark = row.item.name })
			end
		end,
	})
	row.mark:SetPoint("RIGHT", row, "RIGHT", -12, 0)
	row.route = W.Button(row, L["How to get there"], "ghost", {
		role = "muted", height = 26, size = 10.5,
		onClick = function()
			if row.item then
				R.Show(R.ForDungeon(row.item.name))
			end
		end,
	})
	row.route:SetPoint("RIGHT", row.mark, "LEFT", -8, 0)

	function row:Fill(item)
		local kind = item.kind
		local down = item.killed
		self.tile.icon:SetTexture(Theme.MEDIA .. "icon-" .. (down and "check" or ICONS[kind]))
		self.tile.icon:SetRole(down and "go" or "accent")
		self:SetStyle({ line = item.next and "accent" or "cardLine" })
		local hasButtons = kind == "door" and item.spot ~= nil
		self.mark:SetShown(hasButtons)
		self.route:SetShown(hasButtons)
		local reserve = hasButtons and (self.mark:GetWidth() + self.route:GetWidth() + 40) or (kind == "boss" and 96 or 20)
		local room = self:GetWidth() - TEXT_LEFT - reserve
		self.title:SetShown(item.title ~= nil)
		self.body:ClearAllPoints()
		if item.title then
			self.title:SetLabel(item.title)
			self.title:SetRole(down and "muted" or "ink")
			self.title:SetWidth(room)
			self.title:ClearAllPoints()
			self.title:SetPoint("TOPLEFT", self, "TOPLEFT", TEXT_LEFT, -9)
			self.body:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -3)
		else
			self.body:SetPoint("LEFT", self, "LEFT", TEXT_LEFT, 0)
		end
		self.body:SetWidth(room)
		self.body:SetRole(item.title and "muted" or "ink")
		self.body:SetLabel(item.body or "")
		local tag = down and L["Down"] or (item.optional and L["Optional"]) or (item.next and L["Next"]) or ""
		self.tag:SetLabel(tag)
		self.tag:SetRole(down and "go" or (item.next and "accentText" or "faint"))
	end
	return row
end

function Dungeon:Build(page)
	ui.back = W.Button(page, L["Back"], "ghost", {
		role = "muted", height = 24, size = 10.5,
		onClick = function()
			T.Window:Select(Dungeon.from or T.Window.lastTab or "home")
		end,
	})
	ui.back:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
	ui.tile = W.IconTile(page, "gate", 44, "accent")
	ui.tile:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -2)
	ui.kicker = W.Text(page, "label", 9, "accentText")
	ui.kicker:SetPoint("TOPLEFT", ui.tile, "TOPRIGHT", 14, -3)
	ui.title = W.Text(page, "head", 19, "ink")
	ui.title:SetPoint("TOPLEFT", ui.kicker, "BOTTOMLEFT", 0, -5)
	ui.title:SetWidth(PAGE_W - 200)
	ui.facts = W.Text(page, "body", 11, "muted")
	ui.facts:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -58)
	ui.facts:SetWidth(PAGE_W)
	-- The line that matters inside: one short sentence, readable however narrow the window.
	ui.next = W.Text(page, "body", 12, "accentText")
	ui.next:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -76)
	ui.next:SetWidth(PAGE_W)
	ui.list = W.List(page, PAGE_W, 496 - LIST_TOP, ROW_H, ROW_GAP, makeRow)
	ui.list:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -LIST_TOP)
	self.built = true
end

-- Chooses the dungeon: a name from the group finder or the index.
function Dungeon:Goto(name)
	local id = type(name) == "number" and name or D.Find(name)
	if id then
		self.shown = id
		self.scroll = true
		local last = T.Window.lastTab
		self.from = last ~= "dungeon" and last or self.from
	end
end

local function items(dungeon, here)
	local out = {}
	out[#out + 1] = {
		kind = "summary", title = L["About this place"],
		body = dungeon.summary or L["Trailhead has no written route for this place yet. The bosses are listed below, in the order the game lists them."],
	}
	local spot = G.Entrance(dungeon.name)
	local door = dungeon.door
	if spot then
		local zone = spot.zone and L["The door is in %s."]:format(spot.zone) or L["Trailhead knows where the door is."]
		door = door and (zone .. " " .. door) or zone
	elseif not door then
		door = L["Trailhead does not know where the door is yet. It learns it the first time one of your characters walks in."]
	end
	out[#out + 1] = { kind = "door", title = L["Finding the door"], body = door, spot = spot, name = dungeon.name }
	for _, tip in ipairs(dungeon.tips) do
		out[#out + 1] = { kind = "tip", title = L["Tip for the group"], body = tip }
	end
	local nextBoss = here and D.Next(dungeon.id) or nil
	local function boss(name, where, tip, optional)
		local text = where
		if tip then
			text = (text and text .. "\n" or "") .. L["Tip: %s"]:format(tip)
		end
		return {
			kind = "boss", title = name, body = text or "", optional = optional,
			killed = here and D.Killed(dungeon.id, name) or false,
			next = nextBoss ~= nil and nextBoss.name == name and not D.Killed(dungeon.id, name),
		}
	end
	if dungeon.steps then
		for _, step in ipairs(dungeon.steps) do
			if step.boss then
				out[#out + 1] = boss(step.boss, step.where, step.tip, step.optional)
			else
				out[#out + 1] = { kind = "step", body = step.text }
			end
		end
	else
		for _, entry in ipairs(dungeon.bosses) do
			out[#out + 1] = boss(entry.name)
		end
	end
	return out
end

function Dungeon:Refresh()
	if not self.built then
		return
	end
	local dungeon = self.shown and D.Get(self.shown)
	if not dungeon then
		T.Window:Select(T.Window.lastTab or "home")
		return
	end
	local current = D.Current()
	local here = current ~= nil and current.id == dungeon.id
	ui.kicker:SetLabel(dungeon.kind == "raid" and L["Raid"] or L["Dungeon"])
	ui.title:SetLabel(dungeon.name)
	local facts = {}
	local lo, hi = D.Levels(dungeon.id)
	if lo then
		facts[#facts + 1] = L["Levels %d to %d"]:format(lo, hi)
	end
	facts[#facts + 1] = dungeon.size == 1 and L["For one player"]
		or dungeon.kind == "raid" and L["A raid for up to %d players"]:format(dungeon.size)
		or L["A group of %d"]:format(dungeon.size)
	if #dungeon.bosses > 0 then
		facts[#facts + 1] = #dungeon.bosses == 1 and L["1 boss"] or L["%d bosses"]:format(#dungeon.bosses)
	end
	ui.facts:SetLabel(table.concat(facts, "  \194\183  "))
	if here then
		local down, total = D.Progress(dungeon.id)
		local boss = D.Next(dungeon.id)
		if boss then
			ui.next:SetLabel(L["Next boss: %s  (%d of %d down)"]:format(boss.name, down, total))
		else
			ui.next:SetLabel(total > 0 and L["Every boss is down. Well done!"] or L["You are inside."])
		end
		ui.next:SetRole("accentText")
	else
		ui.next:SetLabel(L["Inside the dungeon, this page ticks off each boss as it falls."])
		ui.next:SetRole("faint")
	end
	local list = items(dungeon, here)
	if self.scroll then
		-- Opening the page inside a dungeon starts on the next boss.
		self.scroll = false
		ui.list.offset = 0
		for index, item in ipairs(list) do
			if item.next then
				ui.list.offset = math.max(0, index - 2)
			end
		end
		ui.list:SetItems(list, true)
	else
		ui.list:SetItems(list, true)
	end
end

local queued = false
local function queue()
	if queued or not Dungeon.built or not Dungeon.page:IsVisible() then
		return
	end
	queued = true
	C_Timer.After(0.3, function()
		queued = false
		if Dungeon.page:IsVisible() and not C.InCombat() then
			Dungeon:Refresh()
		end
	end)
end

function Dungeon:OnInit()
	for _, event in ipairs({ "TH_DUNGEON_CHANGED", "TH_PLACES_CHANGED", "PLAYER_LEVEL_UP" }) do
		T:On(event, queue)
	end
end
