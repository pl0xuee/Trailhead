local _, T = ...
local L = T.L
local W = T.Widgets
local C = T.Compat

-- This week: what starts over at the weekly reset in Forever, read from the game where it can be.
-- No tab of its own: it opens from a button on Home and from the Guide.
--
-- What is shown, and where each part comes from:
--  * Time to the weekly reset: C_DateAndTime.GetSecondsUntilWeeklyReset (in the API
--    documentation of the Forever build). Blizzard has not published the reset day, so no day
--    is written here.
--  * Raid lockouts: GetNumSavedInstances / GetSavedInstanceInfo, as the game's own group finder
--    (Blizzard_GroupFinder_VanillaStyle, loaded on Forever) reads them; RequestRaidInfo asks the
--    server for fresh ones. Raids open on 9 December 2026 and reset each week (Blizzard's raid
--    overview, worldofwarcraft.blizzard.com/news/24303009).
--  * PvP rank: Rank Points have a weekly cap (Blizzard, news.blizzard.com/en-us/article/24303316).
--    Read as the game's own PvP rank pane does (Blizzard_UIPanels_Game/Camelot/PVPRankFrame.lua):
--    the rank track is major faction 2800 and the cap is the total for this week's top rank.
-- Nothing here opens or changes a game window.

local Weekly = T:NewModule("weekly")
T.Weekly = Weekly

local PAGE_W = 778
local RANK_FACTION = 2800 -- PVP_RANK_POINTS_FACTION_ID in the game's PvP rank pane
local RAIDS_OPEN = 20261209 -- year, month, day (UTC): Blizzard gives the day, not the hour
local LOCKOUT_ROWS, ROW_STEP = 6, 44

local ui = {}

-- ---------------------------------------------------------------------------
-- Reading the game

function Weekly.Now()
	local now = C.Plain(C.Call("GetServerTime"), nil)
	if type(now) ~= "number" then
		now = time()
	end
	return now
end

local function plural(n, one, many)
	return n == 1 and one or many:format(n)
end

-- "3 days 5 hours", "5 hours 12 minutes", "12 minutes", "under a minute".
function Weekly.Duration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if days > 0 then
		local text = plural(days, L["1 day"], L["%d days"])
		if hours > 0 then
			text = text .. " " .. plural(hours, L["1 hour"], L["%d hours"])
		end
		return text
	elseif hours > 0 then
		local text = plural(hours, L["1 hour"], L["%d hours"])
		if minutes > 0 then
			text = text .. " " .. plural(minutes, L["1 minute"], L["%d minutes"])
		end
		return text
	elseif minutes > 0 then
		return plural(minutes, L["1 minute"], L["%d minutes"])
	end
	return L["under a minute"]
end

-- Seconds until the weekly reset, or nil when the game cannot say.
function Weekly.ResetIn()
	local seconds = C.Plain(C.Call("C_DateAndTime.GetSecondsUntilWeeklyReset"), nil)
	if type(seconds) ~= "number" or seconds <= 0 then
		return nil
	end
	return seconds
end

-- Days since a fixed point, for counting whole days between two dates.
local function dayNumber(year, month, day)
	local y = month <= 2 and year - 1 or year
	local m = month <= 2 and month + 12 or month
	return 365 * y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400) + math.floor((153 * (m - 3) + 2) / 5) + day
end

-- "before" (with the days to go), "today" or "open". Counted in UTC days, since the hour
-- raids open has not been published.
function Weekly.RaidState(now)
	now = now or Weekly.Now()
	local d = date("!*t", now)
	local today = d.year * 10000 + d.month * 100 + d.day
	if today < RAIDS_OPEN then
		return "before", math.max(1, dayNumber(2026, 12, 9) - dayNumber(d.year, d.month, d.day))
	elseif today == RAIDS_OPEN then
		return "today"
	end
	return "open"
end

