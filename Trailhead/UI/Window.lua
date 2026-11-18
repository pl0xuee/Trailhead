local _, T = ...
local L = T.L
local W = T.Widgets
local Theme = T.Theme
local C = T.Compat

-- The one window: title bar, tab rail on the left, and a page that shows the current
-- module. Built the first time it is opened.

local Window = {}
T.Window = Window

local WIDTH, HEIGHT = 920, 600
local BAR, RAIL, PAD, INSET = 54, 92, 10, 20
local TAB_W, TAB_H, TAB_GAP = 76, 62, 6

-- Room a module's page has to draw in.
Window.PAGE_W = WIDTH - RAIL - PAD - INSET * 2 -- 778
Window.PAGE_H = HEIGHT - BAR - PAD - INSET * 2 -- 496

local frame, host
local tabs = {} -- module id -> tab button

local function tabLook(tab)
	local on = tab.active
	tab:SetStyle({
		shape = "tab",
		fill = on and "tabOn" or (tab.hover and "tabHover" or false),
		top = on and "tabOnTop" or false,
	})
	tab.icon:SetRole(on and "tabOnText" or "railText")
	tab.label:SetRole(on and "tabOnText" or "railText")
	tab.mark:SetShown(on)
end

local function buildTab(module, index)
	local tab = W.Panel(frame, nil, "Button")
	tab:SetSize(TAB_W, TAB_H)
	tab:SetPoint("TOPLEFT", frame, "TOPLEFT", (RAIL - TAB_W) / 2, -(BAR + 4 + (index - 1) * (TAB_H + TAB_GAP)))
	tab.icon = W.Icon(tab, module.tab.icon, 22, "railText")
	tab.icon:SetPoint("TOP", tab, "TOP", 0, -11)
	tab.label = W.Text(tab, "body", 10.5, "railText")
	tab.label:SetPoint("BOTTOM", tab, "BOTTOM", 0, 10)
	tab.label:SetJustifyH("CENTER")
	tab.label:SetLabel(module.tab.label)
	tab.mark = W.Fill(tab, "tabMark")
	tab.mark:SetSize(3, 26)
	tab.mark:SetPoint("RIGHT", tab, "LEFT", -3, 0)
	tab:SetScript("OnEnter", function(self)
		self.hover = true
		tabLook(self)
	end)
	tab:SetScript("OnLeave", function(self)
		self.hover = false
		tabLook(self)
	end)
	tab:SetScript("OnClick", function()
		C.Sound("IG_CHARACTER_INFO_TAB")
		Window:Select(module.id)
	end)
	tabLook(tab)
	tabs[module.id] = tab
end

local function savePosition()
	local point, _, relPoint, x, y = frame:GetPoint(1)
	local saved = T.db.window
	saved.point, saved.relPoint, saved.x, saved.y = point, relPoint, x, y
end

local function restorePosition()
	local saved = T.db.window
	frame:ClearAllPoints()
	if saved.point and saved.x and saved.y then
		frame:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x, saved.y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	end
end

-- ---------------------------------------------------------------------------
-- Sitting beside the game's own windows. When a Trailhead button opens the spellbook,
-- talents or the map, Trailhead moves next to that window instead of lying on top of it,
-- and goes back to its own place when that window closes.
--
-- Trailhead is placed by numbers read from the game window, never anchored to it, and
-- the game window itself is not touched. Nothing here runs in a fight.

local GAP = 12
local docked -- { name, target, part, wait, key, hidden, scaled, placed, strip }
local watcher
Window.dockLog = {} -- the last few placements, for the game check

-- ---------------------------------------------------------------------------
-- The narrow strip: when there is no room beside a game window for the full window even at
-- the smallest size, a small panel shows only what belongs to that window (the next talent
-- beside the talents, the spells missing from the bars beside the spellbook) and the full
-- window steps aside until the game window closes or room appears.
--
-- Pages hand in what to show: Window:SetStrip(key, provider), where key is the game window's
-- name, or "name:part" for one part of it, and provider() returns nil (nothing to show) or
-- { title, rows = { {icon, name, right} ... }, note }.

