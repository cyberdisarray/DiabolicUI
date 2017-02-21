local ADDON, Engine = ...
local Module = Engine:NewModule("NamePlates")
local StatusBar = Engine:GetHandler("StatusBar")
local C = Engine:GetStaticConfig("Data: Colors")
local F = Engine:GetStaticConfig("Data: Functions")
local UICenter = Engine:GetFrame()

-- Lua API
local _G = _G
local ipairs = ipairs
local math_floor = math.floor
local pairs = pairs
local select = select
local setmetatable = setmetatable
local string_find = string.find
local table_insert = table.insert
local table_sort = table.sort
local table_wipe = table.wipe
local tonumber = tonumber
local tostring = tostring
local unpack = unpack

-- WoW API
local C_NamePlate = _G.C_NamePlate 
local CreateFrame = _G.CreateFrame
local GetLocale = _G.GetLocale
local GetRaidTargetIndex = _G.GetRaidTargetIndex
local GetTime = _G.GetTime
local GetQuestGreenRange = _G.GetQuestGreenRange
local SetCVar = _G.SetCVar
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitCastingInfo = _G.UnitCastingInfo
local UnitChannelInfo = _G.UnitChannelInfo
local UnitClass = _G.UnitClass
local UnitClassification = _G.UnitClassification
local UnitExists = _G.UnitExists
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitIsEnemy = _G.UnitIsEnemy
local UnitIsFriend = _G.UnitIsFriend
local UnitIsPlayer = _G.UnitIsPlayer
local UnitIsTapDenied = _G.UnitIsTapDenied
local UnitIsTrivial = _G.UnitIsTrivial
local UnitIsUnit = _G.UnitIsUnit
local UnitLevel = _G.UnitLevel
local UnitName = _G.UnitName
local UnitReaction = _G.UnitReaction
local UnitThreatSituation = _G.UnitThreatSituation

-- Engine API
local short = F.Short

-- WoW Frames & Tables
local UIParent = UIParent
local WorldFrame = WorldFrame
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

-- Plate Registries
local AllPlates, VisiblePlates, FadingPlates = {}, {}, {}
local GUID, UID = {}, {}

-- WorldFrame child registry to rule out elements already checked faster
local AllChildren = {}

-- Plate FrameLevel ordering
local FRAMELEVELS = {}

-- Counters to keep track of WorldFrame frames and NamePlates
local WORLDFRAME_CHILDREN, WORLDFRAME_PLATES = -1, 0

-- This will be updated later on by the addon,
-- we just need a value of some sort here as a fallback.
local SCALE = 768/1080 

-- This will be true if forced updates are needed on all plates
-- All plates will be updated in the next frame cycle 
local FORCEUPDATE = false

-- This will be true when plates are shown, hidden or moved, 
-- and their frame levels need to be updated. 
--local UPDATELEVELS = true

-- Frame level constants and counters
local FRAMELEVEL_TARGET = 126
local FRAMELEVEL_CURRENT, FRAMELEVEL_MIN, FRAMELEVEL_MAX, FRAMELEVEL_STEP = 21, 21, 125, 2
local FRAMELEVEL_TRIVAL_CURRENT, FRAMELEVEL_TRIVIAL_MIN, FRAMELEVEL_TRIVIAL_MAX, FRAMELEVEL_TRIVIAL_STEP = 1, 1, 20, 2

-- Update and fading frequencies
local HZ = 1/120 -- max frequency position and visibility updates
local FADE_HZ = 1/120 -- max frequency of frame fade updates
local FADE_IN = 3/4 -- time in seconds to fade in
local FADE_OUT = 1/20 -- time in seconds to fade out

-- Constants for castbar and aura time displays
local DAY, HOUR, MINUTE = 86400, 3600, 60

-- Player and Target data
local LEVEL = UnitLevel("player") -- our current level
local TARGET -- our current target, if any
local COMBAT -- whether or not the player is affected by combat

-- Blizzard textures we use to identify plates and more 
local CATA_PLATE 		= [[Interface\Tooltips\Nameplate-Border]]
local WOTLK_PLATE 		= [[Interface\TargetingFrame\UI-TargetingFrame-Flash]] 
local ELITE_TEXTURE 	= [[Interface\Tooltips\EliteNameplateIcon]] -- elite/rare dragon texture
local BOSS_TEXTURE 		= [[Interface\TargetingFrame\UI-TargetingFrame-Skull]] -- skull textures
local EMPTY_TEXTURE 	= Engine:GetConstant("EMPTY_TEXTURE") -- used to make textures invisible
local BLANK_TEXTURE 	= Engine:GetConstant("BLANK_TEXTURE") -- not currently used (?)

-- Client version constants, to avoid extra function calls and database lookups 
-- during the rather performance intensive OnUpdate handling.
-- Hopefully we'll gain a FPS or two by doing this. 
local ENGINE_LEGION 	= Engine:IsBuild("Legion")
local ENGINE_WOD 		= Engine:IsBuild("WoD")
local ENGINE_MOP 		= Engine:IsBuild("MoP")
local ENGINE_CATA 		= Engine:IsBuild("Cata")
local ENGINE_WOTLK 		= Engine:IsBuild("WotLK")


-- We use the visibility of some items to determine info about a plate's owner, 
-- but still wish these itemse to be hidden from view. 
-- So we simply parent them to this hidden frame.
local UIHider = CreateFrame("Frame")
UIHider:Hide()



-- Utility Functions
----------------------------------------------------------

-- Returns the correct difficulty color compared to the player
local getDifficultyColorByLevel = function(level)
	level = level - LEVEL
	if level > 4 then
		return C.General.DimRed.colorCode
	elseif level > 2 then
		return C.General.Orange.colorCode
	elseif level >= -2 then
		return C.General.Normal.colorCode
	elseif level >= -GetQuestGreenRange() then
		return C.General.OffGreen.colorCode
	else
		return C.General.Gray.colorCode
	end
end

-- In Diablo they don't abbreviate numbers at all
-- Since that would be messy with the insanely high health numbers in WoW, 
-- we compromise and abbreviate numbers larger than 100k. 
local abbreviateNumber = function(number)
	local abbreviated
	if number >= 1e6  then
		abbreviated = short(number)
	else
		abbreviated = tostring(number)
	end
	return abbreviated
end

-- Return a more readable time format for auras and castbars
local formatTime = function(time)
	if time > DAY then -- more than a day
		return ("%1d%s"):format(math_floor(time / DAY), L["d"])
	elseif time > HOUR then -- more than an hour
		return ("%1d%s"):format(math_floor(time / HOUR), L["h"])
	elseif time > MINUTE then -- more than a minute
		return ("%1d%s %d%s"):format(math_floor(time / MINUTE), L["m"], floor(time%MINUTE), L["s"])
	elseif time > 10 then -- more than 10 seconds
		return ("%d%s"):format(math_floor(time), L["s"])
	elseif time > 0 then
		return ("%.1f"):format(time)
	else
		return ""
	end	
end



-- NamePlate Template
----------------------------------------------------------

local NamePlate = Engine:CreateFrame("Frame")
local NamePlate_MT = { __index = NamePlate }

local NamePlate_WotLK = setmetatable({}, { __index = NamePlate })
local NamePlate_WotLK_MT = { __index = NamePlate_WotLK }

local NamePlate_Cata = setmetatable({}, { __index = NamePlate_WotLK })
local NamePlate_Cata_MT = { __index = NamePlate_Cata }

local NamePlate_MoP = setmetatable({}, { __index = NamePlate_Cata })
local NamePlate_MoP_MT = { __index = NamePlate_MoP }

local NamePlate_WoD = setmetatable({}, { __index = NamePlate_MoP })
local NamePlate_WoD_MT = { __index = NamePlate_WoD }

-- Legion NamePlates do NOT inherit from the other expansions, 
-- as the system for NamePlates was completely changed here. 
local NamePlate_Legion = setmetatable({}, { __index = NamePlate })
local NamePlate_Legion_MT = { __index = NamePlate_Legion }

-- Set the nameplate metatable to whatever the current expansion is.
local NamePlate_Current_MT = ENGINE_LEGION and NamePlate_Legion_MT 
						  or ENGINE_WOD and NamePlate_WoD_MT 
						  or ENGINE_MOP and NamePlate_MoP_MT 
						  or ENGINE_CATA and NamePlate_Cata_MT
						  or ENGINE_WOTLK and NamePlate_WotLK_MT 




-- WotLK Plates
----------------------------------------------------------

NamePlate_WotLK.UpdateAll = function(self)
	self:UpdateUnitData() -- update 'cosmetic' info like name, level, and elite/boss textures
	self:UpdateTargetData() -- updates info about target and mouseover
	self:UpdateAlpha() -- updates alpha and frame level based on current target
	self:UpdateFrameLevel() -- update frame level to keep target in front and frames separated
	self:UpdateCombatData() -- updates colors, threat, classes, raid markers, combat status, reaction, etc
	self:ApplyUnitData() -- set name, level, textures and icons
	self:ApplyHealthData() -- update health values
end

