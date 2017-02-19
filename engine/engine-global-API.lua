local ADDON, Engine = ...
local Module = Engine:NewModule("InspectAPI", "HIGH")

-- Lua API
local _G = _G
local math_max = math.max
local pairs = pairs
local string_match = string.match
local string_split = string.split
local table_wipe = table.wipe

-- WoW API
local CheckInteractDistance = _G.CheckInteractDistance
local GetContainerItemLink = _G.GetContainerItemLink
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetInventoryItemLink = _G.GetInventoryItemLink
local GetInventoryItemTexture = _G.GetInventoryItemTexture
local GetItemInfo = _G.GetItemInfo
local GetItemStats = _G.GetItemStats
local GetTime = _G.GetTime
local IsEquippableItem = _G.IsEquippableItem
local NotifyInspect = _G.NotifyInspect
local UnitClass = _G.UnitClass
local UnitExists = _G.UnitExists
local UnitGUID = _G.UnitGUID
local UnitIsUnit = _G.UnitIsUnit

-- Shortcuts to identify client versions
local CATA 			= Engine:IsBuild("Cata") -- 4.0.1 "Cataclysm Systems"

local globalElements = {} -- registry of global functions and elements
local metaMethods = {} -- registry of meta methods

-- Register a global that will be added if it doesn't exist already.
-- The global can be anything you set it to be.
local addGlobal = function(globalName, targetElement)
	globalElements[globalName] = targetElement
end

-- Register a meta method with the given object type.
-- *If targetElement is a string and the name of an existing meta method, 
--  an alias pointing to that element will be created instead.
--  See the SetColorTexture entry farther down for an example. 
local addMetaMethod = function(objectType, metaMethodName, targetElement)
	if not metaMethods[objectType] then
		metaMethods[objectType] = {}
	end
	metaMethods[objectType][metaMethodName] = targetElement
end



-- From Legion and onwards there exists a function to check for the player's 
-- own average itemlevel. But nothing exists for other players. 
-- What we're adding here is a simple API to see anybody's itemlevel 
-- given they're in range and can be inspected. 

local itemCache
local gearDB, specDB = {}, {}
local nextInspectRequest, lastInspectRequest = 0, 0
local currentUNIT, currentGUID

-- BOA Items 
local BOAItems = {
	["133585"] = true, -- Judgment of the Naaru
	["133595"] = true, -- Gronntooth War Horn
	["133596"] = true, -- Orb of Voidsight
	["133597"] = true, -- Infallible Tracking Charm 
	["133598"] = true  -- Purified Shard of the Third Moon
}

-- Upgraded Item Bonus 
local upgradedBonusItems = {
	["001"] =  8, ["373"] =  4, ["374"] =  8, ["375"] =  4,
	["376"] =  4, ["377"] =  4, ["379"] =  4, ["380"] =  4,
	["446"] =  4, ["447"] =  8, ["452"] =  8, ["454"] =  4,
	["455"] =  8, ["457"] =  8, ["459"] =  4, ["460"] =  8,
	["461"] = 12, ["462"] = 16, ["466"] =  4, ["467"] =  8,
	["469"] =  4, ["470"] =  8, ["471"] = 12, ["472"] = 16,
	["492"] =  4, ["493"] =  8, ["494"] =  4, ["495"] =  8,
	["496"] =  8, ["497"] = 12, ["498"] = 16, ["504"] = 12,
	["505"] = 16, ["506"] = 20, ["507"] = 24, ["530"] =  5,
	["531"] = 10
}

-- Timewarped/Warforged Items 
local timeWarpedItems = {
	-- Timewarped
	["615"] = 660, ["692"] = 675,

	-- Warforged
	["656"] = 675
}

-- Inventory Slot IDs we need to check for average item levels
local inventorySlots = {
	INVSLOT_HEAD, INVSLOT_NECK, INVSLOT_SHOULDER, INVSLOT_CHEST, 
	INVSLOT_WAIST, INVSLOT_LEGS, INVSLOT_FEET, INVSLOT_WRIST, INVSLOT_HAND, 
	INVSLOT_FINGER1, INVSLOT_FINGER2, INVSLOT_TRINKET1, INVSLOT_TRINKET2, 
	INVSLOT_BACK, INVSLOT_MAINHAND, INVSLOT_OFFHAND, INVSLOT_RANGED
}