local STRIP_W, STRIP_BAR, STRIP_PAD, STRIP_INSET = 260, 40, 8, 12
local STRIP_ROW, STRIP_ROWS, STRIP_RIGHT = 26, 10, 64
Window.STRIP_W, Window.STRIP_ROWS = STRIP_W, STRIP_ROWS
Window.strips = {}
function Window:SetStrip(key, provider)
	self.strips[key] = provider
end

-- The parts of a game window that each have a strip of their own, told apart by which of the
-- game window's child frames is on show (measured only; the frames are not touched).
local PARTS = {
	PlayerSpellsFrame = { { "talents", "TalentsFrame" }, { "spellbook", "SpellBookFrame" } },
}

local function partOf(d)
	for _, entry in ipairs(PARTS[d.name] or {}) do
		local child = d.target[entry[2]]
		if type(child) == "table" and type(child.IsShown) == "function" and C.Plain(child:IsShown(), false) == true then
			return entry[1]
		end
	end
	return d.part -- what the button that opened it asked for
end

local strip -- the strip's frame, built the first time it is needed

local function buildStrip()
	strip = W.Panel(UIParent, {
		shape = "window", fill = "window", line = "windowLine", top = "windowTop",
		shadow = "shadow", shadowSize = 22,
	}, "Frame", "TrailheadStrip")
	strip:Hide()
	strip:SetSize(STRIP_W, 120)
	strip:SetFrameStrata("HIGH")
	strip:SetClampedToScreen(true)
	strip:EnableMouse(true)

	local logo = W.Panel(strip)
	logo:SetSize(22, 22)
	logo:SetPoint("TOPLEFT", strip, "TOPLEFT", 12, -9)
	logo:SetStyle({ shape = "logo", fill = "logo", shadow = "logoGlow", shadowSize = 5 })
	logo.icon = W.Icon(logo, "tri", 13, "logoInk")
	logo.icon:SetPoint("CENTER", logo, "CENTER", 0, 0)
	strip.title = W.Text(strip, "head", 12.5, "barText")
	strip.title:SetPoint("LEFT", logo, "RIGHT", 9, 0)
	strip.title:SetWidth(STRIP_W - 12 - 22 - 9 - 36)
	local close = W.IconButton(strip, "x", 24, "barIcon", function()
		Window:Close()
	end, { tip = L["Close"] })
	close:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -8, -8)

	local body = W.Panel(strip, { shape = "page", fill = "page", line = "pageLine" })
	body:SetPoint("TOPLEFT", strip, "TOPLEFT", STRIP_PAD, -STRIP_BAR)
	body:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", -STRIP_PAD, STRIP_PAD)
	strip.body = body
	local inner = STRIP_W - STRIP_PAD * 2 - STRIP_INSET * 2
	strip.rows = {}
	for index = 1, STRIP_ROWS do
		local row = CreateFrame("Frame", nil, body)
		row:SetSize(inner, STRIP_ROW)
		row:SetPoint("TOPLEFT", body, "TOPLEFT", STRIP_INSET, -(STRIP_INSET + (index - 1) * STRIP_ROW))
		row.icon = W.GameIcon(row, 20)
		row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.name = W.Text(row, "body", 12, "ink")
		row.right = W.Text(row, "body", 10.5, "muted")
		row.right:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		row.right:SetJustifyH("RIGHT")
		strip.rows[index] = row
	end
	strip.note = W.Text(body, "body", 10.5, "muted", { width = inner })
	strip.note:SetSpacing(2)
end

-- Fills the strip and returns its height.
local function fillStrip(content)
	local inner = STRIP_W - STRIP_PAD * 2 - STRIP_INSET * 2
	strip.title:SetLabel(content.title or "")
	local rows = content.rows or {}
	local y = STRIP_INSET
	for index, row in ipairs(strip.rows) do
		local item = rows[index]
		row:SetShown(item ~= nil)
		if item then
			local hasIcon = item.icon ~= nil
			local right = item.right ~= nil and item.right ~= ""
			row.icon:SetShown(hasIcon)
			if hasIcon then
				row.icon:SetIcon(item.icon)
			end
			row.name:ClearAllPoints()
			row.name:SetPoint("LEFT", row, "LEFT", hasIcon and 28 or 0, 0)
			row.name:SetWidth(inner - (hasIcon and 28 or 0) - (right and STRIP_RIGHT or 0))
			row.name:SetLabel(item.name or "")
			row.right:SetLabel(right and item.right or "")
			y = y + STRIP_ROW
		end
	end
	local note = content.note ~= nil and content.note ~= ""
	strip.note:SetShown(note)
	if note then
		local gap = #rows > 0 and 6 or 0
		strip.note:ClearAllPoints()
		strip.note:SetPoint("TOPLEFT", strip.body, "TOPLEFT", STRIP_INSET, -(y + gap))
		strip.note:SetLabel(content.note)
		y = y + gap + W.TextHeight(strip.note)
	end
	local height = math.floor(STRIP_BAR + y + STRIP_INSET + STRIP_PAD + 0.5)
	strip:SetHeight(height)
	return height
