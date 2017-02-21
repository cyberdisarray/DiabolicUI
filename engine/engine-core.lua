local ADDON, Engine = ...
local L = Engine:GetLocale()


-------------------------------------------------------------
-- Lua API
-------------------------------------------------------------
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local getmetatable = getmetatable
local ipairs = ipairs
local math_abs = math.abs
local math_floor = math.floor
local pairs = pairs
local pcall = pcall
local print = print
local select = select
local setmetatable = setmetatable
local string_join = string.join
local string_match = string.match
local table_concat = table.concat
local tonumber = tonumber
local tostring = tostring
local type = type


-------------------------------------------------------------
-- WOW API
-------------------------------------------------------------
local CreateFrame = _G.CreateFrame
local GetAddOnEnableState = _G.GetAddOnEnableState
local GetAddOnInfo = _G.GetAddOnInfo
local GetBuildInfo = _G.GetBuildInfo
local GetCurrentResolution = _G.GetCurrentResolution
local GetCVar, SetCVar = _G.GetCVar, _G.SetCVar
local GetCVarBool = _G.GetCVarBool
local GetLocale = _G.GetLocale
local GetNumAddOns = _G.GetNumAddOns
local GetRealmName = _G.GetRealmName
local GetResolution = _G.GetResolution
local GetScreenHeight = _G.GetScreenHeight
local GetScreenWidth = _G.GetScreenWidth
local GetScreenResolutions = _G.GetScreenResolutions
local EnableAddOn = _G.EnableAddOn
local InCombatLockdown = _G.InCombatLockdown
local InCinematic = _G.InCinematic
local IsLoggedIn = _G.IsLoggedIn
local IsMacClient = _G.IsMacClient
local LoadAddOn = _G.LoadAddOn
local RegisterStateDriver = _G.RegisterStateDriver
local SetCVar = _G.SetCVar
local StaticPopup_Show = _G.StaticPopup_Show
local StaticPopupDialogs = _G.StaticPopupDialogs
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitFactionGroup = _G.UnitFactionGroup
local UnitName = _G.UnitName
--local GetTime, C_TimerAfter = GetTime, C_Timer.After


-------------------------------------------------------------
-- WOW Frames & Tables
-------------------------------------------------------------
local UIParent = _G.UIParent
local WorldFrame = _G.WorldFrame


-------------------------------------------------------------
-- Engine Registries
-------------------------------------------------------------
local events = {} -- event registry
local timers = {} -- timer registry

local configs = {} -- config registry saved between sessions
local staticConfigs = {} -- static configurations set by the modules

local handlers = {} -- handler registry
local handlerElements = {} -- handler element registry
local handlerElementsEnabledState = {} -- registry to "reverse" the enable/disable status of handler elements

local modules = {} -- module registry
local moduleWidgets = {} -- module widget registry
local moduleLoadPriority = { HIGH = {}, NORMAL = {}, LOW = {} } -- module load priorities

local initializedObjects = {} -- hash table for initialized objects
local enabledObjects = {} -- hash table for enabled modules, widgets and handler elements

local objectName = {} -- table to hold the display names (ID) of all handlers, modules, widgets and elements
local objectType = {} -- table to quickly look up what sort of object we're working with (handler, module, widget, element)

local stack = {} -- local table stack for indexed tables
local queue = {} -- queued function calls for the secure out of combat wrapper
local scale = {} -- screen resolution and UI scale data (not used?)

local keyWords = {} -- keyword registry to translate words to frame handles used for anchoring or parenting


-------------------------------------------------------------
-- Flags and other values meant to be read-only
-------------------------------------------------------------
local BUILD = tonumber((select(2, GetBuildInfo()))) -- current game client build

local INCOMBAT = UnitAffectingCombat("player") -- flag to track combat status
local INLOCKDOWN = InCombatLockdown() -- flag to track combat lockdown status

local PRIORITY_HASH = { HIGH = true, NORMAL = true, LOW = true } -- hashed priority table, for faster validity checks
local PRIORITY_INDEX = { "HIGH", "NORMAL", "LOW" } -- indexed/ordered priority table
local DEFAULT_MODULE_PRIORITY = "NORMAL" -- default load priority for new modules

local KEYWORD_DEFAULT -- default keyword used as a fallback. this will not be user editable.

-- Expansion and patch to game client build translation table
-- *Changed from the original full list to only registering relevant client versions.
local GAME_VERSIONS_TO_BUILD = {
	["Wrath of the Lich King"] 		= 12340, 	["WotLK"]	= 12340, 	["3.3.5a"] 	= 12340,
	["Cataclysm"] 					= 15595, 	["Cata"] 	= 15595, 	["4.3.4"] 	= 15595,
	["Mists of Pandaria"] 			= 18414, 	["MoP"] 	= 18414, 	["5.4.8"] 	= 18414,
	["Warlords of Draenor"] 		= 20779, 	["WoD"] 	= 20779, 	["6.2.3"] 	= 20779, 
																		["6.2.3a"] 	= 21742,
	["Legion"] 						= 22410, 							["7.0.3"] 	= 22410, -- 22594 on wowpedia?
																		["7.1.0"] 	= 22578,
																		["7.1.5"] 	= 23360, -- PTR was 23138
																		["7.2.0"] 	= 23436 -- current PTR build
}

-- Much faster lookup table to determine if we're at 
-- at least the given build, patch, expansion or higher.
--
-- Note that it is still recommended for modules to cache up 
-- constants at startup for the various patch/expansion checks, 
-- because a local constant is seriously much faster than any function. 
local CLIENT_IS_GAME_VERSION = {}
do
	for version, build in pairs(GAME_VERSIONS_TO_BUILD) do
		local isBuild = BUILD >= build
		CLIENT_IS_GAME_VERSION[version] = isBuild 
		CLIENT_IS_GAME_VERSION[tostring(build)] = isBuild 
		CLIENT_IS_GAME_VERSION[tostring(build)] = isBuild 
	end
end


-------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------
DiabolicUI_DB = {} 



-------------------------------------------------------------
-- Engine Frames & UI Widgets
-------------------------------------------------------------

-- Frame meant for events, timers, etc
local Frame = CreateFrame("Frame", nil, WorldFrame) -- parented to world frame to keep running even if the UI is hidden
local FrameMethods = getmetatable(Frame).__index


-- Frame for UI positioning, because sometimes (with multimonitor setups etc) the regular UIParent won't work.
-- We also need this one to have a secure scaling option for the UI, which the user can change graphically even in combat!
local UICenter = CreateFrame("Frame", nil, UIParent, "SecureHandlerAttributeTemplate")
UICenter:SetFrameLevel(UIParent:GetFrameLevel())
UICenter:SetSize(UIParent:GetSize())
UICenter:SetPoint("TOP", UIParent, "TOP")
UICenter:SetPoint("BOTTOM", UIParent, "BOTTOM")
--UICenter:SetPoint("CENTER", UIParent, "CENTER")



-------------------------------------------------------------
-- Declarations of stuff we embed later
-------------------------------------------------------------
local Orb
local StatusBar


-------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------

-- Syntax check (A shout-out to Haste for this one!)
local check = function(self, value, num, ...)
	assert(type(num) == "number", L["Bad argument #%d to '%s': %s expected, got %s"]:format(2, "Check", "number", type(num)))
	for i = 1,select("#", ...) do
		if type(value) == select(i, ...) then 
			return 
		end
	end
	local types = string_join(", ", ...)
	local name = string_match(debugstack(2, 2, 0), ": in function [`<](.-)['>]")
	error(L["Bad argument #%d to '%s': %s expected, got %s"]:format(num, name, types, type(value)), 3)
end

-- Error handling to keep the Engine running.
local protected_call = function(...)
	local _, catch = pcall(...)
	if catch and GetCVarBool("scriptErrors") then
		ScriptErrorsFrame_OnError(catch, false)
	end
end

