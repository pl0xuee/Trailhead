local _, T = ...
local L = T.L

-- Round button on the edge of the minimap. Click opens Trailhead, right-click opens the
-- settings, dragging moves it around the minimap. The ring, background and highlight are
-- the game's own minimap button art (file IDs).

local ICON = "Interface\\AddOns\\Trailhead\\Media\\logo"
local RING, BACKGROUND, HIGHLIGHT = 136430, 136467, 136477
local OUTSIDE = 5 -- how far the button centre sits outside the minimap edge

local button

local function place()
	local angle = math.rad(T.db.minimap.angle)
	local radius = Minimap:GetWidth() / 2 + OUTSIDE
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function followCursor()
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	T.db.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx)) % 360
	place()
end

local function build()
	button = CreateFrame("Button", "TrailheadMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture(HIGHLIGHT)
	local back = button:CreateTexture(nil, "BACKGROUND")
	back:SetTexture(BACKGROUND)
	back:SetSize(24, 24)
	back:SetPoint("CENTER")
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON)
	icon:SetSize(19, 19)
	icon:SetPoint("CENTER")
	local ring = button:CreateTexture(nil, "OVERLAY")
	ring:SetTexture(RING)
	ring:SetSize(50, 50)
	ring:SetPoint("TOPLEFT")
	button:SetScript("OnClick", function(_, mouse)
		GameTooltip:Hide()
		if mouse == "RightButton" then
			T.Window:Open("settings")
		else
			T.Window:Toggle()
		end
	end)
	button:SetScript("OnDragStart", function(self)
		GameTooltip:Hide()
		self:SetScript("OnUpdate", followCursor)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Trailhead", 1, 1, 1)
		GameTooltip:AddLine(L["Click: open or close\nRight-click: settings\nDrag: move this button"], 0.96, 0.74, 0.33)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

-- Shows or hides the button as the setting says.
function T:UpdateMinimapButton()
	if not Minimap or not T.db then
		return
	end
	if not T.db.minimap.show then
		if button then
			button:Hide()
		end
		return
	end
	if not button then
		build()
	end
	place()
	button:Show()
end
