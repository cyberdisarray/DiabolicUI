local ADDON, Engine = ...
local Handler = Engine:GetHandler("UnitFrame")
local StatusBar = Engine:GetHandler("StatusBar")
local C = Engine:GetStaticConfig("Data: Colors")
local L = Engine:GetLocale()

-- Lua API
local _G = _G
local math_floor = math.floor
local math_min = math.min
local select = select
local setmetatable = setmetatable

-- WoW API
local CancelUnitBuff = _G.CancelUnitBuff
local CreateFrame = _G.CreateFrame
local GameTooltip_SetDefaultAnchor = _G.GameTooltip_SetDefaultAnchor
local GetTime = _G.GetTime
local UnitAffectingCombat = _G.UnitAffectingCombat
local G_UnitAura = _G.UnitAura
local G_UnitBuff = _G.UnitBuff
local G_UnitDebuff = _G.UnitDebuff
local UnitExists = _G.UnitExists
local UnitHasVehicleUI = _G.UnitHasVehicleUI
local UnitReaction = _G.UnitReaction

-- WOW frames and objects
local GameTooltip = _G.GameTooltip

-- Blank texture used as a fallback for borders and bars
local BLANK_TEXTURE = [[Interface\ChatFrame\ChatFrameBackground]] 

-- these exist (or are used) in WoD and beyond
local BLING_TEXTURE = [[Interface\Cooldown\star4]]
local EDGE_LOC_TEXTURE = [[Interface\Cooldown\edge-LoC]]
local EDGE_NORMAL_TEXTURE = [[Interface\Cooldown\edge]]

-- Retrive the current game client version
local BUILD = tonumber((select(2, GetBuildInfo()))) 

-- Shortcuts to identify client versions
-- *3.3.0 was the first patch to include spellID as a return argument from UnitAura
local ENGINE_LEGION 	= Engine:IsBuild("Legion")
local ENGINE_WOD 		= Engine:IsBuild("WoD")
local ENGINE_MOP 		= Engine:IsBuild("MoP")
local ENGINE_CATA 		= Engine:IsBuild("Cata")

-- Speeeeed!
local day = L["d"]
local hour = L["h"]
local minute = L["m"]

-- Time constants
local DAY, HOUR, MINUTE = 86400, 3600, 60

local formatTime = function(time)
	if time > DAY then -- more than a day
		return "%1d%s", math_floor(time / DAY), day
	elseif time > HOUR then -- more than an hour
		return "%1d%s", math_floor(time / HOUR), hour
	elseif time > MINUTE then -- more than a minute
		return "%1d%s", math_floor(time / MINUTE), minute
	elseif time > 5 then -- more than 5 seconds
		return "%d", math_floor(time)
	elseif time > 0 then
		return "|cffff0000%.1f|r", time
	else
		return ""
	end	
end

local auraCache = {}


--[[
-----------------------------------------------------------------
-----------------------------------------------------------------
-- 	For future reference, here are the full return values of 
-- 	the API function UnitAura for the relevant client patches. 
-----------------------------------------------------------------
-----------------------------------------------------------------

Legion 7.0.3: 
-----------------------------------------------------------------
*note that in 7.0.3 the icon return value is a fileID, not a file path. 
local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, ... = UnitAura("unit", index[, "filter"])


MOP 5.1.0: 
-----------------------------------------------------------------
local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, shouldConsolidate, spellId, canApplyAura, isBossDebuff, isCastByPlayer = UnitAura(unit, index, filter)


Cata 4.2.0: 
-----------------------------------------------------------------
local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId, canApplyAura, isBossDebuff, value1, value2, value3 = UnitAura(unit, index, filter)


WotLK 3.3.0: 
*note that prior to this patch, the shouldConsolidate and spellId return values didn't exist,
 and auras had to be recognized by their names instead. 
-----------------------------------------------------------------
local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitAura(unit, index, filter)

]]--

