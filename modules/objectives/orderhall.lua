local _, Engine = ...
local Module = Engine:NewModule("OrderHall")


Module.UpdateOrderHallUI = function(self, event, ...)
	local config = self:GetStaticConfig("Objectives").orderhall
end

Module.CreateOrderHallUI = function(self, event, ...)
	local config = self:GetStaticConfig("Objectives").orderhall

	self:RegisterEvent("DISPLAY_SIZE_CHANGED", "UpdateOrderHallUI")
	self:RegisterEvent("UI_SCALE_CHANGED", "UpdateOrderHallUI")
	self:RegisterEvent("GARRISON_FOLLOWER_CATEGORIES_UPDATED", "UpdateOrderHallUI")
	self:RegisterEvent("GARRISON_FOLLOWER_ADDED", "UpdateOrderHallUI")
	self:RegisterEvent("GARRISON_FOLLOWER_REMOVED", "UpdateOrderHallUI")

end

Module.KillBlizzard = function(self, event, ...)
	self:GetHandler("BlizzardUI"):GetElement("OrderHall"):Disable()
end

Module.Blizzard_Loaded = function(self, event, addon, ...)
	if addon == "Blizzard_OrderHallUI" then
		self:UnregisterEvent("ADDON_LOADED", "Blizzard_Loaded")
		self:KillBlizzard()
	end
end

Module.OnInit = function(self)
	-- Class Order Halls were introduced in Legion
	if not Engine:IsBuild("Legion") then
		return
	end

	if IsAddOnLoaded("Blizzard_OrderHallUI") then
		self:KillBlizzard()
	else
		self:RegisterEvent("ADDON_LOADED", "Blizzard_Loaded")
	end

end
