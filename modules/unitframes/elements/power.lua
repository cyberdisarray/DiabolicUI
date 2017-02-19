local _, Engine = ...
local Handler = Engine:GetHandler("UnitFrame")
local C = Engine:GetStaticConfig("Data: Colors")
local F = Engine:GetStaticConfig("Data: Functions")

-- Lua API
local tostring, tonumber = tostring, tonumber
local pairs, unpack = pairs, unpack
local floor = math.floor

-- WoW API
local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsTapDenied = UnitIsTapDenied 
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType


Update = function(self, event, ...)
	local Power = self.Power
	local Mana = self.Mana

	local unit = self.unit

	local dead = UnitIsDeadOrGhost(unit)
	local connected = UnitIsConnected(unit)
	local tapped = UnitIsTapDenied(unit)

	local powerID, powerType = UnitPowerType(unit)
	local power = UnitPower(unit, powerID)
	local powermax = UnitPowerMax(unit, powerID)

	if Power then 
		if dead then
			power = 0
			powermax = 0
		end

		local object_type = Power:GetObjectType()

		if object_type == "Orb" then
			local multi_color = powerType and C.Orb[powerType] 
			local single_color = powerType and C.Power[powerType] or C.Power.UNUSED

			if Power.powerType ~= powerType then
				Power:Clear() -- forces the orb to empty, for a more lively animation on power/form changes
				Power.powerType = powerType
			end

			Power:SetMinMaxValues(0, powermax)
			Power:SetValue(power)
			
			if multi_color then
				for i = 1,4 do
					Power:SetStatusBarColor(unpack(multi_color[i]))
				end
			else
				--for i = 1,4 do
					Power:SetStatusBarColor(unpack(single_color))
				--end
			end

		elseif object_type == "StatusBar" then
			local color = powerType and C.Power[powerType] or C.Power.UNUSED
			if Power.powerType ~= powerType then
				Power.powerType = powerType
			end

			Power:SetMinMaxValues(0, powermax)
			Power:SetValue(power)
			
			local r, g, b
			if not connected then
				r, g, b = unpack(C.Status.Disconnected)
			elseif dead then
				r, g, b = unpack(C.Status.Dead)
			elseif tapped then
				r, g, b = unpack(C.Status.Tapped)
			else
				r, g, b = unpack(color)
			end
			Power:SetStatusBarColor(r, g, b)
		end
		
		if Power.Value then
			if (power == 0 or powermax == 0) and (not Power.Value.showAtZero) then
				Power.Value:SetText("")
			else
				if Power.Value.showDeficit then
					if Power.Value.showPercent then
						if Power.Value.showMaximum then
							Power.Value:SetFormattedText("%s / %s - %d%%", F.Short(powermax - power), F.Short(powermax), floor(power/powermax * 100))
						else
							Power.Value:SetFormattedText("%s / %d%%", F.Short(powermax - power), floor(power/powermax * 100))
						end
					else
						if Power.Value.showMaximum then
							Power.Value:SetFormattedText("%s / %s", F.Short(powermax - power), F.Short(powermax))
						else
							Power.Value:SetFormattedText("%s", F.Short(powermax - power))
						end
					end
				else
					if Power.Value.showPercent then
						if Power.Value.showMaximum then
							Power.Value:SetFormattedText("%s / %s - %d%%", F.Short(power), F.Short(powermax), floor(power/powermax * 100))
						else
							Power.Value:SetFormattedText("%s / %d%%", F.Short(power), floor(power/powermax * 100))
						end
					else
						if Power.Value.showMaximum then
							Power.Value:SetFormattedText("%s / %s", F.Short(power), F.Short(powermax))
						else
							Power.Value:SetFormattedText("%s", F.Short(power))
						end
					end
				end
			end
		end
				
		if Power.PostUpdate then
			Power:PostUpdate()
		end		
	end

	if Mana then
		local mana = UnitPower(unit, SPELL_POWER_MANA)
		local manamax = UnitPowerMax(unit, SPELL_POWER_MANA)

		if powerType == "MANA" or manamax == 0 then
			Mana:Hide()
		else
			if dead then
				mana = 0
				manamax = 0
			end

			local object_type = Mana:GetObjectType()

			if object_type == "Orb" then
				local multi_color = C.Orb.MANA 
				local single_color = C.Power.MANA or C.Power.UNUSED

				Mana:SetMinMaxValues(0, manamax)
				Mana:SetValue(mana)
				
				if multi_color then
					for i = 1,4 do
						Mana:SetStatusBarColor(unpack(multi_color[i]))
					end
				else
					for i = 1,4 do
						Mana:SetStatusBarColor(unpack(single_color))
					end
				end

			elseif object_type == "StatusBar" then
				local color = C.Power.MANA or C.Power.UNUSED

				Mana:SetMinMaxValues(0, manamax)
				Mana:SetValue(mana)
				
				local r, g, b
				if not connected then
					r, g, b = unpack(C.Status.Disconnected)
				elseif dead then
					r, g, b = unpack(C.Status.Dead)
				elseif tapped then
					r, g, b = unpack(C.Status.Tapped)
				else
					r, g, b = unpack(color)
				end
				Mana:SetStatusBarColor(r, g, b)
			end
			
			if not Mana:IsShown() then
				Mana:Show()
			end

			if Mana.PostUpdate then
				Mana:PostUpdate()
			end		
		end
	end
