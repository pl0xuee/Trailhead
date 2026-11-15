-- Your characters: the account-wide record of each character, the page that lists them, the
-- ways into it, and the "since you last played" card on Home.
local H = ...
local Stub, check = H.Stub, H.check

local KEY = "TestRealm-Aeloria"

-- Logs out, moves the saved record back in time and logs in again with the same saved file.
local function relog(T, opts, hours, change)
	Stub.fire("PLAYER_LOGOUT")
	local saved = T.db
	saved.errors = nil
	local rec = saved.chars[KEY]
	if rec then
		rec.at = rec.at - hours * 3600
	end
	if change then
		change(saved)
	end
	return H.load(opts, saved)
end

local function card(T)
	for _, item in ipairs(T.Advisor.Cards(20)) do
		if item.id == "since" then
			return item
		end
	end
	return nil
end

H.section("characters: this character is saved at login and logout", function()
	local T = H.load(nil, H.checked())
	local rec = T.db.chars[KEY]
	check(type(rec) == "table", "a record is written soon after login")
	check(rec.name == "Aeloria" and rec.realm == "Test Realm" and rec.class == "MAGE" and rec.className == "Mage", "name, realm and class")
	check(rec.race == "Human" and rec.level == 14 and rec.faction == 2, "race, level and side")
	check(rec.xp == 6200 and rec.xpMax == 10000 and rec.rested == 2100, "experience and rested experience")
	check(rec.bind == "Goldshire" and rec.money == 341250 and rec.durability == 1, "home, gold and gear")
	check(rec.zone == "Westfall" and type(rec.at) == "number", "zone and when")
	check(type(rec.profs) == "table", "professions are a list")
	check(rec.train == nil, "no trainer count before a trainer visit")
	check(rec.talents == 1 or rec.talentsSome == true, "talent points to spend")
	for _, value in pairs(rec) do
		check(not T.Compat.IsSecret(value), "no secret value is saved")
	end

	-- A trainer visit, then closing it, updates the count.
	H.visit("Jennea Cannon", H.MAGE_TRAINER)
	H.leave()
	check(T.db.chars[KEY].train == 2 and T.db.chars[KEY].trainCost == 3000, "spells ready at the trainer, and the cost")

	Stub.world.money = 500000
	Stub.fire("PLAYER_MONEY")
	Stub.flush()
	check(T.db.chars[KEY].money == 500000, "gold changes are saved")

	Stub.world.level = 15
	Stub.fire("PLAYER_LEVEL_UP", 15)
	Stub.flush()
	check(T.db.chars[KEY].level == 15, "a level up is saved")

	-- In combat nothing is written; it is written once the fight is over.
	Stub.combat = true
	Stub.world.money = 600000
	Stub.fire("PLAYER_MONEY")
	Stub.flush()
	check(T.db.chars[KEY].money == 500000, "nothing written in combat")
	Stub.combat = false
	Stub.fire("PLAYER_REGEN_ENABLED")
	Stub.flush()
	check(T.db.chars[KEY].money == 600000, "written once the fight ends")

	Stub.world.bind = "Sentinel Hill"
	Stub.fire("PLAYER_LOGOUT")
	check(T.db.chars[KEY].bind == "Sentinel Hill", "logging out writes at once")
	H.noErrors(T, "saving")
end)

H.section("characters: a secret name saves nothing", function()
	local T = H.load({ secretName = true }, H.checked())
	check(next(T.db.chars) == nil, "nothing saved without a readable name")
	check(T.Characters.Since() == nil and T.Characters.SinceCard() == nil, "no card")
	T.Window:Open("characters")
	check(Stub.sees("Trailhead cannot tell who this character is yet. Try again in a moment."), "the page says so")
	H.noErrors(T, "secret name")
end)

H.section("characters: a bare client saves what it can", function()
	local T = H.load({ bare = true }, H.checked())
	local rec = T.db.chars.Aeloria
	check(type(rec) == "table" and rec.realm == nil and rec.bind == nil, "keyed by name alone, no realm, no home")
	T.Window:Open("characters")
	check(Stub.sees("Aeloria") and Stub.sees("Playing now"), "the page lists it")
	check(Stub.sees("Log in once on each of your other characters and they show up here too."), "and says how the others get there")
	H.noErrors(T, "bare client")
end)

