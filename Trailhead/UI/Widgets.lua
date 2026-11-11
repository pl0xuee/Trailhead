local _, T = ...
local Theme = T.Theme
local C = T.Compat

-- Widgets: the small set of themed building blocks every screen is made from.
-- All of them restyle themselves when the theme changes.

local W = {}
T.Widgets = W
local MEDIA = Theme.MEDIA

-- ---------------------------------------------------------------------------
-- Nine-slice: nine textures cut from one shape texture, so a rounded or cut-corner
-- shape can be any size without its corners stretching.
-- Parts: 1 2 3 / 4 5 6 / 7 8 9, left to right, top to bottom.

local Slice = {}
Slice.__index = Slice

local function newSlice(frame, layer, sublevel)
	local slice = setmetatable({ frame = frame, parts = {} }, Slice)
	for i = 1, 9 do
		local part = frame:CreateTexture(nil, layer, nil, sublevel)
		-- Pixel snapping moves each part separately and opens hairline gaps between them.
		if part.SetSnapToPixelGrid then
			part:SetSnapToPixelGrid(false)
		end
		if part.SetTexelSnappingBias then
			part:SetTexelSnappingBias(0)
		end
		slice.parts[i] = part
	end
	return slice
end

-- file: texture path; m: slice margin as a fraction of the texture; corner: corner size
-- in UI units; outset: how far the shape reaches beyond the frame (shadows and glows).
function Slice:Layout(file, m, corner, outset)
	if self.file == file and self.m == m and self.corner == corner and self.outset == outset then
		return
	end
	self.file, self.m, self.corner, self.outset = file, m, corner, outset
	local p, f, o, n = self.parts, self.frame, outset or 0, 1 - m
	for i = 1, 9 do
		p[i]:ClearAllPoints()
		p[i]:SetTexture(file)
	end
	p[1]:SetPoint("TOPLEFT", f, "TOPLEFT", -o, o)
	p[3]:SetPoint("TOPRIGHT", f, "TOPRIGHT", o, o)
	p[7]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -o, -o)
	p[9]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", o, -o)
	p[1]:SetSize(corner, corner)
	p[3]:SetSize(corner, corner)
	p[7]:SetSize(corner, corner)
	p[9]:SetSize(corner, corner)
	p[2]:SetPoint("TOPLEFT", p[1], "TOPRIGHT")
	p[2]:SetPoint("BOTTOMRIGHT", p[3], "BOTTOMLEFT")
	p[8]:SetPoint("TOPLEFT", p[7], "TOPRIGHT")
	p[8]:SetPoint("BOTTOMRIGHT", p[9], "BOTTOMLEFT")
	p[4]:SetPoint("TOPLEFT", p[1], "BOTTOMLEFT")
	p[4]:SetPoint("BOTTOMRIGHT", p[7], "TOPRIGHT")
	p[6]:SetPoint("TOPLEFT", p[3], "BOTTOMLEFT")
	p[6]:SetPoint("BOTTOMRIGHT", p[9], "TOPRIGHT")
	p[5]:SetPoint("TOPLEFT", p[1], "BOTTOMRIGHT")
	p[5]:SetPoint("BOTTOMRIGHT", p[9], "TOPLEFT")
	-- SetTexCoord(left, right, top, bottom)
	p[1]:SetTexCoord(0, m, 0, m)
	p[2]:SetTexCoord(m, n, 0, m)
	p[3]:SetTexCoord(n, 1, 0, m)
	p[4]:SetTexCoord(0, m, m, n)
	p[5]:SetTexCoord(m, n, m, n)
	p[6]:SetTexCoord(n, 1, m, n)
	p[7]:SetTexCoord(0, m, n, 1)
	p[8]:SetTexCoord(m, n, n, 1)
	p[9]:SetTexCoord(n, 1, n, 1)
end

function Slice:SetColor(r, g, b, a)
	for i = 1, 9 do
		self.parts[i]:SetVertexColor(r, g, b, a)
	end
end

function Slice:SetShown(shown)
	for i = 1, 9 do
		self.parts[i]:SetShown(shown)
	end
end

W.NewSlice = newSlice

-- ---------------------------------------------------------------------------
-- Panel: a frame with a themed shape. style = {
--   shape  = shape role in the theme ("card", "button", "tile", ...)
--   fill, line, top = colour roles for the body, the border and the top highlight
--   shadow = colour role for a soft shadow or glow behind it; shadowSize = its reach }
-- A colour role may also be a colour table. Leave a field out to not draw that layer.

local LAYERS = {
	shadow = { "BACKGROUND", -8 },
	fill = { "BACKGROUND", -6 },
	line = { "BORDER", 0 },
	top = { "BORDER", 1 },
}

local function paint(frame, key, file, m, corner, outset, role)
	local slice = frame.slices[key]
	local r, g, b, a = Theme:Color(role)
	if not r then
		if slice then
			slice:SetShown(false)
		end
		return
	end
	if not slice then
		slice = newSlice(frame, LAYERS[key][1], LAYERS[key][2])
		frame.slices[key] = slice
	end
	slice:Layout(file, m, corner, outset)
	slice:SetColor(r, g, b, a)
	slice:SetShown(true)
end

local function panelRestyle(frame)
	local theme, style = Theme.current, frame.style
	if not theme or not style then
		return
	end
	local shape = theme.shapes[style.shape] or theme.shapes.card
	local corner = shape.corner
	if shape.round then
		corner = math.min(frame:GetWidth(), frame:GetHeight()) / 2
	end
	paint(frame, "fill", shape.file .. "-fill", shape.m, corner, 0, style.fill)
	paint(frame, "line", shape.file .. "-line", shape.m, corner, 0, style.line)
	paint(frame, "top", shape.file .. "-top", shape.m, corner, 0, style.top)
	-- The shadow texture is a blurred block inset 40 of 128 px, sliced at 60 px.
	local reach = style.shadowSize or 30
	paint(frame, "shadow", MEDIA .. "shadow", 60 / 128, reach * 1.5, reach, style.shadow)
end

-- Changes some style fields and repaints.
local function panelSetStyle(frame, changes)
	frame.style = frame.style or {}
	for key, value in pairs(changes) do
		frame.style[key] = value or nil
	end
	panelRestyle(frame)
end

function W.Panel(parent, style, frameType, name)
	local frame = CreateFrame(frameType or "Frame", name, parent)
	frame.slices = {}
	frame.style = {}
	frame.Restyle = panelRestyle
	frame.SetStyle = panelSetStyle
	-- Round shapes take their corner size from the frame, so repaint when it changes.
	frame:SetScript("OnSizeChanged", function(self)
		local theme, look = Theme.current, self.style
		local shape = theme and look and theme.shapes[look.shape]
		if shape and shape.round then
			panelRestyle(self)
		end
	end)
	Theme:Track(frame)
	if style then
		frame:SetStyle(style)
	end
	return frame
end

-- ---------------------------------------------------------------------------
-- Text. kind: "head", "body", "button" or "label" (label is always in capitals).
-- role: colour role. Use :SetLabel(text) so capitals follow the theme.

local function textRestyle(text)
	local theme, style = Theme.current, text.style
	if not theme then
		return
	end
	local font = theme.font[style.kind] or theme.font.body
	text:SetFont(font.file, style.size * font.scale, style.flags or "")
	local r, g, b, a = Theme:Color(style.role)
	if r then
		text:SetTextColor(r, g, b, a)
	end
	if style.shadow then
		text:SetShadowColor(0, 0, 0, 0.65)
		text:SetShadowOffset(1, -1)
	else
		text:SetShadowOffset(0, 0)
	end
	if text.raw then
		text:SetText(font.upper and text.raw:upper() or text.raw)
	end
end

local function textSetLabel(text, value)
	text.raw = value ~= nil and tostring(value) or ""
	local theme = Theme.current
	local font = theme and (theme.font[text.style.kind] or theme.font.body)
	text:SetText(font and font.upper and text.raw:upper() or text.raw)
end

local function textSetRole(text, role)
	if text.style.role ~= role then
		text.style.role = role
		textRestyle(text)
	end
end