-- Not really a big fan of this method, since it leads to an extra function call. 
-- It is however from a development point of view the easiest way to implement 
-- identical behavior across the various expansions and patches.  

local UnitAura = ENGINE_LEGION and function(unit, i, filter)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId, _, isBossDebuff, isCastByPlayer = G_UnitAura(unit, i, filter)
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer
end 

or ENGINE_MOP and function(unit, i, filter)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId, _, isBossDebuff, isCastByPlayer = G_UnitAura(unit, i, filter)
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer
end

or ENGINE_CATA and function(unit, i, filter)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId, _, isBossDebuff = G_UnitAura(unit, i, filter)
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, 
		(unitCaster and ((unit == "vehicle" and unitCaster == "vehicle") or unitCaster == "player" or unitCaster == "pet"))
end

or function(unit, i, filter)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId = G_UnitAura(unit, i, filter)
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, 
		(unitCaster and unitCaster:find("boss")), 
		(unitCaster and ((unit == "vehicle" and unitCaster == "vehicle") or unitCaster == "player" or unitCaster == "pet"))
end

local UnitBuff = ENGINE_LEGION and function(unit, i, filter)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId, _, isBossDebuff, isCastByPlayer = G_UnitBuff(unit, i, filter)
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer
end 

or ENGINE_MOP and function(unit, i, filter)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId, _, isBossDebuff, isCastByPlayer = G_UnitBuff(unit, i, filter)
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer
end

or ENGINE_CATA and function(unit, i, filter)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId, _, isBossDebuff = G_UnitBuff(unit, i, filter)
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, 
		(unitCaster and ((unit == "vehicle" and unitCaster == "vehicle") or unitCaster == "player" or unitCaster == "pet"))
end

or function(unit, i, filter)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId = G_UnitBuff(unit, i, filter)
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, 
		(unitCaster and unitCaster:find("boss")), 
		(unitCaster and ((unit == "vehicle" and unitCaster == "vehicle") or unitCaster == "player" or unitCaster == "pet"))
end

local UnitDebuff = ENGINE_LEGION and function(unit, i, filter)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId, _, isBossDebuff, isCastByPlayer = G_UnitDebuff(unit, i, filter)
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer
end 

or ENGINE_MOP and function(unit, i, filter)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId, _, isBossDebuff, isCastByPlayer = G_UnitDebuff(unit, i, filter)
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer
end

or ENGINE_CATA and function(unit, i, filter)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId, _, isBossDebuff = G_UnitDebuff(unit, i, filter)
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, 
		(unitCaster and ((unit == "vehicle" and unitCaster == "vehicle") or unitCaster == "player" or unitCaster == "pet"))
end

or function(unit, i, filter)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId = G_UnitDebuff(unit, i, filter)
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, 
		(unitCaster and unitCaster:find("boss")), 
		(unitCaster and ((unit == "vehicle" and unitCaster == "vehicle") or unitCaster == "player" or unitCaster == "pet"))
end



-- Aura Button Template
-----------------------------------------------------

local Aura = Engine:CreateFrame("Button")
local Aura_MT = { __index = Aura }

local AURA_SIZE = 40 
local AURA_BACKDROP = {
	bgFile = BLANK_TEXTURE,
	edgeFile = BLANK_TEXTURE,
	edgeSize = 1,
	insets = {
		left = -1,
		right = -1,
		top = -1,
		bottom = -1
	}
}


Aura.OnEnter = function(self)
	local unit = self.unit
	if not UnitExists(unit) then
		return
	end

	GameTooltip_SetDefaultAnchor(GameTooltip, self)

	if self.isBuff then
		GameTooltip:SetUnitBuff(unit, self:GetID(), self.filter)
	else
		GameTooltip:SetUnitDebuff(unit, self:GetID(), self.filter)
	end
end

Aura.OnLeave = function(self)
	GameTooltip:Hide()
end

