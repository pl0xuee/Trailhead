-- The shipped quest hub list (Data/Hubs.lua, made by tools/gen_hubs.py): towns whose inn or
-- flight master stands at the edge of town still say they have one, and Zephras Isle's towns.
local H = ...
local check = H.check

local INN, FLIGHT = 1, 2

-- name, map, faction (0 both, 1 Horde, 2 Alliance), flags the row must have
local TOWNS = {
	{ "Sentinel Hill", 1436, 2, INN + FLIGHT },
	{ "Darkshire", 1431, 2, INN + FLIGHT },
	{ "Thelsamar", 1432, 2, INN + FLIGHT },
	{ "Theramore Isle", 1445, 2, INN + FLIGHT },
	{ "Southshore", 1424, 2, INN + FLIGHT },
	{ "Revantusk Village", 1425, 1, INN + FLIGHT },
	{ "Shadowprey Village", 1443, 1, INN + FLIGHT },
	{ "Nijel's Point", 1443, 2, INN + FLIGHT },
	{ "Kargath", 1418, 1, INN + FLIGHT },
	{ "Thorium Point", 1427, 1, FLIGHT },
	{ "Thorium Point", 1427, 2, FLIGHT },
	{ "Nethergarde Keep", 1419, 2, FLIGHT },
	{ "Shen'dar Village", 2521, 0, INN },
}

local function row(data, map, name, faction)
	for _, r in ipairs(data[map] or {}) do
		if r[1] == name and (r[4] == faction or r[4] == 0) then
			return r
		end
	end
end

H.section("quest hubs: the shipped list", function()
	local T = H.load()
	local data = T.HubData
	check(type(data) == "table" and data[1436] ~= nil, "the shipped hub list is loaded")
	for _, town in ipairs(TOWNS) do
		local name, map, faction, flags = town[1], town[2], town[3], town[4]
		local r = row(data, map, name, faction)
		check(r ~= nil, name .. " is a hub")
		if r then
			local has = r[8]
			check((flags % 2 == 0 or has % 2 == 1) and (flags % 4 < 2 or has % 4 >= 2),
				name .. " shows its " .. (flags % 4 == 3 and "inn and flight master" or flags % 2 == 1 and "inn" or "flight master"))
		end
	end
	-- Cenarion Hold serves both sides with one inn and a flight master each.
	local hold = row(data, 1451, "Cenarion Hold", 2)
	check(hold and hold[8] % 4 == 3 and row(data, 1451, "Cenarion Hold", 1)[8] % 4 == 3, "Cenarion Hold has an inn and a flight master for both sides")
	-- Valanaar, the Skyborne town in the south-east of Zephras Isle.
	local valanaar = row(data, 2521, "Valanaar", 0)
	check(valanaar and valanaar[2] > 550 and valanaar[2] < 700 and valanaar[3] > 700 and valanaar[3] < 820
		and valanaar[5] == 9 and valanaar[6] == 13, "Valanaar is a hub in the south-east of the isle, levels 9 to 13")
	-- Every row is well formed.
	local bad = 0
	for _, rows in pairs(data) do
		for _, r in ipairs(rows) do
			if type(r[1]) ~= "string" or r[2] < 0 or r[2] > 1000 or r[3] < 0 or r[3] > 1000 or r[5] > r[6] or r[7] < 1 then
				bad = bad + 1
			end
		end
	end
	check(bad == 0, "every hub row is well formed")
	H.noErrors(T, "shipped hubs")
end)
