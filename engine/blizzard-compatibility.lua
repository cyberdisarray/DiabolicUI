--[[
	The MIT License (MIT)
	Copyright (c) 2017 Lars "Goldpaw" Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

]]--


-- 	Blizzard API Layer
-------------------------------------------------------------------
-- 	The purpose of this file is to provide a compapatibility layer
-- 	making the different Blizzard API versions more similar. 


-- Lua API
local _G = _G
local getmetatable = getmetatable
local ipairs = ipairs
local math_max = math.max
local pairs = pairs
local select = select
local string_match = string.match
local table_wipe = table.wipe
local type = type

-- Note: 
-- For the sake of speed, we put the WoW API locals within 
-- the parent namespace of whatever functions are using them. 

-- Retrive the current game client version
local BUILD = tonumber((select(2, GetBuildInfo()))) 

-- Shortcuts to identify client versions
local ENGINE_LEGION_715 	= BUILD >= 23360 -- 7.1.5 
local ENGINE_LEGION_710 	= BUILD >= 22578 -- 7.1.0 
local ENGINE_LEGION_703 	= BUILD >= 22410 -- 7.0.3 
local ENGINE_WOD 			= BUILD >= 20779 -- 6.2.3 
local ENGINE_MOP 			= BUILD >= 18414 -- 5.4.8 
local ENGINE_CATA 			= BUILD >= 15595 -- 4.3.4 

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