Aura.OnClick = CATA and function(self)
	if not UnitAffectingCombat("player") then
		local unit = self.unit
		if not UnitExists(unit) then
			return
		end
		if self.isBuff then
			CancelUnitBuff(unit, self:GetID(), self.filter)
		end
	end
end
or WOTLK_330 and function(self)
	local unit = self.unit
	if not UnitExists(unit) then
		return
	end
	if self.isBuff then
		CancelUnitBuff(unit, self:GetID(), self.filter)
	end
end

Aura.SetCooldownTimer = ENGINE_WOD and function(self, start, duration)
	local cooldown = self.Cooldown
	cooldown:SetSwipeColor(0, 0, 0, .75)
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetDrawSwipe(true)

	if duration > .5 then
		cooldown:SetCooldown(start, duration)
		if self._owner.hideCooldownSpiral then
			cooldown:Hide()
		else
			cooldown:Show()
		end
	else
		cooldown:Hide()
	end
	
end or function(self, start, duration)
	local cooldown = self.Cooldown

	-- Try to prevent the strange WotLK bug where the end shine effect
	-- constantly pops up for a random period of time. 
	if duration > .5 then
		cooldown:SetCooldown(start, duration)
		if self._owner.hideCooldownSpiral then
			cooldown:Hide()
		else
			cooldown:Show()
		end
	else
		cooldown:Hide()
	end
end

local HZ = 1/30
Aura.UpdateTimer = function(self, elapsed)
	if self.timeLeft then
		self.elapsed = (self.elapsed or 0) + elapsed
		if self.elapsed >= HZ then
			self.timeLeft = self.expirationTime - GetTime()
			if self.timeLeft > 0 then
				self.Time:SetFormattedText(formatTime(self.timeLeft))
				self.Timer.Bar:SetValue(self.timeLeft)

				if self._owner.PostUpdateButton then
					self._owner:PostUpdateButton(self, "Timer")
				end
			else
				self:SetScript("OnUpdate", nil)
				self:SetCooldownTimer(0, 0)

				self.Timer:Hide()
				self.Timer.Bar:SetValue(0)
				self.Timer.Bar:SetMinMaxValues(0,0)
				self.Time:SetText("")

				if self._owner.PostUpdateButton then
					self._owner:PostUpdateButton(self, "Timer")
				end
			end	
			self.elapsed = 0
		end
	end
end

-- Use this to initiate the timer bars and spirals on the auras
Aura.SetTimer = function(self, fullDuration, expirationTime)
	if fullDuration and (fullDuration > 0) then
		self.fullDuration = fullDuration
		self.timeStarted = expirationTime - fullDuration
		self.timeLeft = expirationTime - GetTime()

		self.Timer.Bar:SetMinMaxValues(0, fullDuration)
		self.Timer.Bar:SetValue(self.timeLeft)

		if (not self._owner.hideTimerBar) then
			self.Timer:Show()
		end

		self:SetScript("OnUpdate", self.UpdateTimer)
		self:SetCooldownTimer(self.timeStarted, self.fullDuration)
	else
		self:SetScript("OnUpdate", nil)
		self:SetCooldownTimer(0,0)

		self.Time:SetText("")
		self.Timer:Hide()
		self.Timer.Bar:SetValue(0)
		self.Timer.Bar:SetMinMaxValues(0,0)

		self.fullDuration = 0
		self.timeStarted = 0
		self.timeLeft = 0

		if self._owner.PostUpdateButton then
			self._owner:PostUpdateButton(self, "Timer")
		end
	end
end