end

local Enable = function(self)
	local Power = self.Power
	local Mana = self.Mana
	if Power or Mana then
		if Power then
			Power._owner = self
		end
		if Mana then
			Mana._owner = self
		end
		if Power.frequent or Mana.frequent then
			self:EnableFrequentUpdates("Power", Power.frequent or Mana.frequent)
		else
			if Engine:IsBuild("Cata") then
				self:RegisterEvent("UNIT_POWER", Update)
				self:RegisterEvent("UNIT_MAXPOWER", Update)
			else
				self:RegisterEvent("UNIT_MANA", Update)
				self:RegisterEvent("UNIT_RAGE", Update)
				self:RegisterEvent("UNIT_FOCUS", Update)
				self:RegisterEvent("UNIT_ENERGY", Update)
				self:RegisterEvent("UNIT_RUNIC_POWER", Update)
				self:RegisterEvent("UNIT_MAXMANA", Update)
				self:RegisterEvent("UNIT_MAXRAGE", Update)
				self:RegisterEvent("UNIT_MAXFOCUS", Update)
				self:RegisterEvent("UNIT_MAXENERGY", Update)
				self:RegisterEvent("UNIT_DISPLAYPOWER", Update)
				self:RegisterEvent("UNIT_MAXRUNIC_POWER", Update)
			end
			self:RegisterEvent("PLAYER_ENTERING_WORLD", Update)
		end
	end
end

local Disable = function(self)
	local Power = self.Power
	local Mana = self.Mana
	if Power or Mana then
		if not (Power.frequent or Mana.frequent) then
			if Engine:IsBuild("Cata") then
				self:UnregisterEvent("UNIT_POWER", Update)
				self:UnregisterEvent("UNIT_MAXPOWER", Update)
			else
				self:UnregisterEvent("UNIT_MANA", Update)
				self:UnregisterEvent("UNIT_RAGE", Update)
				self:UnregisterEvent("UNIT_FOCUS", Update)
				self:UnregisterEvent("UNIT_ENERGY", Update)
				self:UnregisterEvent("UNIT_RUNIC_POWER", Update)
				self:UnregisterEvent("UNIT_MAXMANA", Update)
				self:UnregisterEvent("UNIT_MAXRAGE", Update)
				self:UnregisterEvent("UNIT_MAXFOCUS", Update)
				self:UnregisterEvent("UNIT_MAXENERGY", Update)
				self:UnregisterEvent("UNIT_DISPLAYPOWER", Update)
				self:UnregisterEvent("UNIT_MAXRUNIC_POWER", Update)
			end
			self:UnregisterEvent("PLAYER_ENTERING_WORLD", Update)
		end
		return true
	end
end

Handler:RegisterElement("Power", Enable, Disable, Update)