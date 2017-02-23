local ADDON, Engine = ...
local Module = Engine:GetModule("UnitFrames")
local UnitFrameWidget = Module:SetWidget("Unit: Player")
local C = Engine:GetStaticConfig("Data: Colors")

-- Lua API
local _G = _G
local unpack = unpack
local pairs = pair
local tostring = tostring

-- WoW API
local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitClass = _G.UnitClass
local UnitPowerMax = _G.UnitPowerMax
local UnitPowerType = _G.UnitPowerType

-- WoW constants
local SPELL_POWER_MANA = _G.SPELL_POWER_MANA

-- player class
local _,CLASS = UnitClass("player")

-- bar visibility constants
local HAS_VEHICLE_UI = false -- entering a value just to reserve the memory. semantics. 
local NUM_VISIBLE_BARS = 1 -- need a fallback here or the spawn will bug out



local updateValueDisplay = function(self)
	local forced = self.mouseIsOver
	if UnitAffectingCombat("player") or forced then
		local orbValue = self.orbValue
		orbValue:SetAlpha(.9)
		orbValue:Show()

		if forced then
			local ourLabel = orbValue.Label
			ourLabel:SetAlpha(.9)
			ourLabel:Show()
		else
			local ourLabel = self.orbValue.Label
			ourLabel:SetAlpha(0)
			ourLabel:Hide()
		end
	else
		local orbValue = self.orbValue
		orbValue:SetAlpha(.4)
		orbValue:Hide()

		local ourLabel = self.orbValue.Label
		ourLabel:SetAlpha(0)
		ourLabel:Hide()
	end
end

local postUpdateHealth = function(health)
	updateValueDisplay(health._owner)
end

local postUpdatePower = function(power)
	local owner = power._owner
	local label = power.Value.Label
	local unit = owner.unit

	-- Check if mana is the current resource or not, 
	-- and crop the primary power bar as needed to 
	-- give room for the secondary mana orb. 
	local powerID, powerType = UnitPowerType(unit)
	label:SetText(_G[powerType] or "")

	if powerType == "MANA" then
		power:SetCrop(0, 0)
	else
		local manamax = UnitPowerMax(unit, SPELL_POWER_MANA)
		if manamax > 0 then
			power:SetCrop(0, power.crop)
		else
			power:SetCrop(0, 0)
		end
	end

	updateValueDisplay(owner)
end

local onEnter = function(self)
	self.mouseIsOver = true
	updateValueDisplay(self)
end

local onLeave = function(self)
	self.mouseIsOver = false
	updateValueDisplay(self)
end

local postCreateAuraButton = function(self, button)
	local config = self.buttonConfig
	local width, height = unpack(config.size)
	local r, g, b = unpack(config.color)

	local icon = button:GetElement("Icon")
	local overlay = button:GetElement("Overlay")
	local scaffold = button:GetElement("Scaffold")
	local timer = button:GetElement("Timer")

	local timerBar = timer.Bar
	local timerBarBackground = timer.Background
	local timerScaffold = timer.Scaffold

	overlay:SetBackdrop(config.glow.backdrop)

	local glow = button:CreateFrame()
	glow:SetFrameLevel(button:GetFrameLevel())
	glow:SetPoint("TOPLEFT", scaffold, "TOPLEFT", -4, 4)
	glow:SetPoint("BOTTOMRIGHT", scaffold, "BOTTOMRIGHT", 3, -3)
	glow:SetBackdrop(config.glow.backdrop)

	local iconShade = scaffold:CreateTexture()
	iconShade:SetDrawLayer("OVERLAY")
	iconShade:SetAllPoints(icon)
	iconShade:SetTexture(config.shade.texture)
	iconShade:SetVertexColor(0, 0, 0, 1)

	local iconDarken = scaffold:CreateTexture()
	iconDarken:SetDrawLayer("OVERLAY")
	iconDarken:SetAllPoints(icon)
	iconDarken:SetColorTexture(0, 0, 0, .15)

	local iconOverlay = overlay:CreateTexture()
	iconOverlay:Hide()
	iconOverlay:SetDrawLayer("OVERLAY")
	iconOverlay:SetAllPoints(icon)
	iconOverlay:SetColorTexture(0, 0, 0, 1)
	icon.Overlay = iconOverlay

	local timerOverlay = timer:CreateFrame()
	timerOverlay:SetFrameLevel(timer:GetFrameLevel() + 3)
	timerOverlay:SetPoint("TOPLEFT", -3, 3)
	timerOverlay:SetPoint("BOTTOMRIGHT", 3, -3)
	timerOverlay:SetBackdrop(config.glow.backdrop)

	button.SetBorderColor = function(self, r, g, b)
		timerBarBackground:SetVertexColor(r * 1/3, g * 1/3, b * 1/3)
		timerBar:SetStatusBarColor(r * 2/3, g * 2/3, b * 2/3)

		overlay:SetBackdropBorderColor(r, g, b, .5)
		glow:SetBackdropBorderColor(r/3, g/3, b/3, .75)
		timerOverlay:SetBackdropBorderColor(r, g, b, .5)

		scaffold:SetBackdropColor(r * 1/3, g * 1/3, b * 1/3)
		scaffold:SetBackdropBorderColor(r, g, b)

		timerScaffold:SetBackdropColor(r * 1/3, g * 1/3, b * 1/3)
		timerScaffold:SetBackdropBorderColor(r, g, b)
	end

	button:SetElement("Glow", glow)
	button:SetSize(width, height)
	button:SetBorderColor(r * 4/5, g * 4/5, b * 4/5)
