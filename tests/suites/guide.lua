-- The Guide: every topic for every class, faction and a few levels; text that fits; the
-- grouped list; the glossary and services; shipped trainer spells and what abilities use up.
local H = ...
local Stub, check = H.Stub, H.check

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local NEW = { class = true, services = true, grouping = true, danger = true, words = true, money = true,
	reputation = true, travel = true, forever = true }
local PANEL_H, ROW_H = 452, 24

-- Whether a topic's text fits the panel, by the same layout the page uses (about 80
-- characters to a line of 15.5 points).
local function fits(info)
	local problems = {}
	if #info.what > 250 then
		problems[#problems + 1] = "what is " .. #info.what
	end
	local shown = #info.rows
	if shown > 9 then
		problems[#problems + 1] = "rows " .. shown
	end
	for _, row in ipairs(info.rows) do
		if row.text and (#row.name > 14 or #row.text > 68) then
			problems[#problems + 1] = "row " .. row.name .. ": " .. row.text
		end
	end
	local top = shown > 0 and (162 + shown * ROW_H + 14) or 146
	local bottom = (info.action or info.pager) and (PANEL_H - 18 - 28) or (PANEL_H - 12)
	local lines = math.floor((bottom - (top + 19)) / 15.5)
	if #(info.next or "") > lines * 80 then
		problems[#problems + 1] = ("next is %d, room for %d"):format(#(info.next or ""), lines * 80)
	end
	return problems
end

H.section("guide: every topic reads for every class", function()
	local guide
	local count, bad = 0, 0
	for _, class in ipairs(CLASSES) do
		for _, level in ipairs({ 1, 10, 40, 60 }) do
			local T = H.load({ class = class, level = level }, H.checked())
			guide = T.modules.guide
			for _, side in ipairs({ "Alliance", "Horde" }) do
				Stub.world.faction = side
				for _, topic in ipairs(guide.Topics) do
					local ok, info = pcall(guide.Read, topic.id)
					count = count + 1
					if not (ok and type(info) == "table" and type(info.what) == "string" and type(info.rows) == "table"
						and type(info.attention) == "number") then
						bad = bad + 1
						print("    " .. class .. " " .. level .. " " .. side .. " " .. topic.id .. ": " .. tostring(info))
					elseif NEW[topic.id] then
						local problems = fits(info)
						if #problems > 0 then
							bad = bad + 1
							print("    " .. class .. " " .. level .. " " .. side .. " " .. topic.id .. ": " .. table.concat(problems, "; "))
						end
					end
				end
			end
			H.noErrors(T, class .. " " .. level)
		end
	end
	check(count == #CLASSES * 4 * 2 * #guide.Topics and bad == 0, "every topic reads and fits (" .. count .. " reads, " .. bad .. " bad)")
end)

H.section("guide: grouped list", function()
	local T = H.load(nil, H.checked())
	local guide = T.modules.guide
	check(#T.GuideGroups == 4 and #guide.Topics >= 18, "four groups hold the topics")
	local perGroup, known = {}, {}
	for _, group in ipairs(T.GuideGroups) do
		known[group.id] = true
	end
	for _, topic in ipairs(guide.Topics) do
		perGroup[topic.group] = (perGroup[topic.group] or 0) + 1
		check(known[topic.group], topic.id .. " is in a known group")
	end
	for id, many in pairs(perGroup) do
		check(many <= 7, "group " .. id .. " fits the list (" .. many .. ")")
	end
	H.slash("")
	T.Window:Select("guide", "talents")
	Stub.flush()
	check(Stub.sees("Talents") and Stub.sees("Coming up") and not Stub.sees("Money"), "only the open group's topics are listed")
	Stub.click("Gold and more")
	Stub.flush()
	check(guide.group == "gold" and Stub.sees("Money") and Stub.sees("Reputation") and not Stub.sees("Talents"), "a group chip opens its topics")
	T.Window:Select("guide", "services")
	Stub.flush()
	check(guide.group == "world" and guide.topic == "services" and Stub.sees("Towns and services"), "going to a topic opens its group")
	H.noErrors(T, "grouped list")
end)

H.section("guide: services and the glossary", function()
	local T = H.load(nil, H.checked())
	local guide = T.modules.guide
	H.slash("")
	T.Window:Select("guide", "services")
	Stub.flush()
	check(Stub.sees("Inn") and Stub.sees("Bank") and Stub.sees("Mailbox") and Stub.sees("Auction house") and Stub.sees("Flight master")
		and Stub.sees("Trainer") and Stub.sees("Stable master"), "the services topic lists every service")
	local info = guide.Read("services")
	for _, row in ipairs(info.rows) do
		check(row.run ~= nil, row.name .. " leads into Find it")
	end
	info.rows[2].run()
	check(T.Window.current == "find", "a service row opens Find it")

	T.Window:Select("guide", "words")
	Stub.flush()
	check(Stub.sees("LFG") and Stub.sees("LFM") and Stub.sees("DPS"), "the glossary opens on the group words")
	local seen = {}
	for page = 1, #T.GuideTopics.words.pages do
		for _, row in ipairs(guide.Read("words").rows) do
			seen[row.name] = true
		end
		guide.Read("words").pager.run()
	end
	for _, word in ipairs({ "LFG", "LFM", "DPS", "Aggro", "Pull", "Add", "AoE", "Buff", "Debuff", "CC", "BoE", "BoP", "Hearth", "Mob", "Proc", "Kite", "Wipe", "Res", "/1", "/2", "/4", "/w name", "/p", "/g", "/who" }) do
		check(seen[word], "the glossary explains " .. word)
	end
	check(seen["Elite, rare"] and seen["Need, greed"], "need, greed, elite and rare are explained")
	Stub.click("Next: Fights")
	Stub.flush()
	check(Stub.sees("Pull") and Stub.sees("Aggro"), "the page button turns to the next page")
	H.noErrors(T, "glossary")
end)

H.section("guide: coming up before and after a trainer visit", function()
	local T = H.load({ class = "MAGE", level = 14 }, H.checked())
	local guide = T.modules.guide
	local info = guide.Read("levels")
	check(info.rows[1].name == "Level 16" and info.rows[1].text:find("Arcane Missiles (Rank 2)", 1, true) and info.rows[1].text:find("Flamestrike", 1, true),
		"a fresh mage sees the spells of level 16 with their ranks")
	check(info.next:find("By the game's own tables, at level 16 your trainer should have", 1, true) and info.next:find("Visit your class trainer once", 1, true),
		"it says the list is from the tables and still asks for a visit")
	local list = { { n = "Cone of Cold", s = "Rank 1", t = "unavailable", l = 16, c = 500 } }
	T = H.load({ class = "MAGE", level = 14 }, H.checked(), { trainer = { at = 1, level = 14, full = true, list = list } })
	info = T.modules.guide.Read("levels")
	check(info.rows[1].name == "Level 16" and info.rows[1].text == "Trainer: Cone of Cold" and not info.next:find("game's own tables", 1, true),
		"after a visit the trainer's own list wins")
	T = H.load({ class = "HORDE_NONE", level = 14 }, H.checked())
	check(type(T.modules.guide.Read("levels").next) == "string", "an unknown class still reads")
	T = H.load({ class = "MAGE", level = 30 }, H.checked())
	Stub.world.faction = "Alliance"
	local alliance = T.modules.guide.Read("levels").rows
	local text = ""
	for _, row in ipairs(alliance) do
		text = text .. row.text .. " "
	end
	check(not text:find("Thunder Bluff", 1, true) and not text:find("Orgrimmar", 1, true), "an Alliance mage is not shown the other side's teleports")
	H.noErrors(T, "coming up shipped")
end)

H.section("guide: what abilities use up", function()
	local T = H.load({ class = "ROGUE", level = 21 }, H.checked())
	local info = T.modules.guide.Read("supplies")
	local found
	for _, row in ipairs(info.rows) do
		found = found or (row.text and row.text:find("Flash Powder for Vanish", 1, true) and row)
	end
	check(found and found.run ~= nil, "a rogue is shown Flash Powder for Vanish with a way to a vendor")
	T = H.load({ class = "WARLOCK", level = 12 }, H.checked())
	C_Item.GetItemCount = function(item) return item == "Soul Shard" and 3 or 0 end
	info = T.modules.guide.Read("supplies")
	found = nil
	for _, row in ipairs(info.rows) do
		found = found or (row.text and row.text:find("Soul Shard for", 1, true) and row)
	end
	check(found and found.text:find("you carry 3", 1, true) and found.run == nil, "a warlock sees how many Soul Shards are carried, and no vendor button")
	T = H.load({ class = "SHAMAN", level = 8 }, H.checked())
	local text = ""
	for _, row in ipairs(T.modules.guide.Read("supplies").rows) do
		text = text .. (row.text or "") .. " "
	end
	check(text:find("Earth Totem", 1, true) ~= nil, "a shaman is shown the Earth Totem")
	T = H.load({ class = "WARRIOR", level = 20 }, H.checked())
	check(#T.modules.guide.Read("supplies").rows == 3, "a warrior needs nothing extra")
	-- The class topic names the same needs.
	T = H.load({ class = "HUNTER", level = 5 }, H.checked())
	info = T.modules.guide.Read("class")
	check(info.rows[4].text:find("Ammunition", 1, true) and info.rows[3].text == "Damage", "the hunter's class notes name ammunition and the damage role")
	T = H.load({ class = "DRUID", level = 5 }, H.checked())
	check(T.modules.guide.Read("class").rows[3].text == "Tank, Healer, Damage", "the druid can fill all three jobs")
	H.noErrors(T, "what abilities use up")
end)