H.section("characters: old and broken saved records", function()
	local saved = H.checked({ chars = {
		["TestRealm-Old"] = { name = "Old", level = "x", profs = "none", at = "yesterday", xp = 5 },
		["TestRealm-Broken"] = "not a table",
		["TestRealm-Nameless"] = { level = 20 },
		["Other-Thrall"] = { name = "Thrall", realm = "Other", level = 30, className = "Shaman", race = "Orc",
			xp = 100, xpMax = 0, profs = { { name = "Mining", rank = 120, max = 150 }, "bad" }, at = time() - 3 * 86400,
			money = 10000, talents = 2, train = 1, durability = 0.5, bind = "Orgrimmar", zone = "Durotar" },
	} })
	local T = H.load(nil, saved)
	local list = T.Characters.List()
	check(#list == 3, "records without a name or that are not tables are skipped")
	check(list[1].key == KEY and list[1].current, "this character comes first")
	check(list[2].key == "Other-Thrall" and list[3].key == "TestRealm-Old", "then the most recent")
	T.Window:Open("characters")
	for _, wanted in ipairs({ "Your characters", "3 characters", "Thrall", "Level 30 Orc Shaman  \194\183  Other  \194\183  Durotar",
		"Home: Orgrimmar  \194\183  1g 0s  \194\183  Gear 50%", "Mining 120/150  \194\183  2 talent points to spend  \194\183  1 spell at the trainer",
		"Saved 3 days ago", "Old", "Date unknown", "No professions", "Home: not set", "Playing now" }) do
		check(Stub.sees(wanted), "page shows: " .. wanted)
	end
	check(Stub.sees("Gold on all of them: 35g 12s"), "gold on every character, added up")
	H.noErrors(T, "old records")
end)

H.section("characters: forgetting a character takes two clicks", function()
	local saved = H.checked({ chars = {
		["Other-Thrall"] = { name = "Thrall", level = 30, at = time() - 3600 },
	} })
	local T = H.load(nil, saved)
	T.Window:Open("characters")
	check(not T.Characters.Forget(KEY), "the character being played cannot be forgotten")
	check(not T.Characters.Forget("nobody"), "an unknown key changes nothing")
	Stub.click("Forget")
	check(T.db.chars["Other-Thrall"] ~= nil and Stub.sees("Yes, forget"), "the first click asks")
	T.Window:Select("home")
	T.Window:Select("characters")
	check(not Stub.sees("Yes, forget"), "leaving the page takes the question back")
	Stub.click("Forget")
	Stub.click("Yes, forget")
	check(T.db.chars["Other-Thrall"] == nil, "the second click forgets")
	check(not Stub.sees("Thrall") and Stub.sees("1 character"), "the page updates")
	check(T.db.chars[KEY] ~= nil, "this character stays")
	H.noErrors(T, "forget")
end)

H.section("characters: the ways in", function()
	local T = H.load(nil, H.checked())
	T.Window:Open("home")
	Stub.click("Your characters")
	check(T.Window.current == "characters", "Home's banner opens the page")
	T.Window:Select("legacy")
	Stub.click("Your characters")
	check(T.Window.current == "characters", "the Legacy page opens it")
	check(T.cdb.tab == "legacy", "the page has no tab of its own")
	H.noErrors(T, "ways in")
end)

H.section("characters: since you last played", function()
	local opts = nil
	local T = H.load(opts, H.checked())
	check(card(T) == nil, "no card on a first login")

	-- Back after a short break: nothing to say.
	T = relog(T, opts, 2)
	check(card(T) == nil, "no card after two hours")

	-- Back after a day, with rested experience built up.
	T = relog(T, opts, 30, function(saved)
		saved.chars[KEY].rested = 100
	end)
	local found = card(T)
	check(found ~= nil, "a card after a day away")
	check(found and found.title == "Welcome back after 1 day", "it says how long")
	check(found and found.body == "On the way to level 15, with 20% of a level rested.", "rested experience and the next level")
	check(found and found.tone == "info" and not found.keep and found.action == "Your characters", "an optional card that can be dismissed")
	T.Window:Open("home")
	check(Stub.sees("Welcome back after 1 day"), "Home shows it")
	T.Advisor.Dismiss(found)
	check(card(T) == nil, "dismissed for the rest of this login")

	-- Nothing gained and nothing else to say: no card.
	T = relog(T, opts, 48, function(saved)
		saved.chars[KEY].rested = 2100
	end)
	check(card(T) == nil, "no card when nothing changed")

	-- Spells at the trainer and worn gear, rested experience unchanged.
	T = relog(T, opts, 10, function(saved)
		saved.chars[KEY].rested = 2100
	end)
	H.visit("Jennea Cannon", H.MAGE_TRAINER)
	H.leave()
	Stub.world.durability[1] = { 3, 40 }
	found = card(T)
	check(found and found.title == "Welcome back after 10 hours", "hours away")
	check(found and found.body == "You were 62% of the way to level 15.\n2 new spells at your trainer. Gear nearly broken.", "trainer and gear")
	check(found and found.action == "Find trainer", "the button goes to the trainer")
	found.run()
	check(T.Window.current == "find", "and opens Find it")
	Stub.world.durability[1] = { 0, 40 }
	found = card(T)
	check(found and found.body:find("Some gear is broken.", 1, true), "broken gear")

	-- A record from another level is not compared.
	T = relog(T, opts, 20, function(saved)
		saved.chars[KEY].rested, saved.chars[KEY].level = 0, 10
	end)
	check(card(T) == nil, "a record from another level says nothing about rest")

	-- A clock that went backwards says nothing.
	T = relog(T, opts, -20)
	check(card(T) == nil, "no card from the future")

	-- Level 60: nothing about experience, but the trainer still counts.
	local T60 = H.load({ level = 60 }, H.checked({ chars = { [KEY] = { name = "Aeloria", level = 60, at = time() - 86400 } } }))
	check(card(T60) == nil, "level 60 with nothing waiting: no card")
	H.noErrors(T, "since you last played")
end)
