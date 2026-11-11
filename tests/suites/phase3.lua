local H = ...
local Stub, check = H.Stub, H.check

-- Phase 3: first run welcome, vendor buttons, the Legacy page, and their settings.

local function sawChat(text)
	for _, line in ipairs(Stub.chat) do
		if line:find(text, 1, true) then
			return true
		end
	end
	return false
end

-- Replaces globals for one section and puts them back afterwards.
local function with(replacements, fn)
	local before = {}
	for name, value in pairs(replacements) do
		before[name] = _G[name]
		_G[name] = value
	end
	local ok, err = pcall(fn)
	for name, old in pairs(before) do
		_G[name] = old
	end
	if not ok then
		error(err, 0)
	end
end

H.section("phase 3: first-run welcome", function()
	local T = H.load()
	check(T.db.welcomeDone == false, "the welcome has not been seen on a new account")
	check(TrailheadWelcome == nil, "nothing is built before the window opens")
	H.slash("")
	check(TrailheadWelcome ~= nil and TrailheadWelcome:IsShown(), "the first time the window opens it shows the welcome")
	check(Stub.sees("Welcome to Trailhead"), "the welcome is readable")
	check(T.Window.current == "home", "the page underneath is still Home")
	check(T.db.welcomeDone == false, "it stays unseen until it is closed")
	Stub.click("Journal")
	check(T.Theme.current.id == "journal" and T.db.theme == "journal", "the look picker works")
	T.Theme:Set("night")
	Stub.click("Skip")
	check(T.db.welcomeDone == true and not TrailheadWelcome:IsShown(), "skip closes it and remembers")
	H.slash("")
	H.slash("")
	check(not TrailheadWelcome:IsShown(), "it does not come back on the next opening")

	H.slash("settings")
	Stub.click("Help and data")
	Stub.click("Show welcome")
	check(TrailheadWelcome:IsShown(), "Settings reopens the welcome")
	Stub.click("Find it")
	check(T.Window.current == "find" and not TrailheadWelcome:IsShown(), "a door button closes it and opens that page")

	H.noErrors(T, "welcome")

	T = H.load(nil, { welcomeDone = true, firstRun = false })
	H.slash("")
	check(TrailheadWelcome == nil, "an account that has seen it never builds it")
	Stub.world.combat = nil
	Stub.combat = true
	check(T.Welcome.Show() == false, "it will not open in combat")
	Stub.combat = false
end)