end

local postUpdateAuraButton = function(self, button, ...)
	local updateType = ...
	local config = self.buttonConfig

	local icon = button:GetElement("Icon")
	local glow = button:GetElement("Glow")
	local timer = button:GetElement("Timer")
	local scaffold = button:GetElement("Scaffold")

	if timer:IsShown() then
		glow:SetPoint("BOTTOMRIGHT", timer, "BOTTOMRIGHT", 3, -3)
	else
		glow:SetPoint("BOTTOMRIGHT", scaffold, "BOTTOMRIGHT", 3, -3)
	end
	
	if self.hideTimerBar then
		local color = config.color
		button:SetBorderColor(color[1], color[2], color[3]) 
		icon:SetDesaturated(false)
		icon:SetVertexColor(.85, .85, .85)
	else
		if button.isBuff then
			if button.isStealable then
				local color = C.General.Title
				button:SetBorderColor(color[1], color[2], color[3]) 
				icon:SetDesaturated(false)
				icon:SetVertexColor(1, 1, 1)
				icon.Overlay:Hide()

			elseif button.isCastByPlayer then
				local color = C.General.XP
				button:SetBorderColor(color[1], color[2], color[3]) 
				icon:SetDesaturated(false)
				icon:SetVertexColor(1, 1, 1)
				icon.Overlay:Hide()

			else

				local color = config.color
				button:SetBorderColor(color[1], color[2], color[3]) 

				if icon:SetDesaturated(true) then
					icon:SetVertexColor(1, 1, 1)
					icon.Overlay:SetVertexColor(C.General.UIOverlay[1], C.General.UIOverlay[2], C.General.UIOverlay[3], .5)
					icon.Overlay:Show()
				else
					icon:SetDesaturated(false)
					icon:SetVertexColor(.7, .7, .7)
					icon.Overlay:SetVertexColor(C.General.UIOverlay[1], C.General.UIOverlay[2], C.General.UIOverlay[3], .25)
					icon.Overlay:Show()
				end		
			end

		elseif button.isCastByPlayer then
			button:SetBorderColor(.7, .1, .1)
			icon:SetDesaturated(false)
			icon:SetVertexColor(1, 1, 1)
			icon.Overlay:Hide()

		else
			local color = config.color
			button:SetBorderColor(color[1], color[2], color[3])

			if icon:SetDesaturated(true) then
				icon:SetVertexColor(1, 1, 1)
				icon.Overlay:SetVertexColor(C.General.UIOverlay[1], C.General.UIOverlay[2], C.General.UIOverlay[3], .5)
				icon.Overlay:Show()
			else
				icon:SetDesaturated(false)
				icon:SetVertexColor(.7, .7, .7)
				icon.Overlay:SetVertexColor(C.General.UIOverlay[1], C.General.UIOverlay[2], C.General.UIOverlay[3], .25)
				icon.Overlay:Show()
			end		
		end
	end

