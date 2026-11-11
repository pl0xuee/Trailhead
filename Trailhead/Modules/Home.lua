local _, T = ...
local L = T.L
local W = T.Widgets
local Theme = T.Theme
local C = T.Compat
local G = T.Game

-- Home: who you are and where you stand (the banner), what to do next (the cards the
-- Advisor picks), shortcuts to the things you look for most, and the next big milestone.

local Home = T:NewModule("home", { label = L["Home"], icon = "home", order = 1 })

local HERO_W, HERO_H = 778, 132 -- must match tools/gen_media.py
local LEFT_W, RIGHT_W, GAP = 510, 250, 18
local CARD_H, CARD_GAP, CARDS = 76, 10, 3
local TILE_H, TILE_GAP = 50, 8
local TIP_H = 50

local TIPS = {
	L["Logging out inside an inn or a capital city builds rested experience, which gives extra experience from kills."],
	L["Class trainers teach new spells and new ranks of old ones. Visit yours every couple of levels."],
	L["Your first talent point arrives at level 10."],
	L["Set your hearthstone at an innkeeper close to where you are questing. It saves a lot of walking."],
	L["Grey items are junk and safe to sell to any vendor. Bags fill up fast, so sell often."],
	L["Flight masters connect the towns you have already visited."],
	L["You can learn to ride at level 40. It is expensive, so start saving gold early."],
	L["Dungeons need a group of five and you travel to the entrance yourselves."],
	L["Lost in a city? Ask a guard. Trailhead remembers the directions for next time."],
	L["Every trainer, vendor and mailbox you use is remembered. Find it again from the Find it tab."],
}

local ui = {}

local function placeText()
	local zone = C.Plain(GetRealZoneText and GetRealZoneText(), "") or ""
	local sub = C.Plain(GetSubZoneText and GetSubZoneText(), "") or ""
	local text = zone
	if sub ~= "" and sub ~= zone then
		text = sub .. ", " .. zone
	end
	local here = G.CurrentZone()
	if here and here.lo then
		text = text .. "  \194\183  " .. L["levels %d-%d"]:format(here.lo, here.hi)
	end
	return text
end

-- ---------------------------------------------------------------------------

local function buildHero(page)
	local hero = W.Panel(page)
	hero:SetSize(HERO_W, HERO_H)
	hero:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	hero:SetStyle({ shape = "hero", line = "heroLine" })

	-- The landscape: one painted texture per theme, corners already rounded to match.
	local art = hero:CreateTexture(nil, "BACKGROUND", nil, -7)
	art:SetAllPoints(hero)
	art.Restyle = function(self)
		self:SetTexture(Theme.current.hero)
	end
	Theme:Track(art)
	art:Restyle()

	-- Level badge.
	local disc = W.Tint(hero, "circle-fill", "ring", "ARTWORK", 0)
	disc:SetSize(60, 60)
	disc:SetPoint("LEFT", hero, "LEFT", 25, 5)
	local ring = W.Tint(hero, "ring", "ringLine", "ARTWORK", 1)
	ring:SetSize(68, 68)
	ring:SetPoint("CENTER", disc, "CENTER", 0, 0)
	ui.level = W.Text(hero, "head", 25, "heroText", { shadow = true })
	ui.level:SetPoint("CENTER", disc, "CENTER", 0, 1)
	ui.level:SetJustifyH("CENTER")

	local badge = W.Panel(hero, { shape = "small", fill = "accent" })
	badge:SetHeight(16)
	badge:SetPoint("CENTER", disc, "BOTTOM", 0, -3)
	ui.class = W.Text(badge, "label", 8.5, "accentInk")
	ui.class:SetPoint("CENTER", badge, "CENTER", 0, 0)
	ui.classBadge = badge
	badge.AfterRestyle = function(self)
		self:SetWidth(math.max(ui.class:GetStringWidth() + 14, 36))
	end

	-- Name, place, experience.
	ui.name = W.Text(hero, "head", 23, "heroText", { shadow = true })
	ui.name:SetPoint("TOPLEFT", hero, "TOPLEFT", 108, -22)
	local pin = W.Icon(hero, "pin", 13, "heroMuted")
	pin:SetPoint("TOPLEFT", hero, "TOPLEFT", 108, -53)
	ui.place = W.Text(hero, "body", 12, "heroMuted", { shadow = true })
	ui.place:SetPoint("LEFT", pin, "RIGHT", 5, 0)

	ui.xp = W.Bar(hero, 330, 8, "xp", "rest")
	ui.xp:SetPoint("TOPLEFT", hero, "TOPLEFT", 108, -79)
	ui.xpText = W.Text(hero, "body", 10.5, "heroMuted", { shadow = true })
	ui.xpText:SetPoint("TOPLEFT", ui.xp, "BOTTOMLEFT", 0, -7)
	ui.restText = W.Text(hero, "body", 10.5, "heroMuted", { shadow = true })
	ui.restText:SetPoint("TOPRIGHT", ui.xp, "BOTTOMRIGHT", 0, -7)
	ui.restText:SetJustifyH("RIGHT")

	-- Gold, home, bags.
	ui.gold = W.Chip(hero, "coin")
	ui.gold:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -16, -24)
	ui.bind = W.Chip(hero, "bed")
	ui.bind:SetPoint("TOPRIGHT", ui.gold, "BOTTOMRIGHT", 0, -6)
	ui.bags = W.Chip(hero, "bag")
	ui.bags:SetPoint("TOPRIGHT", ui.bind, "BOTTOMRIGHT", 0, -6)
	return hero
