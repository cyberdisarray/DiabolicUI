local Addon, Engine = ...
local Module = Engine:NewModule("ChatFilters")

Module.OnInit = function(self, event, ...)
	self.config = self:GetStaticConfig("ChatFilters") -- setup
	self.db = self:GetConfig("ChatFilters") -- user settings
end

Module.OnEnable = function(self, event, ...)
end

Module.OnDisable = function(self)
end
