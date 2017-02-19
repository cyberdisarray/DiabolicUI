local _, Engine = ...
local Module = Engine:GetModule("ActionBars")
local BarWidget = Module:SetWidget("Bar: XP")
local StatusBar = Engine:GetHandler("StatusBar")
local L = Engine:GetLocale()
local C = Engine:GetStaticConfig("Data: Colors")
local F = Engine:GetStaticConfig("Data: Functions")

-- Lua API
local unpack, select = unpack, select
local tonumber, tostring = tonumber, tostring
local floor, min = math.floor, math.min

-- WoW API
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GetAccountExpansionLevel = GetAccountExpansionLevel
local GetTimeToWellRested = GetTimeToWellRested
local GetXPExhaustion = GetXPExhaustion
local IsXPUserDisabled = IsXPUserDisabled
local MAX_PLAYER_LEVEL_TABLE = MAX_PLAYER_LEVEL_TABLE
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitHasVehiclePlayerFrameUI = UnitHasVehiclePlayerFrameUI
local UnitLevel = UnitLevel
local UnitRace = UnitRace
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax

-- Client version constants
local ENGINE_CATA = Engine:IsBuild("Cata")

local BLANK_TEXTURE = [[Interface\ChatFrame\ChatFrameBackground]]

-- pandaren can get 300% rested bonus
local maxRested = select(2, UnitRace("player")) == "Pandaren" and 3 or 1.5

local shortXPString = "%s%%"
local longXPString = "%s / %s"
local fullXPString = "%s / %s - %s%%"
local restedString = " (%s%% %s)"
local shortLevelString = "%s %d"



-- Bar Templates
----------------------------------------------------------

local Bar = CreateFrame("Frame")
local Bar_MT = { __index = Bar }

-- highest priority, will override everything else
local Bar_Reputation = setmetatable({}, { __index = Bar })
local Bar_Reputation_MT = { __index = Bar_Reputation }

-- shown if no reputation is tracked, and user still can gain experience
local Bar_XP = setmetatable({}, { __index = Bar })
local Bar_XP_MT = { __index = Bar_XP }

-- low priority, only shown if player is max leven and no reputation is tracked
-- should however be true most of the time for top level players in Legion
local Bar_Artifact = setmetatable({}, { __index = Bar })
local Bar_Artifact_MT = { __index = Bar_Artifact }


-- Construct a basic bar
Bar.New = function(self)

	local bar = setmetatable(CreateFrame("Frame"), Bar_MT)
	bar.data = {}

	return bar
end

Bar.UpdateData = function(self)
	local data = self.data
	return data
end

Bar.Update = function(self)
	local data = self:UpdateData()
end

Bar.OnEnter = function(self)
	local data = self:UpdateData()
end

Bar.OnLeave = function(self)
	local data = self:UpdateData()
end



BarWidget.OnEnter = function(self)
	local data = self:UpdateData()
	if not data.xpMax then return end

	GameTooltip_SetDefaultAnchor(GameTooltip, self.Controller)
	--GameTooltip:SetOwner(self.Controller, "ANCHOR_NONE")

	local r, g, b = unpack(C.General.Highlight)
	local r2, g2, b2 = unpack(C.General.OffWhite)
	GameTooltip:AddLine(shortLevelString:format(LEVEL, UnitLevel("player")))
	GameTooltip:AddLine(" ")

	-- use XP as the title
	GameTooltip:AddDoubleLine(L["Current XP: "], longXPString:format(F.Colorize(F.Short(data.xp), "Normal"), F.Colorize(F.Short(data.xpMax), "Normal")), r2, g2, b2, r2, g2, b2)
	
	-- add rested bonus if it exists
	if data.restedLeft and data.restedLeft > 0 then
		GameTooltip:AddDoubleLine(L["Rested Bonus: "], longXPString:format(F.Colorize(F.Short(data.restedLeft), "Normal"), F.Colorize(F.Short(data.xpMax * maxRested), "Normal")), r2, g2, b2, r2, g2, b2)
	end
	
	if data.restState == 1 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Rested"], unpack(C.General.Highlight))
		GameTooltip:AddLine(L["%s of normal experience\ngained from monsters."]:format(shortXPString:format(data.mult)), unpack(C.General.Green))
		if data.resting and data.restedTimeLeft and data.restedTimeLeft > 0 then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(L["Resting"], unpack(C.General.Highlight))
			if data.restedTimeLeft > hour*2 then
				GameTooltip:AddLine(L["You must rest for %s additional\nhours to become fully rested."]:format(F.Colorize(floor(data.restedTimeLeft/hour), "OffWhite")), unpack(C.General.Normal))
			else
				GameTooltip:AddLine(L["You must rest for %s additional\nminutes to become fully rested."]:format(F.Colorize(floor(data.restedTimeLeft/minute), "OffWhite")), unpack(C.General.Normal))
			end
		end
	elseif data.restState >= 2 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Normal"], unpack(C.General.Highlight))
		GameTooltip:AddLine(L["%s of normal experience\ngained from monsters."]:format(shortXPString:format(data.mult)), unpack(C.General.Green))

		if not(data.restedTimeLeft and data.restedTimeLeft > 0) then 
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(L["You should rest at an Inn."], unpack(C.General.DimRed))
		end
	end
	
	GameTooltip:Show()
	self.Controller.mouseIsOver = true
	self:UpdateBar()
