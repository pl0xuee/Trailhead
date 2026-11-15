-- This week: the reset countdown, raid lockouts before and after raids open, the PvP rank cap,
-- a client without the functions, secret values, combat, and the ways in from Home and the Guide.
local H = ...
local Stub, check = H.Stub, H.check

-- Puts the fake clock at noon (local time) on a day.
local function at(year, month, day)
	Stub.skew = os.time({ year = year, month = month, day = day, hour = 12 }) - os.time()
end

local DAY, HOUR = 86400, 3600

local function weekly(extra)
	local data = { reset = 3 * DAY + 5 * HOUR, saved = {} }
	for key, value in pairs(extra or {}) do
		data[key] = value
	end
	return { weekly = data }
end

local function open(T)
	H.slash("")
	T.Window:Select("weekly")
	Stub.flush()
end

H.section("weekly: durations read plainly", function()
	local T = H.load(nil, H.checked())
	local D = T.Weekly.Duration
	check(D(3 * DAY + 5 * HOUR + 59) == "3 days 5 hours", "days and hours")
	check(D(DAY) == "1 day" and D(DAY + HOUR) == "1 day 1 hour", "one day, one hour")
	check(D(5 * HOUR + 12 * 60) == "5 hours 12 minutes" and D(2 * HOUR) == "2 hours", "hours and minutes")
	check(D(60) == "1 minute" and D(12 * 60 + 30) == "12 minutes", "minutes")
	check(D(20) == "under a minute" and D(-5) == "under a minute" and D(nil) == "under a minute", "under a minute")
	H.noErrors(T, "durations")
end)

H.section("weekly: before raids open", function()
	local T = H.load(weekly(), H.checked())
	at(2026, 11, 15)
	check(T.Weekly.RaidState() == "before" and select(2, T.Weekly.RaidState()) == 24, "24 days to go on 15 November")
	open(T)
	check(T.Window.current == "weekly", "the page opens")
	check(Stub.sees("This week") and Stub.sees("In 3 days 5 hours"), "the reset countdown")
	check(Stub.sees("Raids open on 9 December, in 24 days"), "a calm empty state with the opening day")
	check(Stub.sees("Barrow Deeps") and Stub.sees("Hyjal Summit") and Stub.sees("Onyxia's Lair") and Stub.sees("40 players"), "the three raids and their size")
	check(Stub.sees("Once they are open, the raids you are saved to show here."), "what the card will show")
	check(Stub.sees("Rank Points have a weekly cap"), "the rank cap without a reading")
	check(Stub.raidInfoAsked == 1, "fresh lockouts asked for once")
	Stub.fire("UPDATE_INSTANCE_INFO")
	check(Stub.raidInfoAsked == 1, "the answer does not ask again")
	at(2026, 12, 8)
	T.Weekly:Refresh()
	check(Stub.sees("Raids open tomorrow, 9 December"), "the day before")
	at(2026, 12, 9)
	T.Weekly:Refresh()
	check(Stub.sees("Raids open today, 9 December"), "the day itself")
	at(2026, 12, 12)
	T.Weekly:Refresh()
	check(Stub.sees("You are not saved to any raid"), "after opening, with no lockouts")
	H.noErrors(T, "before raids open")
end)

