local ADDON, Engine = ...
local Handler = Engine:NewHandler("ChatCommand")

-- Lua API
local string_find = string.find
local string_gsub = string.gsub
local string_split = string.split

-- WoW API
local SlashCmdList = _G.SlashCmdList

-- command registry for all modules
local commandRegistry = {} 

Handler.ParseCommand = function(self, command)
	command = string_gsub(command, "  ", " ")
	if string_find(command, "%s") then
		return string_split(command, " ") -- wrong order?
	else
		return command
	end
end

Handler.PerformCommand = function(self, command, ...)
	if not commandRegistry[command] then
		return
	end
	return commandRegistry[command](...)
end

Handler.OnEnable = function(self)

	_G.SLASH_DIABOLICUISLASHHANDLER1 = "/diabolic"
	_G.SLASH_DIABOLICUISLASHHANDLER2 = "/diabolicui"
	_G.SLASH_DIABOLICUISLASHHANDLER3 = "/dui"

	SlashCmdList["DIABOLICUISLASHHANDLER"] = function(...)
		self:PerformCommand(self:ParseCommand(...))
	end
end

Handler.Register = function(self, command, func)

	-- silently fail if the command already exists
	if commandRegistry[command] then
		return
	end

	commandRegistry[command] = func
end