local CreateAuraButton = function(self)
	local button = setmetatable(self:CreateFrame("Button"), Aura_MT)
	button:EnableMouse(true)
	button:RegisterForClicks("RightButtonUp")
	button._owner = self

	local Scaffold = button:CreateFrame()
	Scaffold:SetPoint("TOPLEFT", 0, 0)
	Scaffold:SetPoint("BOTTOMRIGHT", 0, 0)
	Scaffold:SetBackdrop(AURA_BACKDROP)
	Scaffold:SetFrameLevel(button:GetFrameLevel() + 1)

	local Icon = Scaffold:CreateTexture()
	Icon:SetPoint("TOPLEFT", 2, -2)
	Icon:SetPoint("BOTTOMRIGHT", -2, 2)
	Icon:SetTexCoord(5/64, 59/64, 5/64, 59/64) 
	Icon:SetDrawLayer("ARTWORK")

	local Cooldown = button:CreateFrame("Cooldown")
	Cooldown:Hide()
	Cooldown:SetReverse(true)
	Cooldown:SetFrameLevel(button:GetFrameLevel() + 2)
	Cooldown:SetPoint("TOPLEFT", Icon, "TOPLEFT", 0, 0)
	Cooldown:SetPoint("BOTTOMRIGHT", Icon, "BOTTOMRIGHT", 0, 0)
	Cooldown:SetAlpha(1)

	if ENGINE_WOD then
		Cooldown:SetSwipeColor(0, 0, 0, .75)
		Cooldown:SetBlingTexture(BLING_TEXTURE, .3, .6, 1, .75) -- what wow uses, only with slightly lower alpha
		Cooldown:SetEdgeTexture(EDGE_NORMAL_TEXTURE)
		Cooldown:SetDrawSwipe(true)
		Cooldown:SetDrawBling(true)
		Cooldown:SetDrawEdge(false)
		Cooldown:SetHideCountdownNumbers(false) -- todo: add better numbering
	end

	local Overlay = button:CreateFrame()
	Overlay:SetFrameLevel(button:GetFrameLevel() + 3)
	Overlay:SetPoint("TOPLEFT", Scaffold, "TOPLEFT", -3, 3)
	Overlay:SetPoint("BOTTOMRIGHT", Scaffold, "BOTTOMRIGHT", 3, -3)

	local Count = Overlay:CreateFontString()
	Count:SetDrawLayer("OVERLAY")
	Count:SetFontObject(DiabolicFont_SansBold12)
	Count:SetPoint("BOTTOMRIGHT", Icon, "BOTTOMRIGHT", -1, 1)

	local Time = Overlay:CreateFontString()
	Time:SetDrawLayer("OVERLAY")
	Time:SetFontObject(DiabolicFont_SansBold10)
	Time:SetPoint("TOPLEFT", Icon, "TOPLEFT", -1, 1)

	local Timer = button:CreateFrame()
	Timer:Hide()
	Timer:SetPoint("TOP", button, "BOTTOM", 0, -2)
	Timer:SetSize(AURA_SIZE, 8)

	local TimerScaffold = Timer:CreateFrame()
	TimerScaffold:SetPoint("TOPLEFT", 0, 0)
	TimerScaffold:SetPoint("BOTTOMRIGHT", 0, 0)
	TimerScaffold:SetBackdrop(AURA_BACKDROP)
	TimerScaffold:SetFrameLevel(Timer:GetFrameLevel() + 1)

	local TimerBarBackground = TimerScaffold:CreateTexture()
	TimerBarBackground:SetDrawLayer("BACKGROUND")
	TimerBarBackground:SetPoint("TOPLEFT", 2, -2)
	TimerBarBackground:SetPoint("BOTTOMRIGHT", -2, 2)
	TimerBarBackground:SetTexture(BLANK_TEXTURE)

	local TimerBar = Timer:CreateStatusBar()
	TimerBar:SetStatusBarTexture(BLANK_TEXTURE)
	TimerBar:SetSize(AURA_SIZE - 2*2, 8 - 2*2)
	TimerBar:SetPoint("TOPLEFT", 2, -2)
	TimerBar:SetPoint("BOTTOMRIGHT", -2, 2)
	TimerBar:SetFrameLevel(Timer:GetFrameLevel() + 2)

	button.SetBorderColor = function(self, r, g, b)
		Scaffold:SetBackdropColor(r * 1/3, g * 1/3, b * 1/3)
		Scaffold:SetBackdropBorderColor(r, g, b)

		TimerScaffold:SetBackdropColor(r * 1/3, g * 1/3, b * 1/3)
		TimerScaffold:SetBackdropBorderColor(r, g, b)

		TimerBarBackground:SetVertexColor(r * 1/3, g * 1/3, b * 1/3)
		TimerBar:SetStatusBarColor(r * 2/3, g * 2/3, b * 2/3)
	end

	button.Scaffold = Scaffold
	button.Overlay = Overlay

	button.Icon = Icon
	button.Count = Count
	button.Cooldown = Cooldown
	button.Time = Time
	button.Timer = Timer
	button.Timer.Scaffold = TimerScaffold
	button.Timer.Background = TimerBarBackground
	button.Timer.Bar = TimerBar

	button:SetScript("OnEnter", Aura.OnEnter)
	button:SetScript("OnLeave", Aura.OnLeave)
	button:SetScript("OnClick", Aura.OnClick)
	
	button.UpdateTooltip = Aura.OnEnter

	auraCache[button] = true
	
	return button