end

local function hideStrip()
	if docked then
		docked.strip = nil
	end
	if strip then
		strip:Hide()
	end
end

-- What the strip would show beside the docked window, or nil.
local function stripContent()
	local part = partOf(docked)
	local provider = part and Window.strips[docked.name .. ":" .. part] or Window.strips[docked.name]
	if not provider then
		return nil
	end
	local ok, content = pcall(provider)
	return ok and type(content) == "table" and content or nil
end

local function undock(keepPlace)
	local was = docked
	if not was then
		return
	end
	hideStrip()
	docked = nil
	if watcher then
		watcher:SetScript("OnUpdate", nil)
	end
	if not frame then
		return
	end
	if was.scaled then
		frame:SetScale(T.db.scale)
	end
	if not keepPlace then
		restorePosition()
	end
	if was.hidden and not C.InCombat() then
		frame:Show()
	end
end

-- The game window's edges in the screen's own units, or nil if it has none yet.
local function edges(target)
	local left, right = C.Plain(target:GetLeft(), nil), C.Plain(target:GetRight(), nil)
	local top, bottom = C.Plain(target:GetTop(), nil), C.Plain(target:GetBottom(), nil)
	local own, screen = C.Plain(target:GetEffectiveScale(), nil), C.Plain(UIParent:GetEffectiveScale(), nil)
	if type(left) ~= "number" or type(right) ~= "number" or type(top) ~= "number" or type(bottom) ~= "number"
		or type(own) ~= "number" or type(screen) ~= "number" or screen <= 0 then
		return nil
	end
	local ratio = own / screen
	return left * ratio, right * ratio, top * ratio, bottom * ratio
end

local function place()
	local left, right, top, bottom = edges(docked.target)
	local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
	if not left or screenW <= 0 or screenH <= 0 then
		return
	end
	local key = ("%d:%d:%d:%d:%s"):format(left, right, top, bottom, partOf(docked) or "")
	if key == docked.key then
		return
	end
	docked.key = key
	local entry = { name = docked.name, left = left, right = right, top = top, bottom = bottom, w = screenW, h = screenH }
	Window.dockLog[#Window.dockLog + 1] = entry
	while #Window.dockLog > 6 do
		table.remove(Window.dockLog, 1)
	end

	hideStrip()
	if right - left >= screenW * 0.9 then
		-- It fills the screen (a full-size map): step out of the way until it closes.
		entry.side = "hidden"
		if frame:IsShown() then
			docked.hidden = true
			frame:Hide()
		end
		return
	end

	local scale = T.db.scale
	local roomRight, roomLeft = screenW - right - GAP * 2, left - GAP * 2
	local room = math.max(roomRight, roomLeft)
	if room < WIDTH * scale then
		-- Not enough room at the player's size: shrink as far as the smallest setting.
		local fit = math.floor(room / WIDTH * 100) / 100
		if fit < T.SCALE_MIN then
			entry.side = "no room"
			if docked.scaled then
				docked.scaled = false
				frame:SetScale(T.db.scale)
			end
			if docked.placed then
				docked.placed = false
				restorePosition()
			end
			-- Room for just the narrow strip: show that instead of the full window.
			local content = room >= STRIP_W and stripContent()
			if content then
				entry.side = "strip"
				if frame:IsShown() then
					docked.hidden = true
					frame:Hide()
				end
				if not strip then
					buildStrip()
				end
				local height = fillStrip(content)
				local x = roomRight >= STRIP_W and (right + GAP) or (left - GAP - STRIP_W)
				strip:ClearAllPoints()
				strip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, math.max(math.min(top, screenH), height))
				strip:Show()
				docked.strip = true
				return
			end
			if docked.hidden then
				docked.hidden = false
				frame:Show()
			end
			return
		end
		scale = fit
	end
	if docked.hidden then
		docked.hidden = false
		frame:Show()
	end
	if scale ~= T.db.scale or docked.scaled then
		docked.scaled = scale ~= T.db.scale
		frame:SetScale(scale)
	end
	local width, height = WIDTH * scale, HEIGHT * scale
	local onRight = roomRight >= width
	local x = onRight and (right + GAP) or (left - GAP - width)
	local y = math.max(math.min(top, screenH), height) -- tops lined up, bottom kept on screen
	entry.side, entry.scale = onRight and "right" or "left", scale
	docked.placed = true
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