NamePlate_WotLK.UpdateUnitData = function(self)
	local info = self.info
	local oldRegions = self.old.regions
	local r, g, b

	info.name = oldRegions.name:GetText()
	info.isBoss = oldRegions.bossicon:IsShown() 

	-- If the dragon texture is shown, this is an elite or a rare or both
	local dragon = oldRegions.eliteicon:IsShown()
	if dragon then 
		-- Speeeeed!
		local math_floor = math_floor 

		-- The texture is golden, so a white vertexcolor means it's not a rare, but an elite
		r, g, b = oldRegions.eliteicon:GetVertexColor()
		r, g, b = math_floor(r*100 + .5)/100, math_floor(g*100 + .5)/100, math_floor(b*100 + .5)/100
		if r + g + b == 3 then 
			info.isElite = true
			info.isRare = false
		else
			-- The problem with the following is that only elites have the dragontexture,
			-- while it is possible for mobs to be rares without having elite status.
			info.isElite = oldRegions.eliteicon:GetTexture() == ELITE_TEXTURE 
			info.isRare = true 
		end
	else
		info.isElite = false
		info.isRare = false
	end

	-- Trivial mobs wasn't introduced until WoD
	if ENGINE_WOD then
		info.isTrivial = not(self.old.bars.group:GetScale() > .9)
	end

	info.level = self.info.isBoss and -1 or tonumber(oldRegions.level:GetText()) or -1
end

NamePlate_WotLK.UpdateTargetData = function(self)
	self.info.isTarget = TARGET and (self.baseFrame:GetAlpha() == 1)
	self.info.isMouseOver = self.old.regions.highlight:IsShown() == 1 
end

NamePlate_WotLK.UpdateCombatData = function(self)
	-- Shortcuts to our own objects
	local config = self.config
	local info = self.info
	local oldBars = self.old.bars
	local oldRegions = self.old.regions

	-- Our color table
	local C = C

	-- Blizzard tables
	local RAID_CLASS_COLORS = RAID_CLASS_COLORS

	-- More Lua speed
	local math_floor = math_floor
	local pairs = pairs
	local select = select
	local unpack = unpack

	local r, g, b, _
	local class, hasClass


	-- check if unit is in combat
	r, g, b = oldRegions.name:GetTextColor()
	r, g, b = math_floor(r*100 + .5)/100, math_floor(g*100 + .5)/100, math_floor(b*100 + .5)/100
	info.isInCombat = r > .5 and g < .5 -- seems to be working
	
	-- check for threat situation
	if oldRegions.threat:IsShown() then
		r, g, b = oldRegions.threat:GetVertexColor()
		r, g, b = math_floor(r*100 + .5)/100, math_floor(g*100 + .5)/100, math_floor(b*100 + .5)/100
		if r > 0 then
			if g > 0 then
				if b > 0 then
					info.unitThreatSituation = 1
				else
					info.unitThreatSituation = 2
				end
			else
				info.unitThreatSituation = 3
			end
		else
			info.unitThreatSituation = 0
		end
	else
		info.unitThreatSituation = nil
	end

	info.health = oldBars.health:GetValue() or 0
	info.healthMax = select(2, oldBars.health:GetMinMaxValues()) or 1
		
	-- check for raid marks
	info.isMarked = oldRegions.raidicon:IsShown()

	-- figure out class
	r, g, b = oldBars.health:GetStatusBarColor()
	r, g, b = math_floor(r*100 + .5)/100, math_floor(g*100 + .5)/100, math_floor(b*100 + .5)/100

	for class in pairs(RAID_CLASS_COLORS) do
		if RAID_CLASS_COLORS[class].r == r and RAID_CLASS_COLORS[class].g == g and RAID_CLASS_COLORS[class].b == b then
			info.isNeutral = false
			info.isCivilian = false
			info.isClass = class
			info.isFriendly = false
			info.isTapped = false
			info.isPlayer = true
			hasClass = true
			break
		end
	end

	-- figure out reaction and type if no class is found
	if not hasClass then
		info.isClass = false
		if (r + g + b) >= 1.5 and (r == g and r == b) then -- tapped npc (.53, .53, .53)
			info.isNeutral = false
			info.isCivilian = false
			info.isFriendly = false
			info.isTapped = true
			info.isPlayer = false
		elseif g + b == 0 then -- hated/hostile/unfriendly npc
			info.isNeutral = false
			info.isCivilian = false
			info.isFriendly = false
			info.isTapped = false
			info.isPlayer = false
		elseif r + b == 0 then -- friendly npc
			info.isNeutral = false
			info.isCivilian = false
			info.isFriendly = true
			info.isTapped = false
			info.isPlayer = false
		elseif r + g > 1.95 then -- neutral npc
			info.isNeutral = true
			info.isCivilian = false
			info.isFriendly = false
			info.isTapped = false
			info.isPlayer = false
		elseif r + g == 0 then -- friendly player
			info.isNeutral = false
			info.isCivilian = true
			info.isFriendly = true
			info.isTapped = false
			info.isPlayer = true
		else 
			if r == 0 and (g > b) and (g + b > 1.5) and (g + b < 1.65) then -- monk?
				info.isNeutral = false
				info.isCivilian = false
				info.isClass = "MONK"
				info.isFriendly = false
				info.isTapped = false
				info.isPlayer = true
				hasClass = true
			else -- enemy player (no class colors enabled)
				info.isNeutral = false
				info.isCivilian = false
				info.isFriendly = false
				info.isTapped = false
				info.isPlayer = false
			end
		end
	end

	-- apply health and threat coloring
	if not info.healthColor then
		info.healthColor = {}
	end
	if info.unitThreatSituation and info.unitThreatSituation > 0 then
		local color = C.Threat[info.unitThreatSituation]
		r, g, b = color[1], color[2], color[3]
		if not info.threatColor then
			info.threatColor = {}
		end

		info.threatColor[1] = r
		info.threatColor[2] = g
		info.threatColor[3] = b

		info.healthColor[1] = r
		info.healthColor[2] = g
		info.healthColor[3] = b
	else
		if info.isClass then
			if config.showEnemyClassColor then
				local color = C.Class[info.isClass]
				r, g, b = color[1], color[2], color[3]
			else
				local color = C.Reaction[1]
				r, g, b = color[1], color[2], color[3]
			end
		elseif info.isFriendly then
			if info.isPlayer then
				local color = C.Reaction.civilian
				r, g, b = color[1], color[2], color[3]
			else
				local color = C.Reaction[5]
				r, g, b = color[1], color[2], color[3]
			end
		elseif info.isTapped then
			local color = C.tapped
			r, g, b = color[1], color[2], color[3]
		else
			if info.isPlayer then
				local color = C.Reaction[1]
				r, g, b = color[1], color[2], color[3]
			elseif info.isNeutral then
				local color = C.Reaction[4]
				r, g, b = color[1], color[2], color[3]
			else
				local color = C.Reaction[2]
				r, g, b = color[1], color[2], color[3]
			end
		end

		info.healthColor[1] = r
		info.healthColor[2] = g
		info.healthColor[3] = b
	end

end

NamePlate_WotLK.ApplyUnitData = function(self)
	local info = self.info

	local level
	if info.isBoss or (info.level and info.level < 1) then
		self.BossIcon:Show()
		self.Level:SetText("")
	else
		if info.level and info.level > 0 then
			if info.isFriendly then
				level = C.General.OffWhite.colorCode .. info.level .. "|r"
			else
				level = (getDifficultyColorByLevel(info.level)) .. info.level .. "|r"
			end
			if info.isElite then
				if info.isFriendly then
					level = level .. C.Reaction[5].colorCode .. "+|r"
				elseif info.isNeutral then
					level = level .. C.Reaction[4].colorCode .. "+|r"
				else
					level = level .. C.Reaction[2].colorCode .. "+|r"
				end
			end
		end
		self.Level:SetText(level)
		self.BossIcon:Hide()
	end

	if info.isMarked then
		self.RaidIcon:SetTexCoord(self.old.regions.raidicon:GetTexCoord()) -- ?
		self.RaidIcon:Show()
	else
		self.RaidIcon:Hide()
	end
end

NamePlate_WotLK.ApplyHealthData = function(self)
	local info = self.info
	local health = self.Health

	if info.healthColor then
		health:SetStatusBarColor(unpack(info.healthColor))
	end

	if info.unitThreatSituation and info.unitThreatSituation > 0 then
		if info.threatColor then
			local r, g, b = info.threatColor[1], info.threatColor[2], info.threatColor[3]
			health.Glow:SetVertexColor(r, g, b, 1)
			health.Shadow:SetVertexColor(r, g, b)
		else
			health.Glow:SetVertexColor(0, 0, 0, .25)
			health.Shadow:SetVertexColor(0, 0, 0, 1)
		end
	else
		health.Glow:SetVertexColor(0, 0, 0, .25)
		health.Shadow:SetVertexColor(0, 0, 0, 1)
	end

	health:SetMinMaxValues(0, info.healthMax)
	health:SetValue(info.health)
	health.Value:SetFormattedText("( %s / %s )", abbreviateNumber(info.health), abbreviateNumber(info.healthMax))
end

NamePlate_WotLK.UpdateHealth = function(self)
	self:UpdateCombatData()  -- updates colors, threat, classes, etc
	self:ApplyUnitData() -- set name, level, textures and icons
	self:ApplyHealthData() -- applies health values and coloring
end

