local _, T = ...
local L = T.L
local W = T.Widgets
local C = T.Compat
local G = T.Game

-- Your characters: every character on the account as it was when last saved
-- (Services/Characters.lua), the one being played first, then the most recent.
-- It has no tab of its own (the rail is full): it opens from Home's banner and the Legacy page.

local Page = T:NewModule("characters")
T.CharactersPage = Page
local Chars = T.Characters

local PAGE_W = 778
local ROW_H, ROW_GAP = 80, 6
local LIST_TOP = 58
local BUTTON_W = 110
local DOT = "  \194\183  "

local ui = {}
local armed -- the key whose Forget button has been clicked once

local function str(value)
	return type(value) == "string" and value ~= "" and value or nil
end

local function num(value)
	return type(value) == "number" and value or nil
end

-- Joins the parts that are there; a missing one leaves no gap. `count` is how many there could be.
local function join(parts, count, between)
	local out = {}
	for index = 1, count do
		if parts[index] then
			out[#out + 1] = parts[index]
		end
	end
	return table.concat(out, between or DOT)
end

-- "Level 14 Human Mage  ·  Realm  ·  Westfall"
local function whoText(rec)
	local level = num(rec.level)
	local who = join({ level and level > 0 and L["Level %d"]:format(level) or nil, str(rec.race), str(rec.className) }, 3, " ")
	return join({ who ~= "" and who or nil, str(rec.realm), str(rec.zone) }, 3)
end

-- "62% to level 15, rested 20% of a level  ·  Home: Goldshire  ·  34g 12s  ·  Gear 100%"
local function stateText(rec)
	local level, xp, xpMax = num(rec.level), num(rec.xp), num(rec.xpMax)
	local progress
	if level and xp and xpMax and xpMax > 0 then
		progress = L["%d%% to level %d"]:format(math.floor(xp / xpMax * 100), level + 1)
		local rested = num(rec.rested)
		if rested and rested > 0 then
			progress = progress .. ", " .. L["rested %d%% of a level"]:format(math.floor(rested / xpMax * 100))
		end
	elseif level and level >= G.MaxLevel() then
		progress = L["Maximum level"]
	end
	local home = str(rec.bind) and L["Home: %s"]:format(rec.bind) or L["Home: not set"]
	local gold = num(rec.money) and G.MoneyText(rec.money) or nil
	local gear = num(rec.durability) and L["Gear %d%%"]:format(math.floor(rec.durability * 100 + 0.5)) or nil
	return join({ progress, home, gold, gear }, 4)
end

-- "Alchemy 75/150, Cooking 40/75  ·  2 talent points to spend  ·  3 spells at the trainer"
local function moreText(rec)
	local profs = {}
	for _, prof in ipairs(type(rec.profs) == "table" and rec.profs or {}) do
		if type(prof) == "table" and str(prof.name) and num(prof.rank) and num(prof.max) then
			profs[#profs + 1] = ("%s %d/%d"):format(prof.name, prof.rank, prof.max)
		end
	end
	local talents
	local points = num(rec.talents)
	if points and points > 0 then
		talents = points == 1 and L["1 talent point to spend"] or L["%d talent points to spend"]:format(points)
	elseif rec.talentsSome == true then
		talents = L["Talent points to spend"]
	end
	local train
	local count = num(rec.train)
	if count and count > 0 then
		train = count == 1 and L["1 spell at the trainer"] or L["%d spells at the trainer"]:format(count)
	end
	return join({ #profs > 0 and table.concat(profs, ", ") or L["No professions"], talents, train }, 3)
end

local function makeRow(list, width)
	local row = W.Panel(list, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	row:SetSize(width, ROW_H)
	-- The name row holds when it was saved and the Forget button; the lines under it get the
	-- whole width (the first stays clear of the button).
	local fullW = width - 32
	row.name = W.Text(row, "head", 14, "ink")
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -9)
	row.name:SetWidth(fullW - BUTTON_W - 220)
	row.when = W.Text(row, "body", 10, "faint")
	row.when:SetJustifyH("RIGHT")
	row.when:SetWidth(190)
	row.who = W.Text(row, "body", 11, "muted")
	row.who:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -29)
	row.who:SetWidth(fullW - BUTTON_W - 14)
	row.state = W.Text(row, "body", 10.5, "muted")
	row.state:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -46)
	row.state:SetWidth(fullW)
	row.more = W.Text(row, "body", 10.5, "muted")
	row.more:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -62)
	row.more:SetWidth(fullW)
	row.forget = W.Button(row, L["Forget"], "ghost", {
		role = "muted", height = 24, size = 11, width = BUTTON_W,
		onClick = function()
			local item = row.item
			if not item or item.current then
				return
			end
			if armed == item.key then
				armed = nil
				Chars.Forget(item.key)
			else
				armed = item.key
			end
			Page:Refresh(true)
		end,
	})
	row.forget:SetPoint("TOPRIGHT", row, "TOPRIGHT", -14, -8)

	function row:Fill(item)
		local rec = item.rec
		self.name:SetLabel(rec.name)
		self.who:SetLabel(whoText(rec))
		self.state:SetLabel(stateText(rec))
		self.more:SetLabel(moreText(rec))
		self.when:ClearAllPoints()
		if item.current then
			self.when:SetPoint("TOPRIGHT", self, "TOPRIGHT", -14, -12)
			self.when:SetLabel(L["Playing now"])
			self.when:SetRole("go")
			self.forget:Hide()
		else
			self.when:SetPoint("TOPRIGHT", self.forget, "TOPLEFT", -12, -4)
			self.when:SetLabel(Chars.Ago(rec.at))
			self.when:SetRole("faint")
			self.forget:Show()
			local sure = armed == item.key
			self.forget:SetKind("ghost", sure and "warn" or "muted")
			self.forget:SetLabel(sure and L["Yes, forget"] or L["Forget"])
		end
	end
	return row
end

function Page:Build(page)
	self.page = page
	local title = W.Text(page, "head", 20, "ink")
	title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	title:SetLabel(L["Your characters"])
	-- No tab of its own: Back returns to the page it was opened from.
	local back = W.Button(page, L["Back"], "ghost", {
		role = "muted", height = 24, size = 10.5,
		onClick = function()
			T.Window:Back()
		end,
	})
	back:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
	local sub = W.Text(page, "body", 11.5, "muted", { width = 520 })
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	sub:SetLabel(L["Every character you play with Trailhead, saved each time you log out."])
	ui.total = W.Text(page, "body", 11.5, "muted")
	ui.total:SetPoint("RIGHT", back, "LEFT", -14, 0)
	ui.total:SetJustifyH("RIGHT")
	ui.count = W.Text(page, "head", 13, "ink")
	ui.count:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -32) -- in line with the rows, clear of the scroll bar
	ui.count:SetJustifyH("RIGHT")

	ui.list = W.List(page, PAGE_W, 496 - LIST_TOP, ROW_H, ROW_GAP, makeRow)
	ui.list:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -LIST_TOP)
	ui.empty = W.Text(page, "body", 11.5, "muted", { width = PAGE_W })
	ui.empty:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -LIST_TOP)
	ui.empty:SetLabel(L["Trailhead cannot tell who this character is yet. Try again in a moment."])
	ui.hint = W.Text(page, "body", 11.5, "muted", { width = PAGE_W })
	ui.hint:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(LIST_TOP + ROW_H + 14))
	ui.hint:SetLabel(L["Log in once on each of your other characters and they show up here too."])

	T:On("TH_CHARACTERS_CHANGED", function()
		if page:IsVisible() then
			Page:Refresh(true)
		end
	end)
	self.built = true
end

-- keep = true for a refresh of the page already on screen (a Forget click): the list keeps
-- its place and a Forget waiting for its second click stays armed.
function Page:Refresh(keep)
	if not self.built then
		return
	end
	if not keep then
		armed = nil
	end
	-- This character's record is written a moment after login; opening the page writes it now.
	local key = Chars.Key()
	if key and not C.InCombat() and type(Chars.All()[key]) ~= "table" then
		T.SafeCall("Characters.Save", Chars.Save)
	end
	local items = Chars.List()
	ui.list:SetItems(items, keep)
	ui.empty:SetShown(#items == 0)
	ui.hint:SetShown(#items == 1)
	local gold, counted = 0, 0
	for _, item in ipairs(items) do
		if num(item.rec.money) then
			gold, counted = gold + item.rec.money, counted + 1
		end
	end
	ui.count:SetLabel(#items == 1 and L["1 character"] or L["%d characters"]:format(#items))
	ui.total:SetLabel(counted > 1 and L["Gold on all of them: %s"]:format(G.MoneyText(gold)) or "")
end
