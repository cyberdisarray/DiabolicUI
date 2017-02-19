local _, Engine = ...
local Module = Engine:GetModule("ActionBars")
local ControllerWidget = Module:SetWidget("Controller: Pet")

-- Lua API
local setmetatable = setmetatable

-- Client version constants
local ENGINE_MOP = Engine:IsBuild("MoP")

local Controller = Engine:CreateFrame("Frame")
local Controller_MT = { __index = Controller }

Controller.UpdateBarArtwork = function(self)
	local Bar = Module:GetWidget("Bar: Pet"):GetFrame()
	if Bar then
		Bar:UpdateStyle()
	end
end

ControllerWidget.OnEnable = function(self)
	local config = Module.config
	local db = Module.db
	local controlConfig = config.structure.controllers.pet
	local controlPosition = config.structure.controllers.pet.position

	self.Controller = setmetatable(Engine:CreateFrame("Frame", nil, Engine:GetFrame(), "SecureHandlerAttributeTemplate"), Controller_MT)
	self.Controller.db = db
	self.Controller:SetFrameStrata("BACKGROUND")
	self.Controller:SetAllPoints()
	self.Controller:SetAttribute("padding", controlConfig.padding)
	self.Controller:SetAttribute("controller_width", controlConfig.size[1])
	self.Controller:SetAttribute("controller_height", controlConfig.size[2])
	self.Controller:SetAttribute("controller_width_vehicle", controlConfig.size_vehicle[1])
	self.Controller:SetAttribute("controller_height_vehicle", controlConfig.size_vehicle[2])
	self.Controller:SetSize(controlConfig.size[1], controlConfig.size[2])
	self.Controller:Place(controlPosition.point, controlPosition.anchor, controlPosition.anchor_point, controlPosition.xoffset, controlPosition.yoffset)
		
	-- attribute driver to handle number of visible bars, layouts, sizes etc
	self.Controller:SetAttribute("_onattributechanged", [[
		if name == "state-page" then
			if value == "vehicle" then
				local width = self:GetAttribute("controller_width_vehicle");
				local height = self:GetAttribute("controller_height_vehicle");

				self:SetWidth(width);
				self:SetHeight(height);
			else
				local width = self:GetAttribute("controller_width");
				local height = self:GetAttribute("controller_height");

				self:SetWidth(width);
				self:SetHeight(height);
			end
		end
		
		-- update button artwork
		control:CallMethod("UpdateBarArtwork");
	]])	

	
	-- Enable the new page driver
	RegisterStateDriver(self.Controller, "page", ENGINE_MOP and "[overridebar][possessbar][shapeshift][vehicleui][nopet]vehicle;novehicle" or "[bonusbar:5][vehicleui][nopet]vehicle;novehicle")
	
	-- because the bars aren't created when the first call comes
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateBarArtwork")

end

ControllerWidget.UpdateBarArtwork = function(self)
	self:GetFrame():UpdateBarArtwork()
end

ControllerWidget.GetFrame = function(self)
	return self.Controller
end
