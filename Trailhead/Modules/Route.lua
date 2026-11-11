local _, T = ...
local L = T.L
local W = T.Widgets
local Theme = T.Theme
local C = T.Compat
local R = T.Routes
local P = T.Places

-- How to get there: numbered steps from where you stand to anything Trailhead lists.
-- Opened from the "How to get there" button on a row; it has no tab of its own.

local Route = T:NewModule("route")

local PAGE_W = 778
local STEPS_TOP, STEP_H, STEP_GAP, MAX_STEPS = 74, 66, 8, 4

local ui = { rows = {} }

local function makeStep(page, index)
	local row = W.Panel(page, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	row:SetSize(PAGE_W, STEP_H)
	row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(STEPS_TOP + (index - 1) * (STEP_H + STEP_GAP)))
	row.badge = W.Panel(row, { shape = "tile", fill = "tile", line = "tileLine" })
	row.badge:SetSize(34, 34)
	row.badge:SetPoint("LEFT", row, "LEFT", 12, 0)
	row.number = W.Text(row.badge, "head", 15, "accentText")
	row.number:SetPoint("CENTER", row.badge, "CENTER", 0, 0)
	row.number:SetJustifyH("CENTER")
	row.number:SetLabel(tostring(index))
	row.title = W.Text(row, "head", 13, "ink")
	row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 60, -11)
	row.title:SetWidth(PAGE_W - 230)
	row.detail = W.Text(row, "body", 10.5, "muted", { width = PAGE_W - 230 })
	row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -5)
	row.detail:SetSpacing(3)
	row.button = W.Button(row, L["Set marker"], "ghost", {
		role = "accentText", height = 28, size = 11,
		onClick = function()
			if row.step then
				R.Mark(row.step)
			end
		end,
	})
	row.button:SetPoint("RIGHT", row, "RIGHT", -12, 0)
	return row
end

function Route:Build(page)
	ui.back = W.Button(page, L["Back"], "ghost", {
		role = "muted", height = 24, size = 10.5,
		onClick = function()
			T.Window:Select(Route.from or T.Window.lastTab or "home")
		end,
	})
	ui.back:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
	ui.tile = W.IconTile(page, "pin", 44, "accent")
	ui.tile:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -2)
	ui.kicker = W.Text(page, "label", 9, "accentText")
	ui.kicker:SetPoint("TOPLEFT", ui.tile, "TOPRIGHT", 14, -3)
	ui.kicker:SetLabel(L["How to get there"])
	ui.title = W.Text(page, "head", 19, "ink")
	ui.title:SetPoint("TOPLEFT", ui.kicker, "BOTTOMLEFT", 0, -5)
	ui.title:SetWidth(PAGE_W - 200)
	ui.where = W.Text(page, "body", 10.5, "muted")
	-- On the small line above the title, where no title is long enough to reach it.
	ui.where:SetPoint("BOTTOMLEFT", ui.kicker, "BOTTOMRIGHT", 12, -1)

	for index = 1, MAX_STEPS do
		ui.rows[index] = makeStep(page, index)
	end
	ui.note = W.Text(page, "body", 11.5, "muted", { width = PAGE_W - 24 })
	ui.note:SetSpacing(4)
	self.built = true
end

-- Chooses what to route to: a target from Routes (R.ForResult, R.ForZone, R.ForDungeon).
function Route:Goto(target)
	if type(target) == "table" then
		self.target = target
		local last = T.Window.lastTab
		self.from = last ~= "route" and last or self.from
	end
end

function Route:Refresh()
	if not self.built then
		return
	end
	local target = self.target
	if not target then
		T.Window:Select(T.Window.lastTab or "home")
		return
	end
	local plan = R.Plan(target)
	self.plan = plan
	ui.tile.icon:SetTexture(Theme.MEDIA .. "icon-" .. (plan.icon or "pin"))
	ui.title:SetLabel(plan.title or "")
	ui.where:SetLabel(plan.where or "")
	local shown = 0
	for index, row in ipairs(ui.rows) do
		local step = plan.steps[index]
		row.step = step
		row:SetShown(step ~= nil)
		if step then
			shown = index
			row.title:SetLabel(step.text)
			row.detail:SetLabel(step.detail or "")
			row.button:SetShown(type(step.map) == "number")
		end
	end
	ui.note:ClearAllPoints()
	ui.note:SetPoint("TOPLEFT", self.page, "TOPLEFT", 12, -(STEPS_TOP + shown * (STEP_H + STEP_GAP) + 10))
	ui.note:SetLabel(plan.note or "")
end

local queued = false
local function queue()
	if queued or not Route.built or not Route.page:IsVisible() then
		return
	end
	queued = true
	C_Timer.After(0.5, function()
		queued = false
		if Route.page:IsVisible() and not C.InCombat() then
			Route:Refresh()
		end
	end)
end

function Route:OnInit()
	-- The steps depend on where you stand and which flight points you have.
	for _, event in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "TH_TAXI_CHANGED", "TH_PLACES_CHANGED" }) do
		T:On(event, queue)
	end
end

-- Opens the steps to a target from anywhere in Trailhead.
function R.Show(target)
	if target then
		T.Window:Open("route", target)
	end
end