NamePlate_WotLK.UpdateAlpha = function(self)
	local info = self.info
	if self.visiblePlates[self] then
		local oldHealth = self.old.bars.health
		local current, min, max = oldHealth:GetValue(), oldHealth:GetMinMaxValues()
		if (current == 0) or (max == 0) then
			self.targetAlpha = 0 -- just fade out the dead units fast, they tend to get stuck. weird. 
		else 
			if TARGET then
				if info.isTarget then
					self.targetAlpha = 1 -- current target, keep alpha at max
				else
					self.targetAlpha = .3 -- non-targets while you have an actual target
				end
			else
				self.targetAlpha = .7 -- no target selected
			end
		end
	else
		self.targetAlpha = 0 -- fade out hidden frames
	end
end

NamePlate_WotLK.UpdateFrameLevel = function(self)
	local info = self.info
	local healthValue = self.Health.Value
	if TARGET and info.isTarget then
		if self:GetFrameLevel() ~= FRAMELEVEL_TARGET then
			self:SetFrameLevel(FRAMELEVEL_TARGET)
		end
		if not healthValue:IsShown() then
			healthValue:Show()
		end
	else 
		if self:GetFrameLevel() ~= self.frameLevel then
			self:SetFrameLevel(self.frameLevel)
		end
		if healthValue:IsShown() then
			healthValue:Hide()
		end
	end	
end

NamePlate_WotLK.IsTarget = function(self)
	return self.info.isTarget
end

NamePlate_WotLK.IsTrivial = function(self)
	return self.info.isTrivial
end

NamePlate_WotLK.OnShow = function(self)
	local info = self.info
	local baseFrame = self.baseFrame

	info.level = nil
	info.name = nil
	--info.rawname = nil
	info.isInCombat = nil
	info.isCasting = nil
	info.isClass = nil
	info.isBoss = nil
	info.isElite = nil
	info.isFriendly = nil
	info.isMouseOver = nil
	info.isNeutral = nil
	info.isPlayer = nil
	info.isRare = nil
	info.isShieldedCast = nil
	info.isTapped = nil
	info.isTarget = nil
	info.isTrivial = nil
	info.unitThreatSituation = nil
	info.healthMax = 0
	info.health = 0

	self.Highlight:Hide() -- hide custom highlight
	-- self.old.regions.highlight:Hide() -- hide old highlight

	--self.old.regions.highlight:ClearAllPoints()
	--self.old.regions.highlight:SetAllPoints(self.Health)

	self.Health:Show()
	self.Cast:Hide()
	self.Cast.Shadow:Hide()
	self.Auras:Hide()

	self.visiblePlates[self] = self.baseFrame -- this will trigger the fadein 

	self.currentAlpha = 0
	self:SetAlpha(0)
	self:UpdateTargetData()
	self:UpdateAlpha()
	self:UpdateFrameLevel()

	if self.targetAlpha > 0 then
		if self.baseFrame:IsShown() then 
			self:Show() 
		end
	end
	
	-- Force an update to catch alpha changes when our target moves back into sight
	FORCEUPDATE = true 

	-- Update the frame levels of the visible plates
	--UPDATELEVELS = true

	-- setup player classbars
	-- setup auras
	-- setup raid targets
end

NamePlate_WotLK.OnHide = function(self)
	local info = self.info

	info.level = nil
	info.name = nil
	--info.rawname = nil
	info.isInCombat = nil
	info.isCasting = nil
	info.isClass = nil
	info.isBoss = nil
	info.isElite = nil
	info.isFriendly = nil
	info.isMouseOver = nil
	info.isNeutral = nil
	info.isPlayer = nil
	info.isRare = nil
	info.isShieldedCast = nil
	info.isTapped = nil
	info.isTarget = nil
	info.isTrivial = nil
	info.unitThreatSituation = nil
	info.healthMax = 0
	info.health = 0

	self.Cast:Hide()
	self.Cast.Shadow:Hide()
	self.Auras:Hide()

	self.visiblePlates[self] = false -- this will trigger the fadeout and hiding

	-- Force an update to catch alpha changes when our target moves out of sight
	FORCEUPDATE = true 

	-- Update the frame levels of the still visible plates
	--UPDATELEVELS = true
end


NamePlate_WotLK.HandleBaseFrame = function(self, baseFrame)
	local old = {
		baseFrame = baseFrame,
		bars = {},
		regions = {} 
	}

	old.bars.health, 
	old.bars.cast = baseFrame:GetChildren()
	
	old.regions.threat, 
	old.regions.healthborder, 
	old.regions.castshield, 
	old.regions.castborder, 
	old.regions.casticon, 
	old.regions.highlight, 
	old.regions.name, 
	old.regions.level, 
	old.regions.bossicon, 
	old.regions.raidicon, 
	old.regions.eliteicon = baseFrame:GetRegions()
	
	old.bars.health:SetStatusBarTexture(EMPTY_TEXTURE)
	old.bars.health:Hide()
	old.bars.cast:SetStatusBarTexture(EMPTY_TEXTURE)
	old.bars.cast:Hide()
	old.regions.name:Hide()
	old.regions.threat:SetTexture(nil)
	old.regions.healthborder:Hide()
	old.regions.highlight:SetTexture(nil)

	old.regions.level:SetWidth(.0001)
	old.regions.level:Hide()
	old.regions.bossicon:SetTexture(nil)
	old.regions.raidicon:SetAlpha(0)
	-- old.regions.eliteicon:SetTexture(nil)
	UIHider[old.regions.eliteicon] = old.regions.eliteicon:GetParent()
	old.regions.eliteicon:SetParent(UIHider)
	old.regions.castborder:SetTexture(nil)
	old.regions.castshield:SetTexture(nil)
	old.regions.casticon:SetTexCoord(0, 0, 0, 0)
	old.regions.casticon:SetWidth(.0001)
	
	self.baseFrame = baseFrame
	self.old = old

	return old
end

NamePlate_WotLK.HookScripts = function(self, baseFrame)
	baseFrame:HookScript("OnShow", function(baseFrame) self:OnShow() end)
	baseFrame:HookScript("OnHide", function(baseFrame) self:OnHide() end)

	self.old.bars.health:HookScript("OnValueChanged", function() self:UpdateHealth() end)
	self.old.bars.health:HookScript("OnMinMaxChanged", function() self:UpdateHealth() end)

	--self.old.bars.cast:HookScript("OnShow", OldCastBar.OnShowCast)
	--self.old.bars.cast:HookScript("OnHide", OldCastBar.OnHideCast)
	--self.old.bars.cast:HookScript("OnValueChanged", OldCastBar.OnUpdateCast)
end



-- Legion Plates
----------------------------------------------------------
NamePlate_Legion.UpdateTargetData = function(self)
	--self.info.isTarget = UnitExists("target") and UnitIsUnit("player", "target")
	--self.info.isMouseOver = UnitIsUnit("mouseover", self.unit)
end

NamePlate_Legion.UpdateAlpha = function(self)
	local unit = self.unit
	if not UnitExists(unit) then
		return
	end
	if self.visiblePlates[self] then
		if UnitExists("target") then
			if UnitIsUnit(unit, "target") then
				self.targetAlpha = 1 -- current target, keep alpha at max
			elseif UnitIsTrivial(unit) then 
				self.targetAlpha = .15 -- keep the trivial frames transparent
			else
				self.targetAlpha = .35 -- non-targets while you have an actual target
			end
		else
			if UnitIsTrivial(unit) then 
				self.targetAlpha = .25 -- keep trivial frames more transparent
			else
				self.targetAlpha = .85 -- no target selected
			end
		end
	else
		self.targetAlpha = 0 -- fade out hidden frames
	end
end

NamePlate_Legion.UpdateFrameLevel = function(self)
	local unit = self.unit
	if not UnitExists(unit) then
		return
	end
	if self.visiblePlates[self] then
		local healthValue = self.Health.Value
		if UnitIsUnit(unit, "target") then
			if self:GetFrameLevel() ~= FRAMELEVEL_TARGET then
				self:SetFrameLevel(FRAMELEVEL_TARGET)
			end
			if not healthValue:IsShown() then
				healthValue:Show()
			end
			healthValue:Show()
		else
		if self:GetFrameLevel() ~= self.frameLevel then
			self:SetFrameLevel(self.frameLevel)
		end
		if healthValue:IsShown() then
			healthValue:Hide()
		end
		end
	end
end

NamePlate_Legion.UpdateHealth = function(self)
	local unit = self.unit
	if not UnitExists(unit) then
		return
	end
	
	local health = UnitHealth(unit)
	local healthMax = UnitHealthMax(unit)
	
	self.Health:SetMinMaxValues(0, healthMax)
	self.Health:SetValue(health)
	self.Health.Value:SetFormattedText("( %s / %s )", abbreviateNumber(health), abbreviateNumber(healthMax))
end

NamePlate_Legion.UpdateName = function(self)
	local unit = self.unit
	if not UnitExists(unit) then
		return
	end
end

