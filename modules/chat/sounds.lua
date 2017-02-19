local Addon, Engine = ...
local Module = Engine:NewModule("ChatSounds")

Module.OnInit = function(self, event, ...)
	self.config = self:GetStaticConfig("ChatSounds") -- setup
	self.db = self:GetConfig("ChatSounds") -- user settings
end

Module.OnEnable = function(self, event, ...)
end

Module.OnDisable = function(self)
end
