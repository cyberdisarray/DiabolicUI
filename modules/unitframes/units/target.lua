local Addon, Engine = ...

local UnitFrame = Engine:GetHandler("UnitFrame")
local StatusBar = Engine:GetHandler("StatusBar")
local C = Engine:GetStaticConfig("Data: Colors")

local Module = Engine:GetModule("UnitFrames")
local UnitFrameWidget = Module:SetWidget("Unit: Target")


-- Lua API
local _G = _G
local unpack = unpack

-- WoW API
local PlaySound = _G.PlaySound
local UnitClassification = _G.UnitClassification
local UnitExists = _G.UnitExists
local UnitPowerType = _G.UnitPowerType
local UnitPower = _G.UnitPower
local UnitPowerMax = _G.UnitPowerMax
local UnitIsEnemy = _G.UnitIsEnemy
local UnitIsFriend = _G.UnitIsFriend
local UnitIsPlayer = _G.UnitIsPlayer

-- Time limit in seconds where we separate between short and long buffs
local TIME_LIMIT = 300

local _, playerClass = UnitClass("player")
local PlayerIsRogue = playerClass == "ROGUE" -- to check for rogue anticipation



-- Utility Functions
--------------------------------------------------------------------------
local getBackdropName = function(haspower)
	return "Backdrop" .. (haspower and "Power" or "")
end

local getBorderName = function(isboss, haspower, ishighlight)
	return "Border" .. (isboss and "Boss" or "Normal") .. (haspower and "Power" or "") .. (ishighlight and "Highlight" or "")
end

local getThreatName = function(isboss, haspower)
	return "Threat" .. (isboss and "Boss" or "Normal") .. (haspower and "Power" or "")
end

local compare = function(a,b,c,d,e,f)
	if d == nil and e == nil and f == nil then
		return 
	end
	return (a == d) and (b == e) and (c == f)
end


-- reposition the unit classification when needed
local classificationPostUpdate = function(self, unit)
	if not unit then
		return
	end

	local isPlayer = UnitIsPlayer(unit)

	local powerID, powerType = UnitPowerType(unit)
	local power = UnitPower(unit, powerID)
	local powermax = UnitPowerMax(unit, powerID)

	local haspower = isPlayer or not(power == 0 or powermax == 0)
	local isboss = UnitClassification(unit) == "worldboss"

	local hadpower = self.haspower
	local wasboss = self.isboss
	
	-- todo: clean this mess up
	if isboss then
		if haspower then
			if hadpower and wasboss then
				return
			end
			self:ClearAllPoints()
			self:SetPoint(unpack(self.position.boss_double))
			self.isboss = true
			self.haspower = true
		else
			if wasboss and (not hadpower) then
				return
			end
			self:ClearAllPoints()
			self:SetPoint(unpack(self.position.boss_single))
			self.isboss = true
			self.haspower = false
		end
	else
		if haspower then
			if hadpower and (not wasboss) then
				return
			end
			self:ClearAllPoints()
			self:SetPoint(unpack(self.position.normal_double))
			self.isboss = false
			self.haspower = true
		else
			if (not hadpower) and (not wasboss) then
				return
			end
			self:ClearAllPoints()
			self:SetPoint(unpack(self.position.normal_single))
			self.isboss = false
			self.haspower = false
		end
	end
end

local setArtworkLayer = function(self, isboss, haspower, ishighlight)
	local cache = self.layers
	local border_name = getBorderName(isboss, haspower, ishighlight)
	local backdrop_name = getBackdropName(haspower)
	local threat_name = getThreatName(isboss, haspower)
	
	-- display the correct border texture
	cache.border[border_name]:Show()
	for id,layer in pairs(cache.border) do
		if id ~= border_name then
			layer:Hide()
		end
	end
	
	-- display the correct backdrop texture
	cache.backdrop[backdrop_name]:Show()
	for id,layer in pairs(cache.backdrop) do
		if id ~= backdrop_name then
			layer:Hide()
		end
	end
	
	-- display the correct threat texture
	--  *This does not affect the visibility of the main threat object, 
	--   it only handles the visibility of the separate sub-textures.
	cache.threat[threat_name]:Show()
	for id,layer in pairs(cache.threat) do
		if id ~= threat_name then
			layer:Hide()
		end
	end
	
end

