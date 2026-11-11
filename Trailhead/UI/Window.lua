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
local docked -- { name, target, wait, key, hidden, scaled, placed, strip }
local watcher
Window.dockLog = {} -- the last few placements, for the game check

-- A page may offer a narrow strip for when the full window has no room beside a game
-- window (a small screen next to the talents). strip = { width, height, ready(), show(x, y), hide() }
-- keyed by the game window's name. While it is up the full window steps aside, like it does for
-- a full-screen map, and comes back with the game window closing.
Window.strips = {}
function Window:SetStrip(name, strip)
	self.strips[name] = strip
end

local function undock(keepPlace)
	local was = docked
	if not was then
		return
	end
	docked = nil
	if was.strip then
		was.strip.hide()
	end
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
	local strip = Window.strips[docked.name]
	local key = ("%d:%d:%d:%d:%s"):format(left, right, top, bottom, strip and strip.ready and strip.ready() and "s" or "")
	if key == docked.key then
		return
	end
	docked.key = key
	local entry = { name = docked.name, left = left, right = right, top = top, bottom = bottom, w = screenW, h = screenH }
	Window.dockLog[#Window.dockLog + 1] = entry
	while #Window.dockLog > 6 do
		table.remove(Window.dockLog, 1)
	end

	if right - left >= screenW * 0.9 then
		-- It fills the screen (a full-size map): step out of the way until it closes.
		entry.side = "hidden"
		if docked.strip then
			docked.strip.hide()
			docked.strip = nil
		end
		if frame:IsShown() then
			docked.hidden = true
			frame:Hide()
		end
		return
	end
	if docked.strip then
		docked.strip.hide()
		docked.strip = nil
	end
	if docked.hidden then
		docked.hidden = false
		frame:Show()
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
			local strip = Window.strips[docked.name]
			if strip and room >= strip.width and (not strip.ready or strip.ready()) then
				entry.side = "strip"
				if frame:IsShown() then
					docked.hidden = true
					frame:Hide()
				end
				local onRight = roomRight >= strip.width
				local x = onRight and (right + GAP) or (left - GAP - strip.width)
				docked.strip = strip
				strip.show(x, math.max(math.min(top, screenH), strip.height))
			end
			return
		end
		scale = fit
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

-- Moves Trailhead next to one of the game's windows, by its global name. Returns true
-- when it is now following that window.
function Window:Beside(name)
	local target = type(name) == "string" and _G[name]
	if T.db.dock == false or not frame or not frame:IsShown() or C.InCombat()
		or type(target) ~= "table" or type(target.GetLeft) ~= "function" or type(target.IsShown) ~= "function" then
		return false
	end
	if docked and docked.name ~= name then
		undock()
	end
	if not docked then
		docked = { name = name, target = target, wait = 5 } -- a few looks for it to appear
	end
	docked.key = nil
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

-- Opens one of the game's windows (a function named by its path, as for C.Call) without
-- Trailhead being closed by it. When a centred window such as the talents opens, the game
-- closes every window that Escape closes, and Trailhead is on that list; it steps off the
-- list for that moment.
function Window:Keep(path, ...)
	local index
	for i, name in ipairs(UISpecialFrames) do
		if name == "TrailheadWindow" then
			index = i
			break
		end
	end
	if index then
		table.remove(UISpecialFrames, index)
	end
	local result = C.Call(path, ...)
	if index then
		tinsert(UISpecialFrames, "TrailheadWindow")
	end
	return result
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
	local subtitle = W.Text(bar, "label", 8.5, "barMuted")
	subtitle:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 11, 0)
	subtitle:SetLabel(L["New player companion"])

	local close = W.IconButton(bar, "x", 28, "barIcon", function()
		Window:Close()
	end)
	close:SetPoint("RIGHT", bar, "RIGHT", -14, -1)
	local gear = W.IconButton(bar, "gear", 28, "barIcon", function()
		if Window.current == "settings" then
			Window:Select(Window.lastTab or "home")
		else
			Window:Select("settings")
		end
	end)
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
	end
	for tabId, tab in pairs(tabs) do
		-- A route has no tab of its own: the page it was opened from stays lit.
		tab.active = tabId == module.id or ((module.id == "route" or module.id == "dungeon") and tabId == self.lastTab)
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

function Window:Open(id, arg)
	if not frame then
		build()
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

T:On("PLAYER_REGEN_ENABLED", function()
	if Window.reopen then
		Window.reopen = false
		Window:Open()
	end
end)
