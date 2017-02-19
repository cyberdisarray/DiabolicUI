local _, Engine = ...
local Handler = Engine:GetHandler("UnitFrame")

-- Lua API
local select = select
local tinsert = table.insert

-- WoW API
local GetComboPoints = GetComboPoints
local IsPlayerSpell = IsPlayerSpell -- added in 5.0.4
local UnitBuff = UnitBuff
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitHasVehicleUI = UnitHasVehicleUI

local ENGINE_MOP = Engine:IsBuild("MoP")
local ENGINE_LEGION = Engine:IsBuild("Legion")

local PlayerIsRogue = select(2, UnitClass("player")) == "ROGUE" -- to check for rogue anticipation
local PlayerIsDruid = select(2, UnitClass("player")) == "DRUID" -- we won't be needing this. leaving it here because. druid. master race.

local OldAnticipation = PlayerIsRogue and ENGINE_MOP and (not ENGINE_LEGION)
local NewAnticipation = PlayerIsRogue and ENGINE_LEGION -- anticipation changed in Legion, so did combopoints

local MAX_COMBO_POINTS
local MAX_ANTICIPATION_POINTS
local Anticipation_Talent, HasAnticipation
local anticipation

if OldAnticipation then
	MAX_COMBO_POINTS = 5
	MAX_ANTICIPATION_POINTS = 5
	
	-- Rogue Anticipation is a Level 90 Talent added in patch 5.0.4. 
	-- 	*We're checking for the anticipation buff by its name, 
	-- 	 but I don't want this to require any localization to function.  
	-- 	 So to make sure we catch the correct spell, we check both for the buff, 
	-- 	 the spell that activates it, and even the talent that causes it. 
	--   I mean... one of them HAS to be right in every client language, right? :/
	anticipation = {}
	tinsert(anticipation, (GetSpellInfo(115190))) -- the buff the rogue gets
	tinsert(anticipation, (GetSpellInfo(115189))) -- the ability that triggers
	tinsert(anticipation, (GetSpellInfo(114015))) -- the rogue talent from MoP 5.0.4

	Anticipation_Talent = 114015
	HasAnticipation = ENGINE_MOP and PlayerIsRogue and IsPlayerSpell(Anticipation_Talent)
	
elseif NewAnticipation then
	MAX_COMBO_POINTS = 6
	MAX_ANTICIPATION_POINTS = 3
else
	MAX_COMBO_POINTS = 5
	MAX_ANTICIPATION_POINTS = nil
end

	
local Update = function(self, event, ...)
	local unit = self.unit
	if unit == "pet" then 
		return 
	end
	local ComboPoints = self.ComboPoints
	
	local cp, cp_max
	local ap, ap_max

	local vehicle = UnitHasVehicleUI("player")
	local combo_unit = vehicle and "vehicle" or "player"

	-- In Legion anticipation is merely 3 more combopoints
	if ENGINE_LEGION then
		cp = UnitPower(combo_unit, SPELL_POWER_COMBO_POINTS)
		cp_max = UnitPowerMax(combo_unit, SPELL_POWER_COMBO_POINTS)
		if cp_max == 8 then
			cp_max = 5
			ap_max = 3
			if cp > 5 then
				ap = cp - 5
				cp = 5
			end
		else
			ap = 0
			ap_max = 0
		end
		
	-- in MoP and WoD, anticipation was a double set of combopoints
	elseif ENGINE_MOP then
		cp = GetComboPoints(combo_unit, "target") 
		cp_max = 5
		if HasAnticipation and not vehicle then
			ap_max = 5
			for i,name in ipairs(anticipation) do
				ap = select(4, UnitBuff("player", name, nil)) or 0
				if ap > 0 then
					break
				end
			end
		end
	else
		cp = GetComboPoints(combo_unit, "target") 
		cp_max = 5
	end

	for i = 1, cp_max do
		if i <= cp then
			ComboPoints[i]:Show()
		else
			ComboPoints[i]:Hide()
		end
	end
	
	-- might have been a spec change, changing max from 6 to 5
	if ENGINE_LEGION then
		if #ComboPoints > cp_max then
			for i = cp_max + 1, #ComboPoints do
				ComboPoints[i]:Hide()
			end
		end
	end
	
	if ap and ap_max then
		local Anticipation = self.ComboPoints.Anticipation
		if Anticipation then
			for i = 1, ap_max do
				if i <= ap then
					Anticipation[i]:Show()
				else
					Anticipation[i]:Hide()
				end
			end
		end
	end
	
	if ComboPoints.PostUpdate then
		return ComboPoints:PostUpdate()
	end
end

local SpellsChanged = function(self, event, ...)
	if not HasAnticipation and IsPlayerSpell(Anticipation_Talent) then
		HasAnticipation = true
		self:RegisterEvent("UNIT_AURA", Update)
	end
	if HasAnticipation and not IsPlayerSpell(Anticipation_Talent) then
		HasAnticipation = false
		self:UnregisterEvent("UNIT_AURA", Update)
	end
	Update(self, event, ...)
end

local Enable = function(self, unit)
	local ComboPoints = self.ComboPoints
	if ComboPoints then
		self:RegisterEvent("PLAYER_ENTERING_WORLD", Update)
		self:RegisterEvent("PLAYER_TARGET_CHANGED", Update)

		if ENGINE_LEGION then
			self:RegisterEvent("UNIT_POWER_FREQUENT", Update)
			self:RegisterEvent("UNIT_MAXPOWER", Update)
		else
			self:RegisterEvent("UNIT_COMBO_POINTS", Update)
			if ENGINE_MOP and PlayerIsRogue then
				self:RegisterEvent("SPELLS_CHANGED", SpellsChanged)
				
				if HasAnticipation then
					self:RegisterEvent("UNIT_AURA", Update)
				end
			end
		end
		return true
	end
end

local Disable = function(self, unit)
	local ComboPoints = self.ComboPoints
	if ComboPoints then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD", Update)
		self:UnregisterEvent("PLAYER_TARGET_CHANGED", Update)
		
		if ENGINE_LEGION then
			self:UnregisterEvent("UNIT_POWER_FREQUENT", Update)
			self:UnregisterEvent("UNIT_MAXPOWER", Update)
		else
			self:UnregisterEvent("UNIT_COMBO_POINTS", Update)
			if ENGINE_MOP and PlayerIsRogue then
				self:UnregisterEvent("SPELLS_CHANGED", SpellsChanged)

				if HasAnticipation then
					self:UnregisterEvent("UNIT_AURA", Update)
				end
			end
		end
	end
end

Handler:RegisterElement("ComboPoints", Enable, Disable, Update)