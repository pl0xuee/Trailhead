local _, T = ...
local L = T.L
local W = T.Widgets
local C = T.Compat
local G = T.Game

-- Spells: what you know but cannot use yet (not on a bar), what your trainer has for you
-- now, and what is coming at later levels.

local Spells = T:NewModule("spells", { label = L["Spells"], icon = "book", order = 3 })

local COL_W, COL_GAP, COL_TOP = 380, 18, 40
local COL_H = 496 - COL_TOP
local ROW_H, ROW_GAP = 26, 4
local LIST_TOP, FOOT = 66, 56

local ui = {}

local function makeRow(list, width)
	local row = CreateFrame("Frame", nil, list)
	row:SetSize(width, ROW_H)
	row.icon = W.GameIcon(row, 20)
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.name = W.Text(row, "body", 12, "ink")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
	row.name:SetWidth(width - 30 - 86) -- a fixed width cuts a long name short with "..."
	row.right = W.Text(row, "body", 10.5, "muted")
	row.right:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.right:SetJustifyH("RIGHT")
	row.header = W.Text(row, "label", 8.5, "accentText")
	row.header:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 5)

	function row:Fill(item)
		local isHeader = item.header ~= nil
		self.header:SetShown(isHeader)
		self.icon:SetShown(not isHeader)
		self.name:SetShown(not isHeader)
		self.right:SetShown(not isHeader)
		if isHeader then
			self.header:SetLabel(item.header)
			return
		end
		self.icon:SetIcon(item.icon)
		local name = item.name
		if item.sub and item.sub ~= "" then
			name = name .. "  (" .. item.sub .. ")"
		end
		self.name:SetLabel(name)
		self.right:SetLabel(item.right or "")
	end
	return row
end

local function column(page, x, title)
	local panel = W.Panel(page, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	panel:SetSize(COL_W, COL_H)
	panel:SetPoint("TOPLEFT", page, "TOPLEFT", x, -COL_TOP)
	panel.title = W.Text(panel, "head", 14, "ink")
	panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -14)
	panel.title:SetLabel(title)
	panel.note = W.Text(panel, "body", 10.5, "muted", { width = COL_W - 32 })
	panel.note:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -5)
	panel.note:SetMaxLines(2)
	panel.list = W.List(panel, COL_W - 32, COL_H - LIST_TOP - FOOT, ROW_H, ROW_GAP, makeRow)
	panel.list:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -LIST_TOP)
	panel.empty = W.Text(panel, "body", 12, "muted", { width = COL_W - 32 })
	panel.empty:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -(LIST_TOP + 8))
	panel.empty:SetSpacing(4)
	return panel
end

function Spells:Build(page)
	local heading = W.Text(page, "head", 18, "ink")
	heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	heading:SetLabel(L["Spells"])
	local sub = W.Text(page, "body", 11, "muted")
	sub:SetPoint("BOTTOMLEFT", heading, "BOTTOMRIGHT", 10, 2)
	sub:SetLabel(L["What you can use, what you can learn, and what comes next."])

	ui.bars = column(page, 0, L["Not on your action bars"])
	local book = W.Button(ui.bars, L["Open spellbook"], "ghost", {
		role = "accentText",
		onClick = function()
			-- Only reached when the safe way is not there (UI/Secure.lua).
			if not C.InCombat() then
				T:Print(L["Open your spellbook from the game's menu bar."])
			end
		end,
	})
	T.Secure.Set(book, "spellbook", function()
		T.Window:Beside("PlayerSpellsFrame", "spellbook")
	end)
	ui.bars.action = book

	ui.learn = column(page, COL_W + COL_GAP, L["From your class trainer"])
	ui.learn.action = W.Button(ui.learn, L["Find my trainer"], "primary", {
		onClick = function()
			T.Window:Select("find", "trainer")
		end,
	})
	self.built = true
end

