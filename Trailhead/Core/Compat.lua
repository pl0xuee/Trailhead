local _, T = ...

-- Compat: every call into the game that might not exist in this client, or might fail,
-- goes through here. A missing or failing API switches off one feature, never the addon.

local C = {}
T.Compat = C
C.errors = {} -- path -> first error text

-- Resolves "C_Map.GetMapLevels" to the function (or value), or nil.
function C.Resolve(path)
	local value = _G
	for part in path:gmatch("[^%.]+") do
		if type(value) ~= "table" then
			return nil
		end
		value = value[part]
		if value == nil then
			return nil
		end
	end
	return value
end
local resolve = C.Resolve

function C.Has(path)
	return type(resolve(path)) == "function"
end

local function finish(path, ok, ...)
	if ok then
		return ...
	end
	if C.errors[path] == nil then
		C.errors[path] = tostring((...))
	end
	return nil
end

-- Calls the function at `path` and returns what it returns; nil if it is missing or fails.
function C.Call(path, ...)
	local fn = resolve(path)
	if type(fn) ~= "function" then
		return nil
	end
	return finish(path, pcall(fn, ...))
end

-- Secret values (Midnight-era client): values addons may hold but not read or compare.
function C.IsSecret(value)
	local check = issecretvalue
	if type(check) ~= "function" then
		return false
	end
	local ok, secret = pcall(check, value)
	return ok and secret and true or false
end

-- Returns value when it is safe to read, otherwise fallback.
function C.Plain(value, fallback)
	if value == nil or C.IsSecret(value) then
		return fallback
	end
	return value
end

function C.InCombat()
	return (InCombatLockdown and InCombatLockdown()) and true or false
end

function C.Sound(key)
	local kit = SOUNDKIT and SOUNDKIT[key]
	if kit and PlaySound then
		pcall(PlaySound, kit)
	end
end
