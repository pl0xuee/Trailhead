local _, T = ...
local L = T.L
local W = T.Widgets
local C = T.Compat
local G = T.Game
local P = T.Places
local R = T.Routes

-- Zones: every zone and dungeon with the levels it is meant for, judged against your
-- level, so "where do I go next?" has an answer. Each zone says where your side should start
-- (its quest hub), and "Quest hubs" lists every hub there with its levels, inn and flight master.

local Zones = T:NewModule("zones", { label = L["Zones"], icon = "mtn", order = 4 })

local PAGE_W = 778
local PILLS_TOP, LIST_TOP = 36, 80
local ROW_H, ROW_GAP = 62, 6
local HUB_H = 52
local TEXT_W = 338 -- room for the text of a row beside its three buttons

local FILTERS = {
	{ id = "fit", label = L["For my level"] },
	{ id = "all", label = L["All zones"] },
	{ id = "dungeons", label = L["Dungeons"] },
	{ id = "raids", label = L["Raids"] },
}

local STATES = {
	fit = { L["Right for you"], "go" },
	soon = { L["Almost"], "info" },
	hard = { L["Too dangerous"], "warn" },
	done = { L["Outgrown"], "faint" },
}

local ui = { pills = {} }
Zones.filter = "fit"
Zones.view = nil -- a zone's map id while its quest hubs are shown

local function hubsOf(map)
	return T.Hubs and T.Hubs.ForZone(map) or {}
end

-- "Start at Razor Hill, levels 6 to about 10", or why there is no start.
local function startLine(map)
	local hubs = T.Hubs
	if not hubs then
		return ""
	end
	local start = hubs.Start(map)
	if start then
		return L["Start at %s, %s"]:format(start.name, hubs.Levels(start))
	end
	if #hubs.ForZone(map) > 0 then
		return L["Quest hubs here, none clearly the place to start"]
	elseif hubs.Known(map) then
		return L["No quest hub listed for your side"]
	end
	return ""
end

-- Puts the game's marker on a hub and opens the map there.
local function markHub(hub)
	if hub then
		P.SetMarker(hub.map, hub.x, hub.y, hub.name)
		P.ShowMap(hub.map)
	end
end

local function makeRow(list, width)
	local row = W.Panel(list, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	row:SetSize(width, ROW_H)
	row.badge = W.Panel(row, { shape = "small", fill = "tile", line = "tileLine" })
	row.badge:SetSize(58, 24)
	row.badge:SetPoint("LEFT", row, "LEFT", 12, 0)
	row.range = W.Text(row.badge, "body", 11, "accentText")
	row.range:SetPoint("CENTER", row.badge, "CENTER", 0, 0)
	row.range:SetJustifyH("CENTER")
	row.title = W.Text(row, "head", 13, "ink")
	row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 84, -9)
	row.title:SetWidth(TEXT_W) -- a fixed width cuts a long name short with "..."
	row.detail = W.Text(row, "body", 10.5, "muted")
	row.detail:SetPoint("TOPLEFT", row, "TOPLEFT", 84, -27)
	row.detail:SetWidth(TEXT_W)
	row.start = W.Text(row, "body", 10.5, "accentText")
	row.start:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 84, 8)
	row.start:SetWidth(TEXT_W)
	row.button = W.Button(row, L["Open map"], "ghost", {
		role = "accentText", height = 26, size = 10.5,
		onClick = function()
			local item = row.item
			if not item then
				return
			elseif item.dungeon then
				T.Window:Select("dungeon", item.name)
			elseif item.map then
				-- With a hub to start at, the marker goes there and the map opens on the zone.
				markHub(T.Hubs and T.Hubs.Start(item.map))
				P.ShowMap(item.map)
			end
		end,
	})
	row.route = W.Button(row, L["How to get there"], "ghost", {
		role = "muted", height = 26, size = 10.5,
		onClick = function()
			local item = row.item
			if not item then
				return
			end
			R.Show(item.map and R.ForZone(item.map, item.name) or R.ForDungeon(item.name))
		end,
	})
	row.hubs = W.Button(row, L["Quest hubs"], "ghost", {
		role = "muted", height = 26, size = 10.5,
		onClick = function()
			if row.item and row.item.map then
				T.Window:Select("zones", { hubs = row.item.map, name = row.item.name })
			end
		end,
	})
	row.button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -12, 9)
	row.tag = W.Text(row, "label", 8.5, "go")
	row.tag:SetJustifyH("RIGHT")
	row.tag:SetPoint("TOPRIGHT", row, "TOPRIGHT", -14, -11)

	function row:Fill(item)
		self.title:SetLabel(item.name)
		self.range:SetLabel(item.lo and (item.lo .. "-" .. item.hi) or "\226\128\147")
		self.detail:SetLabel(item.detail or "")
		self.start:SetLabel(item.start or "")
		self:SetStyle({ line = item.here and "accent" or "cardLine" })
		local state = STATES[item.state or ""]
		self.tag:SetLabel(state and state[1] or "")
		self.tag:SetRole(state and state[2] or "faint")
		-- The main button is "Open map" on a zone and "Route" on a dungeon that has a route page.
		local main = item.map ~= nil or item.routed
		self.button:SetShown(main and true or false)
		self.button:SetLabel(item.dungeon and L["Route"] or L["Open map"])
		self.hubs:SetShown(item.hubs and true or false)
		-- From the right: main button, then "How to get there", then "Quest hubs".
		self.route:ClearAllPoints()
		self.hubs:ClearAllPoints()
		if main then
			self.route:SetPoint("RIGHT", self.button, "LEFT", -8, 0)
		else
			self.route:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -12, 9)
		end
		self.hubs:SetPoint("RIGHT", self.route, "LEFT", -8, 0)
	end
	return row
