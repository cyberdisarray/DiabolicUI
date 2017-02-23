local _, Engine = ...

-- This module needs a HIGH priority, 
-- as other modules rely on it for positioning. 
local Module = Engine:NewModule("Minimap", "HIGH")
local BlizzardUI = Engine:GetHandler("BlizzardUI")
local C = Engine:GetStaticConfig("Data: Colors")
local F = Engine:GetStaticConfig("Data: Functions")
local L = Engine:GetLocale()


-- Lua API
local _G = _G
local date = date
local math_sqrt = math.sqrt
local select = select
local string_format = string.format
local table_insert = table.insert
local table_wipe = table.wipe
local unpack = unpack

-- WoW API
local GetCursorPosition = _G.GetCursorPosition
local GetDifficultyInfo = _G.GetDifficultyInfo
local GetGameTime = _G.GetGameTime
local GetInstanceInfo = _G.GetInstanceInfo
local GetMinimapZoneText = _G.GetMinimapZoneText
local GetPlayerMapPosition = _G.GetPlayerMapPosition
local GetSubZoneText = _G.GetSubZoneText
local GetZonePVPInfo = _G.GetZonePVPInfo
local GetZoneText = _G.GetZoneText
local IsInInstance = _G.IsInInstance
local RegisterStateDriver = _G.RegisterStateDriver
local SetMapToCurrentZone = _G.SetMapToCurrentZone
local ToggleDropDownMenu = _G.ToggleDropDownMenu


-- WoW frames and objects referenced frequently
------------------------------------------------------------------
local GameTooltip = _G.GameTooltip
local Minimap = _G.Minimap
local MinimapBackdrop = _G.MinimapBackdrop
local MinimapCluster = _G.MinimapCluster
local MinimapZoomIn = _G.MinimapZoomIn
local MinimapZoomOut = _G.MinimapZoomOut


-- WoW strings
------------------------------------------------------------------
-- Garrison
local GARRISON_ALERT_CONTEXT_BUILDING = _G.GARRISON_ALERT_CONTEXT_BUILDING
local GARRISON_ALERT_CONTEXT_INVASION = _G.GARRISON_ALERT_CONTEXT_INVASION
local GARRISON_ALERT_CONTEXT_MISSION = _G.GARRISON_ALERT_CONTEXT_MISSION
local GARRISON_LANDING_PAGE_TITLE = _G.GARRISON_LANDING_PAGE_TITLE
local MINIMAP_GARRISON_LANDING_PAGE_TOOLTIP = _G.MINIMAP_GARRISON_LANDING_PAGE_TOOLTIP

-- Zonetext
local DUNGEON_DIFFICULTY1 = _G.DUNGEON_DIFFICULTY1
local DUNGEON_DIFFICULTY2 = _G.DUNGEON_DIFFICULTY2
local SANCTUARY_TERRITORY = _G.SANCTUARY_TERRITORY
local FREE_FOR_ALL_TERRITORY = _G.FREE_FOR_ALL_TERRITORY
local FACTION_CONTROLLED_TERRITORY = _G.FACTION_CONTROLLED_TERRITORY
local CONTESTED_TERRITORY = _G.CONTESTED_TERRITORY
local COMBAT_ZONE = _G.COMBAT_ZONE

-- Time
local TIMEMANAGER_AM = _G.TIMEMANAGER_AM
local TIMEMANAGER_PM = _G.TIMEMANAGER_PM
local TIMEMANAGER_TITLE = _G.TIMEMANAGER_TITLE
local TIMEMANAGER_TOOLTIP_LOCALTIME = _G.TIMEMANAGER_TOOLTIP_LOCALTIME
local TIMEMANAGER_TOOLTIP_REALMTIME = _G.TIMEMANAGER_TOOLTIP_REALMTIME

-- Difficulty and group sizes
local SOLO = SOLO
local GROUP = GROUP

-- Speed constants, because we can never get enough
------------------------------------------------------------------
local WOD 	= Engine:IsBuild("WoD")
local MOP 	= Engine:IsBuild("MoP")
local CATA 	= Engine:IsBuild("Cata")



-- Map functions
------------------------------------------------------------------
local onMouseWheel = function(self, delta)
	if delta > 0 then
		MinimapZoomIn:Click()
		-- self:SetZoom(min(self:GetZoomLevels(), self:GetZoom() + 1))
	elseif delta < 0 then
		MinimapZoomOut:Click()
		-- self:SetZoom(max(0, self:GetZoom() - 1))
	end
end
	
local onMouseUp = function(self, button)
	if button == "RightButton" then
		ToggleDropDownMenu(1, nil,  _G.MiniMapTrackingDropDown, self)
	else
		local x, y = GetCursorPosition()
		x = x / self:GetEffectiveScale()
		y = y / self:GetEffectiveScale()
		local cx, cy = self:GetCenter()
		x = x - cx
		y = y - cy
		if math_sqrt(x * x + y * y) < (self:GetWidth() / 2) then
			self:PingLocation(x, y)
		end
	end