-- What a strip shows has changed (a point spent, a spell put on a bar): it is filled again on
-- the next look at the game window.
function Window:RefreshStrip()
	if docked then
		docked.key = nil
	end
end

-- The strip's frame while it is up, else nil.
function Window:Strip()
	return strip and strip:IsShown() and strip or nil
end

-- Looks at the game window again: follows it when it moves or changes size, and lets
-- go when it closes or Trailhead is closed.
function Window:DockTick()
	if not docked then
		return
	end
	if C.InCombat() or not frame or (not frame:IsShown() and not docked.hidden) then
		undock()
		return
	end
	if not docked.target:IsShown() then
		docked.wait = docked.wait - 1
		if docked.wait < 0 then
			undock()
		end
		return
	end
	docked.wait = 0
	place()
end

-- Moves Trailhead next to one of the game's windows, by its global name. `part` names the
-- part of it that was asked for ("talents", "spellbook"), used for the strip when the game
-- window does not show which part is up. Returns true when it is now following that window.
function Window:Beside(name, part)
	local target = type(name) == "string" and _G[name]
	if T.db.dock == false or not frame or not (frame:IsShown() or (docked and docked.hidden)) or C.InCombat()
		or type(target) ~= "table" or type(target.GetLeft) ~= "function" or type(target.IsShown) ~= "function" then
		return false
	end
	if docked and docked.name ~= name then
		undock()
	end
	if not docked then
		docked = { name = name, target = target, wait = 5 } -- a few looks for it to appear
	end
	docked.key, docked.part = nil, part
	if not watcher then
		watcher = CreateFrame("Frame")
	end
	local since = 0
	watcher:SetScript("OnUpdate", function(_, elapsed)
		since = since + (elapsed or 0)
		if since >= 0.1 then
			since = 0
			T.SafeCall("dock", Window.DockTick, Window)
		end
	end)
	T.SafeCall("dock", Window.DockTick, Window)
	return docked ~= nil
end

function Window:IsBeside()
	return docked and docked.name or nil
end

function Window:Undock(keepPlace)
	undock(keepPlace)
end