end

local MINUTE = 60
local HOUR = 3600
local DAY = 86400

-- Time limit where we separate between short and long buffs
local TIME_LIMIT = MINUTE * 5
local TIME_LIMIT_LOW = MINUTE

-- Combat relevant buffs
local shortBuffFilter = function(self, name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer)
	if duration and (duration > 0) then
		-- Don't list buffs with a long duration here
		if duration > TIME_LIMIT then
			return false
		end
		return true
	end
end

-- Combat relevant debuffs
local shortDebuffFilter = function(self, name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer)
	if duration and (duration > 0) then
		if duration > TIME_LIMIT then
			return false
		end
		return true
	end
end

-- Buffs with a remaining duration of 5 minutes or more, and static auras with no duration
local longBuffFilter = function(self, name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer)
	if duration and (duration > 0) then
		if duration > TIME_LIMIT then
			return true
		end
		return false
	elseif (not duration) or (duration == 0) then
		--if isCastByPlayer then
		--	return false
		--end
		return true
	end
end

-- Left orb (health, castbar, actionbar auras)	
local StyleLeftOrb = function(self, unit, index, numBars, inVehicle)
	local config = Module:GetStaticConfig("UnitFrames").visuals.units.player
	local db = Module:GetConfig("UnitFrames") 

	local configHealth = config.left.health
	local configHealthSpark = config.left.health.spark
	local configHealthLayers = config.left.health.layers
	local configHealthTexts = config.texts.health

	self:Size(unpack(config.left.size))
	self:Place(unpack(config.left.position))


	-- Health
	-------------------------------------------------------------------
	local Health = self:CreateOrb()
	Health:SetSize(unpack(configHealth.size))
	Health:SetPoint(unpack(configHealth.position))
	Health:SetStatusBarTexture(configHealthLayers.gradient.texture, "bar")
	Health:SetStatusBarTexture(configHealthLayers.moon.texture, "moon")
	Health:SetStatusBarTexture(configHealthLayers.smoke.texture, "smoke")
	Health:SetStatusBarTexture(configHealthLayers.shade.texture, "shade")
	Health:SetSparkTexture(configHealthSpark.texture)
	Health:SetSparkSize(unpack(configHealthSpark.size))
	Health:SetSparkOverflow(configHealthSpark.overflow)
	Health:SetSparkFlash(unpack(configHealthSpark.flash))
	Health:SetSparkFlashSize(unpack(configHealthSpark.flash_size))
	Health:SetSparkFlashTexture(configHealthSpark.flash_texture)

	Health.useClassColor = true -- make this a user option later on
	Health.frequent = 1/120

	Health.Value = Health:GetOverlay():CreateFontString(nil, "OVERLAY")
	Health.Value:SetFontObject(configHealthTexts.font_object)
	Health.Value:SetPoint(unpack(configHealthTexts.position))

	Health.Value.Label = Health:GetOverlay():CreateFontString(nil, "OVERLAY")
	Health.Value.Label:SetFontObject(configHealthTexts.font_object)
	Health.Value.Label:SetPoint("BOTTOM", Health.Value, "TOP", 0, 2)
	Health.Value.Label:SetText(HEALTH)

	Health.Value.showPercent = false
	Health.Value.showDeficit = false
	Health.Value.showMaximum = true
	Health.Value.showAtZero = true

	Health.PostUpdate = postUpdateHealth
	

	
	-- CastBar
	-------------------------------------------------------------------
	local CastBar = self:CreateStatusBar()
	CastBar:Hide()
	CastBar:SetSize(unpack(config.castbar.size))
	CastBar:SetStatusBarTexture(config.castbar.texture)
	CastBar:SetStatusBarColor(unpack(config.castbar.color))
	CastBar:SetSparkTexture(config.castbar.spark.texture)
	CastBar:SetSparkSize(unpack(config.castbar.spark.size))
	CastBar:SetSparkFlash(unpack(config.castbar.spark.flash))
	CastBar:DisableSmoothing(true)
	CastBar:Place(unpack(config.castbar.position))
	
	CastBar.Backdrop = CastBar:CreateTexture(nil, "BACKGROUND")
	CastBar.Backdrop:SetSize(unpack(config.castbar.backdrop.size))
	CastBar.Backdrop:SetPoint(unpack(config.castbar.backdrop.position))
	CastBar.Backdrop:SetTexture(config.castbar.backdrop.texture)

	CastBar.SafeZone = CastBar:CreateTexture(nil, "ARTWORK")
	CastBar.SafeZone:SetPoint("RIGHT")
	CastBar.SafeZone:SetPoint("TOP")
	CastBar.SafeZone:SetPoint("BOTTOM")
	CastBar.SafeZone:SetTexture(.7, 0, 0, .25)
	CastBar.SafeZone:SetWidth(0.0001)
	CastBar.SafeZone:Hide()

	CastBar.Name = CastBar:CreateFontString(nil, "OVERLAY")
	CastBar.Name:SetFontObject(config.castbar.name.font_object)
	CastBar.Name:SetPoint(unpack(config.castbar.name.position))
	CastBar.Name.Shade = CastBar:CreateTexture(nil, "BACKGROUND")
	CastBar.Name.Shade:SetPoint("CENTER", CastBar.Name, "CENTER", 0, 4)
	CastBar.Name.Shade:SetTexture(config.castbar.shade.texture)
	CastBar.Name.Shade:SetVertexColor(0, 0, 0)
	CastBar.Name.Shade:SetAlpha(1/3)

	CastBar.Overlay = CastBar:CreateFrame()
	CastBar.Overlay:SetAllPoints()

	CastBar.Border = CastBar.Overlay:CreateTexture(nil, "BORDER")
	CastBar.Border:SetSize(unpack(config.castbar.border.size))
	CastBar.Border:SetPoint(unpack(config.castbar.border.position))
	CastBar.Border:SetTexture(config.castbar.border.texture)

	CastBar.Value = CastBar.Overlay:CreateFontString(nil, "OVERLAY")
	CastBar.Value:SetFontObject(config.castbar.value.font_object)
	CastBar.Value:SetPoint(unpack(config.castbar.value.position))
	CastBar.Value.Shade = CastBar:CreateTexture(nil, "BACKGROUND")
	CastBar.Value.Shade:SetPoint("CENTER", CastBar.Value, "CENTER", 0, 4)
	CastBar.Value.Shade:SetTexture(config.castbar.shade.texture)
	CastBar.Value.Shade:SetVertexColor(0, 0, 0)
	CastBar.Value.Shade:SetAlpha(1/3)

	
	-- Buffs (combat)
	-------------------------------------------------------------------
	local Buffs = self:CreateFrame()
	Buffs:SetSize(unpack(config.buffs.size[HAS_VEHICLE_UI and "vehicle" or tostring(NUM_VISIBLE_BARS)])) 
	Buffs:Place(unpack(config.buffs.position))

	Buffs.config = config.buffs
	Buffs.buttonConfig = config.buffs.button
	Buffs.auraSize = config.buffs.button.size
	Buffs.spacingH = config.buffs.spacingH
	Buffs.spacingV = config.buffs.spacingV
	Buffs.growthX = "RIGHT"
	Buffs.growthY = "UP"
	Buffs.filter = "HELPFUL|PLAYER"
	Buffs.sortByTime = true
	Buffs.sortByDuration = true
	Buffs.sortByName = true
	Buffs.hideCooldownSpiral = false

	Buffs.BuffFilter = shortBuffFilter
	Buffs.PostCreateButton = postCreateAuraButton
	Buffs.PostUpdateButton = postUpdateAuraButton


	-- Debuffs
	-------------------------------------------------------------------
	local Debuffs = self:CreateFrame()
	Debuffs:SetSize(unpack(config.debuffs.size[HAS_VEHICLE_UI and "vehicle" or tostring(NUM_VISIBLE_BARS)]))  
	Debuffs:Place(unpack(config.debuffs.position))

	Debuffs.config = config.debuffs
	Debuffs.buttonConfig = config.debuffs.button
	Debuffs.auraSize = config.debuffs.button.size
	Debuffs.spacingH = config.debuffs.spacingH
	Debuffs.spacingV = config.debuffs.spacingV
	Debuffs.growthX = "LEFT"
	Debuffs.growthY = "UP"
	Debuffs.filter = "HARMFUL"
	Debuffs.sortByTime = true
	Debuffs.sortByDuration = true
	Debuffs.sortByName = true
	Debuffs.hideCooldownSpiral = false

	Debuffs.DebuffFilter = shortDebuffFilter
	Debuffs.PostCreateButton = postCreateAuraButton
	Debuffs.PostUpdateButton = postUpdateAuraButton

	hooksecurefunc(CastBar.Name, "SetText", function(self) self.Shade:SetSize(self:GetStringWidth() + 128, self:GetStringHeight() + 48) end)

	self.orbValue = Health.Value

	self:HookScript("OnEnter", onEnter)
	self:HookScript("OnLeave", onLeave)

	self.Buffs = Buffs
	self.Debuffs = Debuffs
	self.Health = Health
	self.CastBar = CastBar
	

