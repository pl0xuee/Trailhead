local _, T = ...
local L = T.L
local W = T.Widgets
local C = T.Compat

-- Legacy: Forever's own account-wide progression. Challenges earn Legacy Points; each
-- character spends points on perks in three trees; the points also unlock cosmetic rewards.
-- This page shows the player's points (read live, through Compat) and explains the rest.
-- What is written here was checked in the game's own tables and two or more written sources
-- (Blizzard's launch article and the Warcraft wiki). Numbers they do not agree on are left out.

local Legacy = T:NewModule("legacy", { label = L["Legacy"], icon = "shield", order = 6 })
T.Legacy = Legacy

local PAGE_W = 778

local TREES = {
	{
		L["Professions"],
		{
			L["Dedicated Study: raises your lowest profession"],
			L["Bartering: cheaper prices at vendors"],
			L["Master Chef: cooking can make an extra dish"],
			L["Working Overtime: skill rises faster"],
			L["Bountiful Harvest: more rare materials"],
			L["Performance Bonus: better crate hand-ins"],
			L["Luremaster: extra fish with a lure"],
		},
	},
	{
		L["Adventure"],
		{
			L["Thrill of Adventure: health and mana on kills"],
			L["Talented: talent points start before level 10"],
			L["Frequent Flier: cheaper, faster flights"],
			L["Well Rested: rested experience builds faster"],
			L["Field Medicine: shorter bandage wait"],
			L["Field Guide: camp features come back sooner"],
			L["High Alert: notice hidden enemies sooner"],
		},
	},
	{
		L["Resourcefulness"],
		{
			L["Reagent Economy: no reagents to buy"],
			L["Gourmand: food effects last longer"],
			L["Diplomat: reputation grows faster"],
			L["The Quick and the Dead: faster as a ghost"],
			L["Permanence: long buffs last longer"],
			L["Reinforce: less gear wear when you die"],
			L["For Great Honor: more honor"],
		},
	},
}

local ui = {}

-- ---------------------------------------------------------------------------
-- Reading the game

-- { known = false } when the game cannot say (no API, or the system is not available yet);
-- otherwise { known = true, earned = points earned on the account, ready = points this
-- character can still spend, cap = how many it may spend in total (nil if unread) }.
function Legacy.Read()
	local consts = C.Resolve("Constants.LegacyConsts")
	if type(consts) ~= "table" then
		return { known = false }
	end
	local factionID, treeID = consts.LEGACY_REWARD_TRACK_FACTION_ID, consts.LEGACY_TREE_PROFESSIONS_ID
	local earned = C.Plain(C.Call("C_MajorFactions.GetCurrentRenownLevel", factionID), nil)
	if type(earned) ~= "number" then
		return { known = false }
	end
	local out = { known = true, earned = earned }
	local configID = C.Call("C_Traits.GetConfigIDByTreeID", treeID)
	if configID then
		local list = C.Call("C_Traits.GetTreeCurrencyInfo", configID, treeID, false)
		local info = type(list) == "table" and list[1] or nil
		if type(info) == "table" then
			local ready, cap = C.Plain(info.quantity, nil), C.Plain(info.maxQuantity, nil)
			out.ready = type(ready) == "number" and ready or nil
			out.cap = type(cap) == "number" and cap or nil
		end
	end
	return out
end

local function open(path)
	return function()
		if not C.InCombat() then
			T.Window:Keep(path)
		end
	end
end

-- ---------------------------------------------------------------------------
-- The page

local function card(page, x, y, w, h)
	local panel = W.Panel(page, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	panel:SetSize(w, h)
	panel:SetPoint("TOPLEFT", page, "TOPLEFT", x, -y)
	return panel
end

function Legacy:Build(page)
	local title = W.Text(page, "head", 20, "ink")
	title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	title:SetLabel(L["Legacy"])
	local sub = W.Text(page, "body", 11.5, "muted", { width = 640 })
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	sub:SetLabel(L["Forever's own progress for your whole account. Earn points, spend them on perks."])

	-- Your points.
	local mine = card(page, 0, 56, PAGE_W, 84)
	ui.mine = mine
	ui.pointsHead = W.Text(mine, "head", 15, "ink")
	ui.pointsHead:SetPoint("TOPLEFT", mine, "TOPLEFT", 18, -14)
	ui.pointsBody = W.Text(mine, "body", 11.5, "muted", { width = 500 })
	ui.pointsBody:SetPoint("TOPLEFT", ui.pointsHead, "BOTTOMLEFT", 0, -6)
	ui.pointsBody:SetSpacing(3)
	ui.window = W.Button(mine, L["Open Legacy window"], "primary", {
		height = 28, size = 11.5, width = 190, onClick = open("ToggleLegacySystemUI"),
	})
	ui.window:SetPoint("TOPRIGHT", mine, "TOPRIGHT", -16, -14)
	ui.challenges = W.Button(mine, L["Open challenges"], "ghost", {
		role = "accentText", height = 28, size = 11.5, width = 190, onClick = open("ToggleLegacyChallenges"),
	})
	ui.challenges:SetPoint("TOPRIGHT", ui.window, "BOTTOMRIGHT", 0, -8)

	-- What earns a point.
	local earn = card(page, 0, 152, 382, 118)
	local earnHead = W.Text(earn, "head", 14, "ink")
	earnHead:SetPoint("TOPLEFT", earn, "TOPLEFT", 16, -12)
	earnHead:SetLabel(L["What earns a point"])
	local earnBody = W.Text(earn, "body", 11, "muted", { width = 350 })
	earnBody:SetPoint("TOPLEFT", earnHead, "BOTTOMLEFT", 0, -6)
	earnBody:SetSpacing(3)
	earnBody:SetLabel(L["Finish Legacy Challenges. Each one is worth one point, shared by every character on your account. There are 65 at launch: Classes 27, Professions 18, PvP 12, Dungeons 3, Raids 3, Adventure 2."])

	-- What the points unlock.
	local unlock = card(page, 396, 152, 382, 118)
	local unlockHead = W.Text(unlock, "head", 14, "ink")
	unlockHead:SetPoint("TOPLEFT", unlock, "TOPLEFT", 16, -12)
	unlockHead:SetLabel(L["What points unlock"])
	local unlockBody = W.Text(unlock, "body", 11, "muted", { width = 350 })
	unlockBody:SetPoint("TOPLEFT", unlockHead, "BOTTOMLEFT", 0, -6)
	unlockBody:SetSpacing(3)
	unlockBody:SetLabel(L["Perks in three trees, spent by each character on its own, up to 16 points at launch. Your total also unlocks rewards: a toy, a bear cub, a tabard and a bear mount."])

	-- The three trees.
	for index, tree in ipairs(TREES) do
		local x = (index - 1) * (250 + 14)
		local box = card(page, x, 282, 250, 214)
		local head = W.Text(box, "head", 14, "accentText")
		head:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -12)
		head:SetLabel(tree[1])
		local list = W.Text(box, "body", 10.5, "muted", { width = 224 })
		list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -8)
		list:SetSpacing(5)
		list:SetLabel(table.concat(tree[2], "\n"))
	end

	T:On("TRAIT_TREE_CURRENCY_INFO_UPDATED", function()
		if page:IsVisible() then
			Legacy:Refresh()
		end
	end)
	T:On("ACHIEVEMENT_EARNED", function()
		if page:IsVisible() then
			Legacy:Refresh()
		end
	end)
	self.built = true
