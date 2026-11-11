local _, T = ...
local L = T.L

-- Themes. A theme is a set of colours, shapes and fonts; widgets name a role ("card",
-- "accent", "ink") and never a colour, so switching theme restyles everything live.

local Theme = {}
T.Theme = Theme

local MEDIA = "Interface\\AddOns\\Trailhead\\Media\\"
Theme.MEDIA = MEDIA

local function rgb(hex, alpha)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
		alpha or 1,
	}
end

-- Shape textures are 64 px and drawn at half size. margin = slice margin in texture
-- pixels; corner = the same margin in UI units.
local function shape(file, margin)
	return { file = MEDIA .. file, m = margin / 64, corner = margin / 2 }
end
local SHAPES = {
	r12 = shape("r12", 28),
	r7 = shape("r7", 18),
	r4 = shape("r4", 12),
	r2 = shape("r2", 8),
	cut10 = shape("cut10", 24),
	cutb6 = shape("cutb6", 16),
	circle = { file = MEDIA .. "circle", m = 0.5, round = true },
}

Theme.order = { "night", "journal", "ember" }

Theme.defs = {
	night = {
		id = "night",
		name = L["Night"],
		blurb = L["Navy and gold, soft and rounded"],
		hero = MEDIA .. "hero-night",
		fonts = { head = "GameFontNormal", body = "GameFontHighlight" },
		shapes = {
			window = "r12", page = "r12", card = "r12", hero = "r12", button = "r12", tab = "r7",
			tile = "r12", chip = "r7", logo = "r7", small = "r4",
		},
		c = {
			window = rgb("10152a"), windowLine = rgb("33406a"), windowTop = rgb("ffffff", 0.10),
			shadow = rgb("000000", 0.75),
			barText = rgb("f3efe2"), barMuted = rgb("8791b3"), barIcon = rgb("a9b3d6"),
			barHover = rgb("ffffff", 0.07),
			logo = rgb("f2b24a"), logoInk = rgb("2a1a05"), logoGlow = rgb("f5b446", 0.35),
			railText = rgb("7c86a8"), tabHover = rgb("ffffff", 0.05),
			tabOn = rgb("242d52"), tabOnTop = rgb("ffffff", 0.12), tabOnText = rgb("ffe2a0"), tabMark = rgb("f6bd55"),
			page = rgb("161c33"), pageLine = rgb("27304f"),
			ink = rgb("f1eee4"), muted = rgb("8f99ba"), faint = rgb("5d6788"),
			accent = rgb("f6bd55"), accentInk = rgb("2a1a05"), accentText = rgb("f6bd55"),
			go = rgb("5fe0a0"), warn = rgb("f6bd55"), info = rgb("7fb2ff"),
			heroLine = rgb("3a4877"), heroText = rgb("fff8e8"), heroMuted = rgb("b9c2e0"),
			ring = rgb("000000", 0.40), ringLine = rgb("f6bd55"),
			xp = rgb("9a7bff"), rest = rgb("6fd0ff"), track = rgb("000000", 0.50),
			chip = rgb("0a0d1c", 0.66), chipLine = rgb("ffffff", 0.16),
			card = rgb("1b223d"), cardLine = rgb("2f3b63"), cardTop = rgb("ffffff", 0.07),
			cardHover = rgb("222b4b"),
			tile = rgb("0c1120"), tileLine = rgb("34416d"),
			primary = rgb("56d697"), primaryHover = rgb("7df0b4"), primaryInk = rgb("052416"),
			primaryLine = rgb("8ff5c2"), primaryGlow = rgb("5fe0a0", 0.40),
			ghost = rgb("ffffff", 0.03), ghostHover = rgb("ffffff", 0.09),
			tip = rgb("ffffff", 0.03), tipLine = rgb("28324f"), tipText = rgb("aeb7d4"),
			tipIcon = rgb("f6bd55", 0.14),
			field = rgb("0a0d1c", 0.85), fieldLine = rgb("33406a"), fieldText = rgb("f1eee4"), fieldMuted = rgb("7c86a8"),
		},
	},

	journal = {
		id = "journal",
		name = L["Journal"],
		blurb = L["Parchment and leather, classic Warcraft"],
		hero = MEDIA .. "hero-journal",
		parchment = true,
		fonts = { head = "QuestTitleFont", headScale = 1.12, body = "GameFontHighlight" },
		shapes = {
			window = "r7", page = "r4", card = "r4", hero = "r4", button = "r4", tab = "r4",
			tile = "circle", chip = "r4", logo = "circle", small = "r4",
		},
		c = {
			window = rgb("2c1d12"), windowLine = rgb("b08a45"), windowTop = rgb("e6c27a", 0.30),
			shadow = rgb("000000", 0.80),
			barText = rgb("f4e4bd"), barMuted = rgb("b79a68"), barIcon = rgb("d9bf8c"),
			barHover = rgb("f4e4bd", 0.10),
			logo = rgb("b9352b"), logoInk = rgb("ffe7c2"), logoGlow = rgb("000000", 0.45),
			railText = rgb("b79a68"), tabHover = rgb("f4e4bd", 0.08),
			tabOn = rgb("e8d09c"), tabOnTop = rgb("ffffff", 0.45), tabOnText = rgb("4a2a12"), tabMark = rgb("b9352b"),
			page = rgb("ecdcb2"), pageLine = rgb("8c6a32"),
			ink = rgb("3a2413"), muted = rgb("7a6140"), faint = rgb("9b8560"),
			accent = rgb("b8862b"), accentInk = rgb("fff3d6"), accentText = rgb("8c5f12"),
			go = rgb("3f7d3a"), warn = rgb("b86a12"), info = rgb("2f5f8f"),
			heroLine = rgb("8c6a32"), heroText = rgb("fbeccb"), heroMuted = rgb("dcc59a"),
			ring = rgb("26180c", 0.50), ringLine = rgb("d8a545"),
			xp = rgb("d8ae4c"), rest = rgb("9fd0e8"), track = rgb("000000", 0.40),
			chip = rgb("26180c", 0.62), chipLine = rgb("f0d6a0", 0.40),
			card = rgb("fffaea", 0.72), cardLine = rgb("b99b63"), cardTop = rgb("ffffff", 0.55),
			cardHover = rgb("fffdf2", 0.92),
			tile = rgb("f8ecc8"), tileLine = rgb("a8853f"),
			primary = rgb("a82a21"), primaryHover = rgb("c23a2f"), primaryInk = rgb("ffe9c9"),
			primaryLine = rgb("6a1711"), primaryGlow = rgb("5a120d", 0.30),
			ghost = rgb("fffaea", 0.50), ghostHover = rgb("fffdf2", 0.95),
			tip = rgb("5a3c19", 0.10), tipLine = rgb("b99b63"), tipText = rgb("5c4526"),
			tipIcon = rgb("b8862b", 0.22),
			field = rgb("1a1009", 0.80), fieldLine = rgb("8c6a32"), fieldText = rgb("f4e4bd"), fieldMuted = rgb("b79a68"),
		},
	},

	ember = {
		id = "ember",
		name = L["Ember"],
		blurb = L["Charcoal and orange, sharp and bold"],
		hero = MEDIA .. "hero-ember",
		upper = true, -- headings and buttons in capitals
		fonts = { head = "GameFontNormal", body = "GameFontHighlight" },
		shapes = {
			window = "r2", page = "r2", card = "cut10", hero = "r2", button = "cutb6", tab = "r2",
			tile = "r2", chip = "r2", logo = "r2", small = "r2",
		},
		c = {
			window = rgb("151111"), windowLine = rgb("57463c"), windowTop = rgb("ff7a2f", 0.95),
			shadow = rgb("000000", 0.80),
			barText = rgb("fff3e6"), barMuted = rgb("9a8b80"), barIcon = rgb("c4b3a6"),
			barHover = rgb("ffffff", 0.07),
			logo = rgb("f2702c"), logoInk = rgb("1a0b06"), logoGlow = rgb("ff6e28", 0.40),
			railText = rgb("8a7b70"), tabHover = rgb("ffffff", 0.05),
			tabOn = rgb("ff7a2f", 0.18), tabOnTop = nil, tabOnText = rgb("ffb27a"), tabMark = rgb("ff7a2f"),
			page = rgb("1b1716"), pageLine = rgb("322925"),
			ink = rgb("fbeee2"), muted = rgb("a09186"), faint = rgb("6e625a"),
			accent = rgb("ff7a2f"), accentInk = rgb("1a0b06"), accentText = rgb("ff9a55"),
			go = rgb("ffb02e"), warn = rgb("ff6a3d"), info = rgb("54c7d9"),
			heroLine = rgb("5a3a2a"), heroText = rgb("fff3e6"), heroMuted = rgb("e0c4b0"),
			ring = rgb("000000", 0.45), ringLine = rgb("ff7a2f"),
			xp = rgb("ff9a3a"), rest = rgb("54c7d9"), track = rgb("000000", 0.55),
			chip = rgb("0e0908", 0.72), chipLine = rgb("ffa064", 0.30),
			card = rgb("221c1a"), cardLine = rgb("3d322c"), cardTop = nil,
			cardHover = rgb("2b2421"),
			tile = rgb("0f0c0c"), tileLine = rgb("3d322c"),
			primary = rgb("ff9a2a"), primaryHover = rgb("ffc04a"), primaryInk = rgb("221000"),
			primaryLine = rgb("ffd27a"), primaryGlow = rgb("ff9628", 0.42),
			ghost = rgb("000000", 0), ghostHover = rgb("ffffff", 0.07),
			tip = rgb("120f0f"), tipLine = rgb("3a302b"), tipText = rgb("b8a99d"),
			tipIcon = rgb("ff7a2f", 0.16),
			field = rgb("0d0a0a"), fieldLine = rgb("3d322c"), fieldText = rgb("fbeee2"), fieldMuted = rgb("8a7b70"),
		},
	},
}