function W.Text(parent, kind, size, role, opts)
	local text = parent:CreateFontString(nil, opts and opts.layer or "OVERLAY")
	if GameFontHighlight then
		text:SetFontObject(GameFontHighlight) -- a valid font before the first SetText
	end
	text.style = {
		kind = kind or "body", size = size or 12, role = role or "ink",
		shadow = opts and opts.shadow, flags = opts and opts.flags,
	}
	text.Restyle = textRestyle
	text.SetLabel = textSetLabel
	text.SetRole = textSetRole
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	if opts and opts.width then
		text:SetWidth(opts.width)
		text:SetWordWrap(true)
	else
		text:SetWordWrap(false)
	end
	Theme:Track(text)
	text:Restyle()
	return text
end

-- The height a text takes once it has wrapped, so a page can stack what follows under it.
-- The game answers after SetText; where it does not, the letter count gives an estimate.
function W.TextHeight(text)
	local height = text.GetStringHeight and C.Plain(text:GetStringHeight(), nil)
	if type(height) == "number" and height > 0 then
		return height
	end
	local size = text.style and text.style.size or 12
	local width = C.Plain(text:GetWidth(), 0)
	local lines = 1
	if type(width) == "number" and width > 0 then
		lines = math.max(1, math.ceil(#(text.raw or "") * size * 0.5 / width))
	end
	return lines * size * 1.2
end

-- ---------------------------------------------------------------------------
-- Icon: a white glyph from Media, tinted with a colour role.

local function iconRestyle(icon)
	local r, g, b, a = Theme:Color(icon.role)
	if r then
		icon:SetVertexColor(r, g, b, a)
	end
end

local function iconSetRole(icon, role)
	icon.role = role
	iconRestyle(icon)
end

function W.Icon(parent, name, size, role, layer)
	local icon = parent:CreateTexture(nil, layer or "ARTWORK")
	icon:SetTexture(MEDIA .. "icon-" .. name)
	icon:SetSize(size, size)
	icon.role = role or "ink"
	icon.Restyle = iconRestyle
	icon.SetRole = iconSetRole
	Theme:Track(icon)
	icon:Restyle()
	return icon
end

-- A plain tinted texture (any Media file), for rings, glows and bars.
function W.Tint(parent, file, role, layer, sublevel)
	local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
	texture:SetTexture(MEDIA .. file)
	texture.role = role
	texture.Restyle = iconRestyle
	texture.SetRole = iconSetRole
	Theme:Track(texture)
	texture:Restyle()
	return texture
end

-- A flat block of one colour role (stripes, markers, divider lines).
local function fillRestyle(texture)
	local r, g, b, a = Theme:Color(texture.role)
	texture:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
end

function W.Fill(parent, role, layer, sublevel)
	local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
	texture.role = role
	texture.Restyle = fillRestyle
	texture.SetRole = function(self, newRole)
		self.role = newRole
		fillRestyle(self)
	end
	Theme:Track(texture)
	texture:Restyle()
	return texture
end

-- ---------------------------------------------------------------------------
-- Button. kind "primary" is the one main action on a card; "ghost" is an outlined
-- secondary action in a colour role (opts.role). opts: icon, width, height, onClick.

local BUTTON_PAD = 16

local function buttonLook(button)
	local hover = button.hover and button:IsEnabled()
	if button.kind == "primary" then
		button:SetStyle({
			shape = "button", fill = hover and "primaryHover" or "primary", line = "primaryLine",
			shadow = "primaryGlow", shadowSize = 12,
		})
		button.label:SetRole("primaryInk")
		if button.icon then
			button.icon:SetRole("primaryInk")
		end
	else
		-- shadow = false: a button that was the main action a moment ago loses its glow.
		button:SetStyle({ shape = "button", fill = hover and "ghostHover" or "ghost", line = button.role, shadow = false })
		button.label:SetRole(button.role)
		if button.icon then
			button.icon:SetRole(button.role)
		end
	end
	button:SetAlpha(button:IsEnabled() and 1 or 0.45)
end

local function buttonAfterRestyle(button)
	if button.fixedWidth then
		return
	end
	local width = button.label:GetStringWidth() + BUTTON_PAD * 2
	if button.icon then
		width = width + button.icon:GetWidth() + 6
	end
	button:SetWidth(math.max(width, 64))
end

local function buttonSetLabel(button, text)
	button.label:SetLabel(text)
	buttonAfterRestyle(button)
end

local function buttonSetKind(button, kind, role)
	button.kind, button.role = kind, role or button.role
	buttonLook(button)
end

function W.Button(parent, text, kind, opts)
	opts = opts or {}
	local button = W.Panel(parent, nil, "Button")
	button.kind = kind or "ghost"
	button.role = opts.role or "accentText"
	button:SetHeight(opts.height or 30)
	button.label = W.Text(button, "button", opts.size or 12, "ink")
	if opts.icon then
		button.icon = W.Icon(button, opts.icon, 14, "ink")
		button.icon:SetPoint("RIGHT", button, "RIGHT", -BUTTON_PAD + 2, 0)
		button.label:SetPoint("LEFT", button, "LEFT", BUTTON_PAD, 0)
	else
		button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
	end
	if opts.width then
		button.fixedWidth = true
		button:SetWidth(opts.width)
	end
	button.AfterRestyle = buttonAfterRestyle
	button.SetLabel = buttonSetLabel
	button.SetKind = buttonSetKind
	button:SetScript("OnEnter", function(self)
		self.hover = true
		buttonLook(self)
	end)
	button:SetScript("OnLeave", function(self)
		self.hover = false
		buttonLook(self)
	end)
	button:SetScript("OnEnable", buttonLook)
	button:SetScript("OnDisable", buttonLook)
	button:SetScript("OnClick", function(self)
		C.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		if self.onClick then
			T.SafeCall("button", self.onClick, self)
		end
	end)
	button.onClick = opts.onClick
	buttonLook(button)
	button:SetLabel(text)
	return button
end

-- A small square button that is only an icon (settings, close, steppers).
function W.IconButton(parent, icon, size, role, onClick)
	local button = W.Panel(parent, { shape = "small" }, "Button")
	button:SetSize(size, size)
	button.icon = W.Icon(button, icon, math.floor(size * 0.58), role or "barIcon")
	button.icon:SetPoint("CENTER")
	button.onClick = onClick
	button:SetScript("OnEnter", function(self)
		self:SetStyle({ fill = self.hoverRole or "barHover" })
	end)
	button:SetScript("OnLeave", function(self)
		self:SetStyle({ fill = false })
	end)
	button:SetScript("OnClick", function(self)
		C.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		if self.onClick then
			T.SafeCall("iconbutton", self.onClick, self)
		end
	end)
	return button
end

-- ---------------------------------------------------------------------------
-- Bar: a rounded track with up to two fills (the second sits under the first; used for
-- rested experience behind experience).

local function threePart(frame, layer, sublevel, role)
	local set = { role = role }
	for i = 1, 3 do
		local part = frame:CreateTexture(nil, layer, nil, sublevel)
		part:SetTexture(MEDIA .. "bar")
		if part.SetSnapToPixelGrid then
			part:SetSnapToPixelGrid(false)
		end
		if part.SetTexelSnappingBias then
			part:SetTexelSnappingBias(0)
		end
		set[i] = part
	end
	set[1]:SetTexCoord(0, 0.25, 0, 1)
	set[2]:SetTexCoord(0.25, 0.75, 0, 1)
	set[3]:SetTexCoord(0.75, 1, 0, 1)
	return set
end

local function layoutParts(set, frame, width)
	local height = frame:GetHeight()
	local cap = height / 2
	local shown = width >= 1
	width = math.max(width, height)
	for i = 1, 3 do
		set[i]:ClearAllPoints()
		set[i]:SetShown(shown)
	end
	set[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	set[1]:SetSize(cap, height)
	set[2]:SetPoint("TOPLEFT", set[1], "TOPRIGHT", 0, 0)
	set[2]:SetSize(math.max(width - height, 0.01), height)
	set[3]:SetPoint("TOPLEFT", set[2], "TOPRIGHT", 0, 0)
	set[3]:SetSize(cap, height)
end

local function barRestyle(bar)
	for _, set in ipairs(bar.sets) do
		local r, g, b, a = Theme:Color(set.role)
		for i = 1, 3 do
			set[i]:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
		end
	end
end

-- value and under are fractions from 0 to 1; under is the total reach of the second fill.
local function barSet(bar, value, under)
	local width = bar:GetWidth()
	value = math.min(math.max(value or 0, 0), 1)
	under = math.min(math.max(under or 0, 0), 1)
	layoutParts(bar.sets[1], bar, width)
	layoutParts(bar.sets[2], bar, under > value and width * under or 0)
	layoutParts(bar.sets[3], bar, width * value)
end

function W.Bar(parent, width, height, fillRole, underRole)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetSize(width, height or 8)
	bar.sets = {
		threePart(bar, "ARTWORK", 0, "track"),
		threePart(bar, "ARTWORK", 1, underRole or "rest"),
		threePart(bar, "ARTWORK", 2, fillRole or "xp"),
	}
	bar.Restyle = barRestyle
	bar.Set = barSet
	Theme:Track(bar)
	bar:Restyle()
	bar:Set(0, 0)
	return bar
end

-- ---------------------------------------------------------------------------
-- Chip: a small pill with an icon, a quiet label and a value. Sizes itself to its text.

local function chipFit(chip)
	local width = 10 + 13 + 6 + chip.value:GetStringWidth() + 10
	if (chip.label.raw or "") ~= "" then
		width = width + chip.label:GetStringWidth() + 5
	end
	chip:SetWidth(width)
end

local function chipSet(chip, label, value)
	chip.label:SetLabel(label or "")
	chip.value:SetLabel(value or "")
	chip.value:ClearAllPoints()
	if (label or "") ~= "" then
		chip.value:SetPoint("LEFT", chip.label, "RIGHT", 5, 0)
	else
		chip.value:SetPoint("LEFT", chip.icon, "RIGHT", 6, 0)
	end
	chipFit(chip)
end

function W.Chip(parent, icon)
	local chip = W.Panel(parent, { shape = "chip", fill = "chip", line = "chipLine" })
	chip:SetHeight(24)
	chip.icon = W.Icon(chip, icon, 13, "accent")
	chip.icon:SetPoint("LEFT", chip, "LEFT", 10, 0)
	chip.label = W.Text(chip, "body", 11, "heroMuted")
	chip.label:SetPoint("LEFT", chip.icon, "RIGHT", 6, 0)
	chip.value = W.Text(chip, "body", 11, "heroText")
	chip.Set = chipSet
	chip.AfterRestyle = chipFit
	chip:Set("", "")
	return chip
end

-- ---------------------------------------------------------------------------
-- Icon tile: an icon on a small themed tile (cards, placeholders).

function W.IconTile(parent, icon, size, role)
	local tile = W.Panel(parent)
	tile:SetSize(size, size)
	tile:SetStyle({ shape = "tile", fill = "tile", line = "tileLine" })
	tile.icon = W.Icon(tile, icon, math.floor(size * 0.5), role or "accent")
	tile.icon:SetPoint("CENTER")
	return tile
end

-- ---------------------------------------------------------------------------
-- Card: the "What now?" building block. A coloured stripe on the left says what kind of
-- card it is: go (do this now), warn (worth fixing), info (optional).

local function cardSet(card, title, body)
	card.title:SetLabel(title)
	card.body:SetLabel(body)
end

-- Changes what kind of card it is: the stripe and icon colour, and optionally the icon.
local function cardSetTone(card, tone, icon)
	card.stripe:SetRole(tone)
	card.tile.icon:SetRole(tone)
	if icon then
		card.tile.icon:SetTexture(MEDIA .. "icon-" .. icon)
	end
end

function W.Card(parent, width, height, tone, icon)
	local card = W.Panel(parent, { shape = "card", fill = "card", line = "cardLine", top = "cardTop" })
	card:SetSize(width, height)
	card.stripe = W.Fill(card, tone or "info")
	card.stripe:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -14)
	card.stripe:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 1, 14)
	card.stripe:SetWidth(3)
	card.tile = W.IconTile(card, icon or "spark", 48, tone or "info")
	card.tile:SetPoint("LEFT", card, "LEFT", 18, 0)
	card.title = W.Text(card, "head", 15, "ink")
	card.title:SetPoint("TOPLEFT", card.tile, "TOPRIGHT", 14, 1)
	card.body = W.Text(card, "body", 11.5, "muted", { width = width - 48 - 18 - 14 - 18 })
	card.body:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -6)
	card.body:SetSpacing(3)
	card.Set = cardSet
	card.SetTone = cardSetTone
	return card