local function build()
	frame = W.Panel(UIParent, nil, "Frame", "TrailheadWindow")
	frame:Hide()
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetStyle({
		shape = "window", fill = "window", line = "windowLine", top = "windowTop",
		shadow = "shadow", shadowSize = 34,
	})
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetScale(T.db.scale)
	restorePosition()
	tinsert(UISpecialFrames, "TrailheadWindow") -- Escape closes it

	-- Title bar: drag it to move the window.
	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	bar:SetHeight(BAR)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		Window:Undock(true) -- moved by hand: it stays where the player puts it
		frame:StartMoving()
	end)
	bar:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		savePosition()
	end)

	local logo = W.Panel(bar)
	logo:SetSize(30, 30)
	logo:SetPoint("LEFT", bar, "LEFT", 20, -1)
	logo:SetStyle({ shape = "logo", fill = "logo", shadow = "logoGlow", shadowSize = 7 })
	logo.icon = W.Icon(logo, "tri", 18, "logoInk")
	logo.icon:SetPoint("CENTER", logo, "CENTER", 0, 0)

	local title = W.Text(bar, "head", 17, "barText")
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 11, 1)
	title:SetLabel("Trailhead")
	local subtitle = W.Text(bar, "label", 10, "barMuted")
	subtitle:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 11, 0)
	subtitle:SetLabel(L["New player companion"])

	local close = W.IconButton(bar, "x", 28, "barIcon", function()
		Window:Close()
	end, { tip = L["Close"] })
	close:SetPoint("RIGHT", bar, "RIGHT", -14, -1)
	local gear = W.IconButton(bar, "gear", 28, "barIcon", function()
		if Window.current == "settings" then
			Window:Select(Window.lastTab or "home")
		else
			Window:Select("settings")
		end
	end, { tip = L["Settings"] })
	gear:SetPoint("RIGHT", close, "LEFT", -4, 0)

	-- Search: typing anywhere here opens Find it with the results.
	local search = W.Search(bar, 380, 30, L["Find anything: trainer, bank, a zone, a dungeon..."], function(text, typed)
		if not typed then
			return
		end
		if Window.current ~= "find" then
			Window:Select("find")
		end
		T.modules.find:SetQuery(text)
	end)
	search:SetPoint("LEFT", bar, "LEFT", 262, -1)
	Window.search = search

	-- Tab rail.
	local withTabs = {}
	for _, module in ipairs(T.moduleList) do
		if module.tab then
			withTabs[#withTabs + 1] = module
		end
	end
	table.sort(withTabs, function(a, b)
		return (a.tab.order or 99) < (b.tab.order or 99)
	end)
	for index, module in ipairs(withTabs) do
		buildTab(module, index)
	end

	-- The page: where the current module draws.
	local page = W.Panel(frame, { shape = "page", fill = "page", line = "pageLine" })
	page:SetPoint("TOPLEFT", frame, "TOPLEFT", RAIL, -BAR)
	page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)

	-- Paper grain, only for themes that ask for it.
	local grain = page:CreateTexture(nil, "BACKGROUND", nil, -4)
	grain:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -2)
	grain:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)
	grain:SetTexture(Theme.MEDIA .. "parchment", "REPEAT", "REPEAT")
	grain:SetHorizTile(true)
	grain:SetVertTile(true)
	grain.Restyle = function(self)
		self:SetShown(Theme.current and Theme.current.parchment and true or false)
	end
	Theme:Track(grain)
	grain:Restyle()

	host = CreateFrame("Frame", nil, page)
	host:SetPoint("TOPLEFT", page, "TOPLEFT", INSET, -INSET)
	host:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -INSET, INSET)

	frame:SetScript("OnShow", function()
		C.Sound("IG_CHARACTER_INFO_OPEN")
	end)
	frame:SetScript("OnHide", function()
		search.edit:ClearFocus() -- or the keyboard would stay captured by a hidden box
		C.Sound("IG_CHARACTER_INFO_CLOSE")
	end)
	frame:SetScript("OnMouseDown", function()
		search.edit:ClearFocus()
	end)
	Window.frame = frame
end

-- Shows a module's page, building it on first use. `arg` is passed to the module's
-- Goto (which category, which filter) when it has one.
function Window:Select(id, arg)
	local module = T.modules[id] or T.modules.home
	if not frame or not module then
		return
	end
	local previous = self.current and T.modules[self.current]
	if previous and previous.page then
		previous.page:Hide()
	end
	if not module.page then
		module.page = CreateFrame("Frame", nil, host)
		module.page:SetAllPoints(host)
		if module.Build then
			T.SafeCall(module.id .. ".Build", module.Build, module, module.page)
		end
	end
	module.page:Show()
	self.current = module.id
	if module.tab then
		self.lastTab = module.id
		T.cdb.tab = module.id
	elseif not self.lastTab then
		-- Opened straight onto a tab-less page: the tab saved from last time stands in.
		local saved = T.modules[T.cdb.tab]
		self.lastTab = saved and saved.tab and saved.id or "home"
	end
	for tabId, tab in pairs(tabs) do
		-- A page with no tab of its own (a route, a dungeon, This week, Settings...): the tab
		-- it was opened from stays lit, and the page's Back button goes there.
		tab.active = tabId == module.id or (not module.tab and tabId == self.lastTab)
		tabLook(tab)
	end
	if module.id ~= "find" and module.id ~= "route" and module.id ~= "dungeon" then
		self:ClearSearch() -- a search belongs to Find it; leaving the page ends it (a route keeps it for Back)
	end
	if arg ~= nil and module.Goto then
		T.SafeCall(module.id .. ".Goto", module.Goto, module, arg)
	end
	if module.Refresh then
		T.SafeCall(module.id .. ".Refresh", module.Refresh, module)
	end