-- Stuff added in Cata that we want in older versions
------------------------------------------------------------------------------------
if not ENGINE_CATA then

	-- Lua API
	local _G = _G
	local ipairs = ipairs
	local math_max = math_max
	local pairs = pairs
	local string_match = string_match
	local string_split = string_split
	local table_wipe = table_wipe

	-- WoW API
	local GetContainerNumSlots = _G.GetContainerNumSlots
	local GetInventoryItemTexture = _G.GetInventoryItemTexture
	local GetInventoryItemLink = _G.GetInventoryItemLink
	local GetItemInfo = _G.GetItemInfo
	local GetItemStats = _G.GetItemStats
	local IsEquippableItem = _G.IsEquippableItem

	-- WoW Constants
	local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER
	local NUM_BAG_SLOTS = _G.NUM_BAG_SLOTS


	local gearDB, specDB = {}, {}
	local itemStatCache, itemPvPCache = {}
	local nextInspectRequest, lastInspectRequest = 0, 0
	local itemCache
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
		_G.INVSLOT_HEAD, 		_G.INVSLOT_NECK, 		_G.INVSLOT_SHOULDER, 	_G.INVSLOT_CHEST, 
		_G.INVSLOT_WAIST, 		_G.INVSLOT_LEGS, 		_G.INVSLOT_FEET, 		_G.INVSLOT_WRIST, 		_G.INVSLOT_HAND, 
		_G.INVSLOT_FINGER1, 	_G.INVSLOT_FINGER2, 	_G.INVSLOT_TRINKET1, 	_G.INVSLOT_TRINKET2, 
		_G.INVSLOT_BACK, 		_G.INVSLOT_MAINHAND, 	_G.INVSLOT_OFFHAND, 	_G.INVSLOT_RANGED
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


	-- This isn't perfect, but for most purposes it'll do.
	addGlobal("GetAverageItemLevel", function()
		local _, class = UnitClass("player")

		local equip_average_level, equip_total_level, equip_count = 0, 0, ENGINE_MOP and 16 or 17 -- include the relic/ranged slot in WotLK/Cata
		local mainhand, offhand, twohand = 1, 1, 0
		local boa, pvp = 0, 0
		
		local cache = clearCache()

		-- start scanning equipped items
		for _,invSlot in ipairs(inventorySlots) do
			local itemTexture = GetInventoryItemTexture("player", invSlot)
			if itemTexture then
				local itemLink = GetInventoryItemLink("player", invSlot)
				if itemLink then
					local _, _, quality, level, _, _, _, _, slot = GetItemInfo(itemLink)
					if quality and level then
						if quality == 7 then
							boa = boa + 1
							local id = string_match(itemLink, "item:(%d+)")
							level = getBOALevel(player_level, id)
						end
						if invSlot >= 16 then
							-- INVTYPE_RANGED = Bows
							-- INVTYPE_RANGEDRIGHT = Wands, Guns, and Crossbows
							-- INVTYPE_THROWN = Ranged (throwing weapons for Warriors, Rogues in WotLK/Cata)
							if ENGINE_MOP then
								if (slot == "INVTYPE_2HWEAPON") or (slot == "INVTYPE_RANGED") or ((slot == "INVTYPE_RANGEDRIGHT") and (class == "HUNTER")) then
									twohand = twohand + 1
								end
							else
								if (slot == "INVTYPE_2HWEAPON") then
									twohand = twohand + 1
								end
							end
						end
						equip_total_level = equip_total_level + level
						addToCache(level, slot)
					end
				end
			else
				if invSlot == 16 then
					mainhand = 0
				elseif invSlot == 17 then
					offhand = 0
				end
			end
		end

		if ((mainhand == 0) and (offhand == 0)) or (twohand == 1) then
			equip_count = equip_count - 1
		end
		
		-- the item level of the currently equipped items
		equip_average_level = equip_total_level / equip_count

		-- start scanning the backpack and any equipped bags for gear
		for bagID = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
			local numSlots = GetContainerNumSlots(bagID)
			for slotID = 1, numSlots do
				local itemLink = GetContainerItemLink(bagID, slotID)
				if itemLink then
					local canEquip = IsEquippableItem(itemLink)
					if canEquip then
						local _, _, quality, level, _, _, _, _, slot = GetItemInfo(itemLink)
						if quality and level and itemSlot[slot] then
							if quality == 7 then -- don't think these exist here, but still...
								local id = string_match(itemLink, "item:(%d+)")
								local boa_ilvl = getBOALevel(player_level, id)
								addToCache(boa_ilvl, slot)
							else
								addToCache(level, slot)
							end
						end
					end
				end
			end
		end
		
		-- TODO: 
		-- 	Make it return the same values as Blizzard's function.
		-- 	- check for warrior's Titan's Grip
		-- 	- check for heirloom items
		-- 	- figure out what heirlooms count towards the ilvl and not


		-- 	Source: http://wow.gamepedia.com/API_GetAverageItemLevel
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

		
		-- Developer's Notes:
		-- 
		--  1) WotLK featured a ranged slot for all classes, 
		--     with "idols" and similar for the classes lacking the ability to use ranged weapons.
		--     Meaning in WotLK, the number of slots should always be 16 or 17, 
		--     while in MoP and higher, it should be 15 or 16.
		--
		--  2) To properly decide the average and total itemlevels, 
		--     we need to make several passes over the cached table.
		--     Because we can't count both two handers and single handers at the same time. 
		-- 	
		--  3) In WotLK and Cata, all classed had something in their ranged slot, 
		-- 	   while in MoP and beyond nobody had anything, since the ranged slot doesn't exist. 
		--     So the only difference between classes should be whether or not it's a 1h or 2h.
	
		
		-- Compare the cached items to figure out the highest possible
		-- itemlevel from the possible combination of items in your possession.
		local dual_average, dual_total, dual_count = 0, 0, ENGINE_MOP and 2 or 3 -- include the relic/ranged slot in WotLK/Cata
		local twohand_average, twohand_total, twohand_count = 0, 0, ENGINE_MOP and 1 or 2 -- include the relic/ranged slot in WotLK/Cata
		local total_average_level, total_level, total_count = 0, 0, 14 -- 5 armor slots, 1 cloak, 1 wrist, 1 belt, 1 boot(s), 1 neck, 2 rings, 2 trinkets
		local singlehand_max, mainhand_max, offhand_max, twohand_max = 0, 0, 0, 0 -- max ilvls for the various weapon slots

		-- For more information about equip locations / slots:
		-- http://wow.gamepedia.com/ItemEquipLoc
		for slot in pairs(cache) do
			local slotMax = 0
			for i = 1, #cache[slot] do
				-- two-hand
				if slot == "INVTYPE_2HWEAPON" then
					twohand_max = math_max(twohand_max, slotMax)

				-- single-hand (can be equipped in both main and off-hand)
				elseif slot == "INVTYPE_WEAPON" then
					singlehand_max = math_max(singlehand_max, slotMax)
					
				-- main-hand only items
				elseif slot == "INVTYPE_WEAPONMAINHAND" then
					mainhand_max = math_max(mainhand_max, slotMax)
				
				-- off-hand only items
				elseif slot == "INVTYPE_WEAPONOFFHAND" or slot == "INVTYPE_SHIELD" or slot == "INVTYPE_HOLDABLE" then
					offhand_max = math_max(offhand_max, slotMax)

				-- other gear which always should be counted
				else 
					slotMax = math_max(slotMax, cache[slot][i])
				end
			end
			if slotMax > 0 then
				total_level = total_level + slotMax
			end
		end
		
		-- If we have a single-hander with higher level than any main/off-handers, 
		-- then we'll combine that single-hander with the highest of the two others.
		if singlehand_max > mainhand_max or singlehand_max > offhand_max then
			dual_average = (singlehand_max + math_max(offhand_max, mainhand_max) + total_level) / (dual_total + total_count)
		else
			dual_average = (mainhand_max + offhand_max + total_level) / (dual_total + total_count)
		end
		
		-- Max average with a two handed weapon
		twohand_average = (twohand_max + total_level) / (twohand_count + total_count)
		
		-- Max average all things considered. More or less. Can't win 'em all...
		total_average_level = math_max(twohand_average, dual_average)
		
		-- Crossing our fingers that this is right! :) 
		-- *Something bugs out returning a lower total than average sometimes in WotLK, 
		--  so for the sake of simplicity and lesser headaches, we just return equipped twice. -_-
		return math_max(total_average_level, equip_average_level), equip_average_level
	end)

	-- These functions were renamed in 4.0.1.	
	-- Adding the new names as aliases for compatibility.
	addGlobal("SetGuildBankWithdrawGoldLimit", _G.SetGuildBankWithdrawLimit)
	addGlobal("GetGuildBankWithdrawGoldLimit", _G.GetGuildBankWithdrawLimit)