end

-- A hub on the zone's hub list: its levels, whether it has an inn and a flight master.
local function makeHubRow(list, width)
	local row = W.Panel(list, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	row:SetSize(width, HUB_H)
	row.badge = W.Panel(row, { shape = "small", fill = "tile", line = "tileLine" })
	row.badge:SetSize(58, 24)
	row.badge:SetPoint("LEFT", row, "LEFT", 12, 0)
	row.range = W.Text(row.badge, "body", 11, "accentText")
	row.range:SetPoint("CENTER", row.badge, "CENTER", 0, 0)
	row.range:SetJustifyH("CENTER")
	row.title = W.Text(row, "head", 13, "ink")
	row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 84, -9)
	row.title:SetWidth(TEXT_W)
	row.detail = W.Text(row, "body", 10.5, "muted")
	row.detail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 84, 8)
	row.detail:SetWidth(TEXT_W)
	row.marker = W.Button(row, L["Set marker"], "ghost", {
		role = "accentText", height = 26, size = 10.5,
		onClick = function()
			markHub(row.item and row.item.hub)
		end,
	})
	row.marker:SetPoint("RIGHT", row, "RIGHT", -12, 0)
	row.route = W.Button(row, L["How to get there"], "ghost", {
		role = "muted", height = 26, size = 10.5,
		onClick = function()
			if row.item then
				R.Show(R.ForHub(row.item.hub, row.item.zone))
			end
		end,
	})
	row.route:SetPoint("RIGHT", row.marker, "LEFT", -8, 0)
	row.flight = W.Icon(row, "wing", 14, "go")
	row.flight:SetPoint("RIGHT", row.route, "LEFT", -14, 0)
	row.inn = W.Icon(row, "bed", 14, "go")
	row.inn:SetPoint("RIGHT", row.flight, "LEFT", -8, 0)
	row.tag = W.Text(row, "label", 8.5, "go")
	row.tag:SetJustifyH("RIGHT")
	row.tag:SetPoint("RIGHT", row.inn, "LEFT", -14, 0)

	function row:Fill(item)
		local hub = item.hub
		self.title:SetLabel(hub.name)
		self.range:SetLabel(hub.lo == hub.typical and tostring(hub.typical) or (hub.lo .. "-" .. hub.typical))
		local parts = { T.Hubs.Levels(hub):gsub("^%l", string.upper), L["%d quests"]:format(hub.quests) }
		if hub.inn then
			parts[#parts + 1] = L["Inn"]
		end
		if hub.flight then
			parts[#parts + 1] = L["Flight master"]
		end
		self.detail:SetLabel(table.concat(parts, "  \194\183  "))
		self.tag:SetLabel(hub.start and L["Start here"] or "")
		self:SetStyle({ line = hub.start and "accent" or "cardLine" })
		self.inn:SetShown(hub.inn)
		self.flight:SetShown(hub.flight)
		-- The marks close up to the buttons: no gap where a hub has no inn or flight master.
		local edge = hub.flight and self.flight or self.route
		self.inn:ClearAllPoints()
		self.inn:SetPoint("RIGHT", edge, "LEFT", hub.flight and -8 or -14, 0)
		edge = hub.inn and self.inn or edge
		self.tag:ClearAllPoints()
		self.tag:SetPoint("RIGHT", edge, "LEFT", -14, 0)
	end
	return row
end

function Zones:Build(page)
	local heading = W.Text(page, "head", 18, "ink")
	heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	heading:SetLabel(L["Zones"])
	ui.heading = heading
	ui.sub = W.Text(page, "body", 11, "muted")
	ui.sub:SetPoint("BOTTOMLEFT", heading, "BOTTOMRIGHT", 10, 2)
	ui.back = W.Button(page, L["Back"], "ghost", {
		role = "muted", height = 24, size = 10.5,
		onClick = function()
			T.Window:Select("zones", Zones.filter)
		end,
	})
	ui.back:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
	ui.back:Hide()
	ui.hubNote = W.Text(page, "body", 11, "muted", { width = PAGE_W - 24 })
	ui.hubNote:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -PILLS_TOP)
	ui.hubNote:SetSpacing(3)

	local previous
	for _, filter in ipairs(FILTERS) do
		local pill = W.Pill(page, filter.label, nil, function()
			T.Window:Select("zones", filter.id)
		end)
		pill.filter = filter.id
		if previous then
			pill:SetPoint("LEFT", previous, "RIGHT", 8, 0)
		else
			pill:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -PILLS_TOP)
		end
		previous = pill
		ui.pills[#ui.pills + 1] = pill
	end

	ui.list = W.List(page, PAGE_W, 496 - LIST_TOP, ROW_H, ROW_GAP, makeRow)
	ui.list:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -LIST_TOP)
	ui.hubList = W.List(page, PAGE_W, 496 - LIST_TOP, HUB_H, ROW_GAP, makeHubRow)
	ui.hubList:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -LIST_TOP)
	ui.hubList:Hide()
	ui.empty = W.Text(page, "body", 12, "muted", { width = 520 })
	ui.empty:SetPoint("TOP", page, "TOP", 0, -(LIST_TOP + 90))
	ui.empty:SetJustifyH("CENTER")
	ui.empty:SetSpacing(4)
	self.built = true