H.section("weekly: raid lockouts", function()
	local T = H.load(weekly({ saved = {
		{ name = "Onyxia's Lair", reset = 4 * DAY, done = 1, total = 1 },
		{ name = "Hyjal Summit", reset = 2 * DAY + 4 * HOUR, done = 3, total = 8 },
		{ name = "The Deadmines", reset = DAY, isRaid = false },
		{ name = "Barrow Deeps", reset = DAY, locked = false },
	} }), H.checked())
	at(2026, 12, 12)
	local list = T.Weekly.Lockouts()
	check(#list == 2 and list[1].name == "Hyjal Summit" and list[2].name == "Onyxia's Lair", "locked raids only, soonest first")
	open(T)
	check(Stub.sees("Hyjal Summit") and Stub.sees("3 of 8 bosses  \194\183  resets in 2 days 4 hours"), "bosses and reset per raid")
	check(Stub.sees("Onyxia's Lair") and Stub.sees("1 of 1 boss  \194\183  resets in 4 days"), "every raid listed")
	check(not Stub.sees("The Deadmines") and not Stub.sees("Barrow Deeps"), "no dungeons, no expired lockouts")
	check(not Stub.sees("40 players"), "the opening list steps aside")
	check(not Stub.sees("You are not saved to any raid"), "no empty state")
	-- A lockout shows even before the opening day (the game knows best).
	at(2026, 11, 20)
	T.Weekly:Refresh()
	check(Stub.sees("Hyjal Summit") and not Stub.sees("Raids open on 9 December, in 19 days"), "lockouts win over the countdown")
	-- New data comes in: the page follows.
	Stub.weekly.saved = {}
	at(2026, 12, 12)
	Stub.fire("UPDATE_INSTANCE_INFO")
	check(Stub.sees("You are not saved to any raid") and not Stub.sees("3 of 8 bosses  \194\183  resets in 2 days 4 hours"), "refreshes when the game answers")
	H.noErrors(T, "lockouts")
end)

H.section("weekly: PvP rank cap", function()
	local T = H.load(weekly({ rank = { level = 3, earned = 500, capLevel = 5, lastLevel = 4 } }), H.checked())
	local rank = T.Weekly.Rank()
	check(rank.points == 3500 and rank.cap == 5000 and rank.rise == 1000, "points, cap and this week's rise")
	open(T)
	check(Stub.sees("3500 of 5000 Rank Points"), "the reading")
	check(Stub.sees("That is this season's cap so far. It goes up at the weekly reset.\nThis week it went up by 1000."), "what the cap means")
	Stub.weekly.rank = { level = 5, earned = 0, capLevel = 5, lastLevel = 5 }
	Stub.fire("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
	check(Stub.sees("5000 of 5000 Rank Points") and Stub.sees("You are at the cap for now. It goes up at the weekly reset."), "at the cap, no rise")
	Stub.weekly.rank = { level = 1, earned = 200, capLevel = 0, lastLevel = 0 }
	T.Weekly:Refresh()
	check(Stub.sees("1200 Rank Points this season") and Stub.sees("Rank Points have a weekly cap. The game shows no cap for you yet."), "no cap set yet")
	Stub.weekly.rank = nil
	T.Weekly:Refresh()
	check(Stub.sees("Trailhead cannot read your rank here. The PvP tab of your character window shows it."), "no rank track")
	H.noErrors(T, "rank")
end)

H.section("weekly: secret values are not read", function()
	local T = H.load(weekly({ reset = Stub.SECRET, rank = { level = 2, earned = Stub.SECRET, capLevel = 3, lastLevel = 2 },
		saved = { { name = Stub.SECRET, reset = DAY, done = 1, total = 3 }, { name = "Hyjal Summit", reset = Stub.SECRET } } }), H.checked())
	at(2026, 12, 12)
	open(T)
	check(Stub.sees("Not known here"), "a secret reset reads as unknown")
	check(#T.Weekly.Lockouts() == 0 and Stub.sees("You are not saved to any raid"), "secret lockouts are skipped")
	check(T.Weekly.Rank() == nil and Stub.sees("Rank Points have a weekly cap"), "a secret rank reads as unknown")
	H.noErrors(T, "secret values")
end)

H.section("weekly: a client without the functions", function()
	local T = H.load({ bare = true }, H.checked())
	at(2026, 12, 12)
	check(T.Weekly.ResetIn() == nil and T.Weekly.Lockouts() == nil and T.Weekly.Rank() == nil, "nothing to read")
	open(T)
	check(Stub.sees("Not known here") and Stub.sees("Your game does not show lockouts here")
		and Stub.sees("Rank Points have a weekly cap"), "each part says so calmly")
	check(Stub.sees("PvP season journey"), "the written part stays")
	at(2026, 11, 15)
	T.Weekly:Refresh()
	check(Stub.sees("Raids open on 9 December, in 24 days"), "the opening day needs no game function")
	H.noErrors(T, "bare client")
	-- The usual test client: no weekly functions either.
	local T2 = H.load(nil, H.checked())
	open(T2)
	check(Stub.sees("Not known here"), "the default client without the functions")
	H.noErrors(T2, "default client")
end)

H.section("weekly: nothing in combat", function()
	local T = H.load(weekly({ rank = { level = 3, earned = 500, capLevel = 5, lastLevel = 4 } }), H.checked())
	open(T)
	local asked = Stub.raidInfoAsked
	Stub.combat = true
	T.Weekly:Refresh()
	check(Stub.raidInfoAsked == asked, "the server is not asked in combat")
	Stub.weekly.rank = { level = 4, earned = 0, capLevel = 5, lastLevel = 4 }
	Stub.fire("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
	check(Stub.sees("3500 of 5000 Rank Points"), "rank events wait for the fight to end")
	Stub.combat = false
	H.noErrors(T, "combat")
end)

H.section("weekly: the ways in", function()
	local T = H.load(weekly(), H.checked({ welcomeDone = true }))
	at(2026, 11, 15)
	H.slash("")
	T.Window:Select("home")
	Stub.flush()
	check(Stub.sees("This week"), "Home has a This week button")
	check(Stub.raidInfoAsked == 0, "Home asks the server nothing")
	Stub.click("This week")
	Stub.flush()
	check(T.Window.current == "weekly", "the Home button opens the page")
	check(T.modules.weekly.tab == nil, "no tab on the rail")

	local info = T.modules.guide.Read("week")
	check(info and #info.rows == 4 and info.rows[1].text == "In 3 days 5 hours", "the Guide topic reads the reset")
	check(info.rows[2].text == "Open on 9 December, in 24 days", "and the raid opening")
	for _, row in ipairs(info.rows) do
		check(#row.name <= 14 and #row.text <= 68, "guide row fits: " .. row.name)
	end
	T.Window:Select("guide", "week")
	Stub.flush()
	check(Stub.sees("Each week"), "the topic is listed")
	Stub.click("Open This week")
	Stub.flush()
	check(T.Window.current == "weekly", "the Guide button opens the page")
	H.noErrors(T, "ways in")
end)
