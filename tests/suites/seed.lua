local H = ...
local Stub, check, noErrors = H.Stub, H.check, H.noErrors

-- The built-in places (Data/Seed.lua, made by tools/gen_seed.py) as seen by a brand-new
-- character: nothing discovered, no saved data.

-- The generated file read on its own, to check the data and to know where zones sit.
local raw = {}
assert(loadfile("Trailhead/Data/Seed.lua"))("Trailhead", raw)
local zones, lines = {}, {}
for line in raw.Seed.zones:gmatch("[^\n]+") do
	local map, cont, ax, bx, ay, by, name = line:match("^(%d+)|(%d*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
	zones[tonumber(map)] = { cont = tonumber(cont), ax = tonumber(ax), bx = tonumber(bx), ay = tonumber(ay), by = tonumber(by), name = name }
end
for line in raw.Seed.places:gmatch("[^\n]+") do
	local code, faction, map, x, y, name, extra = line:match("^(%a)|(%a?)|(%d+)|(%d+)|(%d+)|([^|]*)|(.*)$")
	lines[#lines + 1] = { code = code, faction = faction, map = tonumber(map), x = tonumber(x) / 1000, y = tonumber(y) / 1000, name = name, extra = extra }
end

local function onContinent(map, x, y)
	local z = zones[map]
	return z.ax * x + z.bx, z.ay * y + z.by
end

local function find(code, name)
	for _, p in ipairs(lines) do
		if p.code == code and p.name == name then
			return p
		end
	end
end

H.section("built-in places: the generated file", function()
	local f = assert(io.open("Trailhead/Data/Seed.lua", "rb"))
	local size = #f:read("*a")
	f:close()
	check(size < 400 * 1024 and size > 20 * 1024, "the file is compact (under 400 KB)")
	local bad = 0
	for _, p in ipairs(lines) do
		if not zones[p.map] or p.x < 0 or p.x > 1 or p.y < 0 or p.y > 1 then
			bad = bad + 1
		end
	end
	check(#lines > 1000 and bad == 0, "every place is on a known zone map, inside it")
	check(zones[1429] and zones[1429].cont == 1415 and zones[1411].cont == 1414, "zones know their continent")
	check(zones[2521] and zones[2521].cont == nil, "the Skyborne isle stands alone: no continent")
	check(zones[84] == nil and zones[1459] == nil and zones[2524] == nil, "no instance, battleground or scenario maps")

	-- Facts that two sources agree on (Forever and pfQuest, or All The Things and pfQuest).
	local function near(code, name, map, x, y)
		local p = find(code, name)
		return p and p.map == map and math.abs(p.x - x) < 0.01 and math.abs(p.y - y) < 0.01
	end
	check(near("i", "Innkeeper Grosk", 1411, 0.516, 0.418), "Innkeeper Grosk is in Razor Hill, Durotar")
	check(near("f", "Karos Razok", 1421, 0.455, 0.425), "Karos Razok flies from the Sepulcher, Silverpine")
	check(near("b", "Karus", 1454, 0.495, 0.693), "Karus is a banker in Orgrimmar")
	check(near("f", "Dungar Longdrink", 1453, 0.710, 0.725), "Dungar Longdrink is Stormwind's flight master")
	check(near("t", "Llane Beshere", 1429, 0.502, 0.422) and find("t", "Llane Beshere").extra == "WARRIOR", "Llane Beshere trains warriors in Northshire")
	check(near("t", "Khelden Bremen", 1429, 0.496, 0.394) and find("t", "Khelden Bremen").extra == "MAGE", "Khelden Bremen trains mages in Northshire")
	check(find("t", "Llane Beshere").faction == "A" and find("t", "Frang").faction == "H", "trainers keep their side")
	check(find("p", "Alchemist Mallory").extra == "Alchemy" and find("p", "Smith Argus").extra == "Blacksmithing", "profession trainers keep their profession")

	-- The zone transform: two zones' maps must agree about a spot they share.
	local ox, oy = onContinent(1454, 0.5, 0.5)
	local dx, dy = onContinent(1411, 0.45, 0.10) -- Durotar's northern edge, at Orgrimmar's gate
	check(math.sqrt((ox - dx) ^ 2 + (oy - dy) ^ 2) < 0.03, "Orgrimmar sits at the top of Durotar on the continent map")
	local ix, iy = onContinent(1455, 0.5, 0.5)
	local mx, my = onContinent(1426, 0.5, 0.5)
	check(math.sqrt((ix - mx) ^ 2 + (iy - my) ^ 2) < 0.06, "Ironforge sits in the middle of Dun Morogh on the continent map")
end)

-- One row per starting area: where a new character stands, and who they are.
local STARTS = {
	{ "human", "Alliance", { "Human", "Human" }, 1429, 0.50, 0.42, "MAGE" },
	{ "dwarf", "Alliance", { "Dwarf", "Dwarf" }, 1426, 0.29, 0.67, "MAGE" },
	{ "gnome", "Alliance", { "Gnome", "Gnome" }, 1426, 0.29, 0.67, "MAGE" },
	{ "night elf", "Alliance", { "Night Elf", "NightElf" }, 1438, 0.57, 0.60, "DRUID" },
	{ "orc", "Horde", { "Orc", "Orc" }, 1411, 0.43, 0.69, "WARRIOR" },
	{ "troll", "Horde", { "Troll", "Troll" }, 1411, 0.43, 0.69, "MAGE" },
	{ "tauren", "Horde", { "Tauren", "Tauren" }, 1412, 0.45, 0.76, "DRUID" },
	{ "undead", "Horde", { "Undead", "Scourge" }, 1420, 0.31, 0.66, "MAGE" },
}

-- The class is one the race can be and has a trainer in its starting area.
local function begin(start, class)
	local T = H.load({ seed = true, class = class or start[7], level = 1 })
	local world = Stub.world
	world.faction, world.race = start[2], start[3]
	world.map, world.x, world.y = start[4], start[5], start[6]
	world.cx, world.cy = onContinent(start[4], start[5], start[6])
	return T, world
end

H.section("built-in places: a new character", function()
	for _, start in ipairs(STARTS) do
		local T = begin(start)
		local P = T.Places
		check(P.Count() == 0, start[1] .. ": nothing found yet")
		local empty, farFirst = {}, {}
		for _, category in ipairs(T.Categories) do
			if not category.hidden then
				local list = P.Find(category.id)
				if #list == 0 then
					empty[#empty + 1] = category.id
				end
				-- Closest to furthest; what cannot be measured (another continent) comes last.
				local last, unmeasured = 0, false
				for _, item in ipairs(list) do
					if item.dist == nil then
						unmeasured = true
					elseif unmeasured or item.dist < last then
						farFirst[#farFirst + 1] = category.id
					else
						last = item.dist
					end
				end
			end
		end
		check(#empty == 0, start[1] .. ": every category lists a place (empty: " .. table.concat(empty, ",") .. ")")
		check(#farFirst == 0, start[1] .. ": every list runs closest to furthest (" .. table.concat(farFirst, ",") .. ")")
		for _, id in ipairs({ "trainer", "vendor", "repair" }) do
			local first = P.Find(id)[1]
			check(first and first.map == start[4] and first.here == true, start[1] .. ": the nearest " .. id .. " is on its own map")
		end
		for _, id in ipairs({ "vendor", "repair", "inn", "mailbox", "professions" }) do
			local first = P.Find(id)[1]
			if first and first.map == start[4] then
				check(first.dist and first.dist < 0.4, start[1] .. ": the nearest " .. id .. " has a distance")
			end
		end
		noErrors(T, start[1])
	end
end)

H.section("built-in places: faction, class and kinds", function()
	local human, orc = STARTS[1], STARTS[5]
	local T = begin(human)
	local P = T.Places
	local names = H.titles(P.Find("trainer"))
	check(not names:find("Llane Beshere") and names:find("Khelden Bremen"), "a mage sees the mage trainer, not the warrior's")
	for _, item in ipairs(P.Find("trainer")) do
		check(item.note == "Mage trainer" and item.known == true and item.kind == "place", "trainer: " .. item.title .. " is marked as built in, with its kind")
	end
	check(#P.Find("trainer") <= 25, "the list is capped")

	T = begin(human, "WARRIOR")
	check(P ~= T.Places and T.Places.Find("trainer")[1].title == "Llane Beshere" and T.Places.Find("trainer")[1].note == "Warrior trainer",
		"a warrior's nearest trainer in Northshire is Llane Beshere")

	-- A Horde character never sees an Alliance place, and the other way round.
	T = begin(orc)
	P = T.Places
	for _, category in ipairs(T.Categories) do
		if not category.hidden then
			for _, item in ipairs(P.Find(category.id)) do
				local rec = nil
				for _, line in ipairs(lines) do
					if line.name == item.title and line.map == item.map and math.abs(line.x - item.x) < 0.001 and line.code == ({ trainer = "t", vendor = "v", repair = "r", inn = "i", flight = "f",
						mailbox = "m", bank = "b", professions = "p", auction = "a", weapons = "w", stable = "s" })[category.id] then
						rec = line
					end
				end
				if rec and rec.faction == "A" then
					check(false, "orc sees an Alliance place: " .. item.title)
				end
			end
		end
	end
	check(not P.Search("Llane Beshere")[1] or P.Search("Llane Beshere")[1].rank ~= 2, "an Alliance trainer is not found by an orc")

	-- Kinds: profession trainers and vendors.
	T = begin(human)
	P = T.Places
	local prof = P.Find("professions")
	local kinds = {}
	for _, item in ipairs(prof) do
		kinds[item.note] = true
	end
	check(kinds["Alchemy trainer"] and kinds["Blacksmithing trainer"], "profession trainers say which profession")
	local titled, plain = false, false
	-- Most vendors now carry a kind (from titles and the wiki's vendor lists), so look through the
	-- whole list for one that has none.
	for _, item in ipairs(T.Places.Find("vendor")) do
		titled = titled or item.note ~= "From the built-in list"
		plain = plain or item.note == "From the built-in list"
	end
	check(plain, "vendors without a known kind say they are built in")
	noErrors(T, "kinds")
end)

H.section("built-in places: yours replace theirs", function()
	local T = begin(STARTS[1])
	local P = T.Places
	local before = P.Find("vendor")
	local near
	for _, item in ipairs(before) do
		if item.map == 1429 and item.shipped then
			near = item
			break
		end
	end
	check(near ~= nil, "a built-in vendor stands near the start")
	local world = Stub.world
	P.Remember("vendor", "Somebody Else", 1429, near.x + 0.01, near.y - 0.01, "seen")
	local after = P.Find("vendor")
	local hidden, own = true, nil
	for _, item in ipairs(after) do
		if item.title == near.title then
			hidden = false
		end
		if item.title == "Somebody Else" then
			own = item
		end
	end
	check(hidden and own and own.known == nil and own.note == "You have been here", "a place you found beside it replaces the built-in one")

	-- The same name hides a built-in place wherever it is.
	check(H.titles(P.Find("inn")):find("Innkeeper Farley"), "the built-in inn is listed")
	P.Remember("inn", "Innkeeper Farley", 1429, 0.10, 0.10, "seen")
	local farleys = 0
	for _, item in ipairs(P.Find("inn")) do
		if item.title == "Innkeeper Farley" then
			farleys = farleys + 1
		end
	end
	check(farleys == 1, "the same innkeeper is listed once, as the one you found")

	-- A trainer you found has the class in its name ("Mage: Khelden Bremen").
	P.Remember("trainer", "Mage: Khelden Bremen", 1429, 0.20, 0.20, "seen")
	farleys = 0
	for _, item in ipairs(P.Find("trainer")) do
		if item.title:find("Khelden Bremen") then
			farleys = farleys + 1
		end
	end
	check(farleys == 1, "a trainer you found hides the built-in one under its plain name")

	-- Every mailbox is called "Mailbox": one found does not hide the others.
	local mailboxes = #P.Find("mailbox")
	P.Remember("mailbox", "Mailbox", 1426, 0.9, 0.9, "seen")
	check(#P.Find("mailbox") == mailboxes + 1, "a mailbox you found does not hide the built-in mailboxes by name")

	-- Another faction's find does not hide anything.
	T.db.places = { { c = "vendor", n = "Alliance Find", m = 1429, x = near.x, y = near.y, z = "x", f = 1, s = "seen", t = 1 } }
	local stillThere = false
	for _, item in ipairs(P.Find("vendor")) do
		if item.title == near.title then
			stillThere = true
		end
	end
	check(stillThere, "a place found by the other faction does not hide the built-in one")
	noErrors(T, "replacing")
end)

H.section("built-in places: order, cap and search", function()
	local T, world = begin(STARTS[5]) -- an orc in Durotar
	local P = T.Places
	local banks = P.Find("bank")
	check(#banks >= 3 and banks[1].here == false and banks[1].dist ~= nil, "no bank in Durotar: the list starts with the nearest town")
	-- Other zones on the continent come by true distance, then other continents.
	local last, order = -1, true
	local sawOtherContinent = false
	for _, item in ipairs(banks) do
		local cont = zones[item.map].cont
		if cont == 1414 then
			local cx, cy = onContinent(item.map, item.x, item.y)
			local want = math.sqrt(((cx - world.cx) * 1.5) ^ 2 + (cy - world.cy) ^ 2) -- maps are 3 wide to 2 tall
			if math.abs(item.dist - want) > 1e-6 or item.dist < last or sawOtherContinent then
				order = false
			end
			last = item.dist
		else
			sawOtherContinent = true
			if item.dist ~= nil then
				order = false
			end
		end
	end
	check(order and sawOtherContinent, "banks: same continent nearest first by real distance, then the other continent")
	check(zones[banks[1].map].cont == 1414, "the nearest bank for a Durotar orc is on Kalimdor")

	-- Cap on a long list.
	T, world = begin(STARTS[1])
	local vendors = T.Places.Find("vendor")
	check(#vendors == 25, "a long list is capped at 25 built-in places")
	-- Search finds a built-in place by name, with its zone and kind.
	local found = T.Places.Search("khelden")
	check(found[1] and found[1].title == "Khelden Bremen" and found[1].where == "Northshire Valley, Elwynn Forest" and found[1].note == "Mage trainer"
		and found[1].shipped == true, "search finds a built-in trainer by name")
	local ok, route = pcall(function() return T.Routes.ForResult(found[1]) end)
	check(ok and route and route.map == 1429 and route.x == found[1].x, "How to get there works for it")
	check(T.Places.Go(found[1]) == true and Stub.waypoint and Stub.waypoint.uiMapID == 1429, "Set marker works for it")
	check(#T.Places.Search("Innkeeper Farley") >= 1 and T.Places.Search("zzzzqqq")[1] == nil, "search finds an inn and nothing for nonsense")
	local count = 0
	for _, item in ipairs(T.Places.Search("a")) do
		if item.shipped and not item.hub then
			count = count + 1
		end
	end
	check(count <= 25, "a broad search keeps built-in matches to 25")

	-- The Find page shows them.
	H.slash("")
	T.Window:Select("find", "mailbox")
	check(Stub.sees("Mailbox") and Stub.sees("Goldshire, Elwynn Forest  \194\183  From the built-in list") and not Stub.sees("None found yet"), "the page lists built-in mailboxes")
	check(Stub.sees("Set marker") and Stub.sees("How to get there"), "with both buttons")
	T.Window:Select("find", "vendor")
	check(Stub.sees("25 places, nearest first. Places you find yourself are added."), "a capped list says so")
	noErrors(T, "order and search")
end)

H.section("built-in places: weapons, riding, flight, new zones", function()
	local T = begin(STARTS[1])
	local P = T.Places
	-- Known.lua keeps priority: a master listed there is not listed twice.
	local seen, twice = {}, false
	for _, item in ipairs(P.Find("weapons")) do
		if seen[item.title] then
			twice = true
		end
		seen[item.title] = true
	end
	check(not twice and seen["Woo Ping"], "weapon masters from the guides are listed once")
	check(#P.Find("riding") >= 1, "riding trainers come from the guides")
	local flights = P.Find("flight")
	check(#flights >= 1, "flight masters are listed even when the game's flight map is empty")
	check(flights[1].shipped == true and flights[1].note ~= nil, "and marked as built in")

	-- The Skyborne isle has its own trainers and an innkeeper.
	local isle = H.load({ seed = true, class = "DRUID", level = 1 })
	Stub.world.map, Stub.world.x, Stub.world.y = 2521, 0.45, 0.45
	local trainers = isle.Places.Find("trainer")
	check(trainers[1] and trainers[1].title == "Naeluna Swiftmend" and trainers[1].map == 2521, "Zephras Isle lists its druid trainer first")
	check(isle.Places.Find("inn")[1].map == 2521, "and its innkeeper")
	check(#isle.Places.Find("bank") >= 1, "a bank elsewhere, since the isle has none")
	noErrors(isle, "the isle")
end)

H.section("built-in places: Skyborne riding", function()
	local check, Stub = H.check, H.Stub
	for _, side in ipairs({ "Alliance", "Horde" }) do
		local T = H.load({ seed = true, level = 1 })
		Stub.world.faction, Stub.world.race = side, { "Skyborne", "Skyborne" }
		local list = T.Places.Find("riding")
		check(#list == 1 and list[1].title == "Genn Fairweather" and list[1].map == 2521,
			side .. " Skyborne: the riding trainer is the one on Zephras Isle")
	end
	local T = H.load({ seed = true, level = 1 })
	local human = T.Places.Find("riding")
	local stray = false
	for _, place in ipairs(human) do
		stray = stray or place.title == "Genn Fairweather"
	end
	check(#human > 0 and not stray, "a human is sent to the human trainer, not the Skyborne one")
end)

-- Class trainers come from Warcraft Tavern's WoW Forever list: every class a race can be in
-- Forever has a trainer in its own starting area (the Human hunter learns in Stormwind).
H.section("built-in places: starting-area trainers", function()
	local classes = {
		human = { "WARRIOR", "PALADIN", "ROGUE", "PRIEST", "MAGE", "WARLOCK" },
		dwarf = { "WARRIOR", "PALADIN", "HUNTER", "PRIEST", "ROGUE", "SHAMAN" },
		gnome = { "WARRIOR", "ROGUE", "MAGE", "WARLOCK", "PRIEST" },
		["night elf"] = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "DRUID" },
		orc = { "WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "WARLOCK", "MAGE" },
		troll = { "WARRIOR", "ROGUE", "HUNTER", "PRIEST", "SHAMAN", "MAGE", "WARLOCK" },
		tauren = { "WARRIOR", "HUNTER", "SHAMAN", "DRUID" },
		undead = { "WARRIOR", "ROGUE", "PRIEST", "MAGE", "WARLOCK", "PALADIN" },
	}
	for _, start in ipairs(STARTS) do
		for _, class in ipairs(classes[start[1]]) do
			local found
			for _, p in ipairs(lines) do
				if p.code == "t" and p.extra == class and p.map == start[4] and (p.faction == "" or (p.faction == "A") == (start[2] == "Alliance"))
					and math.abs(p.x - start[5]) < 0.12 and math.abs(p.y - start[6]) < 0.12 then
					found = true
				end
			end
			check(found, start[1] .. " " .. class:lower() .. ": a trainer in the starting area")
		end
	end
	-- Undead paladins and Dwarf shamans are new in Forever: trainers on the other side exist.
	check(find("t", "Aramis Hammerhand") and find("t", "Aramis Hammerhand").extra == "PALADIN", "Deathknell has a paladin trainer")
	check(find("t", "Teo Hammerstorm") and find("t", "Teo Hammerstorm").faction == "A", "Coldridge Valley has an Alliance shaman trainer")
	-- No pet, demon or portal trainers, no event or battleground vendors, no duplicated warlock.
	for _, name in ipairs({ "Harruk", "Kitha", "Hraug", "Darcie", "Darkcaller Yanka" }) do
		check(not find("t", name) and not find("v", name), name .. " is not listed as a trainer or shop")
	end
	-- The old data's Stormwind and Mulgore maps were drawn differently: spots are corrected.
	local katherine = find("t", "Katherine the Pure")
	check(katherine and math.abs(katherine.x - 0.487) < 0.02 and math.abs(katherine.y - 0.493) < 0.02, "Stormwind's paladin trainer is at the Cathedral")
	local kauth = find("i", "Innkeeper Kauth")
	check(kauth and math.abs(kauth.x - 0.459) < 0.03 and math.abs(kauth.y - 0.641) < 0.03, "the Bloodhoof inn sits in Bloodhoof Village")
	-- Both sides share a neutral town.
	local ratchet = 0
	for _, p in ipairs(lines) do
		if p.map == 1413 and p.x > 0.60 and p.x < 0.65 and p.y > 0.34 and p.y < 0.41 and p.faction ~= "" and p.code ~= "t" then
			ratchet = ratchet + 1
		end
	end
	check(ratchet == 0, "Ratchet's services serve both sides")
	-- New zone: Rog'mar's flight point for the Horde, Farholde Keep's for the Alliance.
	check(find("f", "Rog'mar flight master") and find("f", "Rog'mar flight master").map == 2548, "Riverglades has the Horde flight point")
	check(find("f", "Gretchen Mayberry") and find("f", "Gretchen Mayberry").faction == "A", "and the Alliance one")
end)