end

-- Reserves room on the right of a card for a button and narrows the text to fit.
function W.CardAction(card, button)
	button:SetParent(card)
	button:ClearAllPoints()
	button:SetPoint("RIGHT", card, "RIGHT", -18, 0)
	card.action = button
	local function fit()
		if button.AfterRestyle then
			button:AfterRestyle() -- its width first; it may be later in the restyle order
		end
		local reserved = button:IsShown() and (button:GetWidth() + 14) or 0
		local room = card:GetWidth() - 48 - 18 - 14 - 18 - reserved
		card.body:SetWidth(room)
		card.title:SetWidth(room) -- one line; a title too long for the room ends in "..."
	end
	card.AfterRestyle = fit
	fit()
end

-- ---------------------------------------------------------------------------
-- Pill: a small on/off button for filters and categories. :SetOn(true) marks it chosen.

local function pillLook(pill)
	local on = pill.on
	pill:SetStyle({
		shape = "chip",
		fill = on and "accent" or (pill.hover and "cardHover" or "card"),
		line = on and "accent" or "cardLine",
	})
	pill.label:SetRole(on and "accentInk" or "ink")
	if pill.icon then
		pill.icon:SetRole(on and "accentInk" or "muted")
	end
end

local function pillFit(pill)
	pill:SetWidth(pill.label:GetStringWidth() + (pill.icon and 42 or 24))