end

function Zones:Goto(filter)
	self.view, self.viewName = nil, nil
	if type(filter) == "table" then
		-- { hubs = map id, name = zone name }: the hubs of one zone
		if type(filter.hubs) == "number" then
			self.view, self.viewName = filter.hubs, filter.name
		end
		return
	end
	for _, known in ipairs(FILTERS) do
		if known.id == filter then
			self.filter = filter
		end
	end
end

local function zoneItems(filter, level)
	local items = {}
	local current = G.CurrentZone()
	for _, zone in ipairs(G.World().zones) do
		local state = G.RangeState(zone.lo, zone.hi, level)
		if filter == "all" or state == "fit" or state == "soon" then
			local detail = zone.continent or ""
			local hubs = hubsOf(zone.map)
			-- Strictly true or false: the sort below compares it.
			local away = (zone.hostile and not zone.friendly) and true or false
			if zone == current then
				detail = L["You are here"]
			elseif away then
				detail = (detail ~= "" and detail .. "  \194\183  " or "") .. L["No flight point for your side"]
			end
			items[#items + 1] = {
				name = zone.name, lo = zone.lo, hi = zone.hi, map = zone.map, state = state,
				detail = detail, here = zone == current, away = away,
				start = startLine(zone.map), hubs = #hubs > 0,
			}
		end
	end
	if filter == "fit" then
		-- Zones your side can reach easily first, and among those the ones you are in range of.
		local order = { fit = 1, soon = 2 }
		table.sort(items, function(a, b)
			if a.away ~= b.away then
				return not a.away
			end
			if a.state ~= b.state then
				return order[a.state] < order[b.state]
			end
			if a.lo ~= b.lo then
				return a.lo > b.lo
			end
			return a.name < b.name
		end)
	end
	return items