end

-- ---------------------------------------------------------------------------
-- "What now?": up to three cards from the Advisor.

local function fillCard(card, advice)
	card.advice = advice
	card:SetTone(advice.tone, advice.icon)
	card:Set(advice.title, advice.body)
	if advice.action then
		card.action:Show()
		card.action:SetKind(advice.tone == "go" and "primary" or "ghost", advice.tone)
		card.action:SetLabel(advice.action)
	else
		card.action:Hide()
	end
	card.dismiss:SetShown(not advice.keep)
	card:AfterRestyle()
	card:Show()
end

local function buildCards(page, top)
	local heading = W.Text(page, "head", 18, "ink")
	heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -top)
	heading:SetLabel(L["What now?"])
	ui.cardCount = W.Text(page, "body", 11, "muted")
	ui.cardCount:SetPoint("BOTTOMLEFT", heading, "BOTTOMRIGHT", 10, 2)

	ui.cards = {}
	for index = 1, CARDS do
		local card = W.Card(page, LEFT_W, CARD_H, "info", "spark")
		card:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(top + 34 + (index - 1) * (CARD_H + CARD_GAP)))
		card.body:SetMaxLines(2)
		W.CardAction(card, W.Button(card, "", "ghost", {
			onClick = function()
				local advice = card.advice
				if advice and advice.run then
					advice.run()
					Home:Refresh()
				end
			end,
		}))
		card.dismiss = W.IconButton(card, "x", 18, "faint", function()
			T.Advisor.Dismiss(card.advice)
		end)
		card.dismiss:SetPoint("TOPRIGHT", card, "TOPRIGHT", -5, -5)
		card:Hide()
		ui.cards[index] = card
	end
	return top + 34
end

local function refreshCards()
	local cards = T.Advisor.Cards(CARDS)
	local real = 0
	for index, card in ipairs(ui.cards) do
		local advice = cards[index]
		if advice then
			fillCard(card, advice)
			if advice.id ~= "clear" then
				real = real + 1
			end
		else
			card:Hide()
		end
	end
	if real == 0 then
		ui.cardCount:SetLabel(L["Nothing urgent"])
	elseif real == 1 then
		ui.cardCount:SetLabel(L["1 thing worth doing"])
	else
		ui.cardCount:SetLabel(L["%d things worth doing"]:format(real))
	end
end

