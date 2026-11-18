-- The window and its tab-less pages: catching up after a fight, Back, tooltips on buttons,
-- the Settings switches, scale limits, the Forget all question lapsing, the preset advice on
-- Screen setup and the theme's faint text staying readable.
local H = ...
local Stub, check = H.Stub, H.check

H.section("window: the page catches up when a fight ends", function()
	local T = H.load(nil, H.checked({ hideInCombat = false }))
	H.slash("")
	local window = T.Window
	check(window.Keep == nil, "the old map opener is gone")
	local module = T.modules[window.current]
	local refreshed, ended = 0, 0
	local original = module.Refresh
	module.Refresh = function(self, ...)
		refreshed = refreshed + 1
		return original(self, ...)
	end
	T:On("TH_COMBAT_ENDED", function()
		ended = ended + 1
	end)
	Stub.combat = true
	Stub.fire("PLAYER_REGEN_DISABLED")
	check(window:IsOpen(), "with Hide in combat off the window stays up")
	Stub.combat = false
	Stub.fire("PLAYER_REGEN_ENABLED")
	check(refreshed == 1 and ended == 1, "the page on screen is drawn again and the end is announced")
	window:Close()
	Stub.fire("PLAYER_REGEN_ENABLED")
	check(refreshed == 1 and ended == 2, "a closed window is not drawn")
	module.Refresh = original

	-- With Hide in combat on, the window comes back drawn once.
	T.db.hideInCombat = true
	window:Open()
	refreshed = 0
	module.Refresh = function(self, ...)
		refreshed = refreshed + 1
		return original(self, ...)
	end
	Stub.combat = true
	Stub.fire("PLAYER_REGEN_DISABLED")
	check(not window:IsOpen(), "hidden in the fight")
	Stub.combat = false
	Stub.fire("PLAYER_REGEN_ENABLED")
	check(window:IsOpen() and refreshed == 1, "back afterwards, drawn once")
	module.Refresh = original
	H.noErrors(T, "combat catch-up")
end)

H.section("window: tab-less pages keep their tab and go Back", function()
	local T = H.load(nil, H.checked())
	H.slash("")
	local window = T.Window
	for _, id in ipairs({ "weekly", "characters", "setup", "settings" }) do
		window:Select("guide")
		window:Select(id)
		Stub.flush()
		check(window.current == id and window.lastTab == "guide", id .. ": the tab it came from is remembered")
		Stub.click("Back")
		check(window.current == "guide", id .. ": Back returns to it")
	end
	H.noErrors(T, "back")
end)