end



-- Stuff added in MoP that we want in older versions
------------------------------------------------------------------------------------
if not ENGINE_MOP then
	-- WoW API
	local IsActiveBattlefieldArena = _G.IsActiveBattlefieldArena

	-- In MoP the old functionality relating to party and raids got for the most parts 
	-- replaced by singular group functions, with the addition of an IsInRaid function
	-- to determine if we're in a raid group or not. 

	-- Returns the number of party members, excluding the player (0 to 4).
	-- While in a raid, you are also in a party. You might be the only person in your raidparty, so this function could still return 0.
	-- While in a battleground, this function returns information about your battleground party. You may retrieve information about your non-battleground party using GetRealNumPartyMembers().
	local GetNumPartyMembers = _G.GetNumPartyMembers
	local GetRealNumPartyMembers = _G.GetRealNumPartyMembers

	-- Returns number of players in your raid group, including yourself; or 0 if you are not in a raid group.
	-- While in battlegrounds, this function returns the number of people in the battleground raid group. You may both be in a battleground raid group and in a normal raid group at the same time; you can use GetRealNumRaidMembers() to retrieve the number of people in the latter.
	-- MoP: Replaced by GetNumGroupMembers, and IsInRaid; the former also returns non-zero values for party groups.
	local GetNumRaidMembers = _G.GetNumRaidMembers
	local GetRealNumRaidMembers = _G.GetRealNumRaidMembers

	-- Returns the total number of players in a group.
	-- groupType can be:
	-- 	LE_PARTY_CATEGORY_HOME (1) - to query information about the player's manually-created group.
	-- 	LE_PARTY_CATEGORY_INSTANCE (2) - to query information about the player's instance-specific temporary group (e.g. PvP battleground group, Dungeon Finder group).
	-- 		*If omitted, defaults to _INSTANCE if such a group exists, _HOME otherwise.
	addGlobal("GetNumGroupMembers", function(groupType) 
		if groupType == 1 then
			local realNumRaid = GetRealNumRaidMembers()
			return (realNumRaid > 0) and realNumRaid or GetRealNumPartyMembers()
		elseif groupType == 2 then
			local realNumRaid = GetRealNumRaidMembers()
			return (realNumRaid > 0) and realNumRaid or GetRealNumPartyMembers()
		else
			local numParty = GetNumPartyMembers()
			local numRaid = GetNumRaidMembers()
			local realNumRaid = GetRealNumRaidMembers()
			return (numRaid > 0) and numRaid or (numParty > 0) and numParty or (realNumRaid > 0) and realNumRaid or GetRealNumPartyMembers()
		end
	end)

	-- Returns true if the player is in a groupType group (if groupType was not specified, true if in any type of group), false otherwise.
	-- 	LE_PARTY_CATEGORY_HOME (1) : checks for home-realm parties.
	-- 	LE_PARTY_CATEGORY_INSTANCE (2) : checks for instance-specific groups.
	-- 		*The HOME category includes Parties and Raids. It is possible for a character to belong to a party or a raid at the same time they are in an instance group (LFR or Flex). To distinguish between a party and a raid, use the IsInRaid() function.
	addGlobal("IsInGroup", function(groupType) 
		if groupType == 1 then
			return (GetRealNumRaidMembers() > 0) or (GetRealNumPartyMembers() > 0)
		elseif (groupType == 2) then
			return (GetNumRaidMembers() > 0) or (GetNumPartyMembers() > 0)
		else
			return (GetRealNumRaidMembers() > 0) or (GetRealNumPartyMembers() > 0) or (GetNumRaidMembers() > 0) or (GetNumPartyMembers() > 0)
		end
	end)

	-- Returns true if the player is currently in a groupType raid group (if groupType was not specified, true if in any type of raid), false otherwise
	-- 	LE_PARTY_CATEGORY_HOME (1) : checks for home-realm parties.
	-- 	LE_PARTY_CATEGORY_INSTANCE (2) : checks for instance-specific groups.
	-- 		*This returns true in arenas if groupType is LE_PARTY_CATEGORY_INSTANCE or is unspecified.
	addGlobal("IsInRaid", function(groupType) 
		if groupType == 1 then
			return GetRealNumRaidMembers() > 0
		elseif (groupType == 2) then
			return IsActiveBattlefieldArena() or GetNumRaidMembers() > 0
		else
			return IsActiveBattlefieldArena() or (GetRealNumRaidMembers() > 0) or (GetNumRaidMembers() > 0)
		end
	end)
