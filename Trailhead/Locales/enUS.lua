local _, T = ...

-- English is the key language: L["Some text"] returns "Some text" unless a locale file
-- loaded after this one replaces it. Every string shown to the player goes through L.
T.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
