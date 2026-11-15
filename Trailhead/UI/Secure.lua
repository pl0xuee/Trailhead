local _, T = ...
local C = T.Compat

-- Secure: opens the game's own talent, spellbook and Legacy windows by pressing the game's own
-- menu bar button through a secure button, never by calling Blizzard's window code.
--
-- Why: code that an addon calls runs "tainted". When Trailhead itself opened the talent window,
-- that window loaded and showed tainted, its spell marks on the action buttons were tainted,
-- and from then on every action button failed to show cooldowns ("Secret values are only
-- allowed during untainted execution") until the next reload. A secure button's click is the
-- game's own, so the window opens exactly as it does from the menu bar.
--
-- How: while the mouse is over a Trailhead button that opens one of these windows, an invisible
-- secure button lies exactly over it and takes the click. It cannot live inside the Trailhead
-- window (that window hides in combat, and a window holding a secure button may not), so it
-- sits on the screen itself and only while hovered. Nothing here changes in combat.

local S = {}
T.Secure = S

-- tab: the game's PlayerSpellsUtil.FrameTabs entry the window must be on to count as open.
S.TARGETS = {
	talents = { button = "TalentMicroButton", frame = "PlayerSpellsFrame", tab = "ClassTalents" },
	spellbook = { button = "SpellbookMicroButton", frame = "PlayerSpellsFrame", tab = "SpellBook" },
	legacy = { button = "LegacyMicroButton", frame = "LegacySystemFrame" },
}

local cover -- the secure button: nil until first needed, false if the game would not make one
local owner -- the Trailhead button it lies over
local placed -- the owner's position when it was last laid over it

-- What happened lately, newest last, for /th check: the game check saves it so a cover that
-- does not take the click can be traced from the saved file.
S.log = {}
local function note(what)
	local log = S.log
	log[#log + 1] = ("%s %s"):format(date and date("%H:%M:%S") or "", tostring(what))
	if #log > 20 then
		table.remove(log, 1)
	end
end

local function target(id)
	local def = S.TARGETS[id]
	local button = def and _G[def.button]
	if type(button) == "table" and type(button.Click) == "function" then
		return def, button
	end
	return nil
end

-- True if this window can be opened the safe way.
function S.Can(id)
	return target(id) ~= nil and type(CreateFrame) == "function" and type(InCombatLockdown) == "function"
end

-- True if the window is already up on the right tab. The game's button toggles, and
-- "Open" must not close it. Only reads.
local function alreadyOpen(def)
	local frame = _G[def.frame]
	if type(frame) ~= "table" or type(frame.IsShown) ~= "function" or not frame:IsShown() then
		return false
	end
	if not def.tab then
		return true
	end
	local tabs = C.Resolve("PlayerSpellsUtil.FrameTabs")
	local tab = type(tabs) == "table" and tabs[def.tab]
	if tab == nil or type(frame.IsFrameTabActive) ~= "function" then
		return false
	end
	local ok, active = pcall(frame.IsFrameTabActive, frame, tab)
	return ok and active == true
end

local function rect(frame)
	local left, bottom = C.Plain(frame:GetLeft(), nil), C.Plain(frame:GetBottom(), nil)
	local width, height = C.Plain(frame:GetWidth(), nil), C.Plain(frame:GetHeight(), nil)
	local own, screen = C.Plain(frame:GetEffectiveScale(), nil), C.Plain(UIParent:GetEffectiveScale(), nil)
	if type(left) ~= "number" or type(bottom) ~= "number" or type(width) ~= "number" or type(height) ~= "number"
		or type(own) ~= "number" or type(screen) ~= "number" or screen <= 0 then
		return nil
	end
	local ratio = own / screen
	return left * ratio, bottom * ratio, width * ratio, height * ratio
end

local function place()
	local left, bottom, width, height = rect(owner)
	if not left then
		return false
	end
	local key = ("%.1f:%.1f:%.1f:%.1f"):format(left, bottom, width, height)
	if key ~= placed then
		placed = key
		cover:ClearAllPoints()
		cover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
		cover:SetSize(width, height)
	end
	return true
end

-- Lets go of the button it lies over. In combat the secure button cannot be hidden; it then
-- stays where it is, still only opening the game's window, until combat ends.
local function release()
	local was = owner
	owner, placed = nil, nil
	if cover and not C.InCombat() then
		cover:Hide()
	end
	return was
end

-- Trailhead's escape list: a centred game window closes everything on it when it opens, and
-- Trailhead should stay up beside it. Off the list for the click, back on right after.
local function offEscapeList()
	for i, name in ipairs(UISpecialFrames) do
		if name == "TrailheadWindow" then
			table.remove(UISpecialFrames, i)
			return true
		end
	end
	return false
end

local wasOnList = false

local function make()
	if cover ~= nil then
		return cover or nil
	end
	local ok, made = pcall(CreateFrame, "Button", "TrailheadSecureOpen", UIParent, "SecureActionButtonTemplate")
	if not ok or type(made) ~= "table" then
		cover = false
		note("make failed: " .. tostring(made))
		return nil
	end
	-- Said outright: a frame made by an addon is not sure to take the mouse until told.
	made:EnableMouse(true)
	made:RegisterForClicks("LeftButtonUp")
	made:SetAttribute("useOnKeyDown", false) -- act on the mouse coming up, like every Trailhead button
	made:Hide()
	made:SetScript("OnEnter", function()
		if owner then
			local enter = owner:GetScript("OnEnter")
			if enter then
				enter(owner)
			end
		end
	end)
	made:SetScript("OnLeave", function()
		local was = release()
		if was then
			local leave = was:GetScript("OnLeave")
			if leave then
				leave(was)
			end
		end
	end)
	made:SetScript("OnUpdate", function()
		if C.InCombat() then
			return
		end
		if not owner then
			release()
		elseif not owner:IsVisible() then
			note("released: button hidden")
			release()
		elseif not place() then
			note("released: no position")
			release()
		end
	end)
	made:SetScript("PreClick", function(self)
		note("click " .. tostring(owner and owner.secureId))
		C.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		if C.InCombat() then
			return
		end
		local def = owner and S.TARGETS[owner.secureId]
		self:SetAttribute("type1", (def and not alreadyOpen(def)) and "click" or nil)
		wasOnList = offEscapeList()
	end)
	made:SetScript("PostClick", function(self)
		if wasOnList then
			wasOnList = false
			tinsert(UISpecialFrames, "TrailheadWindow")
		end
		if C.InCombat() then
			return
		end
		self:SetAttribute("type1", "click")
		if owner and owner.secureAfter then
			T.SafeCall("secure", owner.secureAfter, owner)
		end
	end)
	cover = made
	return made
end

-- Lays the secure button over a Trailhead button. Called when the mouse comes onto it.
function S.Cover(button)
	if not button.secureId or C.InCombat() or not button:IsVisible()
		or (button.IsEnabled and not button:IsEnabled()) then
		note("not covered: " .. tostring(button.secureId) .. (C.InCombat() and " combat" or ""))
		return false
	end
	local _, micro = target(button.secureId)
	if not micro then
		note("not covered: no game button for " .. tostring(button.secureId))
		return false
	end
	local made = make()
	if not made then
		return false
	end
	if owner == button and made:IsShown() then
		return true
	end
	owner, placed = button, nil
	if not place() then
		owner = nil
		note("not covered: no position for " .. tostring(button.secureId))
		return false
	end
	made:SetAttribute("type1", "click")
	made:SetAttribute("clickbutton1", micro)
	made:SetFrameStrata(button:GetFrameStrata())
	made:SetFrameLevel(math.min(button:GetFrameLevel() + 20, 9000))
	made:Show()
	note(("covered %s at %s, level %s over %s"):format(tostring(button.secureId), tostring(placed),
		tostring(made:GetFrameLevel()), tostring(button:GetFrameLevel())))
	return true
end

-- The state for /th check. Only reads.
function S.Report()
	local out = { log = {} }
	for i, line in ipairs(S.log) do
		out.log[i] = line
	end
	out.cover = cover == nil and "not made" or cover == false and "failed" or "made"
	if cover then
		local function read(method)
			local fn = cover[method]
			if type(fn) ~= "function" then
				return "missing"
			end
			local ok, value = pcall(fn, cover)
			return ok and tostring(value) or "error"
		end
		out.shown, out.mouse, out.clicks = read("IsShown"), read("IsMouseEnabled"), read("IsMouseClickEnabled")
		out.strata, out.level, out.protected = read("GetFrameStrata"), read("GetFrameLevel"), read("IsProtected")
	end
	out.buttons = {}
	for id, def in pairs(S.TARGETS) do
		local button = _G[def.button]
		local shown = type(button) == "table" and type(button.IsShown) == "function" and button:IsShown()
		out.buttons[id] = type(button) ~= "table" and "missing" or (shown and "shown" or "hidden")
	end
	return out
end

-- Makes a Trailhead button open a game window the safe way: `id` is a key of S.TARGETS (nil
-- for a button that does something else), `after` runs once the game's window has opened.
-- The button's own click stays as the fallback for when the safe way is not there.
function S.Set(button, id, after)
	if not button.secureHooked then
		button.secureHooked = true
		button:HookScript("OnEnter", function(self)
			S.Cover(self)
		end)
	end
	button.secureId = id
	button.secureAfter = after
	if owner == button and not id then
		release()
	end
end

T:On("PLAYER_REGEN_DISABLED", function()
	release()
end)

T:On("PLAYER_REGEN_ENABLED", function()
	if cover and not owner then
		cover:Hide()
	end
end)