end


local Sort = function(self)

end

local SetPosition = function(self, visible)
	-- arranges auras based on available space and visible auras
	local width, height = self:GetSize()
	local auraWidth, auraHeight = unpack(self.auraSize)
	local spacingH = self.spacingH
	local spacingV = self.spacingV
	local cols, rows = math_floor((width + spacingH) / (auraWidth + spacingH)), math_floor((height + spacingV) / (auraHeight + spacingV))
	local visibleAuras = math_min(cols * rows, visible)
	local growthX = self.growthX
	local growthY = self.growthY

	for i = 1, visibleAuras do
		if i == 1 then
			local point = ((growthY == "UP") and "BOTTOM" or (growthY == "DOWN") and "TOP") .. ((growthX == "RIGHT") and "LEFT" or (growthX == "LEFT") and "RIGHT")
			self[i]:Place(point, self, point, 0, 0)
		elseif (i - 1)%cols == 0 then
			local point = ((growthY == "UP") and "BOTTOM" or (growthY == "DOWN") and "TOP") .. ((growthX == "RIGHT") and "LEFT" or (growthX == "LEFT") and "RIGHT")
			self[i]:Place(point, self, point, 0, (math_floor((i-1) / cols) * (auraHeight + spacingV))*(growthY == "DOWN" and -1 or 1))
		else
			self[i]:Place(((growthX == "RIGHT") and "LEFT" or (growthX == "LEFT") and "RIGHT"), self[i-1], growthX, (growthX == "RIGHT") and spacingH or -spacingH, 0)
		end
	end

	return visibleAuras
end

local UpdateTooltip = function(self, event, ...)
	if (event == "MODIFIER_STATE_CHANGED") and ((arg1 == "LSHIFT") or (arg1 == "RSHIFT")) then
		if GameTooltip:IsShown() and auraCache[GameTooltip:GetOwner()] then 
			GameTooltip:GetOwner():UpdateTooltip()
		end
	end
end

