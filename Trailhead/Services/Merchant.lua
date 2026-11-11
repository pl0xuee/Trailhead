local _, T = ...
local L = T.L
local C = T.Compat
local G = T.Game

-- Merchant: while a vendor window is open, two clearly labelled buttons beside it: sell the
-- grey junk and repair all gear, each with its amount shown first. Nothing happens by itself
-- unless the player switched on "sell junk automatically" or "repair automatically" in
-- Settings. Every game call goes through Compat and nothing runs in combat.

local M = {}
T.Merchant = M

M.open = false -- a vendor window is open right now
local bar -- the button strip, built the first time it is needed

-- ---------------------------------------------------------------------------
-- Reading the game

local POOR = 0 -- grey quality

local function poorQuality()
	local quality = C.Resolve("Enum.ItemQuality")
	return type(quality) == "table" and quality.Poor or POOR
end

-- Grey items in the bags: { count, value (copper, what the game reports), partial (true when
-- some prices were not known yet, so value is "at least"), slots = { {bag, slot}, ... } }
function M.Junk()
	local out = { count = 0, value = 0, partial = false, slots = {} }
	local poor = poorQuality()
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		local size = C.Plain(C.Call("C_Container.GetContainerNumSlots", bag), 0) or 0
		for slot = 1, size do
			local info = C.Call("C_Container.GetContainerItemInfo", bag, slot)
			if type(info) == "table" and C.Plain(info.quality, nil) == poor
				and C.Plain(info.hasNoValue, false) ~= true and C.Plain(info.isLocked, false) ~= true then
				local stack = C.Plain(info.stackCount, 1) or 1
				local price = select(11, C.Call("C_Item.GetItemInfo", C.Plain(info.itemID, 0)))
				out.count = out.count + stack
				if type(price) == "number" then
					out.value = out.value + price * stack
				else
					out.partial = true
				end
				out.slots[#out.slots + 1] = { bag, slot }
			end
		end
	end
	return out
end

-- What repairing everything costs: { cost, can } with can true only when something is
-- damaged and this vendor repairs.
function M.RepairInfo()
	if C.Plain(C.Call("CanMerchantRepair"), false) ~= true then
		return { cost = 0, can = false }
	end
	local cost, can = C.Call("GetRepairAllCost")
	cost = C.Plain(cost, 0)
	if type(cost) ~= "number" then
		cost = 0
	end
	return { cost = cost, can = C.Plain(can, false) == true and cost > 0 }
end

-- ---------------------------------------------------------------------------
-- Doing it (only ever from a click, or from the automatic options)

local function say(text)
	T:Print(text)
end

-- Sells the grey items. Returns how many were sold.
function M.SellJunk()
	if not M.open or C.InCombat() then
		return 0
	end
	local junk = M.Junk()
	if junk.count == 0 then
		return 0
	end
	if C.Call("C_MerchantFrame.IsSellAllJunkEnabled") == true and C.Has("C_MerchantFrame.SellAllJunkItems") then
		C.Call("C_MerchantFrame.SellAllJunkItems")
	elseif C.Has("C_Container.UseContainerItem") then
		-- Using an item while a vendor window is open sells it.
		for _, place in ipairs(junk.slots) do
			C.Call("C_Container.UseContainerItem", place[1], place[2])
		end
	else
		return 0
	end
	if junk.partial then
		say(L["Sold %d grey items."]:format(junk.count))
	else
		say(L["Sold %d grey items for %s."]:format(junk.count, G.MoneyText(junk.value)))
	end
	return junk.count
end

-- Repairs all gear. Returns what it cost, or 0 when nothing was done.
function M.Repair()
	if not M.open or C.InCombat() then
		return 0
	end
	local info = M.RepairInfo()
	local money = G.Money()
	if not info.can or not C.Has("RepairAllItems") or (money and money < info.cost) then
		return 0
	end
	C.Call("RepairAllItems")
	say(L["Repaired all your gear for %s."]:format(G.MoneyText(info.cost)))
	return info.cost
end

-- ---------------------------------------------------------------------------
-- The button strip

local function edges(target)
	local left, bottom = C.Plain(target:GetLeft(), nil), C.Plain(target:GetBottom(), nil)
	local own, screen = C.Plain(target:GetEffectiveScale(), nil), C.Plain(UIParent:GetEffectiveScale(), nil)
	if type(left) ~= "number" or type(bottom) ~= "number" or type(own) ~= "number"
		or type(screen) ~= "number" or screen <= 0 then
		return nil
	end
	local ratio = own / screen
	return left * ratio, bottom * ratio
end

local function place()
	bar:ClearAllPoints()
	local target = _G.MerchantFrame
	local left, bottom
	if type(target) == "table" and type(target.GetLeft) == "function" then
		left, bottom = edges(target)
	end
	if left then
		-- Just under the game's vendor window, placed from its measured edge, never anchored to it.
		bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, math.max(bottom - 6, 90))
	else
		bar:SetPoint("CENTER", UIParent, "CENTER", 0, -260)
	end