end

local onUpdate = function(self, elapsed)
	self.elapsedTime = (self.elapsedTime or 0) + elapsed
	if self.elapsedTime > 1 then 

		local db = self.db
		local time = self.widgets.time
		local h, m

		if db.useGameTime then
			h, m = GetGameTime()
		else
			local dateTable = date("*t")
			h = dateTable.hour
			m = dateTable.min 
		end

		if db.use24hrClock then
			time:SetFormattedText("%02d:%02d", h, m)
		else
			if h > 12 then 
				time:SetFormattedText("%d:%02d%s", h - 12, m, TIMEMANAGER_PM)
			elseif h < 1 then
				time:SetFormattedText("%d:%02d%s", h + 12, m, TIMEMANAGER_AM)
			else
				time:SetFormattedText("%d:%02d%s", h, m, TIMEMANAGER_AM)
			end
		end

		self.elapsedTime = 0
	end

	self.elapsedCoords = (self.elapsedCoords or 0) + elapsed
	if self.elapsedCoords > .1 then 

		local coordinates = self.widgets.coordinates
		local x, y = GetPlayerMapPosition("player")

		if ((x == 0) and (y == 0)) or (not x) or (not y) then
			coordinates:SetAlpha(0)
		else
			coordinates:SetAlpha(1)
			coordinates:SetFormattedText("%.1f %.1f", x*100, y*100) -- "%02d, %02d" "%.2f %.2f"
		end
		
		self.elapsedCoords = 0
	end
end



-- Garrison functions
------------------------------------------------------------------
local Garrison_OnEnter = function(self)
	if not self.highlight:IsShown() then
		self.highlight:SetAlpha(0)
		self.highlight:Show()
	end
	self.highlight:StartFadeIn(self.highlight.fadeInDuration)
	GameTooltip:SetOwner(self, "ANCHOR_PRESERVE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOPRIGHT", self, "BOTTOMLEFT", -1, -1)
	GameTooltip:SetText(GARRISON_LANDING_PAGE_TITLE, 1, 1, 1)
	GameTooltip:AddLine(MINIMAP_GARRISON_LANDING_PAGE_TOOLTIP, nil, nil, nil, true)
	GameTooltip:Show()
end

local Garrison_OnLeave = function(self)
	if self.highlight:IsShown() then
		self.highlight:StartFadeOut()
	end
	GameTooltip:Hide()
end

local Garrison_OnClick = function(self, ...)
	if GarrisonLandingPageMinimapButton then
		-- A simple hack to let blizzard handle the click functionality of this one. 
		GarrisonLandingPageMinimapButton:GetScript("OnClick")(GarrisonLandingPageMinimapButton, "LeftButton")
	end
end

local Garrison_ShowPulse = function(self, redAlert)
	if redAlert then
		if self.garrison.icon.glow:IsShown() then
			self.garrison.icon.glow:Hide()
		end
		if not self.garrison.icon.redglow:IsShown() then
			self.garrison.icon.redglow:Show()
		end
	else
		if self.garrison.icon.redglow:IsShown() then
			self.garrison.icon.redglow:Hide()
		end
		if not self.garrison.icon.glow:IsShown() then
			self.garrison.icon.glow:Show()
		end
	end
	if not self.garrison.glow:IsShown() then
		self.garrison.glow:SetAlpha(0)
		self.garrison.glow:Show()
	end
	-- self.garrison.glow:StartFadeIn(.5)
	self.garrison.glow:StartFlash(2.5, 1.5, 0, 1, false)
end

local Garrison_HidePulse = function(self, ...)
	if self.garrison.glow:IsShown() then
		self.garrison.glow:StopFlash()
		self.garrison.glow:StartFadeOut()
	end
end