end

Zones.Items = zoneItems

local function dungeonItems(level, raids)
	local items = {}
	local world = G.World()
	for _, dungeon in ipairs(raids and world.raids or world.dungeons) do
		local spot = G.Entrance(dungeon.name)
		local detail = raids and L["Raid for a large group"] or L["Dungeon for a group of five"]
		if spot and spot.zone then
			detail = detail .. "  \194\183  " .. L["Entrance in %s"]:format(spot.zone)
		end
		-- T.Dungeons is another page's service: the Route button is simply absent without it.
		local routed = T.Dungeons and T.Dungeons.Has and T.Dungeons.Has(dungeon.name) or false
		items[#items + 1] = {
			name = dungeon.name, lo = dungeon.lo, hi = dungeon.hi, dungeon = true, routed = routed,
			state = G.RangeState(dungeon.lo, dungeon.hi, level), detail = detail,
		}
	end
	return items
end

Zones.DungeonItems = dungeonItems

function Zones:Refresh(keep)
	if not self.built then
		return
	end
	local level = G.Level()
	local hubView = self.view ~= nil
	ui.back:SetShown(hubView)
	ui.hubNote:SetShown(hubView)
	ui.hubList:SetShown(hubView)
	ui.list:SetShown(not hubView)
	for _, pill in ipairs(ui.pills) do
		pill:SetShown(not hubView)
		pill:SetOn(pill.filter == self.filter)
	end
	if hubView then
		self:RefreshHubs(keep)
		return
	end
	ui.heading:SetLabel(L["Zones"])
	local items
	if self.filter == "dungeons" then
		items = dungeonItems(level)
		ui.sub:SetLabel(L["Dungeons and the levels they are meant for. You are level %d."]:format(level))
	elseif self.filter == "raids" then
		items = dungeonItems(level, true)
		ui.sub:SetLabel(L["Raids and the levels they are meant for. You are level %d."]:format(level))
	else
		items = zoneItems(self.filter, level)
		ui.sub:SetLabel(L["Zones and the levels they are meant for. You are level %d."]:format(level))
	end
	ui.list:SetItems(items, keep)
	if #items > 0 then
		ui.empty:SetLabel("")
	elseif self.filter == "dungeons" then
		ui.empty:SetLabel(L["The game has not listed any dungeons yet. Try again in a moment."])
	elseif self.filter == "raids" then
		ui.empty:SetLabel(L["The game lists no raids for your character yet.\nRaids are for large groups at the highest levels. They will appear here, with how to get to each, as soon as the game lists them."])
	elseif self.filter == "fit" and #G.World().zones > 0 then
		ui.empty:SetLabel(L["No zone is listed for your level. Look at All zones."])
	else
		ui.empty:SetLabel(L["The game has not listed its zones yet. Try again in a moment."])
	end
end

-- A zone's quest hubs: where to start first, then by level.
function Zones:RefreshHubs(keep)
	local zone = self.viewName or G.MapName(self.view) or ""
	ui.heading:SetLabel(zone)
	ui.sub:SetLabel(L["Quest hubs"])
	local items = {}
	for _, hub in ipairs(hubsOf(self.view)) do
		items[#items + 1] = { hub = hub, zone = zone }
	end
	ui.hubList:SetItems(items, keep)
	ui.empty:SetLabel("")
	if #items == 0 then
		ui.hubNote:SetLabel(startLine(self.view) .. "\n" .. L["Trailhead has no quest hubs listed for your side in this zone."])
		return
	end
	local note = L["Towns and camps where several quests start, for your side."]
	local start = T.Hubs and T.Hubs.Start(self.view)
	if start then
		note = note .. " " .. L["Start at the first one, %s."]:format(start.name)
	end
	ui.hubNote:SetLabel(note)
end

local queued = false
local function queue()
	if queued or not Zones.built or not Zones.page:IsVisible() then
		return
	end
	queued = true
	C_Timer.After(0.3, function()
		queued = false
		if Zones.page:IsVisible() and not C.InCombat() then
			Zones:Refresh(true)
		end
	end)
end

function Zones:OnInit()
	T:On("PLAYER_LEVEL_UP", queue)
	T:On("ZONE_CHANGED_NEW_AREA", queue)
end