H.section("window: buttons can carry a tooltip", function()
	local T = H.load(nil, H.checked())
	local shown, hidden = {}, 0
	GameTooltip = {
		SetOwner = function() end,
		SetText = function(_, text) shown[#shown + 1] = text end,
		Show = function() end,
		Hide = function() hidden = hidden + 1 end,
	}
	local W = T.Widgets
	local button = W.Button(UIParent, "Go", "ghost", { tip = "A plain tip" })
	button.scripts.OnEnter(button)
	button.scripts.OnLeave(button)
	check(shown[1] == "A plain tip" and hidden == 1, "a button shows its tip and hides it again")
	local icon = W.IconButton(UIParent, "x", 24, nil, nil, { tip = function() return "From a function" end })
	icon.scripts.OnEnter(icon)
	check(shown[2] == "From a function", "an icon button's tip can be worked out on hover")
	local bare = W.IconButton(UIParent, "x", 24)
	bare.scripts.OnEnter(bare)
	bare.scripts.OnLeave(bare)
	check(#shown == 2 and hidden == 1, "no tip, no tooltip")
	icon.scripts.OnLeave(icon)
	local broken = W.Button(UIParent, "Go", "ghost", { tip = function() error("broken on purpose") end })
	broken.scripts.OnEnter(broken)
	check(#shown == 2, "a failing tip shows nothing")
	H.noErrors(T, "tooltips")
end)

H.section("settings: switches, scale limits and the minimap hint", function()
	local T = H.load(nil, H.checked())
	H.slash("settings")
	local ui = T.modules.settings.ui
	check(ui.dock.label.raw == "Turn off" and ui.merchantBar.label.raw == "Turn on", "each switch says what a click does")
	check(ui.dock.state.raw == "On" and ui.merchantBar.state.raw == "Off" and Stub.sees("On"),
		"and shows its state beside it")
	T.Window:SetScale(T.SCALE_MIN)
	T.modules.settings:Refresh()
	check(not ui.minus:IsEnabled() and ui.plus:IsEnabled(), "at the smallest size minus is off")
	T.Window:SetScale(T.SCALE_MAX)
	T.modules.settings:Refresh()
	check(ui.minus:IsEnabled() and not ui.plus:IsEnabled(), "at the largest size plus is off")
	T.Window:SetScale(1)
	T.modules.settings:Refresh()

	check(T.db.minimap.show == true, "the minimap button starts shown")
	local chat = #Stub.chat
	ui.minimap.scripts.OnClick(ui.minimap)
	check(T.db.minimap.show == false and ui.minimap.label.raw == "Turn on", "switched off")
	local said = false
	for index = chat + 1, #Stub.chat do
		said = said or Stub.chat[index]:find("/th", 1, true) ~= nil
	end
	check(said, "switching it off says how to open Trailhead without it")
	chat = #Stub.chat
	ui.minimap.scripts.OnClick(ui.minimap)
	check(T.db.minimap.show == true and #Stub.chat == chat, "switching it on says nothing")

	Stub.click("Help and data")
	check(Stub.sees("For bug reports"), "the game check is labelled for bug reports")
	H.noErrors(T, "settings switches")
end)

H.section("settings: Forget all does not stay armed", function()
	local T = H.load(nil, H.checked())
	Stub.fire("MERCHANT_SHOW")
	H.slash("settings")
	Stub.click("Help and data")
	check(T.Places.Count() == 1, "one place is known")

	Stub.click("Forget all")
	check(Stub.sees("Really forget?"), "the first click asks")
	Stub.click("Window")
	Stub.click("Help and data")
	check(Stub.sees("Forget all") and not Stub.sees("Really forget?"), "changing section takes the question back")

	Stub.click("Forget all")
	T.Window:Select("home")
	T.Window:Select("settings")
	check(Stub.sees("Forget all"), "leaving the page takes it back")

	Stub.click("Forget all")
	Stub.flush() -- the few seconds pass
	check(Stub.sees("Forget all") and T.Places.Count() == 1, "it lapses on its own")
	Stub.click("Forget all")
	Stub.click("Really forget?")
	check(T.Places.Count() == 0, "two clicks in a row still forget")
	H.noErrors(T, "forget all")
end)

H.section("setup: the Classic preset gets a word about Enhanced", function()
	local T = H.load(nil, H.checked())
	local advice = "You play with the Classic preset. Enhanced turns on quest markers on the map and a single bag. The Set to Enhanced button in this menu switches."
	check(T.Setup.Preset() == nil and T.Setup.PresetAdvice() == nil, "an unreadable preset says nothing")
	EXPERIENCE_PRESET_CLASSIC, EXPERIENCE_PRESET_ENHANCED = "Classic", "Enhanced"
	SET_PRESET_OPTION_BUTTON_ENHANCED_LABEL = "Set to Enhanced"
	C_GameRules.GetForeverExperiencePreset = function() return 0 end
	check(T.Setup.Preset() == "classic" and T.Setup.PresetAdvice() == advice, "Classic is read and explained")
	H.slash("")
	T.Window:Select("setup")
	Stub.flush()
	check(Stub.sees(advice), "the page shows it")
	C_GameRules.GetForeverExperiencePreset = function() return 1 end
	T.Window:Select("setup")
	check(T.Setup.Preset() == "enhanced" and not Stub.sees(advice), "Enhanced players are not told")
	C_GameRules.GetForeverExperiencePreset = function() return Stub.SECRET end
	check(T.Setup.Preset() == nil, "a secret value is not read")
	EXPERIENCE_PRESET_CLASSIC, EXPERIENCE_PRESET_ENHANCED, SET_PRESET_OPTION_BUTTON_ENHANCED_LABEL = nil, nil, nil
	H.noErrors(T, "preset")
end)

H.section("theme: faint text stays readable", function()
	local T = H.load(nil, H.checked())
	local function lin(c)
		return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
	end
	local function lum(c)
		return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3])
	end
	local function over(top, under)
		local a = top[4] or 1
		return { top[1] * a + under[1] * (1 - a), top[2] * a + under[2] * (1 - a), top[3] * a + under[3] * (1 - a) }
	end
	local function contrast(a, b)
		local x, y = lum(a), lum(b)
		if x < y then
			x, y = y, x
		end
		return (x + 0.05) / (y + 0.05)
	end
	for _, id in ipairs(T.Theme.order) do
		local c = T.Theme.defs[id].c
		local card = over(c.card, c.page)
		for _, back in ipairs({ { "page", c.page }, { "card", card } }) do
			local faint, muted = contrast(c.faint, back[2]), contrast(c.muted, back[2])
			check(faint >= 4.5, ("%s: faint on the %s reads at %.2f:1"):format(id, back[1], faint))
			check(muted > faint, ("%s: muted stands out more than faint on the %s"):format(id, back[1]))
		end
	end
end)