-- Inventory equip locations of items in our containers we 
-- include in our search for the optimal / maximum item level.
local itemSlot = {
	INVTYPE_HEAD = true, 
	INVTYPE_NECK = true, 
	INVTYPE_SHOULDER = true, 
	INVTYPE_CHEST = true, INVTYPE_ROBE = true, 
	INVTYPE_WAIST = true, 
	INVTYPE_LEGS = true, 
	INVTYPE_FEET = true, 
	INVTYPE_WRIST = true, 
	INVTYPE_HAND = true, 
	INVTYPE_FINGER = true, 
	INVTYPE_TRINKET = true, 
	INVTYPE_CLOAK = true, 
	INVTYPE_2HWEAPON = true, 
	INVTYPE_WEAPON = true, 
	INVTYPE_WEAPONMAINHAND = true, 
	INVTYPE_WEAPONOFFHAND = true, 
	INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, 
	INVTYPE_RANGED = true, INVTYPE_THROWN = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_RELIC = true
}

-- Item stats indicating an item is a PvP item
-- *both do not exist in all expansions, but one of them always does
local knownPvPStats = {
	ITEM_MOD_RESILIENCE_RATING_SHORT = true,
	ITEM_MOD_PVP_POWER_SHORT = true
}

-- First clear the cache if one exists, but don't erase any tables,
-- then return it to the user, or create a new table if it's the first call.
local clearCache = function()
	if itemCache then
		for slot,cache in pairs(itemCache) do
			table_wipe(cache)
		end
		return itemCache
	else
		itemCache = {}
		return itemCache
	end
end