end

function Legacy:Refresh()
	if not self.built then
		return
	end
	local read = Legacy.Read()
	if not read.known then
		ui.pointsHead:SetLabel(L["Your Legacy Points"])
		ui.pointsBody:SetLabel(L["Trailhead cannot read your points here. Open the Legacy window to see them. It unlocks with your first point, usually when a character reaches level 25."])
	elseif read.earned <= 0 then
		ui.pointsHead:SetLabel(L["No Legacy Points yet"])
		ui.pointsBody:SetLabel(L["The first one usually comes when a character reaches level 25. Reaching 150 skill in a crafting profession or exploring the whole world map also counts."])
	else
		ui.pointsHead:SetLabel(read.earned == 1 and L["1 Legacy Point earned"] or L["%d Legacy Points earned"]:format(read.earned))
		if read.ready then
			local text = read.ready == 1 and L["1 point ready to spend on this character."] or L["%d points ready to spend on this character."]:format(read.ready)
			if read.cap then
				text = text .. "\n" .. L["This character can spend up to %d in total."]:format(read.cap)
			end
			ui.pointsBody:SetLabel(text)
		else
			ui.pointsBody:SetLabel(L["Open the Legacy window to spend them."])
		end
	end
	ui.window:SetEnabled(C.Has("ToggleLegacySystemUI"))
	ui.challenges:SetEnabled(C.Has("ToggleLegacyChallenges"))
end