NamePlate_Legion.UpdateLevel = function(self)
	local unit = self.unit
	if not UnitExists(unit) then
		return
	end

	local levelstring
	local level = UnitLevel(unit)
	local classificiation = UnitClassification(unit)

	if classificiation == "worldboss" or (level and level < 1) then
		self.BossIcon:Show()
	else
		if level and level > 0 then
			if UnitIsFriend("player", unit) then
				levelstring = C.General.OffWhite.colorCode .. level .. "|r"
			else
				levelstring = (getDifficultyColorByLevel(level)) .. level .. "|r"
			end
			if classificiation == "elite" or classificiation == "rareelite" then
				levelstring = levelstring .. C.Reaction[UnitReaction(unit, "player")].colorCode .. "+|r"
			end
			if classificiation == "rareelite" or classificiation == "rare" then
				levelstring = levelstring .. C.General.DimRed.colorCode .. " (rare)|r"
			end
		end
		self.Level:SetText(levelstring)
		self.BossIcon:Hide()
	end
end

NamePlate_Legion.UpdateColor = function(self)
	local unit = self.unit
	if not UnitExists(unit) then
		return
	end

	local classificiation = UnitClassification(unit)
	local isplayer = UnitIsPlayer(unit)
	local isfriend = UnitIsFriend("player", unit)
	local isenemy = UnitIsEnemy("player", unit)
	local isneutral = UnitReaction(unit, "player") == 4
	local istapped = UnitIsTapDenied(unit)
	local _, class = UnitClass(unit)

	if isplayer then
		if isfriend then
		local color = C.Reaction.civilian
			r, g, b = color[1], color[2], color[3]
		else
			if class and C.Class[class] then
				local color = C.Class[class]
				r, g, b = color[1], color[2], color[3]
			else
				local color = C.Reaction[1]
				r, g, b = color[1], color[2], color[3]
			end
		end
	else
		if isfriend then
			local color = C.Reaction[5]
			r, g, b = color[1], color[2], color[3]
		elseif istapped then
			local color = C.Status.Tapped
			r, g, b = color[1], color[2], color[3]
		elseif isneutral then
			local color = C.Reaction[4]
			r, g, b = color[1], color[2], color[3]
		else
			local color = C.Reaction[2]
			r, g, b = color[1], color[2], color[3]
		end
	end

	self.Health:SetStatusBarColor(r, g, b)	
end

NamePlate_Legion.UpdateThreat = function(self)
	local unit = self.unit
	if not UnitExists(unit) then
		return
	end
	local threat = UnitThreatSituation("player", unit)
	if threat and threat > 0 then
		local color = C.Threat[threat]
		local r, g, b = color[1], color[2], color[3]
		local health = self.Health
		health.Glow:SetVertexColor(r, g, b, 1)
		health.Shadow:SetVertexColor(r, g, b)
	else
		local health = self.Health
		health.Glow:SetVertexColor(0, 0, 0, .25)
		health.Shadow:SetVertexColor(0, 0, 0, 1)
	end
end

NamePlate_Legion.UpdateCast = function(self)
end

NamePlate_Legion.UpdateAuras = function(self)
end

NamePlate_Legion.UpdateRaidTarget = function(self)
	local unit = self.unit
	if not UnitExists(unit) then
		self.RaidIcon:Hide()
		return
	end
	
	local classificiation = UnitClassification(unit)
	local istrivial = UnitIsTrivial(unit) or classificiation == "trivial" or classificiation == "minus"
	if istrivial then
		self.RaidIcon:Hide()
		return
	end
	
	local index = GetRaidTargetIndex(unit)
	if index then
		SetRaidTargetIconTexture(self.RaidIcon, index)
		self.RaidIcon:Show()
	else
		self.RaidIcon:Hide()
	end
end

NamePlate_Legion.UpdateFaction = function(self)
	self:UpdateName()
	self:UpdateLevel()
	self:UpdateColor()
	self:UpdateThreat()
end

NamePlate_Legion.UpdateAll = function(self)
	self:UpdateAlpha()
	self:UpdateFrameLevel()
	self:UpdateHealth()
	self:UpdateName()
	self:UpdateLevel()
	self:UpdateColor()
	self:UpdateThreat()
	self:UpdateRaidTarget()
	self:UpdateCast()
	self:UpdateAuras()
end

NamePlate_Legion.IsTarget = function(self)
	local unit = self.unit
	return UnitExists(unit) and UnitIsUnit(unit, "target")
end

NamePlate_Legion.IsTrivial = function(self)
	local unit = self.unit
	return UnitExists(unit) and UnitIsTrivial(unit)
end

NamePlate_Legion.OnShow = function(self)
	local unit = self.unit
	if not UnitExists(unit) then
		return
	end

	-- setup player classbars
	-- setup auras
	-- setup raid targets

	self.Health:Show()
	self.Auras:Hide()
	self.Cast:Hide()

	self:SetAlpha(0) -- set the actual alpha to 0
	self.currentAlpha = 0 -- update stored alpha value
	self:UpdateAll() -- update all elements while it's still transparent
	self:Show() -- make the fully transparent frame visible

	self.visiblePlates[self] = self.baseFrame -- this will trigger the fadein 

	self:UpdateFrameLevel() -- must be called after the plate has been added to VisiblePlates

	-- Update the frame levels of all the visible plates
	UPDATELEVELS = true	
end

NamePlate_Legion.OnHide = function(self)
	self.visiblePlates[self] = false -- this will trigger the fadeout and hiding

	-- Update the frame levels of the remaining visible plates
	UPDATELEVELS = true	
end

NamePlate_Legion.HandleBaseFrame = function(self, baseFrame)
	local unitframe = baseFrame.UnitFrame
	if unitframe then
		unitframe:Hide()
		unitframe:HookScript("OnShow", function(self) self:Hide() end)
	end
	self.baseFrame = baseFrame
end

NamePlate_Legion.HookScripts = function(self, baseFrame)
	baseFrame:HookScript("OnHide", function(baseFrame) self:OnHide() end)
end



-- WoD Plates
----------------------------------------------------------
NamePlate_WoD.HookScripts = function(self, baseFrame)
	baseFrame:HookScript("OnShow", function(baseFrame) self:OnShow() end)
	baseFrame:HookScript("OnHide", function(baseFrame) self:OnHide() end)

	self.old.bars.health:HookScript("OnValueChanged", function() self:UpdateHealth() end)
	self.old.bars.health:HookScript("OnMinMaxChanged", function() self:UpdateHealth() end)

	--self.old.bars.cast:HookScript("OnShow", OldCastBar.OnShowCast)
	--self.old.bars.cast:HookScript("OnHide", OldCastBar.OnHideCast)
	--self.old.bars.cast:HookScript("OnValueChanged", OldCastBar.OnUpdateCast)

	-- 6.2.2 absorb bar
	--	self.old.bars.absorb:HookScript("OnShow", OldAbsorbBar.OnShowAbsorb)
	--	self.old.bars.absorb:HookScript("OnHide", OldAbsorbBar.OnHideAbsorb)
	--	self.old.bars.absorb:HookScript("OnValueChanged", OldAbsorbBar.OnUpdateAbsorb)
end

NamePlate_WoD.HandleBaseFrame = function(self, baseFrame)
	local old = {
		baseFrame = baseFrame,
		bars = {}, groups = {}, regions = {} 
	}

	local oldBars = old.bars
	local oldGroups = old.groups
	local oldRegions = old.regions

	oldGroups.bars, 
	oldGroups.name = baseFrame:GetChildren()
	
	local artContainer = baseFrame.ArtContainer

	oldBars.group = oldGroups.bars
	
	-- 6.2.2 healthbar
	oldBars.health = artContainer.HealthBar
	oldBars.health.texture = oldBars.health:GetRegions() 
	
	-- 6.2.2 absorbbar
	oldBars.absorb = artContainer.AbsorbBar
	oldBars.absorb.texture = oldBars.absorb:GetRegions() 
	oldBars.absorb.overlay = oldBars.absorb.Overlay

	-- 6.2.2 castbar
	oldBars.cast = artContainer.CastBar
	oldBars.cast.texture = oldBars.cast:GetRegions() 
	
	oldRegions.castborder = artContainer.CastBarBorder
	oldRegions.castshield = artContainer.CastBarFrameShield
	oldRegions.spellicon = artContainer.CastBarSpellIcon
	oldRegions.spelltext = artContainer.CastBarText
	oldRegions.spellshadow = artContainer.CastBarTextBG
	
	-- 6.2.2 frame
	oldRegions.threat = artContainer.AggroWarningTexture
	oldRegions.healthborder = artContainer.Border
	oldRegions.highlight = artContainer.Highlight
	oldRegions.level = artContainer.LevelText
	oldRegions.bossicon = artContainer.HighLevelIcon
	oldRegions.raidicon = artContainer.RaidTargetIcon
	oldRegions.eliteicon = artContainer.EliteIcon

	-- 6.2.2 name
	oldRegions.name = baseFrame.NameContainer.NameText
		
	-- kill off everything blizzard
	oldBars.health:SetStatusBarTexture(EMPTY_TEXTURE)
	oldBars.health:Hide()
	oldBars.cast:SetStatusBarTexture(EMPTY_TEXTURE)
	oldGroups.name:Hide()
	oldRegions.name:Hide()
	oldRegions.threat:SetTexture(nil)
	oldRegions.healthborder:Hide()
	--oldRegions.highlight:SetTexture(nil)

	oldBars.absorb:SetStatusBarTexture(EMPTY_TEXTURE)

	oldRegions.level:SetWidth(.0001)
	oldRegions.level:Hide()
	oldRegions.bossicon:SetTexture(nil)
	oldRegions.raidicon:SetAlpha(0)
	-- oldRegions.eliteicon:SetTexture(nil)
	UIHider[oldRegions.eliteicon] = oldRegions.eliteicon:GetParent()
	oldRegions.eliteicon:SetParent(UIHider)
	oldRegions.castborder:SetTexture(nil)
	oldRegions.castshield:SetTexture(nil)
	oldRegions.spellicon:SetTexCoord(0, 0, 0, 0)
	oldRegions.spellicon:SetWidth(.0001)
	oldRegions.spellshadow:SetTexture(nil)
	oldRegions.spellshadow:Hide()
	oldRegions.spelltext:Hide()

	-- 6.2.2 absorb bar
	oldBars.absorb.texture:SetTexture(nil)
	oldBars.absorb.texture:Hide()
	oldBars.absorb.overlay:SetTexture(nil)
	oldBars.absorb.overlay:Hide()

	self.baseFrame = baseFrame
	self.old = old

	return old