end

function W.Pill(parent, text, icon, onClick)
	local pill = W.Panel(parent, nil, "Button")
	pill:SetHeight(28)
	pill.label = W.Text(pill, "body", 11.5, "ink")
	if icon then
		pill.icon = W.Icon(pill, icon, 14, "muted")
		pill.icon:SetPoint("LEFT", pill, "LEFT", 11, 0)
		pill.label:SetPoint("LEFT", pill.icon, "RIGHT", 6, 0)
	else
		pill.label:SetPoint("LEFT", pill, "LEFT", 12, 0)
	end
	pill.label:SetLabel(text)
	pill.onClick = onClick
	pill.AfterRestyle = pillFit
	pill.SetOn = function(self, on)
		self.on = on and true or false
		pillLook(self)
	end
	pill:SetScript("OnEnter", function(self)
		self.hover = true
		pillLook(self)
	end)
	pill:SetScript("OnLeave", function(self)
		self.hover = false
		pillLook(self)
	end)
	pill:SetScript("OnClick", function(self)
		C.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		if self.onClick then
			T.SafeCall("pill", self.onClick, self)
		end
	end)
	pillLook(pill)
	pillFit(pill)
	return pill
end

-- ---------------------------------------------------------------------------
-- Search box. onChange(text, typed) runs whenever the text changes; `typed` is true when
-- the player typed it. :SetQuery(text) and :GetQuery() read and write it.

