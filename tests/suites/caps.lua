-- Limits on what is saved (found places, errors, dungeon doors) and pages that reuse their
-- widgets instead of making new ones every time they are shown.
local H = ...
local Stub, check = H.Stub, H.check

H.section("caps: found places keep the newest 1500", function()
	local T = H.load(nil, H.checked())
	T.db.places = {}
	for index = 1, 1600 do
		T.Places.Remember("vendor", "Vendor " .. index, 10000 + index, 0.5, 0.5, "seen")
	end
	local list = T.db.places
	check(#list == 1500, "1600 places found: 1500 kept (" .. #list .. ")")
	check(list[1].n == "Vendor 101" and list[#list].n == "Vendor 1600", "the oldest are the ones dropped")
	H.noErrors(T, "places cap")
end)

H.section("caps: the newest 40 errors", function()
	local T = H.load(nil, H.checked())
	for index = 1, 50 do
		T:LogError("test", "error " .. index)
	end
	check(#T.db.errors == 40 and T.db.errors[1].err == "error 11" and T.db.errors[40].err == "error 50", "50 errors: the newest 40 kept")
	T.db.errors = {}
end)

H.section("caps: errors from another version are dropped", function()
	local saved = H.checked({ errors = {
		{ at = 1, where = "Zones", err = "old trouble", v = "0.2.0" },
		{ at = 2, where = "Home", err = "this version", v = "0.13.0" },
		{ at = 3, where = "Odd", err = "no version" },
	} })
	local T = H.load(nil, saved)
	check(#T.db.errors == 1 and T.db.errors[1].err == "this version", "only this version's errors are kept at load")
	H.slash("errors")
	check(Stub.chat[#Stub.chat]:find("[0.13.0] Home: this version", 1, true) ~= nil, "/th errors says which version the error is from")
	T.db.errors = {}
end)

H.section("caps: six spots per dungeon door", function()
	local T = H.load(nil, H.checked())
	local world = Stub.world
	for index = 1, 7 do
		world.instance = nil
		world.x, world.y = index / 10, 0.5
		T.Game.WatchDoor()
		world.instance = { name = "The Deadmines", kind = "party" }
		T.Game.WatchDoor()
	end
	world.instance = nil
	world.x, world.y = 0.56, 0.47
	local spots = T.db.entrances and T.db.entrances.deadmines and T.db.entrances.deadmines.spots or {}
	check(#spots == 6, "seven different doors walked through: six spots kept (" .. #spots .. ")")
	H.noErrors(T, "entrance cap")
end)

H.section("caps: developer data is trimmed from older saves", function()
	local big = function()
		return { list = { A = "x" } }
	end
	local saved = H.checked({
		visits = { { kind = "vendor", npc = "Someone", rows = { "Bread|25" } } },
	})
	saved.probe.report = { words = big(), talents = big(), mounts = big(), visits = big(), rest = { bind = "Goldshire" } }
	local T = H.load(nil, saved)
	local r = T.db.probe.report
	check(T.db.visits == nil and r.words == nil and r.talents == nil and r.mounts == nil and r.visits == nil,
		"visits and the large dumps are removed at load")
	check(r.rest and r.rest.bind == "Goldshire" and T.db.probe.v == T.Probe.VERSION, "the rest of the saved check stays")

	saved = H.checked({ collect = true, visits = { { kind = "vendor", npc = "Someone", rows = { "Bread|25" } } } })
	saved.probe.report = { words = big(), talents = big() }
	T = H.load(nil, saved)
	check(#T.db.visits == 1 and T.db.probe.report.words ~= nil, "with collection on, nothing is removed")
	H.slash("check collect")
	check(T.db.collect == nil and T.db.visits == nil and T.db.probe.report.words == nil, "switching it off removes what it wrote down")
	Stub.world.npc, Stub.world.merchant = "Vendor", { { "Bread", 25, 5, 4540 } }
	Stub.fire("MERCHANT_SHOW")
	Stub.flush()
	check(T.db.visits == nil, "and vendors are no longer written down")
	H.noErrors(T, "developer data")
end)

H.section("caps: pages reuse their widgets", function()
	local T = H.load(nil, H.checked())
	H.slash("")
	local pages = {}
	for _, module in ipairs(T.moduleList) do
		if module.tab then
			pages[#pages + 1] = module.id
		end
	end
	-- Every page once, so each has built what it needs.
	for _, id in ipairs(pages) do
		T.Window:Select(id)
		Stub.flush()
	end
	local made = 0
	local real = _G.CreateFrame
	_G.CreateFrame = function(...)
		made = made + 1
		return real(...)
	end
	local texts = #Stub.fontstrings
	local grew = {}
	for _ = 1, 5 do
		for _, id in ipairs(pages) do
			local before = made
			T.Window:Select(id)
			local module = T.modules[id]
			if module.Refresh then
				module:Refresh()
			end
			Stub.flush()
			if made > before then
				grew[id] = true
			end
		end
	end
	local counted = made
	T.Widgets.Panel(UIParent)
	local seen = made - counted
	_G.CreateFrame = real
	check(seen == 1, "the count sees a widget being made")
	made = counted
	local names = {}
	for id in pairs(grew) do
		names[#names + 1] = id
	end
	table.sort(names)
	check(made == 0, "showing and refreshing every page 5 times makes no new frames"
		.. (#names > 0 and (" (grew: " .. table.concat(names, ", ") .. ")") or ""))
	check(#Stub.fontstrings == texts, "and no new texts (" .. (#Stub.fontstrings - texts) .. " made)")
	H.noErrors(T, "widget reuse")
end)