-- ---------------------------------------------------------------------------
-- "Find nearby": one tile per thing new players look for most.

local function tileLook(tile)
	tile:SetStyle({
		shape = "card", fill = tile.hover and "cardHover" or "card",
		line = tile.hover and "accent" or "cardLine", top = "cardTop",
	})
	tile.label:SetRole(tile.hover and "ink" or "muted")
end

local function buildNearby(page, top, cardsTop)
	local heading = W.Text(page, "head", 14, "ink")
	heading:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT_W + GAP, -(top + 4))
	heading:SetLabel(L["Find nearby"])

	local width = (RIGHT_W - 3 * TILE_GAP) / 4
	local index = 0
	ui.tiles = {}
	for _, category in ipairs(T.Categories) do
		if category.home and index < 8 then
			local tile = W.Panel(page, nil, "Button")
			tile:SetSize(width, TILE_H)
			tile:SetPoint("TOPLEFT", page, "TOPLEFT",
				LEFT_W + GAP + (index % 4) * (width + TILE_GAP),
				-(cardsTop + math.floor(index / 4) * (TILE_H + TILE_GAP)))
			tile.icon = W.Icon(tile, category.icon, 18, "accent")
			tile.icon:SetPoint("TOP", tile, "TOP", 0, -9)
			tile.label = W.Text(tile, "body", 9.5, "muted")
			tile.label:SetPoint("BOTTOM", tile, "BOTTOM", 0, 8)
			tile.label:SetJustifyH("CENTER")
			tile.label:SetLabel(category.short)
			tile.category = category.id
			tile:SetScript("OnEnter", function(self)
				self.hover = true
				tileLook(self)
			end)
			tile:SetScript("OnLeave", function(self)
				self.hover = false
				tileLook(self)
			end)
			tile:SetScript("OnClick", function(self)
				C.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
				T.Window:Select("find", self.category)
			end)
			tileLook(tile)
			index = index + 1
			ui.tiles[index] = tile
		end
	end
	return cardsTop + 2 * TILE_H + TILE_GAP
end

-- ---------------------------------------------------------------------------
-- The next milestone, with the road to level 60 as four steps.

local STEPS = 4

local function milestones()
	local list = {
		{ level = 10, label = L["Talents"], title = L["Level 10: first talent point"],
			note = L["Talents let you shape your class."] },
		{ level = 40, label = L["Mount"], title = L["Level 40: first mount"],
			note = L["Riding is expensive. Start saving gold now."] },
		{ level = 60, label = L["Level 60"], title = L["Level 60: the top"],
			note = L["Raids and the hardest dungeons open up."] },
	}
	-- The first dungeon comes from the game's own list, so it is right for either side.
	local first = G.World().dungeons[1]
	if first and first.lo > 10 and first.lo < 40 then
		table.insert(list, 2, {
			level = first.lo, label = L["Dungeons"], title = L["Level %d: first dungeon"]:format(first.lo),
			note = L["%s. Dungeons need a group of five."]:format(first.name),
		})
	end
	return list
end