-- Puts a column's button straight under its list, or under the empty text when the list is
-- empty, instead of at the foot of a mostly empty card.
local function placeAction(panel, count)
	local y
	if count > 0 then
		local rows = math.min(count, panel.list.visible or count)
		y = LIST_TOP + rows * ROW_H + (rows - 1) * ROW_GAP + 14
	else
		y = LIST_TOP + 8 + W.TextHeight(panel.empty) + 16
	end
	y = math.min(y, COL_H - FOOT + 12)
	panel.action:ClearAllPoints()
	panel.action:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -y)
end

function Spells:Refresh(keep)
	if not self.built then
		return
	end
	local missing = G.SpellsOffBars()
	ui.bars.list:SetItems(missing, keep)
	if #missing == 0 then
		ui.bars.note:SetLabel(L["Spells you know but have not put on a bar."])
		ui.bars.empty:SetLabel(L["Every class spell you know is on a bar. Nothing to do here."])
	else
		ui.bars.note:SetLabel(L["You know these but cannot use them yet. Open your spellbook and drag each one to an empty bar slot."])
		ui.bars.empty:SetLabel("")
	end

	local training = G.Training()
	local level = G.Level()
	local items = {}
	if #training.now > 0 then
		items[#items + 1] = { header = L["Ready to learn now"] }
		for _, spell in ipairs(training.now) do
			spell.right = (spell.cost or 0) > 0 and G.MoneyText(spell.cost) or L["now"]
			items[#items + 1] = spell
		end
	end
	if #training.later > 0 then
		items[#items + 1] = { header = L["Coming up"] }
		for index, spell in ipairs(training.later) do
			if index > 40 then
				break
			end
			spell.right = L["level %d"]:format(spell.level or level)
			items[#items + 1] = spell
		end
	end
	ui.learn.list:SetItems(items, keep)
	if training.source == "trainer" then
		local note = L["As of your last visit to the trainer."]
		if training.cost > 0 then
			note = note .. " " .. L["Learning everything ready now costs about %s."]:format(G.MoneyText(training.cost))
		end
		if not training.full and #training.later == 0 and G.Level() < G.MaxLevel() then
			-- The trainer's window was hiding later levels and they could not be read.
			note = note .. " " .. L["To see later levels here, tick Unavailable in the trainer window's filter."]
		end
		ui.learn.note:SetLabel(note)
	else
		ui.learn.note:SetLabel(L["New spells and new ranks are bought from your class trainer."])
	end
	if #items > 0 then
		ui.learn.empty:SetLabel("")
	elseif training.source == "trainer" then
		ui.learn.empty:SetLabel(L["You have learned everything your trainer offers for now."])
	else
		ui.learn.empty:SetLabel(L["Visit your class trainer once. From then on Trailhead lists what you can learn, what it costs and what is coming at later levels."])
	end
	placeAction(ui.bars, #missing)
	placeAction(ui.learn, #items)
end

local queued = false
local function queue()
	if queued or not Spells.built or not Spells.page:IsVisible() then
		return
	end
	queued = true
	C_Timer.After(0.3, function()
		queued = false
		if Spells.page:IsVisible() and not C.InCombat() then
			Spells:Refresh(true)
		end
	end)
end

-- The narrow strip beside the spellbook (UI/Window.lua shows it when the screen has no room
-- for the whole window): the spells that are on no action bar.
local function spellStrip()
	local missing = G.SpellsOffBars()
	if #missing == 0 then
		return { title = L["Not on your action bars"], note = L["Every class spell you know is on a bar. Nothing to do here."] }
	end
	local most = T.Window.STRIP_ROWS
	local shown = #missing > most and most - 1 or #missing
	local rows = {}
	for index = 1, shown do
		rows[index] = { icon = missing[index].icon or false, name = missing[index].name }
	end
	local note = L["Drag each one from your spellbook to an empty bar slot."]
	if #missing > shown then
		note = L["And %d more."]:format(#missing - shown) .. " " .. note
	end
	return { title = L["Not on your action bars"], rows = rows, note = note }
end

function Spells:OnInit()
	T.Window:SetStrip("PlayerSpellsFrame:spellbook", spellStrip)
	T:On("TH_SPELLS_CHANGED", function()
		T.Window:RefreshStrip()
		queue()
	end)
end
