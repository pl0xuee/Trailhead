-- Page layout details: buttons sit under what they belong to (Spells, Route), the dungeon
-- page's tips share one card and its path steps have a title.
local H = ...
local Stub, check = H.Stub, H.check

-- The visible button with this label, or nil.
local function button(label)
	for _, text in ipairs(Stub.fontstrings) do
		if text.text == label and text.parent and text.parent._kind == "Button" and text.parent:IsVisible() then
			return text.parent
		end
	end
	return nil
end

-- How far down from its anchor a frame was last placed.
local function down(frame)
	local point = frame and frame.points and frame.points[#frame.points]
	return point and -(point[5] or 0) or nil
end

H.section("pages: Spells buttons sit under their lists", function()
	local T = H.load(nil, H.checked())
	H.slash("")
	T.Window:Select("spells")
	Stub.flush()
	local book, trainer = button("Open spellbook"), button("Find my trainer")
	check(book ~= nil and trainer ~= nil, "both buttons show")
	local missing = #T.Game.SpellsOffBars()
	check(missing == 2 and down(book) == 66 + 2 * 26 + 4 + 14, "Open spellbook sits straight under the two spells it lists")
	check(down(trainer) ~= nil and down(trainer) < 200, "Find my trainer sits under the empty text, not at the foot of the card")
	Stub.click("Find my trainer")
	check(T.Window.current == "find" and T.modules.find.category == "trainer", "and it still finds the trainer")
	H.noErrors(T, "spells layout")
end)

H.section("pages: Route offers a flight master as the next step", function()
	local T = H.load(nil, H.checked())
	local R = T.Routes
	H.slash("")
	R.Show({ title = "Somewhere", map = 1429, x = 0.3, y = 0.6 })
	Stub.flush()
	check(T.Window.current == "route" and button("Find a flight master") ~= nil, "a route offers to find a flight master")
	Stub.click("Find a flight master")
	check(T.Window.current == "find" and T.modules.find.category == "flight", "and the button opens the flight masters")
	R.Show(R.ForDungeon("Nowhere Keep"))
	Stub.flush()
	check(T.Window.current == "route" and button("Find a flight master") == nil, "a place Trailhead cannot find offers no button")
	H.noErrors(T, "route next step")
end)

H.section("pages: dungeon tips share one card and path steps are titled", function()
	local T = H.load(nil, H.checked())
	H.slash("")
	-- Ragefire Chasm: two tips and walking steps between the bosses
	local guide = T.DungeonGuides[389]
	check(#guide.tips == 2, "the test dungeon has two tips")
	T.Window:Select("dungeon", "Ragefire Chasm")
	Stub.flush()
	local tips = "- " .. guide.tips[1] .. "\n- " .. guide.tips[2]
	local titled = (Stub.sees("Tips for the group") or Stub.sees("TIPS FOR THE GROUP")) and Stub.sees(tips)
	check(titled and not Stub.sees("Tip for the group") and not Stub.sees("TIP FOR THE GROUP"), "both tips are lines in one card with one title")
	check(Stub.sees("Path") or Stub.sees("PATH"), "a walking step has a title")
	check(Stub.sees(guide.steps[1].text), "and its text")
	H.noErrors(T, "dungeon tips")
end)