local Update = function(self, event, ...)
	local unit = self.unit
	local arg1 = ...

	-- The secure state driver that changes the unit when entering a vehicle 
	-- can sometimes be fairly slow, so when relying on that alone auras won't
	-- be properly updated before the auras on your vehicle change again. 
	-- So we hook into vehicle events to figure out what unit actually to query.
	-- 
	-- Todo: Let the unitframe handler deal with this entire thing, 
	--       and fire callbacks to update the unitframes automatically. 
	local realUnit = self:GetRealUnit()
	if (realUnit == "player") and ((event == "UNIT_ENTERED_VEHICLE") or (event == "UNIT_ENTERING_VEHICLE") or (event == "UNIT_EXITED_VEHICLE") or (event == "UNIT_EXITING_VEHICLE")) then
		if UnitHasVehicleUI(realUnit) then
			unit = "vehicle"
		else
			unit = realUnit
		end
	else
		if not((event == "PLAYER_ENTERING_WORLD") or (event == "FREQUENT") or (event == "FORCED") or (event == "PLAYER_TARGET_CHANGED")) and (unit ~= arg1) then
			return
		end
	end

	local Auras = self.Auras
	if Auras then
		if not UnitExists(unit) then
			Auras:Hide()
		else
			local visible = 0
			local visibleBuffs = 0
			local visibleDebuffs = 0

			if Auras.PreUpdate then
				Auras:PreUpdate(unit)
			end

			local filter = Auras.filter

			-- count buffs
			for i = 1, BUFF_MAX_DISPLAY do

				local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer = UnitBuff(unit, i, filter)

				if not name then
					break
				end

				-- This won't replace the normal filter, but be applied after it
				if name and (Auras.BuffFilter or Auras.AuraFilter) then
					local show = (Auras.BuffFilter or Auras.AuraFilter)(Auras, name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer)
					if not show then
						name = nil
					end
				end

				if name then
					visible = visible + 1
					visibleBuffs = visibleBuffs + 1

					if (not Auras[visible]) then
						Auras[visible] = Auras.CreateButton and Auras:CreateButton() or CreateAuraButton(Auras)
						if Auras.PostCreateButton then
							Auras:PostCreateButton(Auras[visible])
						end
					end

					local button = Auras[visible]
					if button:IsShown() then
						button:Hide() 
					end

					button:SetID(i)

					button.isBuff = true
					button.unit = unit
					button.filter = filter
					button.name = name
					button.rank = rank
					button.count = count
					button.debuffType = debuffType
					button.duration = duration
					button.expirationTime = expirationTime
					button.unitCaster = unitCaster
					button.isStealable = isStealable
					button.isBossDebuff = isBossDebuff
					button.isCastByPlayer = isCastByPlayer

					button.Icon:SetTexture(icon)
					button.Count:SetText((count > 1) and count or "")
					
					button:SetTimer(duration, expirationTime)

					if Auras.PostUpdateButton then
						Auras:PostUpdateButton(button)
					end

					if (not button:IsShown()) then
						button:Show()
					end

				end
	
			end


			-- count debuffs
			for i = 1, DEBUFF_MAX_DISPLAY do

				local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer = UnitDebuff(unit, i, filter)

				if not name then
					break
				end

				-- This won't replace the normal filter, but be applied after it
				if name and (Auras.DebuffFilter or Auras.AuraFilter) then
					local show = (Auras.DebuffFilter or Auras.AuraFilter)(Auras, name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer)
					if not show then
						name = nil
					end
				end

				if name then
					visible = visible + 1
					visibleDebuffs = visibleDebuffs + 1

					if not Auras[visible] then
						Auras[visible] = Auras.CreateButton and Auras:CreateButton() or CreateAuraButton(Auras)
						if Auras.PostCreateButton then
							Auras:PostCreateButton(Auras[visible])
						end
					end

					local button = Auras[visible]
					if button:IsShown() then
						button:Hide() 
					end

					button:SetID(i)

					button.isBuff = false
					button.unit = unit
					button.filter = filter
					button.name = name
					button.rank = rank
					button.count = count
					button.debuffType = debuffType
					button.duration = duration
					button.expirationTime = expirationTime
					button.unitCaster = unitCaster
					button.isStealable = isStealable
					button.isBossDebuff = isBossDebuff
					button.isCastByPlayer = isCastByPlayer

					button.Icon:SetTexture(icon)
					button.Count:SetText((count > 1) and count or "")
					
					button:SetTimer(duration, expirationTime)

					
					if Auras.PostUpdateButton then
						Auras:PostUpdateButton(button)
					end

					if not button:IsShown() then
						button:Show()
					end

				end
			end

			if visible == 0 then
				if Auras:IsShown() then
					Auras:Hide()
				end
			else
				local visible = SetPosition(Auras, visible)
				for i = visible + 1, #Auras do
					Auras[i]:Hide()
					Auras[i]:SetScript("OnUpdate", nil)
					Auras[i]:SetTimer(0,0)
				end 

				if not Auras:IsShown() then
					Auras:Show()
				end
			end

			if Auras.PostUpdate then
				Auras:PostUpdate()
			end	
		end
	end

	local Buffs = self.Buffs
	if Buffs then
		if not UnitExists(unit) then
			Buffs:Hide()
		else
			local visible = 0
			local filter = Buffs.filter

			for i = 1, BUFF_MAX_DISPLAY do

				local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer = UnitAura(unit, i, filter)

				if not name then
					break
				end

				-- This won't replace the normal filter, but be applied after it
				if name and Buffs.BuffFilter then
					local show = Buffs:BuffFilter(name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer)
					if not show then
						name = nil
					end
				end

				if name then
					visible = visible + 1

					if not Buffs[visible] then
						Buffs[visible] = Buffs.CreateButton and Buffs:CreateButton() or CreateAuraButton(Buffs)
						if Buffs.PostCreateButton then
							Buffs:PostCreateButton(Buffs[visible])
						end
					end

					local button = Buffs[visible]
					if button:IsShown() then
						button:Hide() 
					end

					button:SetID(i)

					button.isBuff = true
					button.unit = unit
					button.filter = filter
					button.name = name
					button.rank = rank
					button.count = count
					button.debuffType = debuffType
					button.duration = duration
					button.expirationTime = expirationTime
					button.unitCaster = unitCaster
					button.isStealable = isStealable
					button.isBossDebuff = isBossDebuff
					button.isCastByPlayer = isCastByPlayer

					button.Icon:SetTexture(icon)
					button.Count:SetText((count > 1) and count or "")
					
					button:SetTimer(duration, expirationTime)
					
					if Buffs.PostUpdateButton then
						Buffs:PostUpdateButton(button)
					end

					if not button:IsShown() then
						button:Show()
					end

				end
			end

			if visible == 0 then
				if Buffs:IsShown() then
					Buffs:Hide()
				end
			else
				local visible = SetPosition(Buffs, visible)
				for i = visible + 1, #Buffs do
					Buffs[i]:Hide()
					Buffs[i]:SetScript("OnUpdate", nil)
					Buffs[i]:SetTimer(0,0)
				end 
				if not Buffs:IsShown() then
					Buffs:Show()
				end
			end

			if Buffs.PostUpdate then
				Buffs:PostUpdate()
			end		
		end
	end

	local Debuffs = self.Debuffs
	if Debuffs then
		if not UnitExists(unit) then
			Debuffs:Hide()
		else
			local visible = 0
			local filter = Debuffs.filter

			for i = 1, DEBUFF_MAX_DISPLAY do

				local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer = UnitAura(unit, i, filter)

				if not name then
					break
				end

				-- This won't replace the normal filter, but be applied after it
				if name and Debuffs.DebuffFilter then
					local show = Debuffs:DebuffFilter(name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, spellId, isBossDebuff, isCastByPlayer)
					if not show then
						name = nil
					end
				end

				if name then
					visible = visible + 1

					if not Debuffs[visible] then
						Debuffs[visible] = Debuffs.CreateButton and Debuffs:CreateButton() or CreateAuraButton(Debuffs)
						if Debuffs.PostCreateButton then
							Debuffs:PostCreateButton(Debuffs[visible])
						end
					end

					local button = Debuffs[visible]
					if button:IsShown() then
						button:Hide() 
					end

					button:SetID(i)

					button.isBuff = false
					button.unit = unit
					button.filter = filter
					button.name = name
					button.rank = rank
					button.count = count
					button.debuffType = debuffType
					button.duration = duration
					button.expirationTime = expirationTime
					button.unitCaster = unitCaster
					button.isStealable = isStealable
					button.isBossDebuff = isBossDebuff
					button.isCastByPlayer = isCastByPlayer

					button.Icon:SetTexture(icon)
					button.Count:SetText((count > 1) and count or "")
					
					button:SetTimer(duration, expirationTime)
					
					if Debuffs.PostUpdateButton then
						Debuffs:PostUpdateButton(button)
					end

					if not button:IsShown() then
						button:Show()
					end

				end
			end

			if visible == 0 then
				if Debuffs:IsShown() then
					Debuffs:Hide()
				end
			else
				local visible = SetPosition(Debuffs, visible)
				for i = visible + 1, #Debuffs do
					Debuffs[i]:Hide()
					Debuffs[i]:SetScript("OnUpdate", nil)
					Debuffs[i]:SetTimer(0,0)
				end 
				if not Debuffs:IsShown() then
					Debuffs:Show()
				end
			end

			if Debuffs.PostUpdate then
				Debuffs:PostUpdate()
			end
		end
	end