end

BarWidget.OnLeave = function(self)
	GameTooltip:Hide()
	self.Controller.mouseIsOver = false
	self:UpdateBar()
end

BarWidget.Update = function(self, event, ...)
	self:UpdateVisibility()
	self:UpdateBar()
end

BarWidget.UpdateBar = function(self)
	local data = self:UpdateData()
	if not data.xpMax then return end
	local r, g, b = unpack(C.General[data.color])
	self.XP:SetStatusBarColor(r, g, b)
	self.XP:SetMinMaxValues(0, data.xpMax)
	self.XP:SetValue(data.xp)
	self.Rested:SetMinMaxValues(0, data.xpMax)
	self.Rested:SetValue(min(data.xpMax, data.xp + (data.restedLeft or 0)))
	if data.restedLeft then
		local r, g, b = unpack(C.General.XPRestedBonus)
		self.Backdrop:SetVertexColor(r *.25, g *.25, b *.25)
	else
		self.Backdrop:SetVertexColor(r *.25, g *.25, b *.25)
	end
	if self.mouseIsOver then
		if data.restedLeft then
			self.Value:SetFormattedText(fullXPString..F.Colorize(restedString, "offgreen"), F.Colorize(F.Short(data.xp), "Normal"), F.Colorize(F.Short(data.xpMax), "Normal"), F.Colorize(F.Short(floor(data.xp/data.xpMax*100)), "Normal"), F.Short(floor(data.restedLeft/data.xpMax*100)), L["Rested"])
		else
			self.Value:SetFormattedText(fullXPString, F.Colorize(F.Short(data.xp), "Normal"), F.Colorize(F.Short(data.xpMax), "Normal"), F.Colorize(F.Short(floor(data.xp/data.xpMax*100)), "Normal"))
		end
	else
		self.Value:SetFormattedText(shortXPString, F.Colorize(F.Short(floor(data.xp/data.xpMax*100)), "Normal"))
	end
end

BarWidget.UpdateData = function(self)
	self.data.resting = IsResting()
	self.data.restState, self.data.restedName, self.data.mult = GetRestState()
	self.data.restedLeft, self.data.restedTimeLeft = GetXPExhaustion(), GetTimeToWellRested()
	self.data.xp, self.data.xpMax = UnitXP("player"), UnitXPMax("player")
	self.data.color = self.data.restedLeft and "XPRested" or "XP"
	self.data.mult = (self.data.mult or 1) * 100
	if self.data.xpMax == 0 then
		self.data.xpMax = nil
	end
	return self.data
end

BarWidget.UpdateSettings = function(self)
	local structure_config = Module.config.structure.controllers.xp
	local art_config = Module.config.visuals.xp
	local num_bars = tostring(self.Controller:GetParent():GetAttribute("numbars"))

	self.Controller:SetSize(unpack(structure_config.size[num_bars]))
	self.XP:SetSize(self.Controller:GetSize())
	self.Rested:SetSize(self.Controller:GetSize())
	self.Backdrop:SetTexture(art_config.backdrop.textures[num_bars])
	
end

BarWidget.UpdateVisibility = function(self)
	local player_is_max_level = MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel() or #MAX_PLAYER_LEVEL_TABLE] or MAX_PLAYER_LEVEL_TABLE[#MAX_PLAYER_LEVEL_TABLE]
	local xp_is_disabled = IsXPUserDisabled() or UnitLevel("player") == player_is_max_level
	if ENGINE_CATA then
		-- Certain vehicles like the chair at the Pilgrim's Bounty tables respond to macro vehicle events,
		-- but don't fire for UnitHasVehicleUI. They do however fire for UnitHasVehiclePlayerFrameUI
		-- which was introduced with the Cataclysm expansion.
		if xp_is_disabled or UnitHasVehicleUI("player") or UnitHasVehiclePlayerFrameUI("player") then 
			self.Controller:Hide()
		else
			self.Controller:Show()
		end
	else
		if xp_is_disabled or UnitHasVehicleUI("player") or self.InVehicle then 
			self.Controller:Hide()
		else
			self.Controller:Show()
		end
	end
