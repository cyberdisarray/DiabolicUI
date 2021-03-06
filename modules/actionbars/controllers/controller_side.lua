local _, Engine = ...
local Module = Engine:GetModule("ActionBars")
local ControllerWidget = Module:SetWidget("Controller: Side")

-- Lua API
local ipairs = ipairs
local pairs = pairs
local table_concat = table.concat
local table_insert = table.insert

-- Client version constants
local ENGINE_MOP = Engine:IsBuild("MoP")


local Controller = Engine:CreateFrame("Frame")
local Controller_MT = { __index = Controller }

-- Saves settings when the number of bars are changed
Controller.SaveSettings = function(self)
	local db = self.db
	if not db then
		return
	end
	db.num_side_bars = tonumber(self:GetAttribute("numbars"))
end

-- Proxy method called from the secure environment upon bar num changes and vehicles/possess
-- *not currently used
Controller.UpdateArtwork = function(self)
	Module:UpdateArtwork()
end

-- Updates bar and button artwork upon bar num changes and vehicles/possess
Controller.UpdateBarArtwork = function(self)
	for i = 1,self:GetAttribute("numbars") do
		local Bar = Module:GetWidget("Bar: "..(i + 3)):GetFrame()
		if Bar then
			Bar:UpdateStyle()
		end
	end
end

ControllerWidget.OnEnable = function(self)
	local config = Module.config
	local db = Module.db

	self.Controller = setmetatable(Engine:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate"), Controller_MT)
	self.Controller:SetFrameStrata("BACKGROUND")
	self.Controller:SetAllPoints()
	self.Controller.db = db
	
	-- store controller settings
	local control_config = config.structure.controllers.side
	self.Controller:SetAttribute("padding", control_config.padding)
	self.Controller:SetAttribute("offset", control_config.offset)

	for id in pairs(control_config.size) do
		self.Controller:SetAttribute("controller_width-"..id, control_config.size[id][1])
		self.Controller:SetAttribute("controller_height-"..id, control_config.size[id][2])
	end
	
	self.Controller:ClearAllPoints()

	for id,points in ipairs(control_config.position) do
		self.Controller:Point(points.point, points.anchor, points.anchor_point, points.xoffset, points.yoffset)
	end
	
	-- reset the page before applying a new page driver
	self.Controller:SetAttribute("state-page", "0") 
	
	-- Paging based on class/stance
	-- *in theory a copy of what the main actionbar uses
	-- *also supports user changed paging
	local driver = {}
	local _, player_class = UnitClass("player")

	if ENGINE_MOP then 
		table_insert(driver, "[overridebar][possessbar][shapeshift]possess")
		table_insert(driver, "[bar:2]2; [bar:3]3; [bar:4]4; [bar:5]5; [bar:6]6")

		if player_class == "DRUID" then
			table_insert(driver, "[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10")
		elseif player_class == "MONK" then
			table_insert(driver, "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9")
		elseif player_class == "PRIEST" then
			table_insert(driver, "[bonusbar:1] 7")
		elseif player_class == "ROGUE" then
			table_insert(driver, ("[%s:%s] %s; "):format("form", GetNumShapeshiftForms() + 1, 7) .. "[form:1] 7; [form:3] 7")
		end

	else
		table_insert(driver, "[bonusbar:5]vehicle")
		table_insert(driver, "[vehicleui]vehicle")
		--table_insert(driver, "[bonusbar:5]11")
		table_insert(driver, "[bar:2]2; [bar:3]3; [bar:4]4; [bar:5]5; [bar:6]6")

		if player_class == "DRUID" then
			table_insert(driver, "[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10")
		elseif player_class == "PRIEST" then
			table_insert(driver, "[bonusbar:1] 7")
		elseif player_class == "ROGUE" then
			table_insert(driver, "[bonusbar:1] 7; [form:3] 8")
		elseif player_class == "WARLOCK" then
			table_insert(driver, "[form:2] 7")
		elseif player_class == "WARRIOR" then
			table_insert(driver, "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9")
		end
		
	end
	
	table_insert(driver, "1")
	local page_driver = table_concat(driver, "; ")
	
	-- attribute driver to handle number of visible bars, layouts, sizes etc
	self.Controller:SetAttribute("_onattributechanged", [[
		-- In theory we could use this to create different artworks and layouts
		-- for each stance, actionpage or macro conditional there is. 
		-- For our current UI though, we're only using it to capture vehicles and possessions.
		if name == "state-page" then
			local page = tonumber(value);
			if page then
				self:SetAttribute("state", page);
			end
		end
		
		-- new action page
		if name == "state" then
		end
		
		-- User changed number of visible bars, 
		-- or a pet was called/dismissed and we need a size change for padding.
		if name == "numbars" or name == "petupdate" then
			local num = tonumber(value);
			if num then
				local old_num = self:GetAttribute("old_numbars");
				if old_num ~= num or name == "petupdate" then 
					
					-- tell the secure children about the bar number update
					control:ChildUpdate("set_numbars", num);
					self:SetAttribute("old_numbars", num);
					
					-- update button artwork
					control:CallMethod("UpdateBarArtwork");
					
					-- update controller size
					-- *don't do this if we're currently in a vehicle
					local current_state = self:GetAttribute("state-page");
					if tonumber(current_state) then
						if num == 0 and UnitExists("pet") then
							local width = self:GetAttribute("offset");
							local height = self:GetAttribute("controller_height-"..num);

							self:SetWidth(width);
							self:SetHeight(height);
						else
							local width = self:GetAttribute("controller_width-"..num);
							local height = self:GetAttribute("controller_height-"..num);

							self:SetWidth(width);
							self:SetHeight(height);
						end

						-- tell the addon to update artwork
						--control:CallMethod("UpdateArtwork");
					end

					-- save the number of bars
					control:CallMethod("SaveSettings");
				end
			end
		end
	]])
	
	-- enable the new page driver
	RegisterStateDriver(self.Controller, "page", page_driver)
	
end

ControllerWidget.GetFrame = function(self)
	return self.Controller
end
