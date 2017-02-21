local ADDON, Engine = ...

-- Lua API
local rawset, rawget = rawset, rawget

local gameLocale = GetLocale() -- current game client locale
local fallbackLocale = "enUS" -- fallback language for the UI if no translation is present

-- fallback locale
local L_fallback = setmetatable({}, {
	__newindex = function(self, key, value)
		if value == true then
			rawset(self, key, key)
		else
			rawset(self, key, value)
		end
	end,
	
	-- Slight little copout that will remove all localization errors.
	__index = function(self, key)
		local value = rawget(self, key)
		if value == true then 
			return key
		else
			return value or key
		end
	end,
	metatable = false
})

-- game client locale
local L = setmetatable({}, { 
	__newindex = function(self, key, value)
		if value == true then
			rawset(self, key, key)
		else
			rawset(self, key, value)
		end
	end,
	__index = function(self, key)
		local value = rawget(self, key) or rawget(L_fallback, key)
		if value == true then 
			return key
		else
			return value or key
		end
	end,
	--__index = L_fallback,
	metatable = false
})

-- Set a locale 
Engine.NewLocale = function(self, locale)
	if locale == fallbackLocale then
		return L_fallback
	elseif locale == gameLocale then
		return L
	else
		return 
	end
end

-- Proxy function to get the game locale, 
-- allows us to override the locale for testing.
Engine.GetGameLocale = function(self)
	return gameLocale
end

-- Get the currently active locale
Engine.GetLocale = function(self)
	return L
end

-- Uncomment to test another locale 
-- (Developers only, as it doesn't change the game's own localization)
--gameLocale = "zhCN"