end



-- Stuff added in Legion that we want in older versions
------------------------------------------------------------------------------------
if not ENGINE_LEGION_703 then
	
	-- Many rares and quest mobs in both WoD and Legion can be tapped and looted 
	-- by multiple groups of players, so in patch 7.0.3 a function was added 
	-- to check if you still had the ability to gain credit and loot from the unit in question. 
	-- Prior to that we had to check a whole myriad of functions at once to figure out the same.
	-- So what we do here is to give previous client versions access to the same functionality

	-- WoW API
	local UnitIsFriend = _G.UnitIsFriend
	local UnitPlayerControlled = _G.UnitPlayerControlled
	local UnitIsTapped = _G.UnitIsTapped
	local UnitIsTappedByAllThreatList = _G.UnitIsTappedByAllThreatList
	local UnitIsTappedByPlayer = _G.UnitIsTappedByPlayer
	
	addGlobal("UnitIsTapDenied", function(unit) 
		return UnitIsTapped(unit) and not(UnitPlayerControlled(unit) or UnitIsTappedByPlayer(unit) or UnitIsTappedByAllThreatList(unit) or UnitIsFriend("player", unit))
	end)

	-- In 7.0.3 the ability to directly set a color as a texture was removed, 
	-- and the texture method :SetTexture() could only contain a file path or an atlas ID, 
	-- while setting a texture to a pure color received its own method name :SetColorTexture()
	-- To simplify development, we're adding SetColorTexture() as an alias of SetTexture()
	-- to previous client versions.
	-- This won't fix bad SetTexture calls in Legion, but it allows us to use 
	-- the Legion API in all client versions with no performance loss.
	addMetaMethod("Texture", "SetColorTexture", "SetTexture")