Module.UpdateZoneData = function(self)
	
	SetMapToCurrentZone() -- required for coordinates to function too

	local minimapZoneName = GetMinimapZoneText()
	local pvpType, isSubZonePvP, factionName = GetZonePVPInfo()
	local zoneName = GetZoneText()
	local subzoneName = GetSubZoneText()
	local instance = IsInInstance()

	if subzoneName == zoneName then 
		subzoneName = "" 
	end

	-- This won't be available directly at first login
	local territory
	if pvpType == "sanctuary" then
		territory = SANCTUARY_TERRITORY
	elseif pvpType == "arena" then
		territory = FREE_FOR_ALL_TERRITORY
	elseif pvpType == "friendly" then
		territory = format(FACTION_CONTROLLED_TERRITORY, factionName)
	elseif pvpType == "hostile" then
		territory = format(FACTION_CONTROLLED_TERRITORY, factionName)
	elseif pvpType == "contested" then
		territory = CONTESTED_TERRITORY
	elseif pvpType == "combat" then
		territory = COMBAT_ZONE
	end


	if instance then
		-- instanceType: 
		-- 	"none" if the player is not in an instance
		-- 	"scenario" for scenarios
		-- 	"party" for dungeons, 
		-- 	"raid" for raids
		-- 	"arena" for arenas
		-- 	"pvp" for battlegrounds
		--
		-- difficultyID:
		-- 	1	"Normal" (Dungeons)
		-- 	2	"Heroic" (Dungeons)
		-- 	3	"10 Player"
		-- 	4	"25 Player"
		-- 	5	"10 Player (Heroic)"
		-- 	6	"25 Player (Heroic)"
		-- 	7	"Looking For Raid" (Legacy LFRs; everything prior to Siege of Orgrimmar)
		-- 	8	"Challenge Mode"
		-- 	9	"40 Player"
		-- 	10	nil
		-- 	11	"Heroic Scenario"
		-- 	12	"Normal Scenario"
		-- 	13	nil
		-- 	14	"Normal" (Raids)
		-- 	15	"Heroic" (Raids)
		-- 	16	"Mythic" (Raids)
		-- 	17	"Looking For Raid"
		-- 	18	"Event"
		-- 	19	"Event"
		-- 	20	"Event Scenario"
		-- 	21	nil
		-- 	22	nil
		-- 	23	"Mythic" (Dungeons)
		-- 	24	"Timewalker"
		-- 	25	"PvP Scenario" -- added in Legion

		-- MoP changes:
		-- 	- Now returns an instanceGroupSize. Also added a new possible difficultyID (14) for Flexible Raids.
		-- 	- Now returns a mapID, allowing addons to identify the current instance/continent without relying on localized names.
		-- 	- dynamicDifficulty now always returns 0, while difficultyID is updated to reflect the selected dynamic difficulty (previously, dynamicDifficulty reflected the normal/heroic switch and difficultyID the 10/25 player switch for dynamic instances).
		
		local _
		local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapID, instanceGroupSize
		local groupType, isHeroic, isChallengeMode, toggleDifficultyID

		if MOP then
			name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapID, instanceGroupSize = GetInstanceInfo()
			_, groupType, isHeroic, isChallengeMode, toggleDifficultyID = GetDifficultyInfo(difficultyID)
		else
			name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic = GetInstanceInfo()
		end
		
		local maxMembers, instanceDescription
		if instanceType == "party" then
			if difficultyID == 2 then 
				instanceDescription = DUNGEON_DIFFICULTY2
			else
				instanceDescription = DUNGEON_DIFFICULTY1
			end
			maxMembers = 5
		elseif instanceType == "raid" then
			-- 10 player raids
			if difficultyID == 3 then 
				instanceDescription = RAID_DIFFICULTY1
				maxMembers = 10

			-- 25 player raids
			elseif difficultyID == 4 then 
				instanceDescription = RAID_DIFFICULTY2
				maxMembers = 25

			-- 10 player heoric
			elseif difficultyID == 5 then 
				instanceDescription = RAID_DIFFICULTY3
				maxMembers = 10

			-- 25 player heroic
			elseif difficultyID == 6 then 
				instanceDescription = RAID_DIFFICULTY4
				maxMembers = 25

			-- Legacy LFR (prior to Siege of Orgrimmar)
			elseif difficultyID == 7 then 
				instanceDescription = RAID 
				maxMembers = 25
			
			-- 40 player raids
			elseif difficultyID == 9 then 
				instanceDescription = RAID_DIFFICULTY_40PLAYER
				maxMembers = 40
			
			-- normal raid (WoD)
			elseif difficultyID == 14 then 

			-- heroic raid (WoD)
			elseif difficultyID == 15 then 

			-- mythic raid  (WoD)
			elseif difficultyID == 16 then 

			-- LFR 
			elseif difficultyID == 17 then 
				instanceDescription = RAID 
				maxMembers = 40
			end
		elseif instanceType == "scenario" then
		elseif instanceType == "arena" then
		elseif instanceType == "pvp" then
			instanceDescription = PVP
		else -- "none" -- This shouldn't happen, ever.
		end
		if IsInRaid() or IsInGroup() then
			self.data.difficulty = instanceDescription or difficultyName
			--self.data.difficulty = (instanceDescription or difficultyName) .. " - " .. (IsInGroup() and GetNumGroupMembers() or 1) .. "/" .. ((maxPlayers and maxPlayers > 0) and maxPlayers or maxMembers) 
		else
			local where = instanceDescription or difficultyName
			if where and where ~= "" then
				self.data.difficulty = "(" .. SOLO .. ") " .. where
			else
				-- I'll be surprised if this ever occurs. 
				self.data.difficulty = SOLO
			end
		end
		self.data.instanceName = name or minimapZoneName or ""
	else
		-- make sure it doesn't bug out at login from unavailable data 
		if territory and territory ~= "" then
			if IsInRaid() then
				self.data.difficulty = RAID .. " " .. territory 
			elseif IsInGroup() then
				self.data.difficulty = PARTY .. " " .. territory 
			else 
				self.data.difficulty = SOLO .. " " .. territory 
			end
		else
			if IsInRaid() then
				self.data.difficulty = RAID 
			elseif IsInGroup() then
				self.data.difficulty = PARTY 
			else 
				self.data.difficulty = SOLO
			end
		end
		self.data.instanceName = ""
	end
	
	self.data.minimapZoneName = minimapZoneName or ""
	self.data.zoneName = zoneName or ""
	self.data.subZoneName = subzoneName or ""
	self.data.pvpType = pvpType or ""
	self.data.territory = territory or ""

	self:UpdateZoneText()