-- The raids the character is saved to: { name, reset (seconds), done, total }; nil when the
-- game has no lockout functions.
function Weekly.Lockouts()
	if not (C.Has("GetNumSavedInstances") and C.Has("GetSavedInstanceInfo")) then
		return nil
	end
	local count = C.Plain(C.Call("GetNumSavedInstances"), 0)
	if type(count) ~= "number" then
		return {}
	end
	local out = {}
	for index = 1, math.min(count, 40) do
		local name, _, reset, _, locked, _, _, isRaid, _, _, total, done = C.Call("GetSavedInstanceInfo", index)
		name, reset = C.Plain(name, nil), C.Plain(reset, nil)
		locked, isRaid = C.Plain(locked, false), C.Plain(isRaid, false)
		total, done = C.Plain(total, nil), C.Plain(done, nil)
		if type(name) == "string" and name ~= "" and locked and isRaid and type(reset) == "number" and reset > 0 then
			out[#out + 1] = {
				name = name, reset = reset,
				total = type(total) == "number" and total > 0 and total or nil,
				done = type(done) == "number" and done or nil,
			}
		end
	end
	table.sort(out, function(a, b)
		return a.reset < b.reset
	end)
	return out
end

-- The PvP rank track: { points = Rank Points this season, cap = most allowed so far (nil when
-- the game sets none), rise = how much the cap went up this week (nil if not) }; nil if unread.
function Weekly.Rank()
	local info = C.Call("C_MajorFactions.GetMajorFactionProgressionInfo", RANK_FACTION)
	if type(info) ~= "table" then
		return nil
	end
	local level, earned = C.Plain(info.renownLevel, nil), C.Plain(info.renownReputationEarned, nil)
	local capLevel, lastLevel = C.Plain(info.currentWeekProgressiveMaxLevel, nil), C.Plain(info.previousWeekProgressiveMaxLevel, nil)
	if type(level) ~= "number" or type(earned) ~= "number" then
		return nil
	end
	local function total(at)
		if type(at) ~= "number" then
			return nil
		end
		local value = C.Plain(C.Call("C_MajorFactions.GetTotalReputationForRenownLevel", RANK_FACTION, at), nil)
		return type(value) == "number" and value or nil
	end
	local base = total(level)
	if not base then
		return nil
	end
	local out = { points = base + earned }
	local cap = total(capLevel)
	if cap and cap > 0 then
		out.cap = cap
		local last = total(lastLevel)
		if last and cap > last then
			out.rise = cap - last
		end
	end
	return out
end

-- One line for Home and the Guide: "in 3 days 5 hours" or nil.
function Weekly.ResetText()
	local seconds = Weekly.ResetIn()
	return seconds and L["In %s"]:format(Weekly.Duration(seconds)) or nil
end

-- ---------------------------------------------------------------------------
-- The page