end


-- Stuff removed in Cata
------------------------------------------------------------------------------------
if ENGINE_CATA then
	local GetCurrencyInfo = _G.GetCurrencyInfo
	local GetNumSpellTabs = _G.GetNumSpellTabs
	local GetSpellBookItemInfo = _G.GetSpellBookItemInfo
	local GetSpellBookItemName = _G.GetSpellBookItemName
	local GetSpellTabInfo = _G.GetSpellTabInfo
	local HasPetSpells = _G.HasPetSpells

	-- These functions were renamed in 4.0.1.	
	-- Adding the old names as aliases for compatibility.
	addGlobal("SetGuildBankWithdrawLimit", _G.SetGuildBankWithdrawGoldLimit)
	addGlobal("GetGuildBankWithdrawLimit", _G.GetGuildBankWithdrawGoldLimit)

	-- Removed in 4.0.1 as honor and conquest points 
	-- were moved into the main currency system.
	-- Currency IDs from: http://wow.gamepedia.com/API_GetCurrencyInfo
	addGlobal("GetArenaCurrency", function() 
		local _, currentAmount = GetCurrencyInfo(390)
		return currentAmount
	end)
	addGlobal("GetHonorCurrency", function() 
		local _, currentAmount = GetCurrencyInfo(392)
		return currentAmount
	end)

	-- The spellbook changed in 4.0.1, and its funtions along with it.
	-- BOOKTYPE_SPELL = "spell"
	-- BOOKTYPE_PET = "pet"
	addGlobal("GetSpellName", function(spellID, bookType)
		if bookType == "spell" then
			local slotID = 0
			local numTabs = GetNumSpellTabs()
			for tabIndex = 1, numTabs do
				local _, _, _, numEntries = GetSpellTabInfo(tabIndex)
				for slotIndex = 1, numEntries do
					slotID = slotID + 1
					local _, spellId = GetSpellBookItemInfo(slotID, bookType)
					if spellId == spellID then
						return GetSpellBookItemName(slotID, bookType)
					end
				end
			end
		elseif bookType == "pet" then
			local hasPetSpells = HasPetSpells()
			if hasPetSpells then 
				for slotIndex = 1, hasPetSpells do
					local _, spellId = GetSpellBookItemInfo(slotIndex, bookType)
					if spellId == spellID then
						return GetSpellBookItemName(slotIndex, bookType)
					end
				end
			end
		end
	end)

	-- The entire key ring system was removed from the game in patch 4.2.0
	-- The old function returned 1 or nil, so we simply go with a nil return here
	-- since that is what most accurately mimics what the old return value would have been.
	addGlobal("HasKey", function() return nil end)
	
end


-- Stuff removed in MoP
------------------------------------------------------------------------------------
if ENGINE_MOP then

	-- Armor Penetration as a stat existed only in TBC, WotLK and Cata, 
	-- was removed as a stat on gear in Cata but remained available through talents, 
	-- and was removed from the game entirely along with its functions in MoP.
	-- We return a value of 0 here, since nobody has this stat after MoP.
	addGlobal("GetArmorPenetration", function() return 0 end)

end


-- Stuff removed in WoD
------------------------------------------------------------------------------------
if ENGINE_WOD then 

	-- Guild XP was removed in 6.0.1 along with its functions.
	addGlobal("GetGuildRosterContribution", function() return 0, 0, 0, 0 end)
	addGlobal("GetGuildRosterLargestContribution", function() return 0, 0 end)
	
end