end

local ForceUpdate = function(element)
	return Update(element._owner, "FORCED", element.unit)
end

local Enable = function(self, unit)
	local Auras = self.Auras
	local Buffs = self.Buffs
	local Debuffs = self.Debuffs
	if Auras or Buffs or Debuffs then
		if Auras then
			Auras._owner = self
			Auras.unit = unit
			Auras.ForceUpdate = ForceUpdate
		end
		if Buffs then
			Buffs._owner = self
			Buffs.unit = unit
			Buffs.ForceUpdate = ForceUpdate
		end
		if Debuffs then
			Debuffs._owner = self
			Debuffs.unit = unit
			Debuffs.ForceUpdate = ForceUpdate
		end
		local frequent = (Auras and Auras.frequent) or (Buffs and Buffs.frequent) or (Debuffs and Debuffs.frequent)
		if frequent then
			self:EnableFrequentUpdates("Auras", frequent)
		else
			self:RegisterEvent("UNIT_AURA", Update)
			self:RegisterEvent("PLAYER_ENTERING_WORLD", Update)
			self:RegisterEvent("VEHICLE_UPDATE", Update)
			self:RegisterEvent("UNIT_ENTERED_VEHICLE", Update)
			self:RegisterEvent("UNIT_ENTERING_VEHICLE", Update)
			self:RegisterEvent("UNIT_EXITING_VEHICLE", Update)
			self:RegisterEvent("UNIT_EXITED_VEHICLE", Update)
			self:RegisterEvent("MODIFIER_STATE_CHANGED", UpdateTooltip)

			if (unit == "target") or (unit == "targettarget") then
				self:RegisterEvent("PLAYER_TARGET_CHANGED", Update)
			end
		end
		return true
	end