end



-- MoP Plates
----------------------------------------------------------
NamePlate_MoP.HandleBaseFrame = function(self, baseFrame)
	local old = {
		baseFrame = baseFrame,
		bars = {}, frames = {}, regions = {} 
	}
	
	local oldBars = old.bars
	local oldFrames = old.frames
	local oldRegions = old.regions

	oldFrames.bars, 
	oldFrames.name = baseFrame:GetChildren()

	oldBars.health, 
	oldBars.cast = oldFrames.bars:GetChildren()

	oldRegions.castbar, 
	oldRegions.castborder, 
	oldRegions.castshield, 
	oldRegions.casticon,
	oldRegions.casttext,
	oldRegions.castshadow = oldBars.cast:GetRegions()

	oldRegions.threat, 
	oldRegions.healthborder, 
	oldRegions.highlight, 
	oldRegions.level,  
	oldRegions.bossicon, 
	oldRegions.raidicon, 
	oldRegions.eliteicon = oldFrames.bars:GetRegions()

	oldRegions.name = oldFrames.name:GetRegions()

	oldBars.health:SetStatusBarTexture(EMPTY_TEXTURE)
	oldBars.health:Hide()
	oldBars.cast:SetStatusBarTexture(EMPTY_TEXTURE)
	oldRegions.name:Hide()
	oldRegions.threat:SetTexture(nil)
	oldRegions.healthborder:Hide()
	oldRegions.highlight:SetTexture(nil)

	oldRegions.level:SetWidth(.0001)
	oldRegions.level:Hide()
	oldRegions.bossicon:SetTexture(nil)
	oldRegions.raidicon:SetAlpha(0)
	-- oldRegions.eliteicon:SetTexture(nil)
	UIHider[oldRegions.eliteicon] = oldRegions.eliteicon:GetParent() -- not here?
	oldRegions.eliteicon:SetParent(UIHider)
	oldRegions.castborder:SetTexture(nil)
	oldRegions.castshield:SetTexture(nil)
	oldRegions.casticon:SetTexCoord(0, 0, 0, 0)
	oldRegions.casticon:SetWidth(.0001)
	
	oldRegions.casttext:SetWidth(.0001)
	oldRegions.casttext:Hide()
	oldRegions.castshadow:SetTexture(nil)

	self.baseFrame = baseFrame
	self.old = old

	return old
end



-- Cata Plates
----------------------------------------------------------
NamePlate_Cata.HandleBaseFrame = function(self, baseFrame)
	local old = { 
		baseFrame = baseFrame, 
		bars = {}, regions = {} 
	}

	local oldBars = old.bars
	local oldRegions = old.regions

	oldBars.health, 
	oldBars.cast = baseFrame:GetChildren()

	oldRegions.castbar, -- what is this?
	oldRegions.castborder, 
	oldRegions.castshield, 
	oldRegions.casticon = oldBars.cast:GetRegions()

	oldRegions.threat, 
	oldRegions.healthborder, 
	oldRegions.highlight, 
	oldRegions.name, 
	oldRegions.level, 
	oldRegions.bossicon, 
	oldRegions.raidicon, 
	oldRegions.eliteicon = baseFrame:GetRegions()

	oldBars.health:SetStatusBarTexture(EMPTY_TEXTURE)
	oldBars.health:Hide()
	oldBars.cast:SetStatusBarTexture(EMPTY_TEXTURE)
	oldRegions.name:Hide()
	oldRegions.threat:SetTexture(nil)
	oldRegions.healthborder:Hide()
	oldRegions.highlight:SetTexture(nil)

	oldRegions.level:SetWidth(.0001)
	oldRegions.level:Hide()
	oldRegions.bossicon:SetTexture(nil)
	oldRegions.raidicon:SetAlpha(0)
	-- oldRegions.eliteicon:SetTexture(nil)
	UIHider[oldRegions.eliteicon] = oldRegions.eliteicon:GetParent()
	oldRegions.eliteicon:SetParent(UIHider)
	oldRegions.castborder:SetTexture(nil)
	oldRegions.castshield:SetTexture(nil)
	oldRegions.casticon:SetTexCoord(0, 0, 0, 0)
	oldRegions.casticon:SetWidth(.0001)

	self.baseFrame = baseFrame
	self.old = old

	return old
end



-- General Plates
----------------------------------------------------------
-- Create our custom regions and objects
NamePlate.CreateRegions = function(self)
	local config = self.config
	local widgetConfig = config.widgets
	local textureConfig = config.textures

	-- Health bar
	local Health = self:CreateStatusBar()
	Health:SetSize(unpack(widgetConfig.health.size))
	Health:SetPoint(unpack(widgetConfig.health.place))
	Health:SetStatusBarTexture(textureConfig.bar_texture.path)
	Health:Hide()

	local HealthShade = Health:CreateTexture()

	local HealthShadow = Health:CreateTexture()
	HealthShadow:SetDrawLayer("BACKGROUND")
	HealthShadow:SetSize(unpack(textureConfig.bar_glow.size))
	HealthShadow:SetPoint(unpack(textureConfig.bar_glow.position))
	HealthShadow:SetTexture(textureConfig.bar_glow.path)
	HealthShadow:SetVertexColor(0, 0, 0, 1)
	Health.Shadow = HealthShadow

	local HealthBackdrop = Health:CreateTexture()
	HealthBackdrop:SetDrawLayer("BACKGROUND")
	HealthBackdrop:SetSize(unpack(textureConfig.bar_backdrop.size))
	HealthBackdrop:SetPoint(unpack(textureConfig.bar_backdrop.position))
	HealthBackdrop:SetTexture(textureConfig.bar_backdrop.path)
	HealthBackdrop:SetVertexColor(.15, .15, .15, .85)
	Health.Backdrop = HealthBackdrop
	
	local HealthGlow = Health:CreateTexture()
	HealthGlow:SetDrawLayer("OVERLAY")
	HealthGlow:SetSize(unpack(textureConfig.bar_glow.size))
	HealthGlow:SetPoint(unpack(textureConfig.bar_glow.position))
	HealthGlow:SetTexture(textureConfig.bar_glow.path)
	HealthGlow:SetVertexColor(0, 0, 0, .75)
	Health.Glow = HealthGlow

	local HealthOverlay = Health:CreateTexture()
	HealthOverlay:SetDrawLayer("ARTWORK")
	HealthOverlay:SetSize(unpack(textureConfig.bar_overlay.size))
	HealthOverlay:SetPoint(unpack(textureConfig.bar_overlay.position))
	HealthOverlay:SetTexture(textureConfig.bar_overlay.path)
	HealthOverlay:SetAlpha(.5)
	Health.Overlay = HealthOverlay

	local HealthValue = Health:CreateFontString()
	HealthValue:SetDrawLayer("OVERLAY")
	HealthValue:SetPoint("BOTTOM", Health, "TOP", 0, 6)
	HealthValue:SetFontObject(DiabolicFont_SansBold10)
	HealthValue:SetTextColor(C.General.Prefix[1], C.General.Prefix[2], C.General.Prefix[3])
	Health.Value = HealthValue


	-- Cast bar
	local Cast = self:CreateStatusBar()
	Cast:Hide()
	Cast:SetSize(unpack(widgetConfig.cast.size))
	Cast:SetPoint(unpack(widgetConfig.cast.place))
	Cast:SetStatusBarTexture(textureConfig.bar_texture.path)

	local CastShadow = self:CreateTexture()
	CastShadow:Hide()
	CastShadow:SetDrawLayer("BACKGROUND")
	CastShadow:SetSize(unpack(textureConfig.bar_glow.size))
	CastShadow:SetPoint(unpack(textureConfig.bar_glow.position))
	CastShadow:SetTexture(textureConfig.bar_glow.path)
	CastShadow:SetVertexColor(0, 0, 0, 1)
	Cast.Shadow = CastShadow

	local CastBackdrop = Cast:CreateTexture()
	CastBackdrop:SetDrawLayer("BACKGROUND")
	CastBackdrop:SetSize(unpack(textureConfig.bar_backdrop.size))
	CastBackdrop:SetPoint(unpack(textureConfig.bar_backdrop.position))
	CastBackdrop:SetTexture(textureConfig.bar_backdrop.path)
	CastBackdrop:SetVertexColor(.15, .15, .15, .85)
	Cast.Backdrop = CastBackdrop
	
	local CastGlow = Cast:CreateTexture()
	CastGlow:SetDrawLayer("OVERLAY")
	CastGlow:SetSize(unpack(textureConfig.bar_glow.size))
	CastGlow:SetPoint(unpack(textureConfig.bar_glow.position))
	CastGlow:SetTexture(textureConfig.bar_glow.path)
	CastGlow:SetVertexColor(0, 0, 0, .75)
	Cast.Glow = CastGlow

	local CastOverlay = Cast:CreateTexture()
	CastOverlay:SetDrawLayer("ARTWORK")
	CastOverlay:SetSize(unpack(textureConfig.bar_overlay.size))
	CastOverlay:SetPoint(unpack(textureConfig.bar_overlay.position))
	CastOverlay:SetTexture(textureConfig.bar_overlay.path)
	CastOverlay:SetAlpha(.5)
	Cast.Overlay = CastOverlay

	local CastValue = Cast:CreateFontString()
	CastValue:SetDrawLayer("OVERLAY")
	CastValue:SetPoint("BOTTOM", Cast, "TOP", 0, 6)
	CastValue:SetFontObject(DiabolicFont_SansBold10)
	CastValue:SetTextColor(C.General.Prefix[1], C.General.Prefix[2], C.General.Prefix[3])
	CastValue:Hide()
	Cast.Value = CastValue
	
	-- Cast Name
	local Spell = Cast:CreateFrame()
	SpellName = Spell:CreateFontString()
	SpellName:SetFontObject(DiabolicFont_SansBold12)
	SpellName:SetShadowOffset(.75, -.75)
	SpellName:SetShadowColor(0, 0, 0, 1)
	SpellName:SetTextColor(1, 1, 1)
	Spell.Name = SpellName

	-- Cast Icon
	SpellIcon = Spell:CreateTexture()
	Spell.Icon = SpellIcon

	SpellIconBorder = Spell:CreateTexture()
	Spell.Icon.Border = SpellIconBorder

	SpellIconShield = Spell:CreateTexture()
	Spell.Icon.Shield = SpellIconShield

	SpellIconShade = Spell:CreateTexture()
	Spell.Icon.Shade = SpellIconShade


	-- Mouse hover highlight
	local Highlight = Health:CreateTexture()
	Highlight:Hide()
	Highlight:SetAllPoints()
	Highlight:SetBlendMode("ADD")
	Highlight:SetColorTexture(1, 1, 1, 1/4)
	Highlight:SetDrawLayer("BACKGROUND", 1) 

	-- Unit Name (not actually used)
	--local Name = self:CreateFontString()
	--Name:SetDrawLayer("OVERLAY")
	--Name:SetFontObject(DiabolicFont_HeaderBold12)
	--Name:SetTextColor(unpack(C.General.OffWhite))
	--Name:SetPoint("BOTTOM", Health, "TOP", 0, 6)

	-- Unit Level
	local Level = Health:CreateFontString()
	Level:SetDrawLayer("OVERLAY")
	Level:SetFontObject(DiabolicFont_SansBold10)
	Level:SetTextColor(C.General.OffWhite[1], C.General.OffWhite[2], C.General.OffWhite[3])
	Level:SetJustifyV("TOP")
	Level:SetHeight(10)
	Level:SetPoint("TOPLEFT", Health, "TOPRIGHT", 4, -(Health:GetHeight() - Level:GetHeight())/2)


	-- Icons
	local EliteIcon = Health:CreateTexture()
	EliteIcon:Hide()

	local RaidIcon = Health:CreateTexture()
	RaidIcon:Hide()

	local BossIcon = Health:CreateTexture()
	BossIcon:SetSize(18, 18)
	BossIcon:SetTexture(BOSS_TEXTURE)
	BossIcon:SetPoint("TOPLEFT", self.Health, "TOPRIGHT", 2, 2)
	BossIcon:Hide()

	-- Auras
	local Auras = self:CreateFrame()
	Auras:Hide() 
	Auras:SetAllPoints()

	-- Combat Feedback
	--[[
	self.CombatFeedback = self.Health:CreateFrame()
	self.CombatFeedback:SetSize(self.Health:GetSize())
	for i = 1, 6 do
		self.CombatFeedback[i] = self.CombatFeedback:CreateFontString()
		self.CombatFeedback[i]:SetDrawLayer("OVERLAY")
		self.CombatFeedback[i]:SetFontObject(DiabolicFont_SansBold12)

	end
	]]

	self.Health = Health
	self.Cast = Cast
	self.Auras = Auras
	self.Highlight = Highlight
	self.Level = Level
	self.EliteIcon = EliteIcon
	self.RaidIcon = RaidIcon
	self.BossIcon = BossIcon
	self.Auras = Auras

end

-- Create the sizer frame that handles nameplate positioning
-- *Blizzard changed nameplate format and also anchoring points in Legion,
--  so naturally we're using a different function for this too. Speed!
NamePlate_Legion.CreateSizer = function(self, baseFrame, worldFrame)
	local sizer = self:CreateFrame()
	sizer.plate = self
	sizer.worldFrame = worldFrame
	sizer:SetPoint("BOTTOMLEFT", worldFrame, "BOTTOMLEFT", 0, 0)
	sizer:SetPoint("TOPRIGHT", baseFrame, "CENTER", 0, 0)
	sizer:SetScript("OnSizeChanged", function(self, width, height)
		local plate = self.plate
		local baseFrame = plate.baseFrame
		plate:Hide()
		plate:SetPoint("TOP", self.worldFrame, "BOTTOMLEFT", width, height)
		plate:Show()
	end)
end

NamePlate.CreateSizer = function(self, baseFrame, worldFrame)
	local sizer = self:CreateFrame()
	sizer.plate = self
	sizer.worldFrame = worldFrame
	sizer:SetPoint("BOTTOMLEFT", worldFrame, "BOTTOMLEFT", 0, 0)
	sizer:SetPoint("TOPRIGHT", baseFrame, "TOP", 0, 0)
	sizer:SetScript("OnSizeChanged", function(self, width, height)
		local plate = self.plate
		local baseFrame = plate.baseFrame
		plate:Hide()
		plate:SetPoint("TOP", self.worldFrame, "BOTTOMLEFT", width, height)
		plate:Show()
	end)
end



-- This is where a name plate is first created, 
-- but it hasn't been assigned a unit (Legion) or shown yet.
Module.CreateNamePlate = function(self, baseFrame, name)
	local config = self.config
	local worldFrame = self.worldFrame
	
	local plate = setmetatable(Engine:CreateFrame("Frame", "Engine" .. (name or baseFrame:GetName()), worldFrame), NamePlate_Current_MT)
	plate.info = not(ENGINE_LEGION) and {} or nil
	plate.config = config
	plate.allPlates = self.allPlates
	plate.visiblePlates = self.visiblePlates
	plate.frameLevel = FRAMELEVEL_CURRENT
	plate.targetAlpha = 0
	plate.currentAlpha = 0

	FRAMELEVEL_CURRENT = FRAMELEVEL_CURRENT + FRAMELEVEL_STEP
	if FRAMELEVEL_CURRENT > FRAMELEVEL_MAX then
		FRAMELEVEL_CURRENT = FRAMELEVEL_MIN
	end

	plate:Hide()
	plate:SetAlpha(0)
	plate:SetFrameLevel(plate.frameLevel)
	plate:SetScale(SCALE)
	plate:SetSize(unpack(config.size))
	plate:HandleBaseFrame(baseFrame) -- hide and reference the baseFrame and original blizzard objects
	plate:CreateRegions() -- create our custom regions and objects
	plate:CreateSizer(baseFrame, worldFrame) -- create the sizer that positions the nameplate
	plate:HookScripts(baseFrame, worldFrame)

	plate.allPlates[baseFrame] = plate

	return plate
end




-- NamePlate Handling
----------------------------------------------------------

-- This is called when Legion plates are shown
Module.OnNamePlateAdded = function(self, unit)
	local plate = self:GetNamePlateForUnit(unit)
	if plate then
		plate.unit = unit
		plate:OnShow(unit)

	end
end

-- This is called when Legion plates are hidden
Module.OnNamePlateRemoved = function(self, unit)
	local plate = self:GetNamePlateForUnit(unit)
	if plate then
		plate.unit = nil
		plate:OnHide()
	end
end

-- Called when the player target has changed (Legion)
Module.OnTargetChanged = function(self)
	self:OnUnitAuraUpdate("target")
end

Module.UpdateNamePlateOptions = function(self)
end

Module.OnUnitAuraUpdate = function(self, unit)
	local plate = self:GetNamePlateForUnit(unit)
end

Module.OnRaidTargetUpdate = function(self)
	for baseFrame, plate in self:GetNamePlates() do
	end
end

Module.OnUnitFactionChanged = function(self, unit)
	local plate = self:GetNamePlateForUnit(unit)
	if plate then
		plate:UpdateFaction()
	end
end

-- Return a nameplate object based on its unit (Legion)
Module.GetNamePlateForUnit = function(self, unit)
	local baseFrame = C_NamePlate.GetNamePlateForUnit(unit)
	if baseFrame then
		return self.allPlates[baseFrame]
	end
end 
	