-- Wipe a table and push it to the stack.
local push = function(tbl)
	if #tbl > 0 then
		for i = #tbl, 1, -1 do
			tbl[i] = nil
		end
	end
	stack[#stack + 1] = tbl
end

-- Pull a table from the stack, or create a new one.
local pop = function()
	if #stack > 0 then
		local tbl = stack[#stack]
		stack[#stack] = nil
		return tbl
	end
	return {}
end

local math_round = function(n, accuracy) 
	return (math_floor(n*accuracy))/accuracy 
end

local math_compare = function(a, b, accuracy) 
	return not(math_abs(a-b) > 1/accuracy) 
end

-- Translate keywords to frame handles used for anchoring.
local parseAnchor = function(anchor)
	return anchor and (keyWords[anchor] and keyWords[anchor]() or _G[anchor] and _G[anchor] or anchor) or KEYWORD_DEFAULT and keyWords[KEYWORD_DEFAULT]() or WorldFrame
end

-- Embed source methods into target.
local embed = function(target, source)
	for i,v in pairs(source) do
		if type(v) == "function" then
			target[i] = v
		end
	end
	return target
end

-- Deep copy a table into a new table 
-- or into the optional target.
local copyTable
copyTable = function(source, target)
	local new = target or {}
	for i,v in pairs(source) do
		if type(v) == "table" then
			if new[i] and type(new[i] == "table") then
				new[i] = copyTable(source[i], new[i]) 
			else
				new[i] = copyTable(source[i])
			end
		else
			new[i] = source[i]
		end
	end
	return new
end



-------------------------------------------------------------
-- Event & OnUpdate Handler
-------------------------------------------------------------

-- script handler for Frame's OnEvent
local OnEvent = function(self, event, ...)
	local eventRegistry = events[event]
	if not eventRegistry then
		return 
	end
	
	-- iterate engine events first
	local engine = Engine
	local engineEvents = eventRegistry[engine]
	if engineEvents then
		for index,func in ipairs(engineEvents) do
			if type(func) == "string" then
				if engine[func] then
					engine[func](engine, event, ...)
				else
					return error(L["The Engine has no method named '%s'!"]:format(func))
				end
			else
				func(engine, event, ...)
			end
		end
	end
	
	-- iterate handlers
	for name,handler in pairs(handlers) do
		if enabledObjects[handler] then
			local handler_events = eventRegistry[handler]
			if handler_events then
				for index,func in ipairs(handler_events) do
					if type(func) == "string" then
						if handler[func] then
							handler[func](handler, event, ...)
						else
							return error(L["The handler '%s' has no method named '%s'!"]:format(tostring(handler), func))
						end
					else
						func(handler, event, ...)
					end
				end
			end
			
			-- iterate the elements registered to the current handler
			local elementPool = handlerElements[handler]
			for name,element in pairs(elementPool) do
				local element_events = eventRegistry[element]
				if element_events then
					for index,func in ipairs(element_events) do
						if type(func) == "string" then
							if element[func] then
								element[func](element, event, ...)
							else
								return error(L["The handler element '%s' has no method named '%s'!"]:format(tostring(element), func))
							end
						else
							func(element, event, ...)
						end
					end
				end
			end
			
		end
	end

	-- iterate module events and fire according to priorities
	for index,priority in ipairs(PRIORITY_INDEX) do
		for name,module in pairs(moduleLoadPriority[priority]) do
			if enabledObjects[module] then
				local moduleEvents = eventRegistry[module]
				if moduleEvents then
					for index,func in ipairs(moduleEvents) do
						if type(func) == "string" then
							if module[func] then
								module[func](module, event, ...)
							else
								return error(L["The module '%s' has no method named '%s'!"]:format(tostring(module), func))
							end
						else
							func(module, event, ...)
						end
					end
				end

				-- iterate the widgets registered to the current module
				local widgetPool = moduleWidgets[module]
				for name,widget in pairs(widgetPool) do
					local widgetEvents = eventRegistry[widget]
					if widgetEvents then
						for index,func in ipairs(widgetEvents) do
							if type(func) == "string" then
								if widget[func] then
									widget[func](widget, event, ...)
								else
									return error(L["The module widget '%s' has no method named '%s'!"]:format(tostring(widget), func))
								end
							else
								func(widget, event, ...)
							end
						end
					end
				end
			end
		end
	end

end

-- script handler for Frame's OnUpdate
local OnUpdate = function(self, elapsed, ...)
end

-- engine and object methods
local Fire = function(self, message, ...)
	self:Check(message, 1, "string")
	local eventRegistry = events[message]
	if not eventRegistry then
		return 
	end

	-- iterate engine messages first
	local engine = Engine
	local engineEvents = eventRegistry[engine]
	if engineEvents then
		for index,func in ipairs(engineEvents) do
			if type(func) == "string" then
				if engine[func] then
					engine[func](engine, message, ...)
				else
					return error(L["The Engine has no method named '%s'!"]:format(func))
				end
			else
				func(engine, message, ...)
			end
		end
	end
	
	-- iterate handlers
	for name,handler in pairs(handlers) do
		if enabledObjects[handler] then
			local handler_events = eventRegistry[handler]
			if handler_events then
				for index,func in ipairs(handler_events) do
					if type(func) == "string" then
						if handler[func] then
							handler[func](handler, message, ...)
						else
							return error(L["The handler '%s' has no method named '%s'!"]:format(tostring(handler), func))
						end
					else
						func(handler, message, ...)
					end
				end
			end
		end
	end
	
	-- iterate module messages and fire according to priorities
	for index,priority in ipairs(PRIORITY_INDEX) do
		for name,module in pairs(moduleLoadPriority[priority]) do
			if enabledObjects[module] then
				local moduleEvents = eventRegistry[module]
				if moduleEvents then
					for index,func in ipairs(moduleEvents) do
						if type(func) == "string" then
							if module[func] then
								module[func](module, message, ...)
							else
								return error(L["The module '%s' has no method named '%s'!"]:format(tostring(module), func))
							end
						else
							func(module, message, ...)
						end
					end
				end

				-- iterate the widgets registered to the current module
				local widgetPool = moduleWidgets[module]
				for name,widget in pairs(widgetPool) do
					local widgetEvents = eventRegistry[widget]
					if widgetEvents then
						for index,func in ipairs(widgetEvents) do
							if type(func) == "string" then
								if widget[func] then
									widget[func](widget, message, ...)
								else
									return error(L["The module widget '%s' has no method named '%s'!"]:format(tostring(widget), func))
								end
							else
								func(widget, message, ...)
							end
						end
					end
				end

			end
		end
	end
end

local RegisterEvent = function(self, event, func)
	self:Check(event, 1, "string")
	self:Check(func, 2, "string", "function", "nil")
	if not events[event] then
		events[event] = {}
	end
	if not events[event][self] then
		events[event][self] = {}
	end
	if not Frame:IsEventRegistered(event) then
		Frame:RegisterEvent(event)
		if not Frame.eventRegistry then
			Frame.eventRegistry = {}
		end
		if not Frame.eventRegistry[event] then
			Frame.eventRegistry[event] = 0
		end
	end
	if func == nil then 
		func = "Update"
	end
	for i = 1, #events[event][self] do
		if events[event][self][i] == func then -- avoid duplicate calls to the same function
			return 
		end
	end
	events[event][self][#events[event][self] + 1] = func

	-- This needs to come down here, so that multiple instances of the same event will each get a count
	Frame.eventRegistry[event] = Frame.eventRegistry[event] + 1
end

local IsEventRegistered = function(self, event, func)
	self:Check(event, 1, "string")
	self:Check(func, 2, "string", "function", "nil")
	if not Frame:IsEventRegistered(event) then 
		return false
	end
	if not(events[event] and events[event][self]) then
		return false
	end
	if func == nil then 
		func = "Update"
	end
	for i = 1, #events[event][self] do
		if events[event][self][i] == func then 
			return true
		end
	end
	return false	
end

local UnregisterEvent = function(self, event, func)
	self:Check(event, 1, "string")
	self:Check(func, 2, "string", "function", "nil")
	if not events[event] then
		return error(L["The event '%s' isn't currently registered to any object."]:format(event))
	end
	if not events[event][self] then
		return error(L["The event '%s' isn't currently registered to the object '%s'."]:format(event, tostring(self)))
	end
	if func == nil then 
		func = "Update"
	end
	for i = #events[event][self], 1, -1 do
		if events[event][self][i] == func then 
			events[event][self][i] = nil
			if Frame.eventRegistry and Frame.eventRegistry[event] then
				Frame.eventRegistry[event] = Frame.eventRegistry[event] - 1
				if Frame.eventRegistry[event] == 0 then
					Frame:UnregisterEvent(event)
				end
			end
			return 
		end
	end
	if type(func) == "string" then
		if func == "Update" then
			return error(L["Attempting to unregister the general occurence of the event '%s' in the object '%s', when no such thing has been registered. Did you forget to add function or method name to UnregisterEvent?"]:format(event, tostring(self)))
		else
			return error(L["The method named '%s' isn't registered for the event '%s' in the object '%s'."]:format(func, event, tostring(self)))
		end
	else
		return error(L["The function call assigned to the event '%s' in the object '%s' doesn't exist."]:format(event, tostring(self)))
	end
end

local RegisterMessage = function(self, message, func)
	self:Check(message, 1, "string")
	self:Check(func, 2, "string", "function", "nil")
	if not events[message] then
		events[message] = {}
	end
	if not events[message][self] then
		events[message][self] = {}
	end
	if func == nil then 
		func = "Update"
	end
	for i = 1, #events[message][self] do
		if events[message][self][i] == func then -- avoid duplicate calls to the same function
			return 
		end
	end
	events[message][self][#events[message][self] + 1] = func
end

local IsMessageRegistered = function(self, message, func)
	self:Check(message, 1, "string")
	self:Check(func, 2, "string", "function", "nil")
	if not(events[message] and events[message][self]) then
		return false
	end
	if func == nil then 
		func = "Update"
	end
	for i = 1, #events[message][self] do
		if events[message][self][i] == func then 
			return true
		end
	end
	return false
end

local UnregisterMessage = function(self, message, func)
	self:Check(message, 1, "string")
	self:Check(func, 2, "string", "function", "nil")
	if not events[message] then
		return error(L["The message '%s' isn't currently registered to any object."]:format(message))
	end
	if not events[message][self] then
		return error(L["The message '%s' isn't currently registered to the object '%s'."]:format(message, tostring(self)))
	end
	if func == nil then 
		func = "Update"
	end
	for i = #events[message][self], 1, -1 do
		if events[message][self][i] == func then 
			events[message][self][i] = nil
			--if Frame.eventRegistry and Frame.eventRegistry[message] then
			--	Frame.eventRegistry[message] = Frame.eventRegistry[message] - 1
			--	if Frame.eventRegistry[message] == 0 then
			--		Frame:UnregisterEvent(message)
			--	end
			--end
			return 
		end
	end
	if type(func) == "string" then
		if func == "Update" then
			return error(L["Attempting to unregister the general occurence of the message '%s' in the object '%s', when no such thing has been registered. Did you forget to add function or method name to UnregisterMessage?"]:format(event, tostring(self)))
		else
			return error(L["The method named '%s' isn't registered for the message '%s' in the object '%s'."]:format(func, message, tostring(self)))
		end
	else
		return error(L["The function call assigned to the message '%s' in the object '%s' doesn't exist."]:format(message, tostring(self)))
	end
	
end



-------------------------------------------------------------
-- Timers
-- *Not implemented yet. So don't use them!
-------------------------------------------------------------

-- create a new timer object
local new_timer = function(owner, method, delay, loop, ...)

end

local ScheduleTimer = function(self, method, delay, ...)
	self:Check(method, 1, "string", "function")
	self:Check(delay, 2, "number")

	if not timers[self] then
		timers[self] = {}
	end
	
	local timer = new_timer(owner, method, delay, false, ...)

	timers[self][timer] = method

	return timer
end

local ScheduleRepeatingTimer = function(self, method, callback, ...)
	self:Check(method, 1, "string", "function")
	self:Check(delay, 2, "number")

	if not timers[self] then
		timers[self] = {}
	end
	
	local timer = new_timer(owner, method, delay, true, ...)

	timers[self][timer] = method

	return timer
end

local CancelTimer = function(self, id)
	if not timers[self] then
		return 
	end
end

local CancelAllTimers = function(self)
	if not timers[self] then
		return 
	end
end



-------------------------------------------------------------
-- Config
-------------------------------------------------------------

Engine.ParseSavedVariables = function(self)
	--[[

	-- Fix format changes during development. 
	wipe(DiabolicUI_DB) 

	-- Fix broken saved settings during development. 
	for name,data in pairs(DiabolicUI_DB) do
		for i,v in pairs(DiabolicUI_DB[name]) do
			if i ~= "profiles" then
				i = nil
			end
		end
	end

	]]--
	
	-- Merge and/or overwrite current configs with stored settings.
	-- *doesn't matter that we mess up any links by replacing the tables, 
	--  because this all happens before any module's OnInit or OnEnable,
	--  meaning if the modules do it right, they haven't fetched their config or db yet.
	for name,data in pairs(DiabolicUI_DB) do
		if data.profiles and configs[name] and configs[name].profiles then
			local profiles = data.profiles -- speeeed!

			-- add stored realm dbs to our db
			if profiles.realm then
				for realm,realmdata in pairs(profiles.realm) do
					configs[name].profiles.realm[realm] = copyTable(profiles.realm[realm], configs[name].profiles.realm[realm])
				end
			end

			-- add stored faction dbs to our db
			if profiles.faction then
				for faction,factiondata in pairs(profiles.faction) do
					configs[name].profiles.faction[faction] = copyTable(profiles.faction[faction], configs[name].profiles.faction[faction])
				end
			end

			-- add stored character dbs to our db
			if profiles.character then
				for char,chardata in pairs(profiles.character) do
					configs[name].profiles.character[char] = copyTable(profiles.character[char], configs[name].profiles.character[char])
				end
			end

			-- global config
			if profiles.global then
				configs[name].profiles.global = copyTable(profiles.global, configs[name].profiles.global)
			end
		end
	end	
	
	-- Point the saved variables back to our configs.
	-- *This isn't redundant, because there can be new configs here 
	--  that hasn't previously been saved either because of me adding a new module, 
	--	or because it's the first time running the addon.
	for name,data in pairs(configs) do
		DiabolicUI_DB[name] = { profiles = configs[name].profiles }
	end
end


local NewConfig = function(self, name, config)
	self:Check(name, 1, "string")
	self:Check(config, 2, "table")
	if configs[name] then
		return error(L["The config '%s' already exists!"]:format(name))
	end	
	
	local faction = UnitFactionGroup("player")
	local realm = GetRealmName() 
	local character = UnitName("player")	

	configs[name] = {
		defaults = copyTable(config),
		profiles = {
			realm = { [realm] = copyTable(config) },
			faction = { [faction] = copyTable(config) },
			character = { [character.."-"..realm] = copyTable(config) }, -- we need the realm name here to avoid duplicates
			global = copyTable(config)
		}
	}
end

-- if the 'profile' argument is left out, the 'global' profile will be returned
local GetConfig = function(self, name, profile, option)
	self:Check(name, 1, "string")
	self:Check(profile, 2, "string", "nil")
	self:Check(option, 3, "string", "nil")
	if not configs[name] then
		return error(L["The config '%s' doesn't exist!"]:format(name))
	end	
	local config
	if profile == "realm" then
		config = configs[name].profiles.realm[(GetRealmName())]
		
	elseif profile == "character" then
		config = configs[name].profiles.character[UnitName("player").."-"..GetRealmName()]
		
	elseif profile == "faction" then
		config = configs[name].profiles.faction[(UnitFactionGroup("player"))]
		
	elseif not profile then
		config = configs[name].profiles.global
	end
	if not config then
		return error(L["The config '%s' doesn't have a profile named '%s'!"]:format(name, profile))
	end
	return config
end

local GetConfigDefaults = function(self, name)
	self:Check(name, 1, "string")
	if not configs[name] then
		return error(L["The config '%s' doesn't exist!"]:format(name))
	end	
	return configs[name].defaults
end

local GetStaticConfig = function(self, name)
	self:Check(name, 1, "string")
	if not staticConfigs[name] then
		return error(L["The static config '%s' doesn't exist!"]:format(name))
	end	
	return staticConfigs[name]
end

local NewStaticConfig = function(self, name, config)
	self:Check(name, 1, "string")
	self:Check(config, 2, "table")
	if staticConfigs[name] then
		return error(L["The static config '%s' already exists!"]:format(name))
	end	
	staticConfigs[name] = copyTable(config)
end



-------------------------------------------------------------
-- Secure/OutOfCombat Wrapper
-------------------------------------------------------------

local safeCall = function(func, ...)
	-- perform the function right away when not in combat
	if not INCOMBAT then
		if queue[func] then -- check if the function has been previously queued during combat
			push(queue[func]) -- push the table to the stack
			queue[func] = nil -- remove the element from the queue
		end
		func(...) 
		return
	end
	if not INLOCKDOWN then
		INLOCKDOWN = InCombatLockdown() -- still in PLAYER_REGEN_DISABLED?
		if not INLOCKDOWN then
			if queue[func] then -- check if the function has been previously queued during combat
				push(queue[func]) -- push the table to the stack
				queue[func] = nil -- remove the element from the queue
			end
			func(...)
			return
		end
	end
	
	-- we're still in combat, combat has ended but the event hasn't fired yet. 
	-- we need to queue the function call.
	-- if it has been previously queued, we simply update the arguments
	if queue[func] then
		local tbl, oldArgs = queue[func], #queue[func]
		local numArgs = select("#", ...)
		for i = 1, numArgs do
			tbl[i] = select(i, ...) -- give each argument its own entry
		end
		if oldArgs > numArgs then
			for i = oldArgs + 1, numArgs do
				tbl[i] = nil -- kill of excess args from the previous queue, if any
			end
		end
	else
		local tbl = pop() -- request a fresh table from the stack
		local numArgs = select("#", ...)
		for i = 1, numArgs do
			tbl[i] = select(i, ...) -- give each argument its own entry
		end
		-- To avoid multiple calls of the same function, 
		-- we use the actual function as the key.
		--
		-- 	Note: 	This isn't guaranteed to work, though, since a function 
		-- 			can easily be copied when passed, and thus we can still get 
		-- 			multiple calls to the same function. 
		-- 			So I should rewrite the whole freaking system to use 
		--			some kind of unique IDs. Major TODO. -_-
		queue[func] = tbl 
	end
end

local combatStarts = function(self, event, ...)
	INCOMBAT = true -- combat starts
end

local combatEnds = function(self, event, ...)
	INCOMBAT = false
	INLOCKDOWN = false
	for func,args in pairs(queue) do
		if func then
			local args = args
			func(unpack(args)) 
			if queue[func] then -- the previous function may have deleted itself
				push(queue[func]) -- push the table to the stack
				queue[func] = nil -- remove the element from the queue
			elseif args then -- the table might still be there, even if the reference is gone
				push(args) -- push the table to the stack
			end
		end
	end
end

-- Local wrapper function to turn a function into a safecall 
-- that will be queued to combat end if called while 
-- the player or the player's pet or minion is in combat.
local wrap = function(self, func)
	return function(...)
		return safeCall(func, ...)
	end
end



-------------------------------------------------------------
-------------------------------------------------------------
-- Prototypes
-------------------------------------------------------------
-------------------------------------------------------------

-- default event handler 
local Update = function(self, event, ...)
	if not enabledObjects[self] then
		return
	end
	if self[event] then
		return self[event](self, event, ...)
	end
	if self.OnEvent then
		return self:OnEvent(event, ...)
	end
end

local Init = function(self, ...)
	if not initializedObjects[self] then 
		initializedObjects[self] = true
		if self.OnInit then
			return self:OnInit(...)
		end
	end
end

local Enable = function(self, ...)
	if not enabledObjects[self] then 
		enabledObjects[self] = true
		if self.OnEnable then
			return self:OnEnable(...)
		end
	end
end

local Disable = function(self, ...)
	if enabledObjects[self] then 
		enabledObjects[self] = false
		if self.OnDisable then
			return self:OnDisable(...)
		end
	end
end

local IsEnabled = function(self)
	return enabledObjects[self]
end

local GetHandler = function(self, name, silent)
	self:Check(name, 1, "string")
	self:Check(silent, 2, "boolean", "nil")
	if handlers[name] then
		return handlers[name]
	end
	if not silent then
		return error(L["Bad argument #%d to '%s': No handler named '%s' exist!"]:format(1, "Get", name))
	end
end

local GetModule = function(self, name, silent)
	self:Check(name, 1, "string")
	self:Check(silent, 2, "boolean", "nil")
	if modules[name] then
		return modules[name]
	end
	if not silent then
		return error(L["Bad argument #%d to '%s': No module named '%s' exist!"]:format(1, "Get", name))
	end
end

-- core object that all inherits from
local corePrototype = {
	Check = check,
	Update = Update,
	Enable = wrap(Engine, Enable),
	Disable = wrap(Engine, Disable), 
	IsEnabled = IsEnabled,
	RegisterEvent = RegisterEvent,
	RegisterMessage = RegisterMessage,
	UnregisterEvent = UnregisterEvent,
	UnregisterMessage = UnregisterMessage,
	IsEventRegistered = IsEventRegistered,
	IsMessageRegistered = IsMessageRegistered,
	SendMessage = Fire,
	GetHandler = GetHandler,
	GetModule = GetModule,
	NewConfig = NewConfig,
	GetConfig = GetConfig,
	NewStaticConfig = NewStaticConfig,
	GetStaticConfig = GetStaticConfig,
	Wrap = wrap
}
local corePrototype_MT = { __index = corePrototype, __tostring = function(t) return objectName[t] end }



-------------------------------------------------------------
-- Handlers & Elements
-------------------------------------------------------------
-- 	Handlers are the parts of the engine that function as libraries.
-- 	They are loaded before any modules, and any events or messages 
-- 	are sent to the handlers before the modules. 
-- 	This is intentional.
-------------------------------------------------------------

-- handler element prototypes
local elementPrototype = setmetatable({}, corePrototype_MT)
local elementUnsecurePrototype = setmetatable({
	Enable = Enable,
	Disable = Disable
}, { __index = elementPrototype })
local elementPrototype_MT = { __index = elementPrototype, __tostring = function(t) return objectName[t] end }
local elementUnsecurePrototype_MT = { __index = elementUnsecurePrototype }

-- handler prototype
local handlerPrototype = setmetatable({
	GetElement = function(self, name, ...)
		self:Check(name, 1, "string")
		local elementPool = handlerElements[self]
		return elementPool[name]
	end, 
	
	-- Handler elements are by default blocked from usage in combat. 
	-- To avoid this behavior the 'makeUnsecure' flag must be set to 
	-- 'true' during element creation!
	SetElement = function(self, name, template, makeUnsecure)
		self:Check(name, 1, "string")
		self:Check(template, 2, "table", "nil", "boolean")
		self:Check(makeUnsecure, 3, "boolean", "nil")
		
		if makeUnsecure == nil and type(template) == "boolean" then
			makeUnsecure = template
			template = nil
		end
		
		local elementPool = handlerElements[self]
		if elementPool[name] then
			return error(L["The element '%s' is already registered to the '%s' handler!"]:format(name, tostring(self)))
		end

		local element = setmetatable(template or {}, makeUnsecure and elementUnsecurePrototype_MT or elementPrototype_MT)

		objectName[element] = name
		objectType[element] = "element"
		
		if handlerElementsEnabledState[self] then
			enabledObjects[element] = true
		end

		elementPool[name] = element
		
		return element
	end, 
	
	SetElementDefaultEnabledState = function(self, state)
		handlerElementsEnabledState[self] = state
	end,

	IterateElements = function(self)
		return pairs(handlerElements[self])
	end

}, corePrototype_MT)
local handlerPrototype_MT = { __index = handlerPrototype, __tostring = function(t) return objectName[t] end }



-------------------------------------------------------------
-- Modules & Widgets
-------------------------------------------------------------
-- *not considered part of the engine
-------------------------------------------------------------

-- module widget prototype
local widgetPrototype = setmetatable({
	Init = Init,
}, corePrototype_MT)
local widgetUnsecurePrototype = setmetatable({
	Enable = Enable,
	Disable = Disable
}, { __index = widgetPrototype })
local widgetPrototype_MT = { __index = widgetPrototype, __tostring = function(t) return objectName[t] end }
local widgetUnsecurePrototype_MT = { __index = widgetUnsecurePrototype, __tostring = function(t) return objectName[t] end }

-- module prototype
local modulePrototype = setmetatable({
	Init = Init,
	GetWidget = function(self, name, ...)
		self:Check(name, 1, "string")
		local widgetPool = moduleWidgets[self]
		return widgetPool[name]
	end, 
	SetWidget = function(self, name, makeUnsecure)
		self:Check(name, 1, "string")
		self:Check(makeUnsecure, 2, "boolean", "nil")
		
		local widgetPool = moduleWidgets[self]
		if widgetPool[name] then
			return error(L["The widget '%s' is already registered to the '%s' module!"]:format(name, tostring(self)))
		end

		local widget = setmetatable({}, makeUnsecure and widgetUnsecurePrototype_MT or widgetPrototype_MT)
		
		objectName[widget] = name -- store the name
		objectType[widget] = "widget" -- store the object type
		
		widgetPool[name] = widget
		
		return widget
	end
}, corePrototype_MT)
local moduleUnsecurePrototype = setmetatable({
	Enable = Enable,
	Disable = Disable
}, { __index = modulePrototype })
local modulePrototype_MT = { __index = modulePrototype, __tostring = function(t) return objectName[t] end }
local moduleUnsecurePrototype_MT = { __index = moduleUnsecurePrototype, __tostring = function(t) return objectName[t] end }



-------------------------------------------------------------
-- Custom Frames & UI Widgets
-------------------------------------------------------------
local framePrototype
local frameWidgetPrototype

local blizzardCreateFontString = FrameMethods.CreateFontString
local blizzardCreateTexture = FrameMethods.CreateTexture

frameWidgetPrototype = {
	-- Position a frame, and accept keywords as anchors
	-- to easily hook frames into the secure actionbar controllers.
	Place = function(self, ...)
		local numArgs = select("#", ...)
		if numArgs == 1 then
			local point = ...
			self:ClearAllPoints()
			self:SetPoint(point)
		elseif numArgs == 2 then
			local point, anchor = ...
			self:ClearAllPoints()
			self:SetPoint(point, parseAnchor(anchor))
		elseif numArgs == 3 then
			local point, anchor, rpoint = ...
			self:ClearAllPoints()
			self:SetPoint(point, parseAnchor(anchor), rpoint)
		elseif numArgs == 5 then
			local point, anchor, rpoint, xoffset, yoffset = ...
			self:ClearAllPoints()
			self:SetPoint(point, parseAnchor(anchor), rpoint, xoffset, yoffset)
		end
	end,

	-- Set a single point on a frame without clearing first. 
	-- Like the above function, this too accepts keywords as anchors.
	Point = function(self, ...)
		local numArgs = select("#", ...)
		if numArgs == 1 then
			local point = ...
			self:SetPoint(point)
		elseif numArgs == 2 then
			local point, anchor = ...
			self:SetPoint(point, parseAnchor(anchor))
		elseif numArgs == 3 then
			local point, anchor, rpoint = ...
			self:SetPoint(point, parseAnchor(anchor), rpoint)
		elseif numArgs == 5 then
			local point, anchor, rpoint, xoffset, yoffset = ...
			self:SetPoint(point, parseAnchor(anchor), rpoint, xoffset, yoffset)
		end
	end,

	-- Size a frame, and accept single input values for square frames.
	Size = function(self, ...)
		local numArgs = select("#", ...)
		if numArgs == 1 then
			local size = ...
			self:SetSize(size, size)
		elseif numArgs == 2 then
			self:SetSize(...)
		end
	end
}

framePrototype = {
	-- Create a new orb as a child of the current frame.
	-- *The orb handler inherits from this frame object, 
	--  so all the same methods are available to it too.
	CreateOrb = function(self, ...)
		return Orb:New(self, ...)
	end,

	-- Create a new statusbar as a child of the current frame.
	-- *Same inheritance as the orb objects
	CreateStatusBar = function(self, ...)
		return StatusBar:New(self, ...)
	end,

	-- Create a new frame as a child of the current frame.
	-- *Same inheritance as the orb objects
	CreateFrame = function(self, frameType, frameName, template) 
		return embed(CreateFrame(frameType or "Frame", frameName, self, template), framePrototype)
	end,

	CreateFontString = function(self, ...)
		return embed(blizzardCreateFontString(self, ...), frameWidgetPrototype)
	end,

	CreateTexture = function(self, ...)
		return embed(blizzardCreateTexture(self, ...), frameWidgetPrototype)
	end

}

-- Embed custom frame widget methods in the main frame prototype too 
embed(framePrototype, frameWidgetPrototype)



-------------------------------------------------------------
-------------------------------------------------------------
-- Engine
-------------------------------------------------------------
-------------------------------------------------------------


-------------------------------------------------------------
-- Keyword handling
-------------------------------------------------------------

-- register a keyword to trigger a function call when used as an anchor on a frame
Engine.RegisterKeyword = function(self, keyWord, func)
	keyWords[keyWord] = func
end

-- set the default keyword. can only be done once.
Engine.RegisterKeywordDefault = function(self, keyWord, func)
	KEYWORD_DEFAULT = keyWord
	keyWords[KEYWORD_DEFAULT] = func

	-- clear the function after the first use
	self.RegisterKeywordDefault = nil
end


-------------------------------------------------------------
-- Frame creation
-------------------------------------------------------------
-- Returns the UICenter frame, which should be 
-- the parent of everything except the nameframes.
Engine.GetFrame = function(self)
	return UICenter
end

-- Create a frame with certain extra methods we like to have
Engine.CreateFrame = function(self, frameType, frameName, parent, template) 
	return embed(CreateFrame(frameType or "Frame", frameName, parseAnchor(parent), template), framePrototype)
end



-------------------------------------------------------------
-- WoW client checks
-------------------------------------------------------------

-- This method is mainly meant for other modules to have 
-- access to an easy patch/expansion to build number translation table.
-- For reasons of speed we prefer to access the GAME_VERSIONS_TO_BUILD table directly instead.
Engine.GetBuildFor = function(self, buildOrVersion)
	return GAME_VERSIONS_TO_BUILD[buildOrVersion]
end

-- This is the old IsBuild method
-- It allows us to check for exact version, but is far slower 
Engine.IsBuildVersion = function(self, buildOrVersion, exact)
	local client_build = tonumber(buildOrVersion)
	if client_build then
		if exact then
			return client_build == BUILD
		else
			return client_build <= BUILD
		end
	elseif type(buildOrVersion) == "string" then
		if exact then
			return GAME_VERSIONS_TO_BUILD[buildOrVersion] == BUILD
		else
			return GAME_VERSIONS_TO_BUILD[buildOrVersion] <= BUILD
		end
	end
end

-- This is the new method introduced in v1.1 of the Engine, 
-- and since it's just a true/false table it is much faster. 
Engine.IsBuild = function(self, version)
	return CLIENT_IS_GAME_VERSION[version]
end



-------------------------------------------------------------
-- Track loading screens
-------------------------------------------------------------
do
	local offWorldStatus
	Engine.UpdateOffWorld = function(self, event, ...)
		if event == "PLAYER_LEAVING_WORLD" then
			offWorldStatus = true
		elseif event == "PLAYER_ENTERING_WORLD" then
			offWorldStatus = false
		end
	end

	-- Returns true if the player is in the world.
	-- This is defined by whether the player has entered the world after the last login or reload, 
	-- and will return false if the game client is still starting up or the player is on a loading screen. 
	Engine.IsInWorld = function(self)
		return offWorldStatus == false
	end

	-- Returns true if the player is currently on a loading screen,
	-- but will return false both when the player is in the world or not yet have fully logged in.
	-- The purpose if this function is to specifically check for loading screens while in-game.
	Engine.IsOffWorld = function(self)
		return offWorldStatus == true
	end
end



-------------------------------------------------------------
-- General engine API
-------------------------------------------------------------

Engine.GetConstant = function(self, constant)
	return self:GetStaticConfig("Data: Constants")[constant]
end



-------------------------------------------------------------
-- Addon handling
-------------------------------------------------------------

-- Check if an addon exists in the addon listing and loadable on demand
Engine.IsAddOnLoadable = function(self, target)
	local target = strlower(target)
	for i = 1,GetNumAddOns() do
		local name, title, notes, enabled, loadable, reason, security = self:GetAddOnInfo(i)
		if strlower(name) == target then
			if loadable then
				return true
			end
		end
	end
end

-- Matching the pre-MoP return arguments of the Blizzard API call
Engine.GetAddOnInfo = function(self, index)
	local name, title, notes, enabled, loadable, reason, security
	if self:IsBuild("WoD") then
		name, title, notes, loadable, reason, security, newVersion = GetAddOnInfo(index)
		enabled = not(GetAddOnEnableState(UnitName("player"), index) == 0) -- not a boolean, messed that one up! o.O
	else
		name, title, notes, enabled, loadable, reason, security = GetAddOnInfo(index)
	end
	return name, title, notes, enabled, loadable, reason, security
end

-- Check if an addon is enabled	in the addon listing
Engine.IsAddOnEnabled = function(self, target)
	local target = strlower(target)
	for i = 1,GetNumAddOns() do
		local name, title, notes, enabled, loadable, reason, security = self:GetAddOnInfo(i)
		if strlower(name) == target then
			if enabled then
				return true
			end
		end
	end
end	



-------------------------------------------------------------
-- Handlers and Modules
-------------------------------------------------------------

-- define a new handler/library
Engine.NewHandler = function(self, name)
	self:Check(name, 1, "string")
	
	if handlers[name] then
		return error(L["A handler named '%s' is already registered!"]:format(name))
	end
	
	local handler = setmetatable({}, handlerPrototype_MT) 

	handlerElements[handler] = {} -- local elementpool for the handler
	
	objectName[handler] = name -- store the handler name for easier reference
	objectType[handler] = "handler" -- store the object type

	handlers[name] = handler
	
	return handler
end

-- create a new user module
-- *set loadPriority to "LOW" to delay OnEnable until after PLAYER_LOGIN!
Engine.NewModule = function(self, name, loadPriority, makeUnsecure)
	self:Check(name, 1, "string")
	self:Check(loadPriority, 2, "string", "nil")
	self:Check(makeUnsecure, 3, "boolean", "nil")
	
	if handlers[name] then
		return error(L["Bad argument #%d to '%s': The name '%s' is reserved for a handler!"]:format(1, "New", name))
	end
	if modules[name] then
		return error(L["Bad argument #%d to '%s': A module named '%s' already exists!"]:format(1, "New", name))
	end
	if loadPriority and not PRIORITY_HASH[loadPriority] then
		return error(L["Bad argument #%d to '%s': The load priority '%s' is invalid! Valid priorities are: %s"]:format(5, "New", loadPriority, table_concat(PRIORITY_INDEX, ", ")))
	end
	if not loadPriority then
		loadPriority = DEFAULT_MODULE_PRIORITY
	end
	
	local module = setmetatable({}, makeUnsecure and moduleUnsecurePrototype_MT or modulePrototype_MT) 

	moduleWidgets[module] = {} -- local widgetpool for the module

	objectName[module] = name -- store the module name for easier reference
	objectType[module] = "module" -- store the object type

	moduleLoadPriority[loadPriority][name] = module -- store the module load priority

	modules[name] = module -- insert the new module into the registry
	
	return module
end

-- perform a function or method on all registered modules
Engine.ForAll = function(self, func, priority_filter, ...) 
	self:Check(func, 1, "string", "function")
	self:Check(func, 2, "string", "nil")

	-- if a valid priority filter is set, only modules of that given priority will be called
	if priority_filter then
		if not PRIORITY_HASH[priority_filter] then
			return error(L["Bad argument #%d to '%s': The load priority '%s' is invalid! Valid priorities are: %s"]:format(2, "ForAll", priority_filter, table_concat(PRIORITY_INDEX, ", ")))
		end
		for name,module in pairs(moduleLoadPriority[priority_filter]) do
			if type(func) == "string" then
				if module[func] then
					--protected_call(module[func], module, ...)
					module[func](module, ...)
				end
			else
				--protected_call(func, module, ...)
				func(module, ...)
			end
		end
		return
	end
	
	-- if no priority filter is set, we iterate through all modules, but still by priority
	for index,priority in ipairs(PRIORITY_INDEX) do
		for name,module in pairs(moduleLoadPriority[priority]) do
			if type(func) == "string" then
				if module[func] then
					--protected_call(module[func], module, ...)
					module[func](module, ...)
				end
			else
				--protected_call(func, module, ...)
				func(module, ...)
			end
		end
	end
end



-------------------------------------------------------------
-- Resolution and scale handling
-------------------------------------------------------------
do
	local onlyRunOnce 

	-- A modifier we apply to all scaling, 
	-- to give the user a good default scale 
	-- regardless of screen resolution. 
	local HD_MODIFIER = 1 

	local accuracy = 1e4 -- note that for anything more than 2 decimals will spam reloads on every video options frame opening (unless the slider is disabled, as we're doing)
	local widescreen = 1.6 -- minimum aspect ratio for a screen to be considered widescreen (16:10)
	local currentPixelScale = 1 -- initial pixel scale of the UICenter frame 
	local screenPixelWidth, screenPixelHeight -- on-screen pixel size of the frame

	-- Returns the current game resolution
	UICenter.GetResolution = function(self)
		local resolution
		if Engine:IsBuild("Legion") then
			local monitorIndex = tonumber(GetCVar("gxMonitor"))
			if monitorIndex then
				monitorIndex = monitorIndex + 1
				resolution = ({GetScreenResolutions(monitorIndex)})[GetCurrentResolution(monitorIndex)]
			end
		else
			resolution = ({GetScreenResolutions()})[GetCurrentResolution()]
		end

		if not resolution then 
			return
		end

		local screenWidth = tonumber(string_match(resolution, "(%d+)x%d+")) 
		local screenHeight = tonumber(string_match(resolution, "%d+x(%d+)"))

		return screenWidth, screenHeight
	end

	-- Returns the pixel size of the screen 
	-- the UICenter frame should be located at.
	UICenter.GetScreenSize = function(self)
		local screenWidth, screenHeight = self:GetResolution()
		if not(screenWidth and screenHeight) then
			return
		end

		local aspectRatio = math_round(screenWidth / screenHeight, accuracy)

		-- Somebody using AMD EyeFinity?
		-- 	*we're blatently assuming we're talking about 3x widescreen monitors,
		-- 	 and we will simply ignore all other setups. Dual monitors in WoW is just dumb.
		local viewPortWidth 
		if aspectRatio >= 3*widescreen then
			viewPortWidth = math_floor(screenWidth/3)
		end

		-- Add scaling modifiers for widescreen
		-- 
		-- The UI was designed for FHD 1920x1080, 
		-- so we're scaling to more or less maintain that look,
		-- in both higher and lower resolutions.
		if (aspectRatio >= 1.6) then
			if (viewPortWidth or screenWidth) >= 7680 then
				HD_MODIFIER = 4
			elseif (viewPortWidth or screenWidth) >= 3840 then
				HD_MODIFIER = 2
			elseif (viewPortWidth or screenWidth) >= 1920 then
				HD_MODIFIER = 1
			elseif (viewPortWidth or screenWidth) >= 1600 then
				HD_MODIFIER = math_round(5/6, accuracy)
			elseif (viewPortWidth or screenWidth) >= 1280 then
				HD_MODIFIER = .75
			else
				-- smaller screens are just weird
				HD_MODIFIER = math_round(768/1200, accuracy)
			end
		else
			-- I don't really expect people to be using weird
			-- super high res 4:3 or 5:4 monitors, 
			-- but if they do, we're at least ready for them!
			-- 
			-- These scales also make the UI fit on tiny old
			-- standard screens like 800x600 and 1024x768, though, 
			-- which was sort of the whole point in including them.
			if (viewPortWidth or screenWidth) >= 7680 then
				HD_MODIFIER = 4
			elseif (viewPortWidth or screenWidth) >= 3840 then
				HD_MODIFIER = 2
			elseif (viewPortWidth or screenWidth) >= 1920 then
				HD_MODIFIER = 1
			elseif (viewPortWidth or screenWidth) >= 1600 then
				HD_MODIFIER = math_round(5/6, accuracy)
			elseif (viewPortWidth or screenWidth) >= 1280 then
				HD_MODIFIER = .75
			elseif (viewPortWidth or screenWidth) >= 1024 then
				HD_MODIFIER = math_round(2/3, accuracy)
			else
				-- Smaller screens are even weirder here. 
				-- I mean, 1020x768 or 800x600... really?
				-- Still, let's support it! :) 
				HD_MODIFIER = math_round(1/2, accuracy)
			end
		end
		return viewPortWidth or screenWidth, screenHeight
	end

	UICenter.GetPixelSize = function(self)
		if not(screenPixelWidth and screenPixelHeight) then
			screenPixelWidth, screenPixelHeight = self:GetScreenSize()
		end
		return screenPixelWidth, screenPixelHeight
	end

	UICenter.GetPixelScale = function(self)
		return currentPixelScale
	end

	-- Sets the actual pixel size of the UICenter frame
	UICenter.SetPixelSize = function(self, width, height)
		screenPixelWidth, screenPixelHeight = width, height

		local screenWidth, screenHeight = self:GetScreenSize()
		local effectiveScale = self:GetEffectiveScale()
		local perfectScale = 768/screenHeight
		local scalar = perfectScale / effectiveScale

		self:SetSize(screenPixelWidth * scalar, screenPixelHeight * scalar)
	end

	-- Sets the scale of the UICenter frame, and resizes it to still fill the primary monitor
	UICenter.SetPixelScale = function(self, scale)

		local screenWidth, screenHeight = self:GetScreenSize() -- this also sets the HD_MODIFIER variable
		local perfectEffectiveScale = 768/screenHeight -- The virtual WoW screen always has 768 pixel lines
		local parentEffectiveScale = self:GetParent():GetEffectiveScale()
		local pixelPerfectScale = perfectEffectiveScale / parentEffectiveScale -- this scale is pixel perfect

		currentPixelScale = pixelPerfectScale * scale * HD_MODIFIER

		self:SetScale(currentPixelScale)
		self:SetPixelSize(self:GetScreenSize())
	end

	UICenter.GetSizeOfPixel = function(self)
		local screenWidth, screenHeight = self:GetScreenSize()
		local perfectEffectiveScale = 768/screenHeight
		local parentEffectiveScale = self:GetParent():GetEffectiveScale()
		local pixelPerfectScale = perfectEffectiveScale / parentEffectiveScale

		return pixelPerfectScale
	end

	UICenter:SetAttribute("_onattributechanged", [=[
		if name == "currentPixelScale" then
			local scale = tonumber(value);
			local width, height = self:GetAttribute("screenPixelWidth"), self:GetAttribute("screenPixelHeight"); 
			self:SetScale(scale); 
			self:SetSize()

		elseif name == "pixel_size" then
			local width, height = strsplit(value, ","); 

		end
	]=])

	Engine.UpdateScale = function(self, event, ...)
		if event == "CINEMATIC_STOP" then
			-- We need to make sure that it's actually done, 
			-- as some of those annoying ones that can't be cancelled might still be running. 
			-- It should be noted that InCinematic() still returns true right after this event, 
			-- even when no cinematic is running, thus making it unreliable for this purpose.
			if Engine:IsBuild("MoP") then
				if InCinematic() and not(CinematicFrame.isRealCinematic or CanCancelScene() or CanExitVehicle()) then
					return
				end
			elseif Engine:IsBuild("Cata") then
				if InCinematic() and not(CinematicFrame.isRealCinematic or CanExitVehicle()) then
					return
				end
			end
		else
			-- A cinematic might still be running,
			-- or multiple events might have fired at once. 
			if InCinematic() then
				return
			end
		end


		local screenWidth, screenHeight = UICenter:GetScreenSize()
		if not(screenWidth and screenHeight) then
			if not self:IsEventRegistered("PLAYER_ENTERING_WORLD", "UpdateScale") then
				self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateScale")
			end
			return 
		end

		if event == "PLAYER_ENTERING_WORLD" then
			self:UnregisterEvent("PLAYER_ENTERING_WORLD", "UpdateScale")
		end

		-- todo: make secure calls for all of this, so it can be used from a secure menu that works in combat
		-- 	     probably smart to make the Engine frame attribute driven, and have scale changes applied on attribute change?
		self:Wrap(function() 
			-- resize and rescale our parent frame to ignore user UI scale changes, 
			-- as we have our own setting for this instead
			UICenter:SetPixelScale(1) -- should add a variable here that's stored between sessions
		end)()

		self:KillBlizzard()
	end

	Engine.KillBlizzard = wrap(Engine, function(self)
		if onlyRunOnce then 
			return
		end
		
		-- Killing the UI scale checkbox and slider will prevent blizzards' UI 
		-- from slightly modifying the stored scale everytime we enter the video options. 
		-- If we don't do this, the user will either get spammed with reload requests, 
		-- or the scale will eventually become slightly wrong, and the graphics slightly fuzzy.
		if self:IsBuild("Cata") then
			self:GetHandler("BlizzardUI"):GetElement("Menu_Option"):Remove(true, "Advanced_UIScaleSlider")
			self:GetHandler("BlizzardUI"):GetElement("Menu_Option"):Remove(true, "Advanced_UseUIScale")
		else
			self:GetHandler("BlizzardUI"):GetElement("Menu_Option"):Remove(true, "VideoOptionsResolutionPanelUseUIScale")
			self:GetHandler("BlizzardUI"):GetElement("Menu_Option"):Remove(true, "VideoOptionsResolutionPanelUIScaleSlider")
		end
		
		onlyRunOnce = true
	end)

end

Engine.ReloadUI = function(self)
	local PopUpMessage = self:GetHandler("PopUpMessage")
	if not PopUpMessage:GetPopUp("ENGINE_GENERAL_RELOADUI") then
		PopUpMessage:RegisterPopUp("ENGINE_GENERAL_RELOADUI", {
			title = L["Reload Needed"],
			text = L["The user interface has to be reloaded for the changes to be applied.|n|nDo you wish to do this now?"],
			button1 = L["Accept"],
			button2 = L["Cancel"],
			OnAccept = function() ReloadUI() end,
			OnCancel = function() end,
			timeout = 0,
			exclusive = 1,
			whileDead = 1,
			hideOnEscape = false
		})
	end
	PopUpMessage:ShowPopUp("ENGINE_GENERAL_RELOADUI", self:GetStaticConfig("UI").popup) 
end



-------------------------------------------------------------
-- Engine startup and initialization
-------------------------------------------------------------
do
	local engineIsLoaded, engineVariablesAreLoaded
	Engine.PreInit = function(self, event, ...)
		if event == "ADDON_LOADED" then
			local arg1 = ...
			if arg1 == ADDON then
				engineIsLoaded = true
				self:UnregisterEvent("ADDON_LOADED", "PreInit")
			end
		elseif event == "VARIABLES_LOADED" then
			engineVariablesAreLoaded = true
			self:UnregisterEvent("VARIABLES_LOADED", "PreInit")
		end
		if engineVariablesAreLoaded and engineIsLoaded then
			if not IsLoggedIn() then
				self:RegisterEvent("PLAYER_LOGIN", "Enable")
			end
			return self:Init(event, ADDON)
		end
	end
end

-- called when the addon is fully loaded
Engine.Init = function(self, event, ...)
	local arg1 = ...
	if arg1 ~= ADDON then
		return 
	end

	-- Kill off the event, we don't need it anymore
	if self:IsEventRegistered("ADDON_LOADED", "Init") then
		self:UnregisterEvent("ADDON_LOADED", "Init")
	end

	-- update stored settings (needs to happen before init)
	self:ParseSavedVariables()
	
	-- Might as well do this
	if self:IsBuild("MoP") then
		RegisterStateDriver(UICenter, "visibility", "[petbattle]hide;show")
	end

	-- Previous RothUI users don't always get they need to manually enable these
	if self:IsBuild("Cata") then
		for _,v in ipairs({ "Blizzard_CUFProfiles", "Blizzard_CompactRaidFrames" }) do
			EnableAddOn(v)
			LoadAddOn(v)
		end
	end

	-- Also adding the Blizzard_ObjectiveTracker here, mainly because I tried disabling it myself. Which was bad, bad, bad.
	if self:IsBuild("WoD") then
		EnableAddOn("Blizzard_ObjectiveTracker")
		LoadAddOn("Blizzard_ObjectiveTracker")
	end

	-- initialize all handlers here
	for name, handler in pairs(handlers) do
		handler:Enable()
	end

	-- Cache up shortcuts to some select handlers
	-- we want modules to gain access to directly.
	Orb = self:GetHandler("Orb")
	StatusBar = self:GetHandler("StatusBar")
	
	-- register UI scaling events
	self:RegisterEvent("UI_SCALE_CHANGED", "UpdateScale")
	self:RegisterEvent("DISPLAY_SIZE_CHANGED", "UpdateScale")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateScale")
	self:RegisterEvent("CINEMATIC_STOP", "UpdateScale")

	if VideoOptionsFrameApply then
		VideoOptionsFrameApply:HookScript("OnClick", function() Engine:UpdateScale("VideoOptionsFrameApply") end)
	end

	if VideoOptionsFrameOkay then
		VideoOptionsFrameOkay:HookScript("OnClick", function() Engine:UpdateScale("VideoOptionsFrameOkay") end)
	end

	-- initial UI scale update
	self:UpdateScale()

	local ChatCommand = self:GetHandler("ChatCommand")
	-- add the chat command to toggle auto scaling of the UI
	--[[
	ChatCommand:Register("autoscale", function() 
		local db = self:GetConfig("UI")
		db.autoscale = not db.autoscale
		db.hasbeenqueried = true
		if db.autoscale then
			print(L["Auto scaling of the UI has been enabled."])
		else
			print(L["Auto scaling of the UI has been disabled."])
			Engine:ReloadUI() -- to get back the UI scale slider
		end
		self:UpdateScale()
	end)
	]]--
	
	-- Add a command to reset setups to their default state.
	-- TODO: Make it possible for the modules to add 
	-- 		 these functions in themselves.
	ChatCommand:Register("resetsetup", function()
		-- UI scale
		--[[
		local db = self:GetConfig("UI")
		db.hasbeenqueried = false
		db.autoscale = true
		self:UpdateScale()
		]]--

		-- chat window autoposition
		db = self:GetConfig("ChatWindows")
		db.hasbeenqueried = false
		db.autoposition = true
		self:GetModule("ChatWindows"):PositionChatFrames()
	end)

	-- initialize all modules
	for i = 1, #PRIORITY_INDEX do
		self:ForAll("Init", PRIORITY_INDEX[i], event, ...)
	end
	
	-- enable all objects of NORMAL and HIGH priority
	for i = 1, 2 do
		self:ForAll("Enable", PRIORITY_INDEX[i], event, ...)
	end
	
	initializedObjects[self] = true
	
	-- this could happen on WotLK clients
	if IsLoggedIn() and not self:IsEnabled() then
		self:Enable()
	end
end

-- called after the player has logged in
Engine.Enable = function(self, event, ...)
	if not self:IsInitialized() then
		-- Since the :Init() procedure will call this function, 
		-- we need to return to avoid duplicate calls
		return self:Init("Forced", ADDON)
	end

	-- enable all objects of LOW priority
	for i = 3, #PRIORITY_INDEX do
		self:ForAll("Enable", PRIORITY_INDEX[i], event, ...)
	end
	
	enabledObjects[self] = true
end

-- check if the engine has been initialized
Engine.IsInitialized = function(self)
	return initializedObjects[self]
end

-- check if the engine is fully enabled
Engine.IsEnabled = function(self)
	return enabledObjects[self]
end



-- add general API calls to the Engine
-- *TODO: make a better system for inheritance here
Engine.Check = check 
Engine.Wrap = wrap
Engine.Fire = Fire
Engine.RegisterEvent = RegisterEvent
Engine.RegisterMessage = RegisterMessage
Engine.IsEventRegistered = IsEventRegistered
Engine.IsMessageRegistered = IsMessageRegistered
Engine.UnregisterEvent = UnregisterEvent
Engine.UnregisterMessage = UnregisterMessage
Engine.GetHandler = GetHandler
Engine.GetModule = GetModule
Engine.NewConfig = NewConfig
Engine.GetConfig = GetConfig
Engine.NewStaticConfig = NewStaticConfig
Engine.GetStaticConfig = GetStaticConfig



-- Finalize the Engine and write protect it,
-- because we don't want other addons to be able 
-- to insert methods into the core.
-- Not that there's actually any global access to it, though. 
local protected_MT = {
	__newindex = function(self)
		return error(L["The Engine can't be tampered with!"])
	end,
	__metatable = false
}
(function(tbl)
	local old_MT = getmetatable(tbl)
	if old_MT then
		local new_meta = {}
		for i,v in pairs(old_MT) do
			new_meta[i] = v
		end
		for i,v in pairs(protected_MT) do
			new_meta[i] = v
		end
		return setmetatable(tbl, new_meta)
	else
		return setmetatable(tbl, protected_MT)
	end
end)(Engine)


-- Set the UICenter frame as the default keyword
Engine:RegisterKeywordDefault("UICenter", function() return UICenter end)

-- Register combat tracking events for our safecall wrapper.
Engine:RegisterEvent("PLAYER_REGEN_DISABLED", combatStarts)
Engine:RegisterEvent("PLAYER_REGEN_ENABLED", combatEnds)

-- Register basic startup events with our event handler.
if Engine:IsBuild("Cata") then
	-- From Cata and up saved variables are always loaded before the addon, 
	-- and the event VARIABLES_LOADED simply refer to Blizzard settings here.
	Engine:RegisterEvent("ADDON_LOADED", "Init")
	Engine:RegisterEvent("PLAYER_LOGIN", "Enable")
else
	-- In WotLK the VARIABLES_LOADED event would fire when saved variables
	-- for addons were fully loaded, meaning we should hold back all init procedures
	-- relying on the saved settings until after this event has fired. 
	--
	-- The order was often random, so the only secure way was to register both events, 
	-- and start the init procedures once both had fired for our addon.
	--  
	-- This is also why I'm holding back the PLAYER_LOGIN enable event here, 
	-- because we don't want to risk it firing before the variables are loaded. 
	-- So the PLAYER_LOGIN event is registered during initialization instead,  
	-- or its method fired directly if the player already has logged into the game. 
	Engine:RegisterEvent("ADDON_LOADED", "PreInit")
	Engine:RegisterEvent("VARIABLES_LOADED", "PreInit")
end

-- Our offworld tracking allows us to know when we're on a loading screen.
Engine:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateOffWorld")
Engine:RegisterEvent("PLAYER_LEAVING_WORLD", "UpdateOffWorld")

-- apply scripts to our event/update frame
Frame:SetScript("OnEvent", OnEvent)
Frame:SetScript("OnUpdate", OnUpdate)
