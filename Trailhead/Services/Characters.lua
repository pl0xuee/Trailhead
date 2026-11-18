local _, T = ...
local L = T.L
local C = T.Compat
local G = T.Game

-- Characters: a short record of every character on the account, kept in TrailheadDB.chars so
-- each one can see the others (Modules/Characters.lua). A character's record is written when
-- something on it changes and at logout. At login the record from last time is kept aside, so
-- Home can say what changed while the character was away ("Since you last played").
-- Only plain values are saved: anything the game hands over as a secret is left out.

local Chars = {}
T.Characters = Chars

Chars.AWAY = 8 * 3600 -- seconds away before "since you last played" has anything to say
Chars.GEAR_LOW = 0.25 -- the same line as Home's repair card
Chars.SINCE_FOR = 30 * 60 -- seconds after login the "welcome back" card stays news
local REST_WORTH = 5 -- rested experience worth less than this % of a level is not news
local DELAY = 2 -- seconds to wait after a change, so a burst of events writes once

local before -- this character's record as it was at login, or nil
local loginAt -- when this login began
local pending = false
local missed = false -- a write skipped for combat, owed once it ends

-- The account-wide list, repaired if a hand edit or an old version broke it.
function Chars.All()
	local db = T.db
	if not db then
		return {}
	end
	if type(db.chars) ~= "table" then
		db.chars = {}
	end
	return db.chars
end

local function text(value)
	value = C.Plain(value, nil)
	return type(value) == "string" and value ~= "" and value or nil
end

local function number(value)
	value = C.Plain(value, nil)
	return type(value) == "number" and value or nil
end

-- "Realm-Name" for this character, or nil when the game will not say who it is.
function Chars.Key()
	local name = text((UnitName("player")))
	if not name then
		return nil
	end
	-- The game names the realm two ways ("Realm 7 PvE" and "Realm7PvE") and answers only one of
	-- them early in a login: both come down to the same key, without spaces or hyphens.
	local realm = text(C.Call("GetNormalizedRealmName")) or text(C.Call("GetRealmName"))
	realm = realm and realm:gsub("[%s%-]", "")
	if not realm or realm == "" then
		-- A client with no realm call at all keys by name; one that has it but has not
		-- answered yet waits, so no second record is made.
		if C.Has("GetNormalizedRealmName") or C.Has("GetRealmName") then
			return nil
		end
		return name
	end
	return realm .. "-" .. name
end

-- Which of two records of one character to keep: the higher level (a copy written while the
-- game was logging out can be newer but emptier), then the one with gold read, then the newest.
local function better(a, b)
	local la, lb = tonumber(a.level) or 0, tonumber(b.level) or 0
	if la ~= lb then
		return la > lb
	end
	if (a.money ~= nil) ~= (b.money ~= nil) then
		return a.money ~= nil
	end
	return (tonumber(a.at) or 0) > (tonumber(b.at) or 0)
end

-- Folds records of this character saved under another key (older versions keyed the realm
-- either way, or left it out) into the current key, keeping the newest.
function Chars.Merge()
	local key = Chars.Key()
	if not key then
		return 0
	end
	local list, merged = Chars.All(), 0
	local plainRealm, name = key:match("^(.-)%-(.+)$")
	if not name then
		return 0
	end
	for other, rec in pairs(list) do
		if other ~= key and type(other) == "string" and type(rec) == "table" and rec.name == name then
			local realm = other:match("^(.-)%-") or other
			realm = realm:gsub("[%s%-]", "")
			if other == name or realm == plainRealm then
				local keep = list[key]
				if type(keep) ~= "table" or better(rec, keep) then
					list[key] = rec
				end
				list[other] = nil
				merged = merged + 1
			end
		end
	end
	return merged
end