H.section("phase 3: vendor buttons", function()
	local T = H.load()
	H.check(T.db.merchantBar == false, "the extra buttons are off by default: the game has its own")
	T.db.merchantBar = true
	local calls = { use = 0, all = 0, repair = 0 }
	local bag = {
		{ itemID = 1, stackCount = 2, quality = 0, hasNoValue = false },
		{ itemID = 2, stackCount = 1, quality = 0, hasNoValue = false },
		{ itemID = 3, stackCount = 1, quality = 1, hasNoValue = false },
		{ itemID = 4, stackCount = 1, quality = 0, hasNoValue = true },
	}
	local prices = { [1] = 25, [2] = 55, [3] = 900 }
	local cost, junkAll = 340, false
	local replacements = {
		RepairAllItems = function() calls.repair = calls.repair + 1 end,
		GetRepairAllCost = function() return cost, cost > 0 end,
		CanMerchantRepair = function() return true end,
	}
	local container, item, merchant = {}, {}, {}
	for key, value in pairs(_G.C_Container) do container[key] = value end
	for key, value in pairs(_G.C_Item) do item[key] = value end
	container.GetContainerNumSlots = function(b) return b == 0 and #bag or 0 end
	container.GetContainerItemInfo = function(b, slot) return b == 0 and bag[slot] or nil end
	container.UseContainerItem = function() calls.use = calls.use + 1 end
	item.GetItemInfo = function(id)
		return "Thing", "link", 0, 1, 1, "Misc", "Junk", 1, "", 1, prices[id]
	end
	merchant.IsSellAllJunkEnabled = function() return junkAll end
	merchant.SellAllJunkItems = function() calls.all = calls.all + 1 end
	replacements.C_Container, replacements.C_Item, replacements.C_MerchantFrame = container, item, merchant

	with(replacements, function()
		check(T.db.autoSellJunk == false and T.db.autoRepair == false, "the automatic options are off by default")
		check(T.db.merchantBar == true, "the buttons are switched on for this test")
		check(TrailheadMerchantBar == nil or not TrailheadMerchantBar:IsShown(), "no buttons away from a vendor")
		local junk = T.Merchant.Junk()
		check(junk.count == 3 and junk.value == 105 and #junk.slots == 2, "junk counts grey items with value, not white ones")
		check(T.Merchant.SellJunk() == 0 and calls.use == 0, "selling does nothing without a vendor window")

		Stub.fire("MERCHANT_SHOW")
		check(TrailheadMerchantBar ~= nil and TrailheadMerchantBar:IsShown(), "buttons appear at a vendor")
		check(Stub.sees("Sell 3 junk: 1s 5c"), "the sell button shows the amount first")
		check(Stub.sees("Repair all: 3s 40c"), "the repair button shows the cost first")
		check(calls.use == 0 and calls.repair == 0, "nothing happens by itself")
		Stub.flush()
		check(calls.use == 0 and calls.repair == 0, "not even after the window has filled")

		Stub.click("Sell 3 junk: 1s 5c")
		check(calls.use == 2 and calls.all == 0, "one click uses each grey stack once")
		check(sawChat("Sold 3 grey items for 1s 5c."), "one chat line says what was sold")
		Stub.click("Repair all: 3s 40c")
		check(calls.repair == 1, "one click repairs once")
		check(sawChat("Repaired all your gear for 3s 40c."), "one chat line says what was repaired")

		-- The game's own sell-all call is used when the game offers it.
		junkAll = true
		calls.use = 0
		check(T.Merchant.SellJunk() == 3 and calls.all == 1 and calls.use == 0, "the game's sell-all is called once when enabled")
		junkAll = false

		-- Combat.
		Stub.combat = true
		calls.use, calls.repair = 0, 0
		check(T.Merchant.SellJunk() == 0 and T.Merchant.Repair() == 0 and calls.use == 0 and calls.repair == 0,
			"nothing is sold or repaired in combat")
		Stub.fire("PLAYER_REGEN_DISABLED")
		check(not TrailheadMerchantBar:IsShown(), "the buttons hide when a fight starts")
		Stub.combat = false
		Stub.fire("PLAYER_REGEN_ENABLED")
		check(TrailheadMerchantBar:IsShown(), "and come back afterwards")

		-- Too poor to repair.
		Stub.world.money = 100
		check(T.Merchant.Repair() == 0 and calls.repair == 0, "no repair when the player cannot pay")
		Stub.world.money = nil

		-- Nothing to do: no strip.
		bag = {}
		cost = 0
		Stub.fire("BAG_UPDATE_DELAYED")
		check(not TrailheadMerchantBar:IsShown(), "no buttons when there is nothing to sell or repair")
		bag = { { itemID = 1, stackCount = 2, quality = 0, hasNoValue = false } }
		cost = 340
		Stub.fire("BAG_UPDATE_DELAYED")
		check(TrailheadMerchantBar:IsShown(), "they return when there is")
		Stub.fire("MERCHANT_CLOSED")
		check(not TrailheadMerchantBar:IsShown(), "closing the vendor hides them")

		-- The switch.
		T.db.merchantBar = false
		Stub.fire("MERCHANT_SHOW")
		check(not TrailheadMerchantBar:IsShown(), "the setting hides the buttons")
		Stub.fire("MERCHANT_CLOSED")
		T.db.merchantBar = true

		-- Automatic: only when the player turned it on.
		calls.use, calls.repair = 0, 0
		Stub.fire("MERCHANT_SHOW")
		Stub.flush()
		check(calls.use == 0 and calls.repair == 0, "off means off")
		Stub.fire("MERCHANT_CLOSED")
		T.db.autoSellJunk, T.db.autoRepair = true, true
		Stub.fire("MERCHANT_SHOW")
		Stub.flush()
		check(calls.use == 1 and calls.repair == 1, "turned on, each happens once at the vendor")
		Stub.fire("MERCHANT_CLOSED")
		Stub.combat = true
		calls.use, calls.repair = 0, 0
		Stub.fire("MERCHANT_SHOW")
		Stub.flush()
		check(calls.use == 0 and calls.repair == 0, "even turned on, nothing happens in combat")
		Stub.combat = false
		Stub.fire("MERCHANT_CLOSED")
	end)
	H.noErrors(T, "vendor buttons")

	-- A game without these calls: no errors, no buttons.
	T = H.load({ bare = true })
	Stub.fire("MERCHANT_SHOW")
	Stub.flush()
	check(TrailheadMerchantBar == nil or not TrailheadMerchantBar:IsShown(), "bare game: no buttons")
	H.noErrors(T, "vendor buttons on a bare client")
end)

H.section("phase 3: Legacy page", function()
	local T = H.load()
	check(T.modules.legacy and T.modules.legacy.tab and T.modules.legacy.tab.label == "Legacy", "Legacy has a tab")
	local toggles = 0
	local read = {
		Constants = { LegacyConsts = { LEGACY_REWARD_TRACK_FACTION_ID = 2802, LEGACY_TREE_PROFESSIONS_ID = 1187 } },
		C_MajorFactions = { GetCurrentRenownLevel = function() return 7 end },
		C_Traits = { GetConfigIDByTreeID = function() return 5 end,
			GetTreeCurrencyInfo = function() return { { quantity = 3, maxQuantity = 16 } } end },
		ToggleLegacySystemUI = function() toggles = toggles + 1 end,
		ToggleLegacyChallenges = function() toggles = toggles + 10 end,
	}
	with(read, function()
		local got = T.Legacy.Read()
		check(got.known and got.earned == 7 and got.ready == 3 and got.cap == 16, "points are read through the game's own calls")
		H.slash("")
		Stub.click("Skip")
		T.Window:Select("legacy")
		check(Stub.sees("7 Legacy Points earned"), "earned points shown")
		check(Stub.hasText("3 points ready to spend on this character.\nThis character can spend up to 16 in total."), "points to spend and the cap shown")
		check(Stub.sees("What earns a point"), "what earns the next point is explained")
		local perks = false
		for _, text in ipairs(Stub.fontstrings) do
			perks = perks or (text.text or ""):find("Bartering: cheaper prices at vendors", 1, true) ~= nil
		end
		check(perks, "the perks are listed")
		Stub.click("Open Legacy window")
		check(toggles == 1, "the button opens the game's Legacy window once")
		Stub.click("Open challenges")
		check(toggles == 11, "and the challenges once")
		_G.C_MajorFactions = { GetCurrentRenownLevel = function() return 0 end }
		T.Window:Select("home")
		T.Window:Select("legacy")
		check(Stub.sees("No Legacy Points yet"), "zero points says how to get the first")
	end)
	H.noErrors(T, "legacy")

	-- Without the APIs the page explains instead.
	T = H.load({ bare = true })
	with({ Constants = false }, function()
		check(T.Legacy.Read().known == false, "no constants: not known")
		H.slash("")
		Stub.click("Skip")
		T.Window:Select("legacy")
		check(Stub.sees("Your Legacy Points"), "the page still reads")
		check(Stub.sees("What earns a point"), "and still explains")
	end)
	H.noErrors(T, "legacy without apis")
end)

H.section("phase 3: settings persist", function()
	local T = H.load()
	H.slash("settings")
	Stub.click("Skip")
	Stub.click("At vendors")
	Stub.click("Off", 1)
	check(T.db.merchantBar == true and TrailheadDB.merchantBar == true, "the extra vendor buttons can be switched on and are saved")
	Stub.click("Off", 1)
	check(T.db.autoSellJunk == true and TrailheadDB.autoSellJunk == true, "automatic selling can be switched on and is saved")
	Stub.click("Off", 1)
	check(T.db.autoRepair == true, "automatic repair can be switched on")
	check(T.db.autoSellJunk == true, "the first stays on")

	T = H.load(nil, { welcomeDone = true, firstRun = false, autoSellJunk = true, autoRepair = false, merchantBar = false })
	check(T.db.autoSellJunk == true and T.db.autoRepair == false and T.db.merchantBar == false, "saved choices survive a reload")
	H.noErrors(T, "settings")
end)