local function buildMilestone(page, top, height)
	local card = W.Panel(page, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	card:SetSize(RIGHT_W, height)
	card:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT_W + GAP, -top)
	local label = W.Text(card, "label", 8.5, "accentText")
	label:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -13)
	label:SetLabel(L["Next milestone"])
	ui.mileTitle = W.Text(card, "head", 13.5, "ink")
	ui.mileTitle:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
	ui.mileTitle:SetWidth(RIGHT_W - 32) -- one line: a longer title is cut, never past the card
	ui.mileNote = W.Text(card, "body", 10.5, "muted", { width = RIGHT_W - 32 })
	ui.mileNote:SetPoint("TOPLEFT", ui.mileTitle, "BOTTOMLEFT", 0, -5)
	ui.mileNote:SetMaxLines(2)

	ui.steps, ui.links = {}, {}
	local span = RIGHT_W - 2 * 34
	for index = 1, STEPS do
		local step = {}
		step.disc = W.Tint(card, "circle-fill", "tile", "ARTWORK", 0)
		step.disc:SetSize(22, 22)
		step.ring = W.Tint(card, "circle-line", "tileLine", "ARTWORK", 1)
		step.ring:SetSize(22, 22)
		step.ring:SetPoint("CENTER", step.disc, "CENTER", 0, 0)
		step.number = W.Text(card, "body", 9, "faint")
		step.number:SetPoint("CENTER", step.disc, "CENTER", 0, 0)
		step.number:SetJustifyH("CENTER")
		step.check = W.Icon(card, "check", 12, "accentInk", "OVERLAY")
		step.check:SetPoint("CENTER", step.disc, "CENTER", 0, 0)
		step.label = W.Text(card, "body", 9, "muted")
		step.label:SetPoint("TOP", step.disc, "BOTTOM", 0, -4)
		step.label:SetJustifyH("CENTER")
		ui.steps[index] = step
		if index > 1 then
			local link = W.Fill(card, "cardLine", "ARTWORK", -1)
			link:SetHeight(2)
			link:SetPoint("LEFT", ui.steps[index - 1].disc, "CENTER", 0, 0)
			link:SetPoint("RIGHT", step.disc, "CENTER", 0, 0)
			ui.links[index] = link
		end
	end
	ui.mileCard, ui.mileSpan = card, span
end

local function refreshMilestone()
	local level = G.Level()
	local list = milestones()
	local nextUp
	for _, item in ipairs(list) do
		if level < item.level then
			nextUp = item
			break
		end
	end
	if nextUp then
		local left = nextUp.level - level
		ui.mileTitle:SetLabel(nextUp.title)
		ui.mileNote:SetLabel((left == 1 and L["1 level to go."] or L["%d levels to go."]:format(left)) .. " " .. nextUp.note)
	else
		ui.mileTitle:SetLabel(L["You reached the top"])
		ui.mileNote:SetLabel(L["Level 60. The whole world is open to you now."])
	end
	local count = math.min(#list, STEPS)
	for index, step in ipairs(ui.steps) do
		local item = index <= count and list[index] or nil
		local shown = item ~= nil
		step.disc:SetShown(shown)
		step.ring:SetShown(shown)
		step.number:SetShown(shown)
		step.label:SetShown(shown)
		step.check:SetShown(false)
		if ui.links[index] then
			ui.links[index]:SetShown(shown)
		end
		if item then
			step.disc:ClearAllPoints()
			step.disc:SetPoint("CENTER", ui.mileCard, "BOTTOMLEFT",
				34 + (count > 1 and (index - 1) * ui.mileSpan / (count - 1) or ui.mileSpan / 2), 36)
			local done, isNext = level >= item.level, item == nextUp
			step.disc:SetRole(done and "accent" or "tile")
			step.ring:SetRole((done or isNext) and "accent" or "tileLine")
			step.check:SetShown(done)
			step.number:SetShown(not done)
			step.number:SetLabel(item.level)
			step.number:SetRole(isNext and "accentText" or "faint")
			step.label:SetLabel(item.label)
			step.label:SetRole(isNext and "ink" or "muted")
			if ui.links[index] then
				ui.links[index]:SetRole(done and "accent" or "cardLine")
			end
		end
	end
end

local function buildTip(page, top)
	local tip = W.Panel(page, { shape = "card", fill = "tip", line = "tipLine" })
	tip:SetSize(HERO_W, TIP_H)
	tip:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -top)
	local disc = W.Tint(tip, "circle-fill", "tipIcon", "ARTWORK", 0)
	disc:SetSize(30, 30)
	disc:SetPoint("LEFT", tip, "LEFT", 14, 0)
	local bulb = W.Icon(tip, "bulb", 16, "accent", "OVERLAY")
	bulb:SetPoint("CENTER", disc, "CENTER", 0, 0)
	local label = W.Text(tip, "label", 8.5, "accentText")
	label:SetPoint("TOPLEFT", tip, "TOPLEFT", 56, -8)
	label:SetLabel(L["Did you know?"])
	-- Long tips run onto a second line instead of being cut off.
	ui.tip = W.Text(tip, "body", 11.5, "tipText", { width = HERO_W - 56 - 110 })
	ui.tip:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
	ui.tip:SetMaxLines(2)
	local nextTip = W.Button(tip, L["Next tip"], "ghost", {
		role = "muted", height = 26, size = 11,
		onClick = function()
			T.db.tip = T.db.tip % #TIPS + 1
			ui.tip:SetLabel(TIPS[T.db.tip])
		end,
	})
	nextTip:SetPoint("RIGHT", tip, "RIGHT", -12, 0)