local updateArtworkLayers = function(self)
	local unit = self.unit
	if not unit then
		return
	end

	local isPlayer = UnitIsPlayer(unit)

	local powerID, powerType = UnitPowerType(unit)
	local power = UnitPower(unit, powerID)
	local powermax = UnitPowerMax(unit, powerID)

	local haspower = isPlayer or not(power == 0 or powermax == 0)
	local isboss = UnitClassification(unit) == "worldboss"
	local ishighlight = self:IsMouseOver()
	
	if compare(isboss, haspower, ishighlight, self.isboss, self.haspower, self.ishighlight) then
		return -- avoid unneeded graphic updates
	else
		if not haspower and self.haspower == true then
			-- Forcefully empty the bar fast to avoid 
			-- it being visible after the border has been hidden.
			self.Power:Clear() 
		end
	
		self.isboss = isboss
		self.haspower = haspower
		self.ishighlight = ishighlight

		setArtworkLayer(self, isboss, haspower, ishighlight)
	end
	
end

-- This one will only be called in Legion, and only for Rogues
local updateComboPoints = function(self)
	local vehicle = UnitHasVehicleUI("player")
	local combo_unit = vehicle and "vehicle" or "player"
	local cp = UnitPower(combo_unit, SPELL_POWER_COMBO_POINTS)
	local cp_max = UnitPowerMax(combo_unit, SPELL_POWER_COMBO_POINTS)
	if cp_max == 8 then
		cp_max = 5
	end
	self:SetSize(self.point_width*cp_max + self.point_padding*(cp_max-1), self.point_height)
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

local buffFilter = function(self, name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer)
	if isBossDebuff then
		return true
	elseif isStealable then
		return true
	elseif duration and (duration > 0) then
		if duration > TIME_LIMIT then
			return false
		end
		return true
	end
end

local debuffFilter = function(self, name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer)
	if isBossDebuff then
		return true
	elseif (not isCastByPlayer) then
		return false
	elseif duration and (duration > 0) then
		if duration > TIME_LIMIT then
			return false
		end
		return true
	end
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

local Update = function(self, event, ...)
	updateArtworkLayers(self)
	classificationPostUpdate(self.Classification, self.unit)
end