-- Resolve shape names to shape tables once.
for _, def in pairs(Theme.defs) do
	for role, name in pairs(def.shapes) do
		def.shapes[role] = SHAPES[name]
	end
end

-- Fonts come from the game's own font objects, so every language gets a font that can
-- draw it. Looked up when a theme is applied, because font objects can change with locale.
local function fontFile(objectName)
	local object = _G[objectName] or GameFontNormal
	local file = object and object.GetFont and object:GetFont()
	return file or "Fonts\\FRIZQT__.TTF"
end

local styled = {} -- every themed widget; each has :Restyle() and maybe :AfterRestyle()

function Theme:Track(widget)
	styled[#styled + 1] = widget
	return widget
end

-- Applies a theme. `quiet` skips saving and the change message (used at startup).
function Theme:Set(id, quiet)
	local def = self.defs[id] or self.defs.ember
	def.font = {
		head = { file = fontFile(def.fonts.head), scale = def.fonts.headScale or 1, upper = def.upper },
		body = { file = fontFile(def.fonts.body), scale = 1 },
		button = { file = fontFile(def.fonts.body), scale = 1, upper = def.upper },
		label = { file = fontFile(def.fonts.body), scale = 1, upper = true },
	}
	self.current = def
	if T.db then
		T.db.theme = def.id
	end
	for i = 1, #styled do
		styled[i]:Restyle()
	end
	-- Second pass: sizes that depend on restyled text (button widths and the like).
	for i = 1, #styled do
		local widget = styled[i]
		if widget.AfterRestyle then
			widget:AfterRestyle()
		end
	end
	if not quiet then
		T:Fire("TH_THEME_CHANGED", def.id)
	end
end

-- r, g, b, a for a colour role (or a colour table); nil if the theme leaves it out.
function Theme:Color(role)
	local color = type(role) == "table" and role or (self.current and self.current.c[role])
	if not color then
		return nil
	end
	return color[1], color[2], color[3], color[4] or 1
end