function W.Search(parent, width, height, placeholder, onChange)
	local box = W.Panel(parent, { shape = "button", fill = "field", line = "fieldLine" })
	box:SetSize(width, height)
	box.icon = W.Icon(box, "search", 14, "fieldMuted")
	box.icon:SetPoint("LEFT", box, "LEFT", 12, 0)

	local edit = CreateFrame("EditBox", nil, box)
	edit:SetPoint("LEFT", box.icon, "RIGHT", 8, 0)
	edit:SetPoint("RIGHT", box, "RIGHT", -32, 0)
	edit:SetHeight(height - 8)
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(60)
	if GameFontHighlight then
		edit:SetFontObject(GameFontHighlight)
	end
	edit.Restyle = function(self)
		local theme = Theme.current
		if not theme then
			return
		end
		self:SetFont(theme.font.body.file, 12, "")
		local r, g, b = Theme:Color("fieldText")
		self:SetTextColor(r or 1, g or 1, b or 1)
	end
	Theme:Track(edit)
	edit:Restyle()

	box.hint = W.Text(box, "body", 12, "fieldMuted")
	box.hint:SetPoint("LEFT", edit, "LEFT", 0, 0)
	box.hint:SetLabel(placeholder)
	box.clear = W.IconButton(box, "x", 20, "fieldMuted", function()
		edit:SetText("")
		edit:ClearFocus()
		if box.onChange then
			T.SafeCall("search", box.onChange, "", true) -- emptied by the player, not by code
		end
	end)
	box.clear:SetPoint("RIGHT", box, "RIGHT", -7, 0)
	box.clear:Hide()

	edit:SetScript("OnTextChanged", function(self, typed)
		local text = self:GetText() or ""
		box.hint:SetShown(text == "")
		box.clear:SetShown(text ~= "")
		if box.onChange then
			T.SafeCall("search", box.onChange, text, typed and true or false)
		end
	end)
	edit:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	edit:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	edit:SetScript("OnEditFocusGained", function()
		box:SetStyle({ line = "accent" })
	end)
	edit:SetScript("OnEditFocusLost", function()
		box:SetStyle({ line = "fieldLine" })
	end)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function()
		edit:SetFocus()
	end)

	box.edit = edit
	box.onChange = onChange
	box.SetQuery = function(_, text)
		edit:SetText(text or "")
	end
	box.GetQuery = function()
		return edit:GetText() or ""
	end
	return box