end

Module.UpdateZoneText = function(self)
	local config = self.config 
	self.frame.widgets.zone:SetText(self.data.minimapZoneName)
	self.frame.widgets.zone:SetTextColor(unpack(C.General.Highlight))

	--self.frame.widgets.difficulty:SetFormattedText("%s (%s)", self.data.difficulty, self.data.difficultyValue)
	self.frame.widgets.difficulty:SetText(self.data.difficulty .. " ")
end

Module.EnforceRotation = Engine:Wrap(function(self)
	SetCVar("rotateMinimap", 0)
end)

Module.InCompatible = function(self)
	-- If carbonite is loaded, 
	-- and the setting to move the minimap into the carbonite map is enabled, 
	-- we leave the whole minimap to carbonite and just exit our module completely.
	if Engine:IsAddOnEnabled("Carbonite") then
		if NxData.NXGOpts.MapMMOwn then
			return true
		end
	end
end

Module.GetFrame = function(self)
	return self.frame
end

Module.OnEvent = function(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		self:EnforceRotation()
		self:UpdateZoneData()
	elseif event == "ZONE_CHANGED" 
	or event == "ZONE_CHANGED_INDOORS" 
	or event == "ZONE_CHANGED_NEW_AREA" then	
		self:UpdateZoneData()
	elseif event == "VARIABLES_LOADED" then 
		self:EnforceRotation()
	elseif event == "GARRISON_HIDE_LANDING_PAGE" then
		if self.garrison:IsShown() then
			self.garrison:Hide()
		end
	elseif event == "GARRISON_SHOW_LANDING_PAGE" then
		if not self.garrison:IsShown() then
			self.garrison:Show()
		end
		-- kill the pulsing when we open the report, we don't really need to be reminded any longer
		if _G.GarrisonLandingPage and _G.GarrisonLandingPage:IsShown() then
			Garrison_HidePulse(self) 
		end
	elseif event == "GARRISON_BUILDING_ACTIVATABLE" then
		Garrison_ShowPulse(self)
	elseif event == "GARRISON_BUILDING_ACTIVATED" or event == "GARRISON_ARCHITECT_OPENED" then
		Garrison_HidePulse(self, GARRISON_ALERT_CONTEXT_BUILDING)
	elseif event == "GARRISON_MISSION_FINISHED" then
		Garrison_ShowPulse(self)
	elseif  event == "GARRISON_MISSION_NPC_OPENED" then
		Garrison_HidePulse(self, GARRISON_ALERT_CONTEXT_MISSION)
	elseif event == "GARRISON_INVASION_AVAILABLE" then
		Garrison_ShowPulse(self, true)
	elseif event == "GARRISON_INVASION_UNAVAILABLE" then
		Garrison_HidePulse(self, GARRISON_ALERT_CONTEXT_INVASION)
	elseif event == "SHIPMENT_UPDATE" then
		-- local shipmentStarted = ...
		-- if shipmentStarted then
			-- Garrison_ShowPulse(self) -- we don't need to pulse when a work order starts, because WE just started it!!!
		-- end
	end
end

Module.OnInit = function(self)
	if self:InCompatible() then return end

	local config = self:GetStaticConfig("Minimap")
	local db = self:GetConfig("Minimap")
	local data = {
		minimapZoneName = "",
		difficulty = "",
		instanceName = "",
		zoneName = "",
		subZoneName = "",
		pvpType = "", 
		territory = ""
	}

	local old = {}
	local scaffold = {}
	local custom = {}
	local widgets = {}


	local oldBackdrop = MinimapBackdrop
	oldBackdrop:SetMovable(true)
	oldBackdrop:SetUserPlaced(true)
	oldBackdrop:SetParent(map)
	oldBackdrop:ClearAllPoints()
	oldBackdrop:SetPoint("CENTER", -8, -23)

	-- The global function GetMaxUIPanelsWidth() calculates the available space for 
	-- blizzard windows such as the character frame, pvp frame etc based on the 
	-- position of the MinimapCluster. 
	-- Unless the MinimapCluster is set to movable and user placed, it will be assumed
	-- that it's still in its default position, and the end result will be.... bad. 
	-- In this case it caused the blizzard UI to think there was no space at all, 
	-- and all the frames would spawn in the exact same place. 
	-- Setting it to movable and user placed solved it. :)
	local oldCluster = MinimapCluster
	oldCluster:SetMovable(true)
	oldCluster:SetUserPlaced(true)
	oldCluster:ClearAllPoints()
	oldCluster:SetAllPoints(map)
	oldCluster:EnableMouse(false)
	
	-- bottom layer, handles pet battle hiding(?)
	--	self.frame = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
	--	RegisterStateDriver(self.frame, "visibility", "[petbattle] hide; show")
	local frame = Engine:CreateFrame("Frame", nil, "UICenter")
	frame:SetFrameStrata("LOW")
	frame:SetFrameLevel(0)
	frame:SetSize(config.size[1], config.size[2])
	frame:Place(unpack(config.point))

	-- visibility layer to better control the visibility of the minimap
	local visibility = frame:CreateFrame()
	visibility:SetAllPoints()
	visibility:SetFrameStrata("LOW")
	visibility:SetFrameLevel(0)

	-- We could hook these messages directly to the minimap, but for the purpose of semantics 
	-- and easier future compatibility if we decide to make a fully custom minimap, 
	-- we keep them connected to our own visibility layer instead. 
	visibility:HookScript("OnHide", function() self:SendMessage("ENGINE_MINIMAP_VISIBLE_CHANGED", false) end)
	visibility:HookScript("OnShow", function() self:SendMessage("ENGINE_MINIMAP_VISIBLE_CHANGED", true) end)
	
	-- border layer meant to place widgets in
	local border = visibility:CreateFrame()
	border:SetAllPoints()
	border:SetFrameLevel(4)

	-- minimap holder
	local map = visibility:CreateFrame()
	map:SetFrameStrata("LOW") 
	map:SetFrameLevel(2)
	map:SetPoint(unpack(config.map.point))
	map:SetSize(unpack(config.map.size))

	local UIHider = CreateFrame("Frame")
	UIHider:Hide()
	UIHider.Show = UIHider.Hide

	-- Parent the minimap to our dummy, 
	-- and let the user decide minimap visibility 
	-- by hooking our own regions' visibility to it.
	local oldMinimap = Minimap
	oldMinimap:SetParent(frame) 
	oldMinimap:SetFrameLevel(2) 
	oldMinimap:HookScript("OnHide", function() visibility:Hide() end)
	oldMinimap:HookScript("OnShow", function() visibility:Show() end)

	-- In Cata and again in WoD the blob textures turned butt fugly, 
	-- so we change the settings to something far easier on the eye, 
	-- and also a lot easier to navigate with.
	if CATA then
		-- These "alpha" values range from 0 to 255, for some obscure reason,
		-- so a value of 127 would be 127/255 ≃ 0.5ish in the normal API.
		oldMinimap:SetQuestBlobInsideAlpha(0) -- "blue" areas with quest mobs/items in them
		oldMinimap:SetQuestBlobOutsideAlpha(127) -- borders around the "blue" areas 
		oldMinimap:SetQuestBlobRingAlpha(0) -- the big fugly edge ring texture!
		oldMinimap:SetQuestBlobRingScalar(0) -- ring texture inside quest areas?

		oldMinimap:SetArchBlobInsideAlpha(0) -- "blue" areas with quest mobs/items in them
		oldMinimap:SetArchBlobOutsideAlpha(127) -- borders around the "blue" areas 
		oldMinimap:SetArchBlobRingAlpha(0) -- the big fugly edge ring texture!
		oldMinimap:SetArchBlobRingScalar(0) -- ring texture inside quest areas?

		if WOD then
			oldMinimap:SetTaskBlobInsideAlpha(0) -- "blue" areas with quest mobs/items in them
			oldMinimap:SetTaskBlobOutsideAlpha(127) -- borders around the "blue" areas 
			oldMinimap:SetTaskBlobRingAlpha(0) -- the big fugly edge ring texture!
			oldMinimap:SetTaskBlobRingScalar(0) -- ring texture inside quest areas?
		end	
	end

	-- minimap content/real map (size it to the map holder)
	-- *enables mousewheel zoom, and right click tracking menu
	local mapContent = oldMinimap
	mapContent:SetResizable(true)
	mapContent:SetMovable(true)
	mapContent:SetUserPlaced(true)
	mapContent:ClearAllPoints()
	mapContent:SetPoint("CENTER", map, "CENTER", 0, 0)
	mapContent:SetFrameStrata("LOW") 
	mapContent:SetFrameLevel(2)
	mapContent:SetMaskTexture(config.map.mask)
	mapContent:EnableMouseWheel(true)
	mapContent:SetScript("OnMouseWheel", onMouseWheel)
	mapContent:SetScript("OnMouseUp", onMouseUp)

	mapContent:SetSize(map:GetWidth(), map:GetHeight())
	mapContent:SetScale(1)

	-- Register our Minimap as a keyword with the Engine, 
	-- to capture other module's attempt to anchor to it.
	Engine:RegisterKeyword("Minimap", function() return mapContent end)

	-- Add a dark backdrop using the mask texture
	local mapBackdrop = visibility:CreateTexture()
	mapBackdrop:SetDrawLayer("BORDER", 0)
	mapBackdrop:SetPoint("CENTER", map, "CENTER", 0, 0)
	mapBackdrop:SetSize(map:GetWidth(), map:GetHeight())
	mapBackdrop:SetTexture(config.map.mask)
	mapBackdrop:SetVertexColor(0, 0, 0, .75)

	-- Add a dark overlay using the mask texture
	local mapOverlayHolder = visibility:CreateFrame()
	mapOverlayHolder:SetFrameLevel(3)
	--mapOverlayHolder:SetAllPoints()

	--local mapOverlay = mapContent:CreateTexture()
	local mapOverlay = mapOverlayHolder:CreateTexture()
	mapOverlay:SetDrawLayer("BORDER", 0)
	mapOverlay:SetPoint("CENTER", map, "CENTER", 0, 0)
	mapOverlay:SetSize(map:GetWidth(), map:GetHeight())
	mapOverlay:SetTexture(config.map.mask)
	mapOverlay:SetVertexColor(0, 0, 0, .25)

	-- player coordinates
	local playerCoordinates = border:CreateFontString()
	playerCoordinates:SetFontObject(config.text.coordinates.normalFont)
	playerCoordinates:SetTextColor(unpack(C.General.Title))
	playerCoordinates:SetDrawLayer("OVERLAY", 3)
	playerCoordinates:Place(unpack(config.text.coordinates.point))
	playerCoordinates:SetJustifyV("BOTTOM")

	-- Holder frame for widgets that should remain visible 
	-- even when the minimap is hidden.
	local info = Engine:CreateFrame("Frame", nil, "UICenter")
	info:SetFrameStrata("LOW") 
	info:SetFrameLevel(5)

	-- zone name
	local zoneName = info:CreateFontString()
	zoneName:SetFontObject(config.text.zone.normalFont)
	zoneName:SetDrawLayer("ARTWORK", 0)
	zoneName:Place(unpack(config.text.zone.point))
	zoneName:SetJustifyV("BOTTOM")

	-- time
	local time = info:CreateFontString()
	time:SetFontObject(config.text.time.normalFont)
	time:SetDrawLayer("ARTWORK", 0)
	time:SetTextColor(C.General.Title[1], C.General.Title[2], C.General.Title[3])
	time:Place(unpack(config.text.time.point))
	time:SetJustifyV("BOTTOM")

	local timeClick = info:CreateFrame("Button")
	timeClick:SetAllPoints(time)
	timeClick:RegisterForClicks("RightButtonUp", "LeftButtonUp")
	timeClick.UpdateTooltip = function(self)
		local localTime, realmTime

		local dateTable = date("*t")
		local h, m = dateTable.hour,  dateTable.min 
		local gH, gM = GetGameTime()

		if db.use24hrClock then
			localTime = string_format("%02d:%02d", h, m)
			realmTime = string_format("%02d:%02d", gH, gM)
		else
			if (h > 12) then 
				localTime = string_format("%d:%02d%s", h - 12, m, TIMEMANAGER_PM)
			elseif (h < 1) then
				localTime = string_format("%d:%02d%s", h + 12, m, TIMEMANAGER_AM)
			else
				localTime = string_format("%d:%02d%s", h, m, TIMEMANAGER_AM)
			end
			if (gH > 12) then 
				realmTime = string_format("%d:%02d%s", h - 12, m, TIMEMANAGER_PM)
			elseif (gH < 1) then
				realmTime = string_format("%d:%02d%s", h + 12, m, TIMEMANAGER_AM)
			else
				realmTime = string_format("%d:%02d%s", h, m, TIMEMANAGER_AM)
			end
		end

		local r, g, b = unpack(C.General.OffWhite)

		GameTooltip:SetOwner(mapContent, "ANCHOR_PRESERVE")
		GameTooltip:ClearAllPoints()
		GameTooltip:SetPoint("TOPRIGHT", mapContent, "TOPLEFT", -10, -10)
		GameTooltip:AddLine(TIMEMANAGER_TITLE)
		GameTooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_LOCALTIME, localTime, r, g, b)
		GameTooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_REALMTIME, realmTime, r, g, b)
		GameTooltip:AddLine(L["<Left-click> to toggle calendar."], unpack(C.General.OffGreen))
		GameTooltip:Show()
	end

	timeClick:SetScript("OnEnter", timeClick.UpdateTooltip)
	timeClick:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
	timeClick:SetScript("OnClick", function(self, mouseButton)
		if (mouseButton == "LeftButton") then
			ToggleCalendar()
		end
	end)


	-- group and difficulty status
	local zoneDifficulty = info:CreateFontString()
	zoneDifficulty:SetFontObject(config.text.time.normalFont)
	zoneDifficulty:SetDrawLayer("ARTWORK", 0)
	zoneDifficulty:SetTextColor(unpack(C.General.Title))
	zoneDifficulty:SetPoint("BOTTOMRIGHT", time, "BOTTOMLEFT", 0, 0)
	zoneDifficulty:SetJustifyV("BOTTOM")

	if MOP then
		-- MoP Dungeon Finder Eye
		if _G.QueueStatusMinimapButton then
			local groupConfig = config.widgets.group

			local group = _G.QueueStatusMinimapButton 
			group:SetParent(border)
			group:SetFrameLevel(5)
			group:ClearAllPoints()
			group:SetPoint(unpack(groupConfig.point))
			group:SetSize(groupConfig.size[1], groupConfig.size[2])

			local groupText = border:CreateFontString(nil, "OVERLAY")
			groupText:SetParent(group)
			groupText:Place(unpack(groupConfig.fontAnchor))
			groupText:SetFontObject(groupConfig.normalFont)
			groupText:SetTextColor(groupConfig.fontColor[1], groupConfig.fontColor[2], groupConfig.fontColor[3])
			groupText:SetText(LOOKING) 
			groupText:SetJustifyV("BOTTOM")

			-- Need a separate frame for the updater, 
			-- as the icon frame's OnUpdate is reset on mouseover, 
			-- thus cancelling our script as well. 
			local total, dots = 0, 0
			local updater = CreateFrame("Frame", nil, group)
			updater:SetScript("OnUpdate", function(self, elapsed) 
				total = total + elapsed
				if total > 1 then
					dots = dots + 1
					if dots > 3 then 
						dots = 0
					end
					if dots == 0 then
						groupText:SetText(LOOKING) 
					elseif dots == 1 then
						groupText:SetFormattedText("%s.", LOOKING) 
					elseif dots == 2 then
						groupText:SetFormattedText("%s..", LOOKING) 
					elseif dots == 3 then
						groupText:SetFormattedText("%s...", LOOKING) 
					end
					total = 0
				end 
			end)
		end
	end

	if not MOP then
		-- WotLK and Cata Dungeon Finder Eye
		if _G.MiniMapLFGFrame then
			local groupConfig = config.widgets.group

			local group = _G.MiniMapLFGFrame 
			group:SetParent(border)
			group:SetFrameLevel(5)
			group:ClearAllPoints()
			group:SetPoint(unpack(groupConfig.point))
			group:SetSize(groupConfig.size[1], groupConfig.size[2])

			local groupText = border:CreateFontString(nil, "OVERLAY")
			groupText:SetParent(group)
			groupText:Place(unpack(groupConfig.fontAnchor))
			groupText:SetFontObject(groupConfig.normalFont)
			groupText:SetTextColor(groupConfig.fontColor[1], groupConfig.fontColor[2], groupConfig.fontColor[3])
			groupText:SetText(LOOKING) 
			groupText:SetJustifyV("BOTTOM")

			-- Need a separate frame for the updater, 
			-- as the icon frame's OnUpdate is reset on mouseover, 
			-- thus cancelling our script as well. 
			local total, dots = 0, 0
			local updater = CreateFrame("Frame", nil, group)
			updater:SetScript("OnUpdate", function(self, elapsed) 
				total = total + elapsed
				if total > 1 then
					dots = dots + 1
					if dots > 3 then 
						dots = 0
					end
					if dots == 0 then
						groupText:SetText(LOOKING) 
					elseif dots == 1 then
						groupText:SetFormattedText("%s.", LOOKING) 
					elseif dots == 2 then
						groupText:SetFormattedText("%s..", LOOKING) 
					elseif dots == 3 then
						groupText:SetFormattedText("%s...", LOOKING) 
					end
					total = 0
				end 
			end)
		end

		-- WotLK and Cata PvP battleground and Wintergrasp queue
		if _G.MiniMapBattlefieldFrame then
			local groupConfig = config.widgets.group

			local pvp = _G.MiniMapBattlefieldFrame 
			pvp:SetParent(border)
			pvp:SetFrameLevel(5)
			pvp:ClearAllPoints()
			pvp:SetPoint(unpack(groupConfig.point))
			pvp:SetSize(groupConfig.size[1], groupConfig.size[2])

			local pvpText = border:CreateFontString(nil, "OVERLAY")
			pvpText:SetParent(pvp)
			pvpText:Place(unpack(groupConfig.fontAnchor))
			pvpText:SetFontObject(groupConfig.normalFont)
			pvpText:SetTextColor(groupConfig.fontColor[1], groupConfig.fontColor[2], groupConfig.fontColor[3])
			pvpText:SetText(LOOKING) 
			pvpText:SetJustifyV("BOTTOM")
			
			-- Need a separate frame for the updater, 
			-- as the icon frame's OnUpdate is reset on mouseover, 
			-- thus cancelling our script as well. 
			local total, dots = 0, 0
			local updater = CreateFrame("Frame", nil, pvp)
			updater:SetScript("OnUpdate", function(self, elapsed) 
				total = total + elapsed
				if total > 1 then
					local pvp = GetZonePVPInfo()
					local _, instanceType = GetInstanceInfo()
					if pvp == "combat" or pvp == "arena" or instanceType == "pvp" or instanceType == "arena" then
						pvpText:SetText(PVP) 
					else
						dots = dots + 1
						if dots > 3 then 
							dots = 0
						end
						if dots == 0 then
							pvpText:SetText(LOOKING) 
						elseif dots == 1 then
							pvpText:SetFormattedText("%s.", LOOKING) 
						elseif dots == 2 then
							pvpText:SetFormattedText("%s..", LOOKING) 
						elseif dots == 3 then
							pvpText:SetFormattedText("%s...", LOOKING) 
						end
						total = 0
					end
				end 
			end)
		end
	end

	-- Mapping
	---------------------------------------------------------------
	self.config = config
	self.data = data
	self.db = db

	self.frame = frame
	self.frame.db = db 
	self.frame.data = data 
	self.frame.visibility = visibility

	self.frame.scaffold = scaffold
	self.frame.scaffold.border = border

	self.frame.custom = custom
	self.frame.custom.info = info
	self.frame.custom.map = map
	self.frame.custom.map.content = mapContent
	self.frame.custom.map.overlay = mapOverlay

	self.frame.widgets = widgets
	self.frame.widgets.time = time
	self.frame.widgets.zone = zoneName
	self.frame.widgets.difficulty = zoneDifficulty
	self.frame.widgets.coordinates = playerCoordinates
	self.frame.widgets.finder = finder

	self.frame.old = old 
	self.frame.old.map = oldMinimap
	self.frame.old.backdrop = oldBackdrop
	self.frame.old.cluster = oldCluster


	-- Will move these up when the new garrison button graphics are done
	do return end

	if WOD then 
		self.frame.widgets.garrison = CreateFrame("Frame", nil, self.frame.scaffold.border) 
		self.frame.widgets.garrison:EnableMouse(true) 
		self.frame.widgets.garrison:SetScript("OnEnter", Garrison_OnEnter) 
		self.frame.widgets.garrison:SetScript("OnLeave", Garrison_OnLeave) 
		self.frame.widgets.garrison:SetScript("OnMouseDown", Garrison_OnClick)

		self.garrison = self.frame.widgets.garrison
	end

