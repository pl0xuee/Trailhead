local _, T = ...
local L = T.L

-- The things a new player goes looking for. `track` is the icon file of the game's own
-- minimap tracking entry for it (the same number in every language), `words` are extra
-- search terms, and `home` puts it in the "Find nearby" grid on the Home page.

T.Categories = {
	{ id = "trainer", label = L["Class trainer"], short = L["Trainer"], icon = "cap", track = 136455, home = true,
		words = L["spells train abilities ranks learn"] },
	{ id = "vendor", label = L["Vendor"], short = L["Vendor"], icon = "bag", home = true,
		words = L["shop sell buy merchant food drink junk supplies"] },
	{ id = "repair", label = L["Repair"], short = L["Repair"], icon = "hammer", track = 136465, home = true,
		words = L["armor weapon broken durability smith fix"] },
	{ id = "inn", label = L["Inn"], short = L["Inn"], icon = "bed", track = 136458, home = true,
		words = L["innkeeper hearthstone rest home tavern"] },
	{ id = "flight", label = L["Flight master"], short = L["Flight"], icon = "wing", track = 136456, home = true,
		words = L["fly flight path taxi gryphon wind rider travel"] },
	{ id = "mailbox", label = L["Mailbox"], short = L["Mailbox"], icon = "mail", track = 136459, home = true,
		words = L["mail post letter"] },
	{ id = "bank", label = L["Bank"], short = L["Bank"], icon = "bank", track = 136453, home = true,
		words = L["banker storage vault"] },
	{ id = "professions", label = L["Profession trainer"], short = L["Crafting"], icon = "pick", track = 136463, home = true,
		words = L["crafting tradeskill gathering mining herbalism skinning cooking fishing first aid"] },
	{ id = "auction", label = L["Auction house"], short = L["Auction"], icon = "coin", track = 136452,
		words = L["auctioneer trade market"] },
	{ id = "weapons", label = L["Weapon master"], short = L["Weapons"], icon = "sword",
		words = L["weapon master skill learn sword axe mace dagger staff bow gun crossbow polearm thrown fist"] },
	{ id = "riding", label = L["Riding trainer"], short = L["Riding"], icon = "shoe",
		words = L["mount riding ride horse wolf raptor kodo ram tiger vendor"] },
	{ id = "stable", label = L["Stable master"], short = L["Stable"], icon = "shoe", track = 136466,
		words = L["pet hunter stable"] },
	-- Anything a guard pointed to that fits nowhere above. Found by name in the search.
	{ id = "other", label = L["Other places"], short = L["Other"], icon = "pin", hidden = true, words = "" },
}

T.CategoryById = {}
for _, category in ipairs(T.Categories) do
	T.CategoryById[category.id] = category
end