Module.GetNamePlates = function(self)
	return pairs(self.allPlates)
end

-- Target updates (WotLK - WoD)
Module.UpdateTarget = function(self)
	local name, realm = UnitName("target")
	if name and realm then
		TARGET = name..realm
	elseif name then
		TARGET = name
	else
		TARGET = false
	end
	FORCEUPDATE = "TARGET" -- initiate alpha changes
end

Module.UpdateCombat = function(self)
	COMBAT = UnitAffectingCombat("player")
end

-- Player level updates
Module.UpdateLevel = function(self, event, ...)
	if event == "PLAYER_LEVEL_UP" then
		LEVEL = ...
	else
		LEVEL = UnitLevel("player")
	end
end

Module.UpdateAllScales = function(self)
	--local scale = UIParent:GetEffectiveScale()
	local scale = UICenter:GetEffectiveScale()
	if scale then
		SCALE = scale
	end
	self:ForAllPlates("SetScale", SCALE)
end

-- Couldn't we just schedule a FORCEUPDATE...?
Module.UpdateAllPlates = function(self)
	for baseFrame, plate in self:GetNamePlates() do
		plate:UpdateAll()
	end	
end

-- Apply a nameplate method or separate function to all NamePlates 
Module.ForAllPlates = function(self, methodOrFunction, ...)
	for baseFrame, plate in self:GetNamePlates() do
		if type(methodOrFunction) == "string" then
			plate[methodOrFunction](plate, ...)
		else
			methodOrFunction(plate, ...)
		end 
	end
end



-- NamePlate Event Handling
----------------------------------------------------------
local hasSetBlizzardSettings
Module.OnEvent = ENGINE_LEGION and function(self, event, ...)
	if event == "NAME_PLATE_CREATED" then
		local namePlateFrameBase = ...
		self:CreateNamePlate(namePlateFrameBase)
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		local namePlateUnitToken = ...
		self:OnNamePlateAdded(namePlateUnitToken)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		local namePlateUnitToken = ...
		self:OnNamePlateRemoved(namePlateUnitToken)
	elseif event == "PLAYER_TARGET_CHANGED" then
		self:OnTargetChanged()
	elseif event == "DISPLAY_SIZE_CHANGED" then
		self:UpdateNamePlateOptions()
		self:UpdateAllScales()
	elseif event == "UNIT_AURA" then
		self:OnUnitAuraUpdate(...)
	elseif event == "VARIABLES_LOADED" then
		self:UpdateNamePlateOptions()
	elseif event == "CVAR_UPDATE" then
		local name = ...
		if name == "SHOW_CLASS_COLOR_IN_V_KEY" or name == "SHOW_NAMEPLATE_LOSE_AGGRO_FLASH" then
			self:UpdateNamePlateOptions()
		end
	elseif event == "RAID_TARGET_UPDATE" then
		self:OnRaidTargetUpdate()
	elseif event == "UNIT_FACTION" then
		self:OnUnitFactionChanged(...)
	elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
		self:UpdateAllPlates()
	elseif event == "UI_SCALE_CHANGED" then
		self:UpdateAllScales()
	elseif event == "PLAYER_ENTERING_WORLD" then
		if (not hasSetBlizzardSettings) then
			if _G.C_NamePlate then
				self:UpdateBlizzardSettings()
			else
				self:RegisterEvent("ADDON_LOADED", "OnEvent")
			end
			hasSetBlizzardSettings = true
		end

		self:UpdateAllScales()
		self.Updater:SetScript("OnUpdate", function(_, ...) self:OnUpdate(...) end)
	elseif event == "PLAYER_LEAVING_WORLD" then
		self.Updater:SetScript("OnUpdate", nil)
	elseif event == "ADDON_LOADED" then
		local addon = ...
		if addon == "Blizzard_NamePlates" then
			self:UpdateBlizzardSettings()
			self:UnregisterEvent("ADDON_LOADED")
		end
	end