end

Module.OnEnable = function(self)
	if self:InCompatible() then return end

	BlizzardUI:GetElement("Minimap"):Disable()
	BlizzardUI:GetElement("Menu_Option"):Remove(true, "InterfaceOptionsDisplayPanelShowClock")
	BlizzardUI:GetElement("Menu_Option"):Remove(true, "InterfaceOptionsDisplayPanelRotateMinimap")

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("ZONE_CHANGED", "OnEvent")
	self:RegisterEvent("ZONE_CHANGED_INDOORS", "OnEvent")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnEvent")
	self:RegisterEvent("VARIABLES_LOADED", "OnEvent")
	self:UpdateZoneData()

	-- Initiate updates for time, coordinates, etc
	self.frame:SetScript("OnUpdate", onUpdate)

	-- Report the initial minimap visibility, and enforce booleans (avoid the 1/nil blizzard is so fond of)
	-- *Note that I plan to make minimap visibility save between sessions, so strictly speaking this is not redundant, 
	--  event though the minimap technically always is visible at /reload. 
	self:SendMessage("ENGINE_MINIMAP_VISIBLE_CHANGED", not not(self.frame.visibility:IsShown()))
	
	-- since we haven't implemented this fully, we exit now
	do return end
	
	if WOD then 
		self:RegisterEvent("GARRISON_SHOW_LANDING_PAGE", "OnEvent")
		self:RegisterEvent("GARRISON_HIDE_LANDING_PAGE", "OnEvent")
		self:RegisterEvent("GARRISON_BUILDING_ACTIVATABLE", "OnEvent")
		self:RegisterEvent("GARRISON_BUILDING_ACTIVATED", "OnEvent")
		self:RegisterEvent("GARRISON_ARCHITECT_OPENED", "OnEvent")
		self:RegisterEvent("GARRISON_MISSION_FINISHED", "OnEvent")
		self:RegisterEvent("GARRISON_MISSION_NPC_OPENED", "OnEvent")
		self:RegisterEvent("GARRISON_INVASION_AVAILABLE", "OnEvent")
		self:RegisterEvent("GARRISON_INVASION_UNAVAILABLE", "OnEvent")
		self:RegisterEvent("SHIPMENT_UPDATE", "OnEvent")
	end
	
end