-- Stuff removed in Legion
------------------------------------------------------------------------------------
if ENGINE_LEGION_703 then
	-- In patch 7.0.3 (Legion) Death Knights stopped having 
	-- multiple types of runes, and all are now of the same kind. 
	addGlobal("RUNETYPE_BLOOD", 1)
	addGlobal("RUNETYPE_CHROMATIC", 2)
	addGlobal("RUNETYPE_FROST", 3)
	addGlobal("RUNETYPE_DEATH", 4)

	-- All runes are Death runes in Legion
	addGlobal("GetRuneType", function(id) return 4 end)

	-- In patch 7.1.0 the social chat button changed name, 
	-- and possibly some of its functionality. 
	-- Wouldn't surprise me if not, though. Blizzard do strange things. 
	-- For the sake of simplicity we make sure that both names always exist. 
	if ENGINE_LEGION_710 then
		addGlobal("FriendsMicroButton", _G.QuickJoinToastButton)
	else
		addGlobal("QuickJoinToastButton", _G.FriendsMicroButton)
	end
	
end



-- Lua Enums
------------------------------------------------------------------------------------
if not ENGINE_MOP then
	addGlobal("LE_PARTY_CATEGORY_HOME", 1)
	addGlobal("LE_PARTY_CATEGORY_INSTANCE", 2)
end

