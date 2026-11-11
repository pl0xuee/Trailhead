-- Writes every page of the addon, in every look, to JSON files for tools/layout_review.py,
-- which works out where each text and button lands, reports what collides or is cut off and
-- draws the pages. Run through the tool, not by hand:  python3 tools/layout_review.py
local H = ...
local Stub = H.Stub
local OUT = os.getenv("TH_LAYOUT")
local ONLY = os.getenv("TH_LAYOUT_ONLY") -- a Lua pattern: only scenes whose name matches

-- Letter widths (in ems) of the stand-in font, written by the tool.
local widths = dofile(OUT .. "/widths.lua")
local function lineWidth(text, size)
	local total = 0
	for index = 1, #text do
		local byte = text:byte(index)
		if byte < 128 then
			total = total + (widths[byte] or widths.other)
		elseif byte >= 192 then
			total = total + widths.other -- one letter of a longer UTF-8 sequence
		end
	end
	return total * size
end
local function measure(text, size)
	local widest = 0
	for line in (text .. "\n"):gmatch("(.-)\n") do
		widest = math.max(widest, lineWidth(line, size))
	end
	return widest
end

local function quote(text)
	return '"' .. tostring(text):gsub('[%c"\\]', function(ch)
		if ch == '"' or ch == "\\" then return "\\" .. ch end
		return ("\\u%04x"):format(ch:byte())
	end) .. '"'
end

local function list(values)
	local out = {}
	for index = 1, #values do
		local value = values[index]
		out[index] = type(value) == "number" and ("%.4f"):format(value) or (value == nil and "null" or quote(value))
	end
	return "[" .. table.concat(out, ",") .. "]"
end

local function dump(name, T)
	local ids = {}
	for index, object in ipairs(Stub.all) do
		ids[object] = index
	end
	local out = {}
	for index, o in ipairs(Stub.all) do
		local f = {}
		local function put(key, value)
			f[#f + 1] = quote(key) .. ":" .. value
		end
		local rec = rawget(o, "rec") or {}
		put("id", index)
		put("kind", quote(o._kind))
		put("parent", o.parent and ids[o.parent] or 0)
		put("shown", o.shown and "true" or "false")
		if o.w then put("w", ("%.4f"):format(o.w)) end
		if o.h then put("h", ("%.4f"):format(o.h)) end
		local points = {}
		for _, p in ipairs(o.points or {}) do
			local pt, a, b, c, d = p[1], p[2], p[3], p[4], p[5]
			local rel, relPoint, x, y
			if type(a) == "number" then
				relPoint, x, y = pt, a, b or 0
			elseif type(b) == "string" then
				rel, relPoint, x, y = a, b, c or 0, d or 0
			else
				rel, relPoint, x, y = a, pt, b or 0, c or 0
			end
			local relId = type(rel) == "table" and (ids[rel] or -1) or (o.parent and ids[o.parent] or 0)
			points[#points + 1] = ("[%s,%d,%s,%.4f,%.4f]"):format(quote(pt), relId, quote(relPoint), x, y)
		end
		put("points", "[" .. table.concat(points, ",") .. "]")
		if rec.SetAllPoints then
			local rel = rec.SetAllPoints[1]
			put("all", type(rel) == "table" and (ids[rel] or -1) or (o.parent and ids[o.parent] or 0))
		end
		if o.layer then put("layer", quote(o.layer)) end
		if o.sub then put("sub", o.sub) end
		if o.scale then put("scale", o.scale) end
		if rec.SetAlpha then put("alpha", rec.SetAlpha[1] or 1) end
		if rec.SetFrameStrata then put("strata", quote(rec.SetFrameStrata[1])) end
		if rec.SetFrameLevel then put("level", rec.SetFrameLevel[1] or 0) end
		if o._kind == "Texture" then
			if rec.SetColorTexture then
				put("solid", list(rec.SetColorTexture))
			elseif o.texture ~= nil then
				put("texture", quote(o.texture))
			end
			if rec.SetVertexColor then put("vertex", list(rec.SetVertexColor)) end
			if rec.SetTexCoord then put("coord", list(rec.SetTexCoord)) end
		elseif o._kind == "FontString" or o._kind == "EditBox" then
			if o.text then put("text", quote(o.text)) end
			if o.font then put("size", ("%.3f"):format(o.font[2])) put("font", quote(o.font[1])) end
			if rec.SetTextColor then put("color", list(rec.SetTextColor)) end
			if rec.SetJustifyH then put("jh", quote(rec.SetJustifyH[1])) end
			if rec.SetJustifyV then put("jv", quote(rec.SetJustifyV[1])) end
			if rec.SetWordWrap then put("wrap", rec.SetWordWrap[1] and "true" or "false") end
			if rec.SetSpacing then put("spacing", rec.SetSpacing[1] or 0) end
			if rec.SetMaxLines then put("maxlines", rec.SetMaxLines[1] or 0) end
			if rawget(o, "style") then put("style", quote(o.style.kind)) end
		end
		if o._kind ~= "Texture" and o._kind ~= "FontString" then
			if o.scripts and (o.scripts.OnClick or o.scripts.OnMouseUp) then put("click", "true") end
			if o.enabled == false then put("disabled", "true") end
			local style = rawget(o, "style")
			if type(style) == "table" and (style.fill or style.line) then
				put("panel", quote(tostring(style.fill or style.line)))
			end
		end
		out[#out + 1] = "{" .. table.concat(f, ",") .. "}"
	end
	local names = {}
	for key, value in pairs(_G) do
		if type(key) == "string" and type(value) == "table" and ids[value] then
			names[#names + 1] = quote(key) .. ":" .. ids[value]
		end
	end
	local current = T.Window.current and T.modules[T.Window.current]
	local file = assert(io.open(OUT .. "/" .. name .. ".json", "w"))
	file:write('{"name":', quote(name), ',"names":{', table.concat(names, ","), '},"page":',
		tostring(current and current.page and ids[current.page] or 0), ',"errors":',
		tostring(#((TrailheadDB and TrailheadDB.errors) or {}) + #Stub.errors),
		',"objects":[\n', table.concat(out, ",\n"), "\n]}\n")
	file:close()
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in pairs(value) do
		out[key] = copy(item)
	end
	return out
end

-- The whole game world instead of the seven zones the tests use: real zone and dungeon names
-- and list lengths. Zone levels come from the shipped quest hubs; dungeon levels are invented.
local REAL = dofile("tests/layout_world.lua")
do
	local shipped = {}
	assert(loadfile("Trailhead/Data/Hubs.lua"))("Trailhead", shipped)
	local zones, dungeon = {}, 0
	for _, row in ipairs(REAL.maps) do
		local hubs = shipped.HubData[row[1]]
		if row[3] == 3 then
			local lo, hi = 1, 60
			if hubs then
				lo, hi = 99, 0
				for _, hub in ipairs(hubs) do
					lo, hi = math.min(lo, hub[5]), math.max(hi, hub[6])
				end
				hi = math.min(60, math.max(hi, lo + 9))
			end
			zones[#zones + 1] = { row[2], 116, lo, hi }
		end
	end
	local activities = {}
	for _, row in ipairs(REAL.activities) do
		if row[2] == 2 then
			dungeon = dungeon + 1
			local lo = math.min(13 + math.floor(dungeon * 1.8), 58)
			activities[#activities + 1] = { row[1], 2, lo, math.min(lo + 8, 60) }
		elseif row[2] == 114 then
			activities[#activities + 1] = { row[1], 114, 60, 60 }
		end
	end
	for _, zone in ipairs(zones) do
		activities[#activities + 1] = zone
	end
	REAL.activities = activities
end

local LOOKS = { "ember", "night", "journal" }
local count = 0

-- One page state, drawn in every look. `setup` gets the loaded addon and drives it there.
local function scene(name, opts, saved, char, setup)
	if ONLY then -- a comma list of Lua patterns
		local wanted = false
		for pattern in ONLY:gmatch("[^,]+") do
			wanted = wanted or name:find(pattern) ~= nil
		end
		if not wanted then
			return
		end
	end
	for _, look in ipairs(LOOKS) do
		local o, s = copy(opts or {}), copy(saved or H.checked())
		o.seed = true
		if o.real ~= false then
			o.real = REAL
		end
		s.theme = look
		Stub.all = {}
		Stub.measure = measure
		local ok, err = xpcall(function()
			local horde = o.horde
			o.horde = nil
			local T = H.load(o, s, copy(char))
			if horde then
				Stub.world.faction = "Horde"
				Stub.world.race = { "Orc", "Orc" }
			end
			setup(T)
			Stub.flush()
			dump(name .. "." .. look, T)
		end, debug.traceback)
		Stub.all, Stub.measure = nil, nil
		if not ok then
			print("  layout scene " .. name .. " failed: " .. tostring(err))
		end
		count = count + 1
	end
end

assert(loadfile("tests/layout_scenes.lua"))(H, scene)
print(("layout: %d pages written to %s"):format(count, OUT))
