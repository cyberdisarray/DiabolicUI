local _, Engine = ...
local Handler = Engine:GetHandler("UnitFrame")
local C = Engine:GetStaticConfig("Data: Colors")
local F = Engine:GetStaticConfig("Data: Functions")

-- Lua API
local _G = _G
local math_floor = math.floor
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local unpack = unpack

-- WoW API
local UnitClassification = _G.UnitClassification
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitIsConnected = _G.UnitIsConnected
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitIsPlayer = _G.UnitIsPlayer
local UnitIsUnit = _G.UnitIsUnit
local UnitIsTapDenied = _G.UnitIsTapDenied 
local UnitLevel = _G.UnitLevel
local UnitPlayerControlled = _G.UnitPlayerControlled
local UnitReaction = _G.UnitReaction


Update = function(self, event, ...)
	local Health = self.Health

	local unit = self.unit

	local dead = UnitIsDeadOrGhost(unit)
	local connected = UnitIsConnected(unit)
	local tapped = UnitIsTapDenied(unit)

	local health = UnitHealth(unit)
	local healthmax = UnitHealthMax(unit)

	local objectType = Health:GetObjectType()
	
	if dead then
		health = 0
		healthmax = 0
	end

	Health:SetMinMaxValues(0, healthmax)
	Health:SetValue(health)

	if (objectType == "Orb") then
		if Health.useClassColor and UnitIsPlayer(unit) then
			local _, class = UnitClass(unit)
			if C.Orb[class] then
				for i,v in pairs(C.Orb[class]) do
					Health:SetStatusBarColor(v[1], v[2], v[3], v[4], v[5])
				end
			else
				r, g, b = unpack(C.Class[class] or C.Class.UNKNOWN)
				Health:SetStatusBarColor(r, g, b, "ALL")
			end
		else
			for i,v in pairs(C.Orb.HEALTH) do
				Health:SetStatusBarColor(v[1], v[2], v[3], v[4], v[5])
			end
		end
	elseif (objectType == "StatusBar") then
		local r, g, b
		if not UnitIsConnected(unit) then
			r, g, b = unpack(C.Status.Disconnected)
		elseif UnitIsDead(unit) or UnitIsGhost(unit) then
			r, g, b = unpack(C.Status.Dead)
		elseif not UnitIsFriend(unit, "player") and UnitIsTapDenied(unit) then
			r, g, b = unpack(C.Status.Tapped)
		elseif UnitIsPlayer(unit) then
			local _, class = UnitClass(unit)
			r, g, b = unpack(C.Class[class] or C.Class.UNKNOWN)
		elseif UnitPlayerControlled(unit) and (not UnitIsPlayer(unit)) then
			if UnitIsFriend(unit, "player") then
				local _, class = UnitClass(unit)
				r, g, b = unpack(C.Reaction[5])
			elseif UnitIsEnemy(unit, "player") then
				local _, class = UnitClass(unit)
				r, g, b = unpack(C.Reaction[1])
			else
				local _, class = UnitClass(unit)
				r, g, b = unpack(C.Reaction[4])
			end
			--local _, class = UnitClass(unit)
			--r, g, b = unpack(C.Class[class] or C.Class.UNKNOWN)
		elseif UnitReaction(unit, "player") then
			r, g, b = unpack(C.Reaction[UnitReaction(unit, "player")])
		else
			r, g, b = unpack(C.Orb.HEALTH[1])
		end
		Health:SetStatusBarColor(r, g, b)
	end
	
	if Health.Value then
		if (health == 0 or healthmax == 0) and (not Health.Value.showAtZero) then
			Health.Value:SetText("")
		else
			if Health.Value.showDeficit then
				if Health.Value.showPercent then
					if Health.Value.showMaximum then
						Health.Value:SetFormattedText("%s / %s - %d%%", F.Short(healthmax - health), F.Short(healthmax), math_floor(health/healthmax * 100))
					else
						Health.Value:SetFormattedText("%s / %d%%", F.Short(healthmax - health), math_floor(health/healthmax * 100))
					end
				else
					if Health.Value.showMaximum then
						Health.Value:SetFormattedText("%s / %s", F.Short(healthmax - health), F.Short(healthmax))
					else
						Health.Value:SetFormattedText("%s / %s", F.Short(healthmax - health))
					end
				end
			else
				if Health.Value.showPercent then
					if Health.Value.showMaximum then
						Health.Value:SetFormattedText("%s / %s - %d%%", F.Short(health), F.Short(healthmax), math_floor(health/healthmax * 100))
					elseif Health.Value.hideMinimum then
						Health.Value:SetFormattedText("%d%%", math_floor(health/healthmax * 100))
					else
						Health.Value:SetFormattedText("%s / %d%%", F.Short(health), math_floor(health/healthmax * 100))
					end
				else
					if Health.Value.showMaximum then
						Health.Value:SetFormattedText("%s / %s", F.Short(health), F.Short(healthmax))
					else
						Health.Value:SetFormattedText("%s / %s", F.Short(health))
					end
				end
			end
		end
	end
	
	if Health.PostUpdate then
		return Health:PostUpdate()
	end
end
	
local Enable = function(self)
	local Health = self.Health
	if Health then
		Health._owner = self
		if Health.frequent then
			self:EnableFrequentUpdates("Health", Health.frequent)
		else
			self:RegisterEvent("UNIT_HEALTH", Update)
			self:RegisterEvent("UNIT_MAXHEALTH", Update)
			self:RegisterEvent("UNIT_HAPPINESS", Update)
			self:RegisterEvent("UNIT_FACTION", Update)
			self:RegisterEvent("PLAYER_ENTERING_WORLD", Update)
		end
		return true
	end
end

local Disable = function(self)
	local Health = self.Health
	if Health then 
		if not Health.frequent then
			self:UnregisterEvent("UNIT_HEALTH", Update)
			self:UnregisterEvent("UNIT_MAXHEALTH", Update)
			self:UnregisterEvent("UNIT_HAPPINESS", Update)
			self:UnregisterEvent("UNIT_FACTION", Update)
			self:UnregisterEvent("PLAYER_ENTERING_WORLD", Update)
		end
	end
end

Handler:RegisterElement("Health", Enable, Disable, Update)