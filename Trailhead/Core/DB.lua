local _, T = ...

-- Saved settings. TrailheadDB is shared by every character on the account,
-- TrailheadCharDB belongs to one character.

local DEFAULTS = {
	schema = 1,
	theme = "ember",
	scale = 1,
	hideInCombat = true,
	dock = true, -- sit beside game windows that Trailhead opens
	firstRun = true,
	welcomeDone = false, -- the welcome panel has been closed once
	merchantBar = false, -- extra sell and repair buttons at a vendor; off, because the game has its own
	autoSellJunk = false, -- only ever on if the player turns it on
	autoRepair = false, -- same
	tip = 1,
	minimap = { show = true, angle = 208 },
	window = {}, -- point, relPoint, x, y once the window has been moved
	places = {}, -- services the player has found, shared by all characters
	cardsOff = {}, -- advice cards switched off for good, by id
	interface = { prev = {} }, -- what the player had before a Screen setup change, by option id
}

local CHAR_DEFAULTS = {
	schema = 1,
	tab = "home",
}

T.SCALE_MIN, T.SCALE_MAX, T.SCALE_STEP = 0.7, 1.4, 0.05

local function fill(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			fill(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
	return target
end

function T:InitDB()
	if type(TrailheadDB) ~= "table" then
		TrailheadDB = {}
	end
	if type(TrailheadCharDB) ~= "table" then
		TrailheadCharDB = {}
	end
	local db = fill(TrailheadDB, DEFAULTS)
	local cdb = fill(TrailheadCharDB, CHAR_DEFAULTS)

	-- Repair anything a hand edit or an older version left in a bad state.
	if not T.Theme.defs[db.theme] then
		db.theme = DEFAULTS.theme
	end
	if type(db.scale) ~= "number" or db.scale < T.SCALE_MIN or db.scale > T.SCALE_MAX then
		db.scale = DEFAULTS.scale
	end
	if type(db.minimap.angle) ~= "number" then
		db.minimap.angle = DEFAULTS.minimap.angle
	end
	if type(db.tip) ~= "number" then
		db.tip = 1
	end
	if type(cdb.tab) ~= "string" then
		cdb.tab = CHAR_DEFAULTS.tab
	end

	T.db, T.cdb = db, cdb
end