end

-- Right orb (power, minimap auras)
local StyleRightOrb = function(self, unit, index, numBars, inVehicle)
	local config = Module:GetStaticConfig("UnitFrames").visuals.units.player
	local db = Module:GetConfig("UnitFrames") 

	local configPower = config.right.power
	local configPowerSpark = config.right.power.spark
	local configPowerLayers = config.right.power.layers
	local configPowerTexts = config.texts.power
	
	self:Size(unpack(config.right.size))
	self:Place(unpack(config.right.position))


	-- Power
	-------------------------------------------------------------------

	local Power = self:CreateOrb(true) -- reverse the rotation
	Power:SetSize(unpack(configPower.size))
	Power:SetPoint(unpack(configPower.position))
	Power:SetCrop(0, 0)
	Power.crop = configPower.size[1]/2

	Power:SetStatusBarTexture(configPowerLayers.gradient.texture, "bar")
	Power:SetStatusBarTexture(configPowerLayers.moon.texture, "moon")
	Power:SetStatusBarTexture(configPowerLayers.smoke.texture, "smoke")
	Power:SetStatusBarTexture(configPowerLayers.shade.texture, "shade")

	Power:SetSparkTexture(configPowerSpark.texture)
	Power:SetSparkSize(unpack(configPowerSpark.size))
	Power:SetSparkOverflow(configPowerSpark.overflow)
	Power:SetSparkFlash(unpack(configPowerSpark.flash))
	Power:SetSparkFlashSize(unpack(configPowerSpark.flash_size))
	Power:SetSparkFlashTexture(configPowerSpark.flash_texture)

	Power.Value = Power:GetOverlay():CreateFontString(nil, "OVERLAY")
	Power.Value:SetFontObject(configPowerTexts.font_object)
	Power.Value:SetPoint(unpack(configPowerTexts.position))
	Power.Value.showPercent = false
	Power.Value.showDeficit = false
	Power.Value.showMaximum = true
	Power.Value.showAtZero = true

	Power.Value.Label = Power:GetOverlay():CreateFontString(nil, "OVERLAY")
	Power.Value.Label:SetFontObject(configPowerTexts.font_object)
	Power.Value.Label:SetPoint("BOTTOM", Power.Value, "TOP", 0, 2)
	Power.Value.Label:SetText("")
	
	Power.frequent = 1/120
	
	Power.PostUpdate = postUpdatePower


	-- Adding a mana only power resource for classes or specs with mana as the secondary resource.
	-- This is compatible with all current and future classes and specs that function this way, 
	-- since the only thing this element does is to show mana if the player has mana but 
	-- mana isn't the currently displayed resource. 
	local Mana = self:CreateOrb()
	Mana:Hide()
	Mana:SetCrop(configPower.size[1]/2, 0)
	Mana:SetSize(unpack(configPower.size))
	Mana:SetPoint(unpack(configPower.position))

	Mana:SetStatusBarTexture(configPowerLayers.gradient.texture, "bar")
	Mana:SetStatusBarTexture(configPowerLayers.moon.texture, "moon")
	Mana:SetStatusBarTexture(configPowerLayers.smoke.texture, "smoke")
	Mana:SetStatusBarTexture(configPowerLayers.shade.texture, "shade")

	Mana:SetSparkTexture(configPowerSpark.texture)
	Mana:SetSparkSize(unpack(configPowerSpark.size))
	Mana:SetSparkOverflow(configPowerSpark.overflow)
	Mana:SetSparkFlash(unpack(configPowerSpark.flash))
	Mana:SetSparkFlashSize(unpack(configPowerSpark.flash_size))
	Mana:SetSparkFlashTexture(configPowerSpark.flash_texture)

	Mana.frequent = 1/120

	-- We need a holder frame to get the orb split above the globe artwork
	local SeparatorHolder = Mana:CreateFrame()
	SeparatorHolder:SetAllPoints()
	SeparatorHolder:SetFrameStrata("MEDIUM")
	SeparatorHolder:SetFrameLevel(10)

	local Separator = SeparatorHolder:CreateTexture(nil, "ARTWORK")
	Separator:SetSize(unpack(configPower.separator.size))
	Separator:SetPoint(unpack(configPower.separator.position))
	Separator:SetTexture(configPower.separator.texture)


	-- Buffs (no duration)
	-------------------------------------------------------------------
	local Buffs = self:CreateFrame()
	Buffs:SetSize(config.auras.size[1], config.auras.size[2]) 
	Buffs:Place(unpack(config.auras.position)) -- Minimap is always visible on /reload

	Buffs.position = config.auras.position
	Buffs.positionWithoutMinimap = config.auras.positionWithoutMinimap
	Buffs.config = config.auras
	Buffs.buttonConfig = config.auras.button
	Buffs.auraSize = config.auras.button.size
	Buffs.spacingH = config.auras.spacingH
	Buffs.spacingV = config.auras.spacingV
	Buffs.growthX = "LEFT"
	Buffs.growthY = "DOWN"
	Buffs.filter = "HELPFUL"
	Buffs.sortByTime = true
	Buffs.sortByDuration = true
	Buffs.sortByName = true
	Buffs.hideTimerBar = true
	Buffs.hideCooldownSpiral = true -- looks slightly weird on long term buffs

	Buffs.BuffFilter = longBuffFilter
	Buffs.PostCreateButton = postCreateAuraButton
	Buffs.PostUpdateButton = postUpdateAuraButton



	self.orbValue = Power.Value

	self:HookScript("OnEnter", onEnter)
	self:HookScript("OnLeave", onLeave)

	self.Buffs = Buffs
	self.Power = Power
	self.Mana = Mana
	