end
or ENGINE_WOTLK and function(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		if (not hasSetBlizzardSettings) then
			self:UpdateBlizzardSettings()
			hasSetBlizzardSettings = true
		end
		self:UpdateAllScales()
		self.Updater:SetScript("OnUpdate", function(_, ...) self:OnUpdate(...) end)
	elseif event == "PLAYER_LEAVING_WORLD" then
		self.Updater:SetScript("OnUpdate", nil)
	elseif event == "PLAYER_CONTROL_GAINED" then
		self:UpdateAllPlates()
	elseif event == "PLAYER_CONTROL_LOST" then
		self:UpdateAllPlates()
	elseif event == "PLAYER_LEVEL_UP" then
		self:UpdateLevel()
	elseif event == "PLAYER_TARGET_CHANGED" then
		self:UpdateTarget()
	elseif (event == "PLAYER_REGEN_ENABLED") or (event == "PLAYER_REGEN_DISABLED") then
		self:UpdateCombat()
	--elseif event == "RAID_TARGET_UPDATE" then
	--	self:UpdateAllPlates()
	elseif event == "DISPLAY_SIZE_CHANGED" then
		self:UpdateAllScales()
	elseif event == "UI_SCALE_CHANGED" then
		self:UpdateAllScales()
	--elseif event == "UNIT_FACTION" then
	--	self:UpdateAllPlates()
	elseif event == "UNIT_LEVEL" then
		self:UpdateAllPlates()
	elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
		self:UpdateAllPlates()
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		self:UpdateAllPlates()
	end
end



-- NamePlate Update Cycle
----------------------------------------------------------

Module.OnUpdate = function(self, elapsed)
	
	self.elapsed = (self.elapsed or 0) + elapsed
	self.elapsedFading = (self.elapsedFading or 0) + elapsed

	if self.elapsed > HZ then

		-- Scan the WorldFrame for possible NamePlates
		if not ENGINE_LEGION then
			local numChildren = select("#", self.worldFrame:GetChildren())

			-- If the number of children in the WorldFrame 
			--  is different from the number we have stored, 
			-- we parse the children to check for new NamePlates.
			if WORLDFRAME_CHILDREN ~= numChildren then
				-- Localizing even more to reduce the load when entering large scale raids
				local select = select
				local allPlates = self.allPlates
				local allChildren = self.allChildren
				local worldFrame = self.worldFrame
				local isNamePlate = self.IsNamePlate 
				local createNamePlate = self.CreateNamePlate

				for i = 1, numChildren do
					local object = select(i, worldFrame:GetChildren())
					if not(allChildren[object]) then 
						local isPlate = isNamePlate(_, object)
						if isPlate and not(allPlates[object]) then
							-- Update our NamePlate counter
							WORLDFRAME_PLATES = WORLDFRAME_PLATES + 1

							-- Create and show the nameplate
							-- The constructor function returns the plate, 
							-- so we can chain the OnShow method in the same call.
							createNamePlate(self, object, "NamePlate"..WORLDFRAME_PLATES):OnShow()
						elseif not isPlate then
							allChildren[object] = true
						end
					end
				end

				-- Update our WorldFrame subframe counter to the current number of frames
				WORLDFRAME_CHILDREN = numChildren

				-- Debugging the performance drops in AV and Wintergrasp
				-- by printing out number of new plates and comparing it to when the spikes occur.
				-- *verified that nameplate creation is NOT a reason for the spikes. 
				--if WORLDFRAME_PLATES ~= oldNumPlates then
				--	print(("Total plates: %d - New this cycle: %d"):format(WORLDFRAME_PLATES, WORLDFRAME_PLATES - oldNumPlates))
				--end
			end
		end

		-- Update visibility, positions, health values and target alpha
		for plate, baseFrame in pairs(self.visiblePlates) do
			local force = FORCEUPDATE or plate.FORCEUPDATE

			if baseFrame then
				if force then
					if (force == "TARGET") then
						plate:UpdateTargetData()
						plate:UpdateAlpha()
						plate:UpdateFrameLevel()
					else
						plate:UpdateAll()
					end
					plate.FORCEUPDATE = false
				else
					plate:UpdateTargetData()
					plate:UpdateAlpha()
					plate:UpdateHealth()
				end
			end
		end
		FORCEUPDATE = false

		self.elapsed = 0
	end

	if self.elapsedFading > FADE_HZ then
		for plate, baseFrame in pairs(self.visiblePlates) do
			if not baseFrame then
				plate.targetAlpha = 0
			end

			if plate.currentAlpha ~= plate.targetAlpha then
				local difference
				if plate.targetAlpha > plate.currentAlpha then
					difference = plate.targetAlpha - plate.currentAlpha
				else
					difference = plate.currentAlpha - plate.targetAlpha
				end
			
				local step_in = elapsed/(FADE_IN * difference)
				local step_out = elapsed/(FADE_OUT * difference)

				FadingPlates[plate] = true

				if plate.targetAlpha > plate.currentAlpha then
					if plate.targetAlpha > plate.currentAlpha + step_in then
						plate.currentAlpha = plate.currentAlpha + step_in -- fade in
					else
						plate.currentAlpha = plate.targetAlpha -- fading done
						FadingPlates[plate] = false
					end
				elseif plate.targetAlpha < plate.currentAlpha then
					if plate.targetAlpha < plate.currentAlpha - step_out then
						plate.currentAlpha = plate.currentAlpha - step_out -- fade out
					else
						plate.currentAlpha = plate.targetAlpha -- fading done
						FadingPlates[plate] = false
					end
				else
					plate.currentAlpha = plate.targetAlpha -- fading done
					FadingPlates[plate] = false
				end
				plate:SetAlpha(plate.currentAlpha)
			else
				FadingPlates[plate] = false
			end

			if plate.currentAlpha == 0 and plate.targetAlpha == 0 then
				plate.visiblePlates[plate] = nil
				plate:Hide()
			end
		end	
		self.elapsedFading = 0
	end

end



-- NamePlate Parsing (pre Legion)
----------------------------------------------------------
-- Figure out if the given frame is a NamePlate
Module.IsNamePlate = ENGINE_MOP and function(self, baseFrame)
	local name = baseFrame:GetName()
	if name and string_find(name, "^NamePlate%d") then
		local _, name_frame = baseFrame:GetChildren()
		if name_frame then
			local name_region = name_frame:GetRegions()
			return (name_region and (name_region:GetObjectType() == "FontString"))
		end
	end
end
or ENGINE_CATA and function(self, baseFrame)
	local threat_region, border_region = baseFrame:GetRegions()
	return (border_region and (border_region:GetObjectType() == "Texture") and (border_region:GetTexture() == CATA_PLATE))
end
or ENGINE_WOTLK and function(self, baseFrame)
	local region = baseFrame:GetRegions()
	return (region and (region:GetObjectType() == "Texture") and (region:GetTexture() == WOTLK_PLATE))
end

-- Force some blizzard console variables to our liking
Module.UpdateBlizzardSettings = ENGINE_LEGION and Engine:Wrap(function(self)
	local config = self.config
	local setCVar = SetCVar

	-- Insets at the top and bottom of the screen 
	-- which the target nameplate will be kept away from. 
	-- Used to avoid the target plate being overlapped 
	-- by the target frame or actionbars and keep it in view.
	setCVar("nameplateLargeTopInset", .22) -- default .1
	setCVar("nameplateOtherTopInset", .22) -- default .08
	setCVar("nameplateLargeBottomInset", .22) -- default .15
	setCVar("nameplateOtherBottomInset", .22) -- default .1


	setCVar("nameplateClassResourceTopInset", 0)
	setCVar("nameplateGlobalScale", 1)
	setCVar("NamePlateHorizontalScale", 1)
	setCVar("NamePlateVerticalScale", 1)

	-- Scale modifier for large plates, used for important monsters
	setCVar("nameplateLargerScale", 1) -- default 1.2

	-- The maximum distance to show a nameplate at
	setCVar("nameplateMaxDistance", 100)

	-- The minimum scale and alpha of nameplates
	setCVar("nameplateMinScale", 1) -- .5 default .8
	setCVar("nameplateMinAlpha", .3) -- default .5

	-- The minimum distance from the camera plates will reach their minimum scale and alpa
	setCVar("nameplateMinScaleDistance", 30) -- default 10
	setCVar("nameplateMinAlphaDistance", 30) -- default 10

	-- The maximum scale and alpha of nameplates
	setCVar("nameplateMaxScale", 1) -- default 1
	setCVar("nameplateMaxAlpha", 0.85) -- default 0.9
	
	-- The maximum distance from the camera where plates will still have max scale and alpa
	setCVar("nameplateMaxScaleDistance", 10) -- default 10
	setCVar("nameplateMaxAlphaDistance", 10) -- default 10

	-- Show nameplates above heads or at the base (0 or 2)
	setCVar("nameplateOtherAtBase", 0)

	-- Scale and Alpha of the selected nameplate (current target)
	setCVar("nameplateSelectedAlpha", 1) -- default 1
	setCVar("nameplateSelectedScale", 1) -- default 1
	

	-- Setting the base size involves changing the size of secure unit buttons, 
	-- but since we're using our out of combat wrapper, we should be safe.
	local width, height = config.size[1], config.size[2]

	C_NamePlate.SetNamePlateFriendlySize(width, height)
	C_NamePlate.SetNamePlateEnemySize(width, height)

	--NamePlateDriverMixin:SetBaseNamePlateSize(unpack(config.size))

	--[[
		7.1 new methods in C_NamePlate:

		Added:
		SetNamePlateFriendlySize,
		GetNamePlateFriendlySize,
		SetNamePlateEnemySize,
		GetNamePlateEnemySize,
		SetNamePlateSelfClickThrough,
		GetNamePlateSelfClickThrough,
		SetNameplateFriendlyClickThrough,
		GetNameplateFriendlyClickThrough,
		SetNamePlateEnemyClickThrough,
		GetNamePlateEnemyClickThrough

		These functions allow a specific area on the nameplate to be marked as a preferred click area such that if the nameplate position query results in two overlapping nameplates, the nameplate with the position inside its preferred area will be returned:

		SetNamePlateSelfPreferredClickInsets,
		GetNamePlateSelfPreferredClickInsets,
		SetNamePlateFriendlyPreferredClickInsets,
		GetNamePlateFriendlyPreferredClickInsets,
		SetNamePlateEnemyPreferredClickInsets,
		GetNamePlateEnemyPreferredClickInsets,
	]]
end)
or Engine:Wrap(function(self)
	local config = self.config
	local setCVar = SetCVar

	-- These are from which expansion...? /slap myself for not commenting properly!!

	-- we're forcing these from blizzard, but will give custom options through this module
	--setCVar("bloatthreat", 0) -- sale plates based on the gained threat on a mob with multiple threat targets. weird. 
	--setCVar("bloattest", 0) -- weird setting that shrinks plates for values > 0
	--setCVar("bloatnameplates", 0) -- don't change frame size based on threat. it's silly.
	--setCVar("repositionfrequency", 1) -- don't skip frames between updates
	-- setCVar("ShowClassColorInNameplate", 1) -- display class colors -- leave this to the setup tutorial, let the user decide later
	--setCVar("ShowVKeyCastbar", 1) -- display castbars
	--setCVar("showVKeyCastbarSpellName", 1) -- display spell names on castbars
	--setCVar("showVKeyCastbarOnlyOnTarget", 0) -- display castbars only on your current target
end)

Module.OnInit = function(self)
	-- Speeeeed!!
	self.config = self:GetStaticConfig("NamePlates")
	self.worldFrame = WorldFrame
	self.allPlates = AllPlates
	self.allChildren = AllChildren
	self.visiblePlates = VisiblePlates
end

Module.OnEnable = function(self)
	--do return end
	if not self.Updater then
		-- We parent our update frame to the WorldFrame, 
		-- as we need it to run even if the user has hidden the UI.
		self.Updater = CreateFrame("Frame", nil, self.worldFrame)

		-- When parented to the WorldFrame, setting the strata to TOOLTIP 
		-- will cause its updates to run close to last in the update cycle. 
		self.Updater:SetFrameStrata("TOOLTIP") 
	end

	if ENGINE_LEGION then
		-- Detection, showing and hidding
		self:RegisterEvent("NAME_PLATE_CREATED", "OnEvent")
		self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "OnEvent")
		self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", "OnEvent")
		--self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnEvent")

		-- Updates
		self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")
		--self:RegisterEvent("PLAYER_CONTROL_GAINED", "OnEvent")
		--self:RegisterEvent("PLAYER_CONTROL_LOST", "OnEvent")
		--self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		--self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
		self:RegisterEvent("PLAYER_LEVEL_UP", "OnEvent")
		self:RegisterEvent("RAID_TARGET_UPDATE", "OnEvent")
		--self:RegisterEvent("UNIT_AURA", "OnEvent")
		self:RegisterEvent("UNIT_FACTION", "OnEvent")
		self:RegisterEvent("UNIT_LEVEL", "OnEvent")
		self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", "OnEvent")

		self:RegisterEvent("CVAR_UPDATE", "OnEvent")
		self:RegisterEvent("VARIABLES_LOADED", "OnEvent")
		
		-- NamePlate Update Cycles
		--self:RegisterEvent("PLAYER_LEAVING_WORLD", "OnEvent")
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")

		-- Scale Changes
		self:RegisterEvent("DISPLAY_SIZE_CHANGED", "OnEvent")
		self:RegisterEvent("UI_SCALE_CHANGED", "OnEvent")
		
	elseif ENGINE_WOTLK then
		self:UpdateBlizzardSettings()

		-- Update
		self:RegisterEvent("PLAYER_CONTROL_GAINED", "OnEvent")
		self:RegisterEvent("PLAYER_CONTROL_LOST", "OnEvent")
		self:RegisterEvent("PLAYER_LEVEL_UP", "OnEvent")
		self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent") 
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
		self:RegisterEvent("RAID_TARGET_UPDATE", "OnEvent")
		--self:RegisterEvent("UNIT_FACTION", "OnEvent")
		self:RegisterEvent("UNIT_LEVEL", "OnEvent")
		--self:RegisterEvent("UNIT_TARGET", "OnEvent")
		self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", "OnEvent")
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnEvent")
	
		-- NamePlate Update Cycles
		self:RegisterEvent("PLAYER_LEAVING_WORLD", "OnEvent")
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")

		-- Scale Changes
		self:RegisterEvent("DISPLAY_SIZE_CHANGED", "OnEvent")
		self:RegisterEvent("UI_SCALE_CHANGED", "OnEvent")
	end

end
