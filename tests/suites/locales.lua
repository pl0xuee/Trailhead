-- Translations (Trailhead/Locales/*.lua): every entry is a text the addon still uses, keeps the
-- English text's %d and %s in the same order (Lua cannot reorder them), and the addon runs in
-- that language without errors.
local H = ...
local Stub = H.Stub

local LOCALES = { deDE = "deDE.lua", frFR = "frFR.lua", esES = "esES.lua", esMX = "esES.lua" }

-- The texts the addon passes through L[...] today.
local function currentKeys()
	local keys = {}
	local pipe = io.popen("python3 tools/gen_locale_keys.py 2>/dev/null")
	for line in pipe:lines() do
		keys[(line:gsub("\\n", "\n"))] = true
	end
	pipe:close()
	return keys
end

local function specifiers(text)
	local out = {}
	for spec in text:gsub("%%%%", ""):gmatch("%%[-+#0]*%d*%.?%d*[cdeEfgGioqsuxX]") do
		out[#out + 1] = spec
	end
	return table.concat(out, " ")
end

-- Runs a locale file the way the game does and returns its lookup, plus the keys it lists.
local function read(locale, file)
	local path = "Trailhead/Locales/" .. file
	local keys = {}
	for line in io.lines(path) do
		local quoted = line:match('^\t%[(".-")%] = "')
		if quoted then
			keys[#keys + 1] = assert(loadstring("return " .. quoted))()
		end
	end
	local L = setmetatable({}, { __index = function(_, key) return key end })
	local env = setmetatable({ GetLocale = function() return locale end }, { __index = _G })
	local chunk = assert(loadfile(path))
	setfenv(chunk, env)
	chunk("Trailhead", { L = L })
	return L, keys
end

H.section("translations", function()
	local current = currentKeys()
	for locale, file in pairs(LOCALES) do
		local L, keys = read(locale, file)
		local bad, stale, done = {}, {}, 0
		for _, key in ipairs(keys) do
			local text = L[key]
			if text ~= key then
				done = done + 1
				if specifiers(text) ~= specifiers(key) then
					bad[#bad + 1] = key
				end
			end
			if not current[key] then
				stale[#stale + 1] = key
			end
		end
		H.check(#bad == 0, locale .. ": every translation keeps the English %d and %s in order"
			.. (#bad > 0 and (" (" .. #bad .. " wrong, first: " .. bad[1]:gsub("\n", "\\n") .. ")") or ""))
		H.check(#stale == 0, locale .. ": no entry for a text the addon no longer uses"
			.. (#stale > 0 and (" (" .. #stale .. ", first: " .. stale[1]:gsub("\n", "\\n") .. ")") or ""))
		print(("  %s: %d of %d texts translated"):format(locale, done, #keys))
		local other = read("enUS", file)
		H.check(other["Home"] == "Home", locale .. ": the file does nothing on an English client")
	end
end)

H.section("translations: the addon runs in each language", function()
	for _, locale in ipairs({ "deDE", "frFR", "esES", "esMX" }) do
		local T = H.load({ locale = locale })
		H.slash("")
		for _, id in ipairs({ "home", "find", "spells", "builds", "zones", "guide", "legacy", "setup", "weekly", "characters", "settings" }) do
			if T.modules[id] then
				T.Window:Select(id)
				Stub.flush()
			end
		end
		H.noErrors(T, locale)
	end
end)