end

UnitFrameWidget.OnEvent = function(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		-- set our constants for number of visible bars and vehicleUI
		local hasVehicleUI = self.ActionBarController:InVehicle() or false
		local numVisibleBars = self.ActionBarController:GetNumBars() or 1 -- fallback value

		if hasVehicleUI then
			self.Left.Buffs:SetSize(unpack(self.config.buffs.size["vehicle"]))
			self.Left.Debuffs:SetSize(unpack(self.config.debuffs.size["vehicle"]))
		else
			self.Left.Buffs:SetSize(unpack(self.config.buffs.size[tostring(numVisibleBars)]))
			self.Left.Debuffs:SetSize(unpack(self.config.debuffs.size[tostring(numVisibleBars)]))
		end	

		NUM_VISIBLE_BARS = numVisibleBars
		HAS_VEHICLE_UI = hasVehicleUI

		self.Left.Buffs:ForceUpdate("Buffs")

	elseif event == "ENGINE_ACTIONBAR_VEHICLE_CHANGED" then
		local hasVehicleUI = ...
		if hasVehicleUI ~= HAS_VEHICLE_UI then
			if hasVehicleUI then
				self.Left.Buffs:SetSize(unpack(self.config.buffs.size["vehicle"]))
				self.Left.Debuffs:SetSize(unpack(self.config.debuffs.size["vehicle"]))
			else
				self.Left.Buffs:SetSize(unpack(self.config.buffs.size[tostring(NUM_VISIBLE_BARS)]))
				self.Left.Debuffs:SetSize(unpack(self.config.debuffs.size[tostring(NUM_VISIBLE_BARS)]))
			end
			self.Left.Buffs:ForceUpdate("Buffs")
			HAS_VEHICLE_UI = hasVehicleUI
		end 

	elseif event == "ENGINE_ACTIONBAR_VISIBLE_CHANGED" then
		local numVisibleBars = ...
		if numVisibleBars ~= NUM_VISIBLE_BARS then
			if hasVehicleUI then
				self.Left.Buffs:SetSize(unpack(self.config.buffs.size["vehicle"]))
				self.Left.Debuffs:SetSize(unpack(self.config.debuffs.size["vehicle"]))
			else
				self.Left.Buffs:SetSize(unpack(self.config.buffs.size[tostring(numVisibleBars)]))
				self.Left.Debuffs:SetSize(unpack(self.config.debuffs.size[tostring(numVisibleBars)]))
			end
			self.Left.Buffs:ForceUpdate("Buffs")
			NUM_VISIBLE_BARS = numVisibleBars
		end
	
	elseif event == "ENGINE_MINIMAP_VISIBLE_CHANGED" then
		local isMinimapVisible = ...
		if isMinimapVisible then
			self.Right.Buffs:Place(unpack(self.config.auras.position))
		else
			self.Right.Buffs:Place(unpack(self.config.auras.positionWithoutMinimap))
		end
	end
end

UnitFrameWidget.OnEnable = function(self)
	self.config = self:GetStaticConfig("UnitFrames").visuals.units.player
	self.db = self:GetConfig("UnitFrames") 

	-- get the main actionbar controller, as we need some info from it
	self.ActionBarController = Engine:GetModule("ActionBars"):GetWidget("Controller: Main"):GetFrame()
	self.IsMinimapVisible = Engine:GetModule("Minimap").IsMinimapVisible

	-- set our constants for number of visible bars and vehicleUI
	NUM_VISIBLE_BARS = self.ActionBarController:GetNumBars() or 1 -- fallback value
	HAS_VEHICLE_UI = self.ActionBarController:InVehicle() or false

	-- spawn the orbs
	local UnitFrame = Engine:GetHandler("UnitFrame")
	self.Left = UnitFrame:New("player", "UICenter", StyleLeftOrb) -- health / main
	self.Right = UnitFrame:New("player", "UICenter", StyleRightOrb) -- power / mana in forms

	-- check for correct numbers in all clients!
	local BlizzardUI = self:GetHandler("BlizzardUI")
	if Engine:IsBuild("WotLK") then
		BlizzardUI:GetElement("Menu_Panel"):Remove(11, "InterfaceOptionsBuffsPanel")
	end

	-- Disable Blizzard's castbars for player 
	BlizzardUI:GetElement("Auras"):Disable()
	BlizzardUI:GetElement("CastBars"):Remove("player")

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterMessage("ENGINE_ACTIONBAR_VEHICLE_CHANGED", "OnEvent")
	self:RegisterMessage("ENGINE_ACTIONBAR_VISIBLE_CHANGED", "OnEvent")
	self:RegisterMessage("ENGINE_MINIMAP_VISIBLE_CHANGED", "OnEvent")

	--[[
	local box = UIParent:CreateTexture(nil, "OVERLAY")
	box:SetSize(400, 300)
	box:SetPoint("BOTTOMRIGHT", -20, 100)
	box:SetColorTexture(1, 1, 1, .5)
	box:Hide()

	local frame = CreateFrame("Frame")
	frame.elapsed = 0
	frame.HZ = 1/120
	frame:SetScript("OnUpdate", function(self, elapsed) 
		self.elapsed = self.elapsed + elapsed
		if self.elapsed > self.HZ then
			local mouseover = UnitExists("mouseover")
			if mouseover and UnitIsPlayer("mouseover") then
				local _, class = UnitClass("mouseover")
				if class then
					local r, g, b = unpack(C.Class[class])
					box:SetVertexColor(r, g, b)
				else
					box:SetVertexColor(0, 0, 0)
				end
				if not box:IsShown() then
					box:Show()
				end
			else
				if box:IsShown() then
					box:Hide()
				end
			end
			self.elapsed = 0
		end
	end)]]
end

UnitFrameWidget.GetFrame = function(self)
	return self.Left, self.Right
end