-- Reads the character now. Fields the game does not answer are left out; `keep` (the record
-- from before) fills in what the game cannot tell yet, like professions early in a login.
function Chars.Read(keep)
	keep = type(keep) == "table" and keep or {}
	local name = text((UnitName("player")))
	if not name then
		return nil
	end
	local out = {
		name = name,
		realm = text(C.Call("GetRealmName")) or text(C.Call("GetNormalizedRealmName")),
		class = G.ClassFile(),
		className = text(G.ClassName()),
		race = text((C.Call("UnitRace", "player"))),
		faction = G.Faction(),
		level = G.Level(),
		at = time(),
	}
	local xp, xpMax = number(UnitXP and UnitXP("player")), number(UnitXPMax and UnitXPMax("player"))
	local cap = number(C.Call("GetMaxPlayerLevel"))
	if xp and xpMax and xpMax > 0 and not (cap and out.level >= cap) then
		out.xp, out.xpMax = xp, xpMax
		out.rested = number(C.Call("GetXPExhaustion")) or 0
	end
	out.bind = G.BindLocation()
	out.money = G.Money()
	out.durability = G.LowestDurability()
	out.zone = text(C.Call("GetRealZoneText"))

	local skills = G.Skills()
	local profs = {}
	for _, group in ipairs({ skills.professions, skills.secondary }) do
		for _, skill in ipairs(group or {}) do
			profs[#profs + 1] = { name = skill.name, rank = skill.rank, max = skill.max }
		end
	end
	if #profs == 0 and not skills.complete and type(keep.profs) == "table" then
		profs = keep.profs -- the game has not listed them yet: keep what was known
	end
	out.profs = profs

	local talents = G.Talents()
	if talents and not talents.unspentUnknown then
		out.talents = talents.unspent
	elseif G.HasTalentPoints() then
		out.talentsSome = true
	elseif talents or C.Has("C_ClassTalents.HasUnspentTalentPoints") then
		out.talents = 0
	end

	local training = G.Training()
	if training.source then
		out.train = #training.now
		out.trainCost = training.cost
	end
	return out
end

-- Writes this character's record now.
function Chars.Save()
	local key = Chars.Key()
	if not key or not T.db then
		return nil
	end
	local list = Chars.All()
	local record = Chars.Read(list[key])
	if record then
		list[key] = record
	end
	return record
end

-- Writes it shortly, out of combat.
local function soon()
	if pending then
		return
	end
	pending = true
	C.Call("C_Timer.After", DELAY, function()
		pending = false
		if C.InCombat() then
			missed = true -- PLAYER_REGEN_ENABLED writes it
			return
		end
		missed = false
		T.SafeCall("Characters.Save", Chars.Save)
		T:Fire("TH_CHARACTERS_CHANGED")
	end)
end

function Chars.IsCurrent(key)
	return key ~= nil and key == Chars.Key()
end

-- Every record, most recently saved first. Each comes back as { key, rec } with rec untouched.
function Chars.List()
	local out = {}
	for key, rec in pairs(Chars.All()) do
		if type(key) == "string" and type(rec) == "table" and type(rec.name) == "string" then
			out[#out + 1] = { key = key, rec = rec, current = Chars.IsCurrent(key) }
		end
	end
	table.sort(out, function(a, b)
		if a.current ~= b.current then
			return a.current
		end
		local ta, tb = tonumber(a.rec.at) or 0, tonumber(b.rec.at) or 0
		if ta ~= tb then
			return ta > tb
		end
		return a.key < b.key
	end)
	return out
end

-- Removes a character's record. The one being played comes back at the next save, so it is
-- not offered.
function Chars.Forget(key)
	local list = Chars.All()
	if type(key) ~= "string" or list[key] == nil or Chars.IsCurrent(key) then
		return false
	end
	list[key] = nil
	T:Fire("TH_CHARACTERS_CHANGED")
	return true
end

-- ---------------------------------------------------------------------------
-- Words

-- "3 days", "1 day", "5 hours", "20 minutes", "now".
function Chars.Span(seconds)
	seconds = tonumber(seconds) or 0
	if seconds < 60 then
		return L["moments"]
	end
	local days, hours, minutes = math.floor(seconds / 86400), math.floor(seconds / 3600), math.floor(seconds / 60)
	if days >= 1 then
		return days == 1 and L["1 day"] or L["%d days"]:format(days)
	elseif hours >= 1 then
		return hours == 1 and L["1 hour"] or L["%d hours"]:format(hours)
	end
	return minutes == 1 and L["1 minute"] or L["%d minutes"]:format(minutes)
end

-- How long ago a record was saved: "Saved 2 days ago".
function Chars.Ago(at)
	at = tonumber(at)
	if not at then
		return L["Date unknown"]
	end
	local since = time() - at
	if since < 60 then
		return L["Saved just now"]
	end
	return L["Saved %s ago"]:format(Chars.Span(since))
end

-- ---------------------------------------------------------------------------
-- Since you last played

-- What changed while this character was away, or nil when it was not away long enough or
-- there is nothing worth saying. { away, toward, part, rested, train, gear }
function Chars.Since()
	local prev = before
	if type(prev) ~= "table" or type(prev.at) ~= "number" then
		return nil
	end
	local away = (loginAt or time()) - prev.at
	if away < Chars.AWAY then
		return nil
	end
	local out = { away = away }
	local level = G.Level()
	local xp, xpMax = number(UnitXP and UnitXP("player")), number(UnitXPMax and UnitXPMax("player"))
	local cap = number(C.Call("GetMaxPlayerLevel"))
	if xp and xpMax and xpMax > 0 and not (cap and level >= cap) then
		out.toward = level + 1
		out.part = math.floor(xp / xpMax * 100)
		local now = number(C.Call("GetXPExhaustion")) or 0
		-- Compared with the same level only: a record from another level says nothing.
		if prev.level == level and type(prev.rested) == "number" then
			local gained = math.floor((now - prev.rested) / xpMax * 100)
			if gained >= REST_WORTH then
				out.rested = gained
			end
		end
	end
	local training = G.Training()
	if training.source and #training.now > 0 then
		out.train = #training.now
	end
	local worst = G.LowestDurability()
	if worst and worst < Chars.GEAR_LOW then
		out.gear = worst
	end
	if not (out.rested or out.train or out.gear) then
		return nil
	end
	return out
end

-- The Home card (Services/Advisor.lua), or nil. Only in the first half hour of a login: after
-- that it is no longer news. Spells waiting at the trainer are left to the training card,
-- which says the same with prices; with nothing else to tell, there is no card.
function Chars.SinceCard()
	if loginAt and time() - loginAt > Chars.SINCE_FOR then
		return nil
	end
	local since = Chars.Since()
	if since and since.train and T.Advisor and T.Advisor.TrainCardShows and T.Advisor.TrainCardShows(since.train) then
		since.train = nil
		if not (since.rested or since.gear) then
			since = nil
		end
	end
	if not since then
		return nil
	end
	local first
	if since.rested and since.toward then
		first = L["On the way to level %d, with %d%% of a level rested."]:format(since.toward, since.rested)
	elseif since.toward then
		first = L["You were %d%% of the way to level %d."]:format(since.part, since.toward)
	end
	local more = {}
	if since.train then
		more[#more + 1] = since.train == 1 and L["1 new spell at your trainer."]
			or L["%d new spells at your trainer."]:format(since.train)
	end
	if since.gear then
		more[#more + 1] = since.gear <= 0 and L["Some gear is broken."] or L["Gear nearly broken."]
	end
	local body = table.concat(more, " ")
	if first then
		body = body ~= "" and (first .. "\n" .. body) or first
	end
	-- The button goes where the most useful next step is.
	local action, run = L["Your characters"], function()
		T.Window:Open("characters")
	end
	if since.train then
		action, run = L["Find trainer"], function()
			T.Window:Open("find", "trainer")
		end
	elseif since.gear then
		action, run = L["Find repair"], function()
			T.Window:Open("find", "repair")
		end
	end
	return {
		id = "since", tone = "info", icon = "moon", key = "since:" .. tostring(before.at),
		title = L["Welcome back after %s"]:format(Chars.Span(since.away)),
		body = body, action = action, run = run,
	}
end

-- ---------------------------------------------------------------------------

T:On("PLAYER_LOGIN", function()
	loginAt = time()
	T.SafeCall("Characters.Merge", Chars.Merge)
	local key = Chars.Key()
	local saved = key and Chars.All()[key]
	if type(saved) == "table" then
		before = {}
		for field, value in pairs(saved) do
			before[field] = value
		end
	end
	for _, event in ipairs({
		"PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_MONEY", "TRAINER_CLOSED", "HEARTHSTONE_BOUND",
		"SKILL_LINES_CHANGED", "UPDATE_INVENTORY_DURABILITY", "ZONE_CHANGED_NEW_AREA", "TRAIT_CONFIG_UPDATED",
	}) do
		T:On(event, soon)
	end
	T:On("PLAYER_REGEN_ENABLED", function()
		if missed then
			soon()
		end
	end)
	-- Logging out or reloading: the game has already emptied gold, experience and professions,
	-- so only the time is written; everything else is from the last save while playing.
	T:On("PLAYER_LOGOUT", function()
		local key = Chars.Key()
		local rec = key and Chars.All()[key]
		if type(rec) == "table" then
			rec.at = time()
		end
	end)
end)