end

-- Draws the page on screen again, as it is now.
local KEEPS_SCROLL = { find = true, spells = true, setup = true, characters = true, zones = true }

function Window:RefreshPage()
	local module = self.current and T.modules[self.current]
	if frame and frame:IsShown() and module and module.page and module.Refresh then
		-- Lists keep their scroll position (their Refresh takes keep = true for that).
		T.SafeCall(module.id .. ".Refresh", module.Refresh, module, KEEPS_SCROLL[module.id] or nil)
	end
end

-- The tab-less pages' Back button: back to the tab that was on show before.
function Window:Back()
	self:Select(self.lastTab or "home")
end

function Window:Open(id, arg)
	if not frame then
		build()
	end
	if docked and docked.hidden then
		undock() -- asked for while a strip or a full-screen map has it tucked away: back home
	end
	frame:Show()
	self:Select(id or self.current or T.cdb.tab, arg)
	T:Fire("TH_WINDOW_OPENED")
end

-- Empties the search box without that counting as the player typing.
function Window:ClearSearch()
	if self.search and self.search:GetQuery() ~= "" then
		self.search:SetQuery("")
	end
	if T.modules.find then
		T.modules.find.query = ""
	end
end

-- Opens Find it with the results for `text`, as if the player had typed it.
function Window:Search(text)
	self:Open("find")
	if self.search and self.current == "find" then
		self.search:SetQuery(text)
		T.modules.find:SetQuery(text)
	end
end

function Window:Close()
	if docked and docked.hidden then
		docked.hidden = false -- closed from the strip: it stays closed
		undock()
	end
	if frame then
		frame:Hide()
	end
end

function Window:Toggle()
	if frame and frame:IsShown() then
		self:Close()
	else
		self:Open()
	end
end

function Window:IsOpen()
	return frame ~= nil and frame:IsShown()
end

function Window:SetScale(scale)
	scale = math.min(math.max(scale, T.SCALE_MIN), T.SCALE_MAX)
	scale = math.floor(scale * 100 + 0.5) / 100
	T.db.scale = scale
	if frame then
		frame:SetScale(scale)
	end
	if docked then
		docked.key, docked.scaled = nil, false -- placed again at the new size on the next look
	end
	return scale
end

function Window:ResetPosition()
	undock(true)
	local saved = T.db.window
	saved.point, saved.relPoint, saved.x, saved.y = nil, nil, nil, nil
	if frame then
		restorePosition()
	end
end

-- Stay out of the way in a fight, and come back afterwards.
-- A focused search box swallows every key, movement included. Let go of it as soon as
-- the player clicks anywhere else or a fight starts.
local function dropFocus()
	local search = Window.search
	if search and search.edit:HasFocus() then
		search.edit:ClearFocus()
	end
end

T:On("GLOBAL_MOUSE_DOWN", function()
	local search = Window.search
	if search and search.edit:HasFocus() and not search:IsMouseOver() then
		search.edit:ClearFocus()
	end
end)

T:On("PLAYER_REGEN_DISABLED", function()
	dropFocus()
	if docked then
		local hidden = docked.hidden
		docked.hidden = false
		undock()
		Window.reopen = hidden or Window.reopen
	end
	if frame and frame:IsShown() and T.db.hideInCombat then
		Window.reopen = true
		frame:Hide()
	end
end)

-- Pages skip their refreshes during a fight. When it ends the page on screen is drawn again
-- (a boss killed, experience gained), and TH_COMBAT_ENDED tells anything else that waited.
T:On("PLAYER_REGEN_ENABLED", function()
	if Window.reopen then
		Window.reopen = false
		Window:Open() -- Open refreshes the page itself
	elseif frame and frame:IsShown() then
		Window:RefreshPage()
	end
	T:Fire("TH_COMBAT_ENDED")
end)