if not ENGINE_WOD then
	addGlobal("LE_NUM_ACTIONS_PER_PAGE", 12)
	addGlobal("LE_NUM_BONUS_ACTION_PAGES", 4)
	addGlobal("LE_NUM_NORMAL_ACTION_PAGES", 6)

	addGlobal("LE_BAG_FILTER_FLAG_IGNORE_CLEANUP", 1)
	addGlobal("LE_BAG_FILTER_FLAG_EQUIPMENT", 2)
	addGlobal("LE_BAG_FILTER_FLAG_CONSUMABLES", 3)
	addGlobal("LE_BAG_FILTER_FLAG_TRADE_GOODS", 4)
	addGlobal("LE_BAG_FILTER_FLAG_JUNK", 5)

	addGlobal("LE_CHARACTER_UNDELETE_RESULT_OK", 1)
	addGlobal("LE_CHARACTER_UNDELETE_RESULT_ERROR_COOLDOWN", 2)
	addGlobal("LE_CHARACTER_UNDELETE_RESULT_ERROR_CHAR_CREATE", 3)
	addGlobal("LE_CHARACTER_UNDELETE_RESULT_ERROR_DISABLED", 4)
	addGlobal("LE_CHARACTER_UNDELETE_RESULT_ERROR_NAME_TAKEN_BY_THIS_ACCOUNT", 5)
	addGlobal("LE_CHARACTER_UNDELETE_RESULT_ERROR_UNKNOWN", 6)

	addGlobal("LE_EXPANSION_CLASSIC", 0)
	addGlobal("LE_EXPANSION_BURNING_CRUSADE", 1)
	addGlobal("LE_EXPANSION_WRATH_OF_THE_LICH_KING", 2)
	addGlobal("LE_EXPANSION_CATACLYSM", 3)
	addGlobal("LE_EXPANSION_MISTS_OF_PANDARIA", 4)
	addGlobal("LE_EXPANSION_WARLORDS_OF_DRAENOR", 5)
	addGlobal("LE_EXPANSION_LEGION", 6)
	addGlobal("LE_EXPANSION_LEVEL_CURRENT", ENGINE_MOP and 4 or ENGINE_CATA and 3 or 2)

	addGlobal("LE_FRAME_TUTORIAL_GARRISON_BUILDING", 9)
	addGlobal("LE_FRAME_TUTORIAL_GARRISON_MISSION_LIST", 10)
	addGlobal("LE_FRAME_TUTORIAL_GARRISON_MISSION_PAGE", 11)
	addGlobal("LE_FRAME_TUTORIAL_GARRISON_LANDING", 12)
	addGlobal("LE_FRAME_TUTORIAL_GARRISON_ZONE_ABILITY", 13)
	addGlobal("LE_FRAME_TUTORIAL_WORLD_MAP_FRAME", 14)
	addGlobal("LE_FRAME_TUTORIAL_CLEAN_UP_BAGS", 15)
	addGlobal("LE_FRAME_TUTORIAL_BAG_SETTINGS", 16)
	addGlobal("LE_FRAME_TUTORIAL_REAGENT_BANK_UNLOCK", 17)
	addGlobal("LE_FRAME_TUTORIAL_TOYBOX_FAVORITE", 18)
	addGlobal("LE_FRAME_TUTORIAL_TOYBOX_MOUSEWHEEL_PAGING", 19)
	addGlobal("LE_FRAME_TUTORIAL_LFG_LIST", 20)

	addGlobal("LE_ITEM_QUALITY_POOR", 0)
	addGlobal("LE_ITEM_QUALITY_COMMON", 1)
	addGlobal("LE_ITEM_QUALITY_UNCOMMON", 2)
	addGlobal("LE_ITEM_QUALITY_RARE", 3)
	addGlobal("LE_ITEM_QUALITY_EPIC", 4)
	addGlobal("LE_ITEM_QUALITY_LEGENDARY", 5)
	addGlobal("LE_ITEM_QUALITY_ARTIFACT", 6)
	addGlobal("LE_ITEM_QUALITY_HEIRLOOM", 7)
	addGlobal("LE_ITEM_QUALITY_WOW_TOKEN", 8)

	addGlobal("LE_LFG_LIST_DISPLAY_TYPE_ROLE_COUNT", 1)
	addGlobal("LE_LFG_LIST_DISPLAY_TYPE_ROLE_ENUMERATE", 2)
	addGlobal("LE_LFG_LIST_DISPLAY_TYPE_CLASS_ENUMERATE", 3)
	addGlobal("LE_LFG_LIST_DISPLAY_TYPE_HIDE_ALL", 4)

	addGlobal("LE_LFG_LIST_FILTER_RECOMMENDED", 1)
	addGlobal("LE_LFG_LIST_FILTER_NOT_RECOMMENDED", 2)
	addGlobal("LE_LFG_LIST_FILTER_PVE", 4)
	addGlobal("LE_LFG_LIST_FILTER_PVP", 8)

	addGlobal("LE_MOUNT_JOURNAL_FILTER_COLLECTED", 1)
	addGlobal("LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED", 2)

	addGlobal("LE_PAN_STEADY", 1)
	addGlobal("LE_PAN_NONE", 2)
	addGlobal("LE_PAN_NONE_RANGED", 3)
	addGlobal("LE_PAN_FAST_SLOW", 4)
	addGlobal("LE_PAN_SLOW_FAST", 5)
	addGlobal("LE_PAN_AND_JUMP", 6)

	addGlobal("LE_PET_JOURNAL_FLAG_DEFAULT", 262144)

	addGlobal("LE_QUEST_FACTION_ALLIANCE", 1)
	addGlobal("LE_QUEST_FACTION_HORDE", 2)

	addGlobal("LE_QUEST_FREQUENCY_DEFAULT", 1)
	addGlobal("LE_QUEST_FREQUENCY_DAILY", 2)
	addGlobal("LE_QUEST_FREQUENCY_WEEKLY", 3)

	addGlobal("LE_RAID_BUFF_HASTE", 4)
	addGlobal("LE_RAID_BUFF_CRITICAL_STRIKE", 7) -- 6 in WoD
	addGlobal("LE_RAID_BUFF_MASTERY", 8) -- 7 in WoD

	--addGlobal("LE_RAID_BUFF_MULITSTRIKE", 8)
	--addGlobal("LE_RAID_BUFF_VERSATILITY", 9)

	addGlobal("LE_TRACKER_SORTING_MANUAL", 1)
	addGlobal("LE_TRACKER_SORTING_PROXIMITY", 2)
	addGlobal("LE_TRACKER_SORTING_DIFFICULTY_LOW", 3)
	addGlobal("LE_TRACKER_SORTING_DIFFICULTY_HIGH", 4)

	addGlobal("LE_UNIT_STAT_STRENGTH", 1)
	addGlobal("LE_UNIT_STAT_AGILITY", 2)
	addGlobal("LE_UNIT_STAT_STAMINA", 3)
	addGlobal("LE_UNIT_STAT_INTELLECT", 4)
	addGlobal("LE_UNIT_STAT_SPIRIT", 5)
end



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