end


BarWidget.OnEnable = function(self)
	self.data = {}

	local structure_config = Module.config.structure.controllers.xp
	local art_config = Module.config.visuals.xp
	local num_bars = tostring(Module.db.num_bars)

	local Main = Module:GetWidget("Controller: Main"):GetFrame()
	
	local Controller = CreateFrame("Frame", nil, Main)
	Controller:SetFrameStrata("BACKGROUND")
	Controller:SetFrameLevel(0)
	Controller:SetSize(unpack(structure_config.size[num_bars]))
	Controller:SetPoint(unpack(structure_config.position))
	Controller:EnableMouse(true)
	Controller:SetScript("OnEnter", function() self:OnEnter() end)
	Controller:SetScript("OnLeave", function() self:OnLeave() end)

	local Backdrop = Controller:CreateTexture(nil, "BACKGROUND")
	Backdrop:SetSize(unpack(art_config.backdrop.texture_size))
	Backdrop:SetPoint(unpack(art_config.backdrop.texture_position))
	Backdrop:SetTexture(art_config.backdrop.textures[num_bars])
	Backdrop:SetAlpha(.75)
	
	local Rested = StatusBar:New(Controller)
	Rested:SetSize(Controller:GetSize())
	Rested:SetAllPoints()
	Rested:SetFrameLevel(1)
	Rested:SetAlpha(art_config.rested.alpha)
	Rested:SetStatusBarTexture(art_config.rested.texture)
	Rested:SetStatusBarColor(unpack(C.General.XPRestedBonus))
	Rested:SetSparkTexture(art_config.rested.spark.texture)
	Rested:SetSparkSize(unpack(art_config.rested.spark.size))
	Rested:SetSparkFlash(2.75, 1.25, .175, .425)
	
	local XP = StatusBar:New(Controller)
	XP:SetSize(Controller:GetSize())
	XP:SetAllPoints()
	XP:SetFrameLevel(2)
	XP:SetAlpha(art_config.bar.alpha)
	XP:SetStatusBarTexture(art_config.bar.texture)
	XP:SetSparkTexture(art_config.bar.spark.texture)
	XP:SetSparkSize(unpack(art_config.bar.spark.size))
	XP:SetSparkFlash(2.75, 1.25, .35, .85)
	
	local Overlay = CreateFrame("Frame", nil, Controller)
	Overlay:SetFrameStrata("MEDIUM")
	Overlay:SetFrameLevel(35) -- above the actionbar artwork
	Overlay:SetAllPoints()
	
	local Value = Overlay:CreateFontString(nil, "OVERLAY")
	Value:SetPoint("CENTER")
	Value:SetFontObject(art_config.normalFont)
	Value:Hide()
	
	self.Controller = Controller
	self.Backdrop = Backdrop
	self.Rested = Rested
	self.XP = XP
	self.Value = Value
	
	-- Our XP/Rep bars aren't secure, so we need to update their sizes
	-- from normal Lua, not the secure environment.
	Main:HookScript("OnAttributeChanged", function(_, name, value) 
		if name == "numbars" then
			self:UpdateSettings()
		elseif name == "state-page" then
			if value == "vehicle" then
				self.InVehicle = true
			else
				self.InVehicle = nil
			end
		end
	end)
	
	self:RegisterEvent("PLAYER_ALIVE", "Update")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
	self:RegisterEvent("PLAYER_LEVEL_UP", "Update")
	self:RegisterEvent("PLAYER_XP_UPDATE", "Update")
	self:RegisterEvent("PLAYER_LOGIN", "Update")
	self:RegisterEvent("PLAYER_FLAGS_CHANGED", "Update")
	self:RegisterEvent("DISABLE_XP_GAIN", "Update")
	self:RegisterEvent("ENABLE_XP_GAIN", "Update")
	self:RegisterEvent("PLAYER_UPDATE_RESTING", "Update")
	self:RegisterEvent("UNIT_ENTERED_VEHICLE", "Update")
	self:RegisterEvent("UNIT_EXITED_VEHICLE", "Update")
	
	
	-- Note to self for later: 
	-- 	ReputationWatchBarStatusBar ( >= WoD)
	-- 	ReputationWatchBar.StatusBar (Legion > )
	
	-- debugging
	--local test_texture = Overlay:CreateTexture(nil, "OVERLAY")
	--test_texture:SetTexture(BLANK_TEXTURE)
	--test_texture:SetAllPoints()
	--test_texture:SetVertexColor(1, 0, 0, .5)
	
end

BarWidget.GetFrame = function(self)
	return self.Controller
end