end

local Disable = function(self, unit)
	local Auras = self.Auras
	local Buffs = self.Buffs
	local Debuffs = self.Debuffs
	if Auras or Buffs or Debuffs then
		if Auras then
			Auras.unit = nil
		end
		if Buffs then
			Buffs.unit = nil
		end
		if Debuffs then
			Debuffs.unit = nil
		end
		if not ((Auras and Auras.frequent) or (Buffs and Buffs.frequent) or (Debuffs and Debuffs.frequent)) then
			self:UnregisterEvent("UNIT_AURA", Update)
			self:UnregisterEvent("PLAYER_ENTERING_WORLD", Update)
			self:UnregisterEvent("UNIT_ENTERED_VEHICLE", Update)
			self:UnregisterEvent("UNIT_ENTERING_VEHICLE", Update)
			self:UnregisterEvent("UNIT_EXITING_VEHICLE", Update)
			self:UnregisterEvent("UNIT_EXITED_VEHICLE", Update)
			self:UnregisterEvent("MODIFIER_STATE_CHANGED", UpdateTooltip)

			if (unit == "target") or (unit == "targettarget") then
				self:UnregisterEvent("PLAYER_TARGET_CHANGED", Update)
			end
		end
	end
end

Handler:RegisterElement("Auras", Enable, Disable, Update)