end

local function build()
	local W = T.Widgets
	bar = W.Panel(UIParent, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" }, "Frame", "TrailheadMerchantBar")
	bar:Hide()
	bar:SetSize(384, 84)
	bar:SetFrameStrata("HIGH")
	bar:EnableMouse(true)
	bar.title = W.Text(bar, "label", 9, "accentText")
	bar.title:SetPoint("TOPLEFT", bar, "TOPLEFT", 14, -10)
	bar.title:SetLabel(L["Trailhead at this vendor"])
	bar.sell = W.Button(bar, L["Sell junk"], "ghost", {
		role = "accentText", height = 30, size = 11, width = 178,
		onClick = function()
			M.SellJunk()
			M.Refresh()
		end,
	})
	bar.sell:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 12, 12)
	bar.repair = W.Button(bar, L["Repair all"], "ghost", {
		role = "accentText", height = 30, size = 11, width = 178,
		onClick = function()
			M.Repair()
			M.Refresh()
		end,
	})
	bar.repair:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -12, 12)
	bar.note = W.Text(bar, "body", 10, "muted", { width = 354 })
	bar.note:SetPoint("TOPLEFT", bar, "TOPLEFT", 14, -26)
end

-- Shows or hides the strip and fills in the amounts.
function M.Refresh()
	local wanted = M.open and T.db and T.db.merchantBar == true and not C.InCombat()
	local junk, repair
	if wanted then
		junk, repair = M.Junk(), M.RepairInfo()
		wanted = junk.count > 0 or repair.can
	end
	if not wanted then
		if bar then
			bar:Hide()
		end
		return
	end
	if not bar then
		build()
	end
	local sellLabel = L["Sell junk"]
	if junk.count > 0 then
		sellLabel = junk.partial and L["Sell %d junk"]:format(junk.count)
			or L["Sell %d junk: %s"]:format(junk.count, G.MoneyText(junk.value))
	end
	bar.sell:SetLabel(sellLabel)
	bar.sell:SetEnabled(junk.count > 0)
	local money = G.Money()
	local repairLabel = repair.can and L["Repair all: %s"]:format(G.MoneyText(repair.cost)) or L["Repair all"]
	bar.repair:SetLabel(repairLabel)
	bar.repair:SetEnabled(repair.can and (not money or money >= repair.cost))
	bar.note:SetLabel(junk.count > 0 and L["Grey items are junk. Selling them is safe."] or L["Nothing to sell right now."])
	place()
	bar:Show()
end

-- ---------------------------------------------------------------------------
-- Events

T:On("MERCHANT_SHOW", function()
	M.open = true
	M.Refresh()
	-- The automatic options run a moment later, after the game has filled the window.
	C.Call("C_Timer.After", 0.3, function()
		if not M.open or C.InCombat() then
			return
		end
		if T.db.autoSellJunk == true then
			M.SellJunk()
		end
		if T.db.autoRepair == true then
			M.Repair()
		end
		M.Refresh()
	end)
end)

T:On("MERCHANT_CLOSED", function()
	M.open = false
	M.Refresh()
end)

for _, event in ipairs({ "BAG_UPDATE_DELAYED", "MERCHANT_UPDATE", "PLAYER_MONEY", "UPDATE_INVENTORY_DURABILITY", "PLAYER_REGEN_ENABLED" }) do
	T:On(event, function()
		if M.open then
			M.Refresh()
		end
	end)
end

T:On("PLAYER_REGEN_DISABLED", function()
	if bar then
		bar:Hide()
	end
end)