end

function Home:Build(page)
	buildHero(page)
	local top = HERO_H + 22
	local cardsTop = buildCards(page, top)
	local cardsBottom = cardsTop + CARDS * CARD_H + (CARDS - 1) * CARD_GAP
	local tilesBottom = buildNearby(page, top, cardsTop)
	buildMilestone(page, tilesBottom + 10, cardsBottom - tilesBottom - 10)
	buildTip(page, cardsBottom + 10)
	self.built = true
end

function Home:Refresh()
	if not self.built then
		return
	end
	local level = G.Level()
	local className = G.ClassName()
	ui.level:SetLabel(level > 0 and level or "")
	ui.class:SetLabel(className)
	ui.classBadge:AfterRestyle()
	ui.name:SetLabel(C.Plain((UnitName("player")), "") or "")
	ui.place:SetLabel(placeText())

	local xp = C.Plain(UnitXP("player"), 0) or 0
	local xpMax = C.Plain(UnitXPMax("player"), 0) or 0
	local rested = C.Plain(C.Call("GetXPExhaustion"), 0) or 0
	local cap = C.Plain(C.Call("GetMaxPlayerLevel"), nil)
	if xpMax <= 0 or (cap and level >= cap) then
		ui.xp:Hide()
		ui.xpText:SetLabel(L["Maximum level"])
		ui.restText:SetLabel("")
	else
		ui.xp:Show()
		ui.xp:Set(xp / xpMax, (xp + rested) / xpMax)
		ui.xpText:SetLabel(L["%d%% to level %d"]:format(math.floor(xp / xpMax * 100), level + 1))
		if rested > 0 then
			ui.restText:SetLabel(L["Rested: double experience from kills"])
		elseif C.Call("IsResting") then
			ui.restText:SetLabel(L["Resting here builds rested experience"])
		else
			ui.restText:SetLabel("")
		end
	end

	ui.gold:Set("", G.MoneyText(GetMoney and GetMoney()))
	ui.bind:Set(L["Home"], G.BindLocation() or L["not set"])
	ui.bags:Set(L["Bags"], L["%d free"]:format(G.FreeBagSlots()))

	ui.tip:SetLabel(TIPS[(T.db.tip - 1) % #TIPS + 1])
	refreshCards()
	refreshMilestone()
end

-- Refresh when something on the banner changes, at most a few times a second and only
-- while the page is on screen.
local queued = false
local function queue()
	if queued or not Home.built or not Home.page:IsVisible() then
		return
	end
	queued = true
	C_Timer.After(0.25, function()
		queued = false
		if Home.page:IsVisible() and not C.InCombat() then
			Home:Refresh()
		end
	end)
end

function Home:OnInit()
	for _, event in ipairs({
		"PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION",
		"PLAYER_UPDATE_RESTING", "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "HEARTHSTONE_BOUND",
		"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
	}) do
		T:On(event, queue)
	end
	for _, event in ipairs({
		"UPDATE_INVENTORY_DURABILITY", "TRAIT_CONFIG_UPDATED", "TH_THEME_CHANGED", "TH_PROBE_DONE",
		"TH_SPELLS_CHANGED", "TH_ADVICE_CHANGED", "TH_SKILLS_CHANGED",
	}) do
		T:On(event, queue)
	end
end