-- Add an item into the cache for its slot
local addToCache = function(ilvl, slot)
	if slot == "INVTYPE_ROBE" then
		slot = "INVTYPE_CHEST"
	end
	if not itemCache[slot] then
		itemCache[slot] = {}
	end
	itemCache[slot][#itemCache[slot] + 1] = ilvl
end

local getBOALevel = function(level, id)
	if level > 97 then
		if BOAItems[id] then
			level = 715
		else
			level = 605 - (100 - level) * 5
		end
	elseif level > 90 then
		level = 590 - (97 - level) * 10
	elseif level > 85 then
		level = 463 - (90 - level) * 19.5
	elseif level > 80 then
		level = 333 - (85 - level) * 13.5
	elseif level > 67 then
		level = 187 - (80 - level) * 4
	elseif level > 57 then
		level = 105 - (67 - level) * 2.8
	else
		level = level + 5
	end

	return level
end

local itemStatCache = {}
local itemPvPCache = {}

local isPvPItem = function(item)
	if itemPvPCache[item] then
	else
		local itemName, itemLink = GetItemInfo(item) 
		if itemLink then 
			local itemString = string_match(itemLink, "item[%-?%d:]+")
			local _, itemID = string_split(":", itemString)

			if itemPvPCache[itemID] then
				return itemPvPCache[itemID]
			else
				local isPvP

				-- cache up the stat table
				itemStatCache[itemID] = GetItemStats(itemLink)

				for stat in pairs(itemStatCache[itemID]) do
					if knownPvPStats[stat] then
						isPvP = true
						break
					end
				end

				-- cache it up
				itemPvPCache[itemID] = isPvP
				itemPvPCache[itemName] = isPvP
				itemPvPCache[itemLink] = isPvP
				itemPvPCache[itemString] = isPvP

				return isPvP
			end
		end
	end
end

addGlobal("IsPVPItem", isPvPItem)


Module.OnEvent = function(self, event, ...)
	if event == "PLAYER_REGEN_DISABLED" then
		self.frame:Hide()

	elseif event == "PLAYER_REGEN_ENABLED" then

	-- Inventory information is updated for the inspected unit.
	elseif event == "UNIT_INVENTORY_CHANGED" then

	-- Talent information is available for the inspected unit.
	elseif event == "INSPECT_READY" then
	elseif event == "INSPECT_TALENT_READY" then
		local GUID = UnitGUID("mouseover")
		if GUID == currentGUID then
			local unit = "mouseover"
			if UnitExists(unit) then
				local gear = self:GetUnitGear(currentUNIT)
				gearDB[currentGUID] = gear

				local spec = self:GetUnitSpec(currentUNIT)
				specDB[currentGUID] = spec

				if not(gear and spec) then
					self:ScanUnit(currentUNIT, true)
				else
					self:SetUnitInfo(gear, spec)
				end
			end

			-- If this is a WotLK client we need to unregister the event,
			-- as it was only possible to inspect one unit at a time back then, 
			-- so we should only ever track this event directly after a NotifyInspect request has been sent!
			self:UnregisterEvent("INSPECT_TALENT_READY", "OnEvent")
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- remove the initial event, we don't need it anymore
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")

		-- register a new event handler
		self:SetScript("OnEvent", onEvent)

		-- set the onupdate handler 
		self:SetScript("OnUpdate", function(self, elapsed)
			nextInspectRequest = nextInspectRequest - elapsed
			if nextInspectRequest > 0 then 
				return 
			end

			if currentUNIT and currentGUID and (UnitGUID(currentUNIT) == currentGUID) then
				lastInspectRequest = GetTime() 
				
				if not CATA then
					-- In WotLK, we could only inspect one unit at a time, 
					-- so to avoid confusion we only register the event on demand, 
					-- and will remove it once it fires.
					self:RegisterEvent("INSPECT_TALENT_READY")
				end
				NotifyInspect(currentUNIT)
			end
			self:Hide()
		end)

		-- register the real events needed
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")

		-- In WotLK, we could only inspect one unit at a time, 
		-- so to avoid confusion we only register the WotLK event on demand, 
		-- and will remove it once it fires.
		--
		-- The Cata event returns which unit the inspect was for, 
		-- so it's safe to leave that active at all times. 
		if CATA then 
			self:RegisterEvent("INSPECT_READY")
		end
	end
end

--
--	Currently Blizzard's formula for equipped average item level is as follows:
--
--	 sum of item levels for equipped gear (I)
--	-----------------------------------------  = Equipped Average Item Level
--	       number of slots (S)
--
--	(I) = in taking the sum, the tabard and shirt always count as zero
--	      some heirloom items count as zero, other heirlooms count as one
--
--	(S) = number of slots depends on the contents of the main and off hand as follows:
--	      17 with both hands holding items 
--	      17 with a single one-hand item (or a single two-handed item with Titan's Grip)
--	      16 with a two-handed item equipped (and no Titan's Grip)
--	      16 with both hands empty
--
--
--   Source: http://wow.gamepedia.com/API_GetAverageItemLevel


addGlobal("UnitItemLevel", function(unit) 
	if (not unit) or (not UnitExists(unit)) or (not CanInspect(unit)) then 
		return
	end
	if (not UnitIsUnit("player", unit)) then
	end


	local _, class = UnitClass(unit)

	local boaItems, pvpItems = 0, 0



end)


do return end


-- Add global functions
for globalName, targetElement in pairs(globalElements) do
	if not _G[globalName] then
		_G[globalName] = targetElement
	end
end

-- Add meta methods
local frameObject = CreateFrame("Frame")
local objectTypes = {
	Frame = frameObject, 
	Texture = frameObject:CreateTexture()
}
for objectType, methods in pairs(metaMethods) do
	local object = objectTypes[objectType]
	local object_methods = getmetatable(object).__index
	for method, targetElement in pairs(methods) do
		if not object[method] then
			if type(targetElement) == "string" then
				object_methods[method] = object[targetElement]
			else
				object_methods[method] = targetElement
			end
		end
	end
end

Module.RequestItemLevel = function(self, unit)
	if (UnitIsDeadOrGhost("player") or UnitOnTaxi("player")) or (not CheckInteractDistance(unit, 1)) or (not UnitIsVisible(unit)) or (not CanInspect(unit)) or (_G.InspectFrame and _G.InspectFrame:IsShown()) then
		return
	end



end


Module.OnInit = function(self)
	self.frame = CreateFrame("Frame")
	self.frame:Hide()
end

Module.OnEnable = function(self)


end