end

-- ---------------------------------------------------------------------------
-- List: a fixed column of rows showing part of a longer list; the mouse wheel scrolls.
-- make(list, width) builds one row: a frame with :Fill(item). Rows are reused, so a list
-- of any length costs the same.

local function listRefresh(list)
	local count, visible = #list.items, list.visible
	local last = math.max(0, count - visible)
	list.offset = math.min(math.max(list.offset, 0), last)
	for index = 1, visible do
		local row, item = list.rows[index], list.items[list.offset + index]
		row:SetShown(item ~= nil)
		if item then
			row.item = item
			row:Fill(item)
		end
	end
	local scrolls = count > visible
	list.rail:SetShown(scrolls)
	list.thumb:SetShown(scrolls)
	if scrolls then
		local height = list:GetHeight()
		local size = math.max(24, height * visible / count)
		list.thumb:SetHeight(size)
		list.thumb:ClearAllPoints()
		list.thumb:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -(height - size) * list.offset / last)
	end
end

function W.List(parent, width, height, rowHeight, gap, make)
	local list = CreateFrame("Frame", nil, parent)
	list:SetSize(width, height)
	list.rows, list.items, list.offset = {}, {}, 0
	-- As many rows as the height holds. Resize makes more when the list is given more room
	-- (the Find page, once it knows how many lines its category buttons took).
	local function fit(tall)
		list.visible = math.max(1, math.floor((tall + gap) / (rowHeight + gap)))
		for index = #list.rows + 1, list.visible do
			local row = make(list, width - 12)
			row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(index - 1) * (rowHeight + gap))
			row:Hide()
			list.rows[index] = row
		end
		for index = list.visible + 1, #list.rows do
			list.rows[index]:Hide()
		end
	end
	fit(height)
	list.rail = W.Fill(list, "track", "ARTWORK", 0)
	list.rail:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, 0)
	list.rail:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)
	list.rail:SetWidth(3)
	list.thumb = W.Fill(list, "accent", "ARTWORK", 1)
	list.thumb:SetWidth(3)
	list.Refresh = listRefresh
	list.Resize = function(self, tall)
		if tall ~= self:GetHeight() then
			self:SetHeight(tall)
			fit(tall)
			listRefresh(self)
		end
	end
	-- keep = true stays at the current scroll position (for a refresh of the same list).
	list.SetItems = function(self, items, keep)
		self.items = items or {}
		if not keep then
			self.offset = 0
		end
		listRefresh(self)
	end
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(self, delta)
		self.offset = self.offset - (delta or 0)
		listRefresh(self)
	end)
	listRefresh(list)
	return list
end

-- A square picture from the game (a spell icon), edges trimmed. :SetIcon(fileID).
function W.GameIcon(parent, size)
	local icon = parent:CreateTexture(nil, "ARTWORK")
	icon:SetSize(size, size)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon.SetIcon = function(self, file)
		self:SetTexture(file or 134400) -- 134400 is the game's question-mark icon
	end
	return icon
end