local Style = function(self, unit)
	local config = Module:GetStaticConfig("UnitFrames").visuals.units.target
	local db = Module:GetConfig("UnitFrames") 
	
	self:Size(unpack(config.size))
	self:Place(unpack(config.position))


	-- Artwork
	-------------------------------------------------------------------

	local shade = self:CreateTexture(nil, "BACKGROUND")
	shade:SetSize(unpack(config.textures.layers.shade.size))
	shade:SetPoint(unpack(config.textures.layers.shade.position))
	shade:SetTexture(config.textures.layers.shade.texture)
	shade:SetVertexColor(config.textures.layers.shade.color)

	local backdrop = self:CreateTexture(nil, "BACKGROUND")
	backdrop:SetSize(unpack(config.textures.size))
	backdrop:SetPoint(unpack(config.textures.position))
	backdrop:SetTexture(config.textures.layers.backdrop.single)

	local backdropPower = self:CreateTexture(nil, "BACKGROUND")
	backdropPower:SetSize(unpack(config.textures.size))
	backdropPower:SetPoint(unpack(config.textures.position))
	backdropPower:SetTexture(config.textures.layers.backdrop.double)
	
	local border = self:CreateFrame()
	border:SetFrameLevel(self:GetFrameLevel() + 4)
	border:SetAllPoints()
	
	local borderNormal = border:CreateTexture(nil, "BORDER")
	borderNormal:SetSize(unpack(config.textures.size))
	borderNormal:SetPoint(unpack(config.textures.position))
	borderNormal:SetTexture(config.textures.layers.border.standard_single.normal)
	
	local borderNormalHighlight = border:CreateTexture(nil, "BORDER")
	borderNormalHighlight:SetSize(unpack(config.textures.size))
	borderNormalHighlight:SetPoint(unpack(config.textures.position))
	borderNormalHighlight:SetTexture(config.textures.layers.border.standard_single.highlight)

	local borderNormalPower = border:CreateTexture(nil, "BORDER")
	borderNormalPower:SetSize(unpack(config.textures.size))
	borderNormalPower:SetPoint(unpack(config.textures.position))
	borderNormalPower:SetTexture(config.textures.layers.border.standard_double.normal)

	local borderNormalPowerHighlight = border:CreateTexture(nil, "BORDER")
	borderNormalPowerHighlight:SetSize(unpack(config.textures.size))
	borderNormalPowerHighlight:SetPoint(unpack(config.textures.position))
	borderNormalPowerHighlight:SetTexture(config.textures.layers.border.standard_double.highlight)

	local borderBoss = border:CreateTexture(nil, "BORDER")
	borderBoss:SetSize(unpack(config.textures.size))
	borderBoss:SetPoint(unpack(config.textures.position))
	borderBoss:SetTexture(config.textures.layers.border.boss_single.normal)

	local borderBossHighlight = border:CreateTexture(nil, "BORDER")
	borderBossHighlight:SetSize(unpack(config.textures.size))
	borderBossHighlight:SetPoint(unpack(config.textures.position))
	borderBossHighlight:SetTexture(config.textures.layers.border.boss_single.highlight)

	local borderBossPower = border:CreateTexture(nil, "BORDER")
	borderBossPower:SetSize(unpack(config.textures.size))
	borderBossPower:SetPoint(unpack(config.textures.position))
	borderBossPower:SetTexture(config.textures.layers.border.boss_double.normal)

	local borderBossPowerHighlight = border:CreateTexture(nil, "BORDER")
	borderBossPowerHighlight:SetSize(unpack(config.textures.size))
	borderBossPowerHighlight:SetPoint(unpack(config.textures.position))
	borderBossPowerHighlight:SetTexture(config.textures.layers.border.boss_double.highlight)


	-- Health
	-------------------------------------------------------------------
	local health = self:CreateStatusBar()
	health:SetSize(unpack(config.health.size))
	health:SetPoint(unpack(config.health.position))
	health:SetStatusBarTexture(config.health.texture)
	health.frequent = 1/120
	
	local healthValueHolder = health:CreateFrame()
	healthValueHolder:SetAllPoints()
	healthValueHolder:SetFrameLevel(border:GetFrameLevel() + 1)
	
	health.Value = healthValueHolder:CreateFontString(nil, "OVERLAY")
	health.Value:SetFontObject(config.texts.health.font_object)
	health.Value:SetPoint(unpack(config.texts.health.position))
	health.Value.showPercent = true
	health.Value.showDeficit = false
	health.Value.showMaximum = false

	health.PostUpdate = function(self)
		local min, max = self:GetMinMaxValues()
		local value = self:GetValue()
		if UnitAffectingCombat("player") then
			self.Value:SetAlpha(1)
		else
			self.Value:SetAlpha(.7)
		end
	end
	
	
	-- Power
	-------------------------------------------------------------------
	local power = self:CreateStatusBar()
	power:SetSize(unpack(config.power.size))
	power:SetPoint(unpack(config.power.position))
	power:SetStatusBarTexture(config.power.texture)
	power.frequent = 1/120
	


	-- CastBar
	-------------------------------------------------------------------
	local castBar = health:CreateStatusBar()
	castBar:Hide()
	castBar:SetAllPoints()
	castBar:SetStatusBarTexture(1, 1, 1, .15)
	castBar:SetSize(health:GetSize())
	castBar:DisableSmoothing(true)


	
	-- Auras
	-------------------------------------------------------------------
	local auras = self:CreateFrame()
	auras:SetSize(unpack(config.auras.size))
	auras:Place(unpack(config.auras.position))
	
	auras.config = config.auras
	auras.buttonConfig = config.auras.button
	auras.auraSize = config.auras.button.size
	auras.spacingH = config.auras.spacingH
	auras.spacingV = config.auras.spacingV
	auras.growthX = "RIGHT"
	auras.growthY = "DOWN"
	auras.filter = nil

	auras.BuffFilter = buffFilter
	auras.DebuffFilter = debuffFilter
	auras.PostCreateButton = postCreateAuraButton
	auras.PostUpdateButton = postUpdateAuraButton

	

	-- Threat
	-------------------------------------------------------------------
	local threat = self:CreateFrame()
	threat:SetFrameLevel(0)
	threat:SetAllPoints()
	threat:Hide()
	
	local threatNormal = threat:CreateTexture(nil, "BACKGROUND")
	threatNormal:Hide()
	threatNormal:SetSize(unpack(config.textures.size))
	threatNormal:SetPoint(unpack(config.textures.position))
	threatNormal:SetTexture(config.textures.layers.border.standard_single.threat)
	
	local threatNormalPower = threat:CreateTexture(nil, "BACKGROUND")
	threatNormalPower:Hide()
	threatNormalPower:SetSize(unpack(config.textures.size))
	threatNormalPower:SetPoint(unpack(config.textures.position))
	threatNormalPower:SetTexture(config.textures.layers.border.standard_double.threat)

	local threatBoss = threat:CreateTexture(nil, "BACKGROUND")
	threatBoss:Hide()
	threatBoss:SetSize(unpack(config.textures.size))
	threatBoss:SetPoint(unpack(config.textures.position))
	threatBoss:SetTexture(config.textures.layers.border.boss_single.threat)

	local threatBossPower = threat:CreateTexture(nil, "BACKGROUND")
	threatBossPower:Hide()
	threatBossPower:SetSize(unpack(config.textures.size))
	threatBossPower:SetPoint(unpack(config.textures.position))
	threatBossPower:SetTexture(config.textures.layers.border.boss_double.threat)


	-- Texts
	-------------------------------------------------------------------
	local name = border:CreateFontString(nil, "OVERLAY")
	name:SetFontObject(config.name.font_object)
	name:SetPoint(unpack(config.name.position))
	name:SetSize(unpack(config.name.size))
	name:SetJustifyV("BOTTOM")
	name:SetJustifyH("CENTER")
	name:SetIndentedWordWrap(false)
	name:SetWordWrap(true)
	name:SetNonSpaceWrap(false)
	name.colorBoss = true
	
	local classification = border:CreateFontString(nil, "OVERLAY")
	classification:SetFontObject(config.classification.font_object)
	classification:SetPoint(unpack(config.classification.position.normal_single))
	classification.position = config.classification.position -- should contain all 4 positions

	local spellName = castBar:CreateFontString(nil, "OVERLAY")
	spellName:SetFontObject(config.classification.font_object)
	spellName:SetPoint("CENTER", classification, "CENTER", 0, 0) -- just piggyback on the classification positions

	local castTime = castBar:CreateFontString(nil, "OVERLAY")
	castTime:SetFontObject(config.texts.castTime.font_object)
	castTime:SetPoint(unpack(config.texts.castTime.position))

	castBar:HookScript("OnShow", function() 
		classification:Hide()
		spellName:Show() 
	end)

	castBar:HookScript("OnHide", function() 
		classification:Show()
		spellName:Hide() 
	end)

	
	-- Put everything into our layer cache
	-------------------------------------------------------------------
	self.layers = { 
		backdrop = {
			Backdrop = backdrop,
			BackdropPower = backdropPower
		}, 
		border = {
			BorderNormal = borderNormal,
			BorderNormalHighlight = borderNormalHighlight,
			BorderNormalPower = borderNormalPower,
			BorderNormalPowerHighlight = borderNormalPowerHighlight,
			BorderBoss = borderBoss,
			BorderBossHighlight = borderBossHighlight,
			BorderBossPower = borderBossPower,
			BorderBossPowerHighlight = borderBossPowerHighlight
		}, 
		threat = {
			ThreatNormal = threatNormal,
			ThreatNormalPower = threatNormalPower,
			ThreatBoss = threatBoss,
			ThreatBossPower = threatBossPower
		} 
	} 

	self.Auras = auras
	self.CastBar = castBar
	self.CastBar.Name = spellName
	self.CastBar.Value = castTime
	self.Classification = classification
	self.Classification.PostUpdate = classificationPostUpdate
	self.Health = health
	self.Name = name
	self.Power = power
	self.Power.PostUpdate = function() Update(self) end
	self.Threat = threat
	self.Threat.SetVertexColor = function(_, ...) 
		for i,v in pairs(self.layers.threat) do
			v:SetVertexColor(...)
		end
	end

	self:HookScript("OnEnter", updateArtworkLayers)
	self:HookScript("OnLeave", updateArtworkLayers)

	self:RegisterEvent("PLAYER_ENTERING_WORLD", Update)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", Update)
	self:RegisterEvent("UNIT_NAME_UPDATE", Update)

end

UnitFrameWidget.OnEvent = function(self, event, ...)
	if event == "PLAYER_TARGET_CHANGED" then
		if UnitExists("target") then
			if UnitIsEnemy("target", "player") then
				PlaySound("igCreatureAggroSelect")
			elseif UnitIsFriend("player", "target") then
				PlaySound("igCharacterNPCSelect")
			else
				PlaySound("igCreatureNeutralSelect")
			end
		else
			PlaySound("INTERFACESOUND_LOSTTARGETUNIT")
		end
	end
end

UnitFrameWidget.OnEnable = function(self)
	self.UnitFrame = UnitFrame:New("target", Engine:GetFrame(), Style)

	self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")
end

UnitFrameWidget.GetFrame = function(self)
	return self.UnitFrame
end