local function card(page, x, y, w, h)
	local panel = W.Panel(page, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	panel:SetSize(w, h)
	panel:SetPoint("TOPLEFT", page, "TOPLEFT", x, -y)
	return panel
end

-- The raids that open on 9 December, with their size (Blizzard's raid overview).
local RAIDS = {
	{ L["Barrow Deeps"], 10 },
	{ L["Hyjal Summit"], 20 },
	{ L["Onyxia's Lair"], 40 },
}

function Weekly:Build(page)
	self.page = page
	local title = W.Text(page, "head", 20, "ink")
	title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	title:SetLabel(L["This week"])
	local sub = W.Text(page, "body", 11.5, "muted", { width = PAGE_W })
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	sub:SetLabel(L["What starts over once a week in Forever, read from your game where it can be."])

	-- The reset.
	local reset = card(page, 0, 56, PAGE_W, 76)
	local label = W.Text(reset, "label", 8.5, "accentText")
	label:SetPoint("TOPLEFT", reset, "TOPLEFT", 18, -14)
	label:SetLabel(L["Weekly reset"])
	ui.reset = W.Text(reset, "head", 17, "ink")
	ui.reset:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -7)
	ui.reset:SetWidth(250)
	ui.resetNote = W.Text(reset, "body", 11, "muted", { width = PAGE_W - 300 - 18 })
	ui.resetNote:SetPoint("LEFT", reset, "LEFT", 300, 0)
	ui.resetNote:SetSpacing(3)
	ui.resetNote:SetMaxLines(3)

	-- Raids.
	local raids = card(page, 0, 144, 382, 352)
	ui.raids = raids
	local raidHead = W.Text(raids, "head", 14, "ink")
	raidHead:SetPoint("TOPLEFT", raids, "TOPLEFT", 16, -12)
	raidHead:SetLabel(L["Raid lockouts"])
	ui.raidState = W.Text(raids, "head", 13, "accentText", { width = 350 })
	ui.raidState:SetPoint("TOPLEFT", raidHead, "BOTTOMLEFT", 0, -10)
	ui.raidBody = W.Text(raids, "body", 11, "muted", { width = 350 })
	ui.raidBody:SetPoint("TOPLEFT", ui.raidState, "BOTTOMLEFT", 0, -6)
	ui.raidBody:SetSpacing(3)
	ui.raidBody:SetMaxLines(2)
	ui.rows = {}
	for index = 1, LOCKOUT_ROWS do
		local row = {} -- placed when filled: lockouts start higher than the raids that open
		row.name = W.Text(raids, "head", 12, "ink")
		row.name:SetWidth(350)
		row.detail = W.Text(raids, "body", 10.5, "muted")
		row.detail:SetWidth(350)
		ui.rows[index] = row
	end
	ui.raidFoot = W.Text(raids, "body", 10.5, "faint", { width = 350 })
	ui.raidFoot:SetPoint("BOTTOMLEFT", raids, "BOTTOMLEFT", 16, 14)
	ui.raidFoot:SetSpacing(2)
	ui.raidFoot:SetMaxLines(2)

	-- PvP rank.
	local rank = card(page, 396, 144, 382, 170)
	local rankHead = W.Text(rank, "head", 14, "ink")
	rankHead:SetPoint("TOPLEFT", rank, "TOPLEFT", 16, -12)
	rankHead:SetLabel(L["PvP rank"])
	ui.rankState = W.Text(rank, "head", 13, "accentText", { width = 350 })
	ui.rankState:SetPoint("TOPLEFT", rankHead, "BOTTOMLEFT", 0, -10)
	ui.rankBody = W.Text(rank, "body", 11, "muted", { width = 350 })
	ui.rankBody:SetPoint("TOPLEFT", ui.rankState, "BOTTOMLEFT", 0, -6)
	ui.rankBody:SetSpacing(3)
	ui.rankBody:SetMaxLines(4)

	-- The season journey and Legacy: written facts, nothing to read.
	local journey = card(page, 396, 326, 382, 170)
	local journeyHead = W.Text(journey, "head", 14, "ink")
	journeyHead:SetPoint("TOPLEFT", journey, "TOPLEFT", 16, -12)
	journeyHead:SetLabel(L["PvP season journey"])
	local journeyBody = W.Text(journey, "body", 11, "muted", { width = 350 })
	journeyBody:SetPoint("TOPLEFT", journeyHead, "BOTTOMLEFT", 0, -8)
	journeyBody:SetSpacing(3)
	journeyBody:SetLabel(L["Each PvP season has a journey with weekly tasks. They give Honor and Rank Points, and three of them in a season also give a Legacy Point."]
		.. "\n\n" .. L["Legacy challenges do not reset. Each one counts once for your whole account."])

	T:On("UPDATE_INSTANCE_INFO", function()
		if page:IsVisible() and not C.InCombat() then
			Weekly:Refresh(true)
		end
	end)
	for _, event in ipairs({ "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "UPDATE_FACTION" }) do
		T:On(event, function()
			if page:IsVisible() and not C.InCombat() then
				Weekly:Refresh(true)
			end
		end)
	end
	self.built = true
end

local function hideRows()
	for _, row in ipairs(ui.rows) do
		row.name:Hide()
		row.detail:Hide()
	end
end

local function showRow(index, top, name, detail)
	local row = ui.rows[index]
	if not row then
		return
	end
	local y = top + (index - 1) * ROW_STEP
	row.name:ClearAllPoints()
	row.name:SetPoint("TOPLEFT", ui.raids, "TOPLEFT", 16, -y)
	row.detail:ClearAllPoints()
	row.detail:SetPoint("TOPLEFT", ui.raids, "TOPLEFT", 16, -(y + 18))
	row.name:SetLabel(name)
	row.detail:SetLabel(detail)
	row.name:Show()
	row.detail:Show()
end

local function refreshRaids()
	local list = Weekly.Lockouts()
	local state, days = Weekly.RaidState()
	hideRows()
	if list and #list > 0 then
		ui.raidState:Hide()
		ui.raidBody:Hide()
		for index, item in ipairs(list) do
			local resets = L["resets in %s"]:format(Weekly.Duration(item.reset))
			if item.total and item.done then
				local bosses = item.total == 1 and L["%d of 1 boss"]:format(item.done) or L["%d of %d bosses"]:format(item.done, item.total)
				resets = bosses .. "  \194\183  " .. resets
			end
			showRow(index, 44, item.name, resets)
		end
		ui.raidFoot:SetLabel(L["Each raid resets once a week."])
		return
	end
	-- No lockouts: what opens, and when.
	ui.raidState:Show()
	ui.raidBody:Show()
	if state == "before" then
		ui.raidState:SetLabel(days == 1 and L["Raids open tomorrow, 9 December"]
			or L["Raids open on 9 December, in %d days"]:format(days))
		ui.raidBody:SetLabel(L["Three raids open for level 60 characters, and each one resets once a week."])
		ui.raidFoot:SetLabel(L["Once they are open, the raids you are saved to show here."])
	elseif state == "today" then
		ui.raidState:SetLabel(L["Raids open today, 9 December"])
		ui.raidBody:SetLabel(L["Three raids open for level 60 characters, and each one resets once a week."])
		ui.raidFoot:SetLabel(L["Once they are open, the raids you are saved to show here."])
	elseif list then
		ui.raidState:SetLabel(L["You are not saved to any raid"])
		ui.raidBody:SetLabel(L["The raids are for level 60 characters, and each one resets once a week."])
		ui.raidFoot:SetLabel(L["A raid you are saved to shows here with the time until it resets."])
	else
		ui.raidState:SetLabel(L["Your game does not show lockouts here"])
		ui.raidBody:SetLabel(L["The raids are for level 60 characters, and each one resets once a week."])
		ui.raidFoot:SetLabel("")
	end
	for index, raid in ipairs(RAIDS) do
		showRow(index, 112, raid[1], L["%d players"]:format(raid[2]))
	end
end

local function refreshRank()
	local rank = Weekly.Rank()
	if not rank then
		ui.rankState:SetLabel(L["Rank Points have a weekly cap"])
		ui.rankBody:SetLabel(L["Trailhead cannot read your rank here. The PvP tab of your character window shows it."])
		return
	end
	if rank.cap then
		ui.rankState:SetLabel(L["%d of %d Rank Points"]:format(rank.points, rank.cap))
		local text = rank.points >= rank.cap and L["You are at the cap for now. It goes up at the weekly reset."]
			or L["That is this season's cap so far. It goes up at the weekly reset."]
		if rank.rise then
			text = text .. "\n" .. L["This week it went up by %d."]:format(rank.rise)
		end
		ui.rankBody:SetLabel(text)
	else
		ui.rankState:SetLabel(L["%d Rank Points this season"]:format(rank.points))
		ui.rankBody:SetLabel(L["Rank Points have a weekly cap. The game shows no cap for you yet."])
	end
end

-- `again` is set when fresh data has just come in, so the server is not asked once more.
function Weekly:Refresh(again)
	if not self.built then
		return
	end
	local seconds = Weekly.ResetIn()
	if seconds then
		ui.reset:SetLabel(L["In %s"]:format(Weekly.Duration(seconds)))
		ui.resetNote:SetLabel(L["Then raid lockouts start over and the cap on PvP Rank Points goes up."])
	else
		ui.reset:SetLabel(L["Not known here"])
		ui.resetNote:SetLabel(L["Your game does not tell Trailhead when the week starts over. Raid lockouts start over then and the cap on PvP Rank Points goes up."])
	end
	refreshRaids()
	refreshRank()
	-- Ask the server for fresh lockouts; UPDATE_INSTANCE_INFO brings them back here.
	if not again and not C.InCombat() then
		C.Call("RequestRaidInfo")
	end
end
