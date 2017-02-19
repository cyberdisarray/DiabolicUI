local _, Engine = ...
local Module = Engine:GetModule("Bags")
local Widget = Module:SetWidget("Data: Locales")
local L

-- Lua API
local _G = _G
local unpack = unpack

-- WoW API
local GetAuctionItemClasses = _G.GetAuctionItemClasses
local GetAuctionItemSubClasses = _G.GetAuctionItemSubClasses
local GetItemSubClassInfo = _G.GetItemSubClassInfo

-- Client Constants
local ENGINE_LEGION 	= Engine:IsBuild("Legion")
local ENGINE_WOD 		= Engine:IsBuild("WoD")
local ENGINE_MOP 		= Engine:IsBuild("MoP")
local ENGINE_CATA 		= Engine:IsBuild("Cata")

-- This function pretty much does what the old GetAuctionItemSubClasses did prior to Legion. 
-- Not as elegant as their new system, but far easier to work with for us poor developers. :) 
local GetNamedSubClasses = function(class)
	local subs = { GetAuctionItemSubClasses(class) } -- this now only returns subclass indices, not names
	if #subs > 0 then 
		local namedSubs = {}
		for i = 1, #subs do
			namedSubs[i] = (GetItemSubClassInfo(class, subs[i])) -- found this in blizzard's AuctionUI. it returns names! :) 
		end
		return unpack(namedSubs)
	end
end

Widget.GetLocale = function(self)
	if L then 
		return L 
	end

	L = {}

	if ENGINE_LEGION then

		-- The display order here is the same as it is in the Auction House UI.
		-------------------------------------------------------------------------

		-- The function to directly retrieve these names are gone, and though it is possible
		-- to extract them from globals made available by the blizzard auction house addon,
		-- it is a better solution to get them from the same place that addon gets them from instead. 

		L["Weapons"] 			= _G.AUCTION_CATEGORY_WEAPONS 			-- classID  2 - LE_ITEM_CLASS_WEAPON
		L["Armor"] 				= _G.AUCTION_CATEGORY_ARMOR				-- classID  4 - LE_ITEM_CLASS_ARMOR
		L["Containers"] 		= _G.AUCTION_CATEGORY_CONTAINERS 		-- classID  1 - LE_ITEM_CLASS_CONTAINER
		L["Gems"] 				= _G.AUCTION_CATEGORY_GEMS 				-- classID  3 - LE_ITEM_CLASS_GEM
		L["Item Enhancements"] 	= _G.AUCTION_CATEGORY_ITEM_ENHANCEMENT	-- classID  8 - LE_ITEM_CLASS_ITEM_ENHANCEMENT
		L["Consumables"] 		= _G.AUCTION_CATEGORY_CONSUMABLES 		-- classID  0 - LE_ITEM_CLASS_CONSUMABLE
		L["Glyphs"] 			= _G.AUCTION_CATEGORY_GLYPHS 			-- classID 16 - LE_ITEM_CLASS_GLYPH
		L["Trade Goods"] 		= _G.AUCTION_CATEGORY_TRADE_GOODS 		-- classID  7 - LE_ITEM_CLASS_TRADEGOODS
		L["Recipies"] 			= _G.AUCTION_CATEGORY_RECIPES 			-- classID  9 - LE_ITEM_CLASS_RECIPE
		L["Battle Pets"] 		= _G.AUCTION_CATEGORY_BATTLE_PETS 		-- classID 17 - LE_ITEM_CLASS_BATTLEPET
		L["Quest Items"]  		= _G.AUCTION_CATEGORY_QUEST_ITEMS 		-- classID 12 - LE_ITEM_CLASS_QUESTITEM
		L["Miscellaneous"] 		= _G.AUCTION_CATEGORY_MISCELLANEOUS 	-- classID 15 - LE_ITEM_CLASS_MISCELLANEOUS
		L["WoW Token"] 			= _G.TOKEN_FILTER_LABEL 				-- classID 18 -- can't find a global constant for this ID


		-- Weapons (2)
		L["One-Handed Axes"], L["Two-Handed Axes"], L["Bows"], L["Guns"], L["One-Handed Maces"], L["Two-Handed Maces"], 
		L["Polearms"], L["One-Handed Swords"], L["Two-Handed Swords"], L["Warglaives"], L["Staves"], 
		L["Fist Weapons"], L["Miscellaneous"], L["Daggers"], L["Thrown"], L["Crossbows"], L["Wands"], L["Fishing Poles"] = GetNamedSubClasses(2)

		-- Armor (4)
		L["Miscellaneous"], L["Cloth"], L["Leather"], L["Mail"], L["Plate"], L["Cosmetic"], L["Shields"] = GetNamedSubClasses(4)

		-- Containers (1)
		L["Bag"], L["Herb Bag"], L["Enchanting Bag"], L["Engineering Bag"], L["Gem Bag"], L["Mining Bag"], 
		L["Leatherworking Bag"], L["Inscription Bag"], L["Tackle Box"], L["Cooking Bag"] = GetNamedSubClasses(1)

		-- Gems (3)
		L["Artifact"], L["Relic"], L["Intellect"], L["Agility"], L["Strength"], L["Stamina"], 
		L["Critical Strike"], L["Mastery"], L["Haste"], L["Versatility"], L["Other"], L["Multiple Stats"] = GetNamedSubClasses(3)

		-- Item Enhancement (8)
		L["Head"], L["Neck"], L["Shoulder"], L["Cloak"], L["Chest"], L["Wrist"], L["Hands"], L["Waist"], L["Legs"], L["Feet"], L["Finger"], L["Weapon"], 
		L["Two-Handed Weapon"], L["Shield/Off-hand"], L["Misc"] = GetNamedSubClasses(8)

		-- Consumables (0)
		L["Explosives and Devices"], L["Potion"], L["Elixir"], L["Flask"], L["Food & Drink"], L["Bandage"], L["Vantus Runes"], 
		L["Other"] = GetNamedSubClasses(0)

		-- Glyph (16)
		L["Warrior"], L["Paladin"], L["Hunter"], L["Rogue"], L["Priest"], L["Shaman"], L["Mage"], L["Warlock"], L["Druid"], L["Death Knight"], 
		L["Monk"], L["Demon Hunter"] = GetNamedSubClasses(16)

		-- Trade Goods (7)
		L["Cloth"], L["Leather"], L["Metal & Stone"], L["Cooking"], L["Herb"], L["Enchanting"], L["Inscription"], L["Jewelcrafting"], 
		L["Parts"], L["Elemental"], L["Other"] = GetNamedSubClasses(7)

		-- Recipe (9)
		L["Book"], L["Leatherworking"], L["Tailoring"], L["Engineering"], L["Blacksmithing"], L["Alchemy"], L["Enchanting"], 
		L["Jewelcrafting"], L["Inscription"], L["Cooking"], L["First Aid"], L["Fishing"] = GetNamedSubClasses(9)

		-- Battle Petts (17)
		L["Humanoid"], L["Dragonkin"], L["Flying"], L["Undead"], L["Critter"], L["Magic"], L["Elemental"], L["Beast"], L["Aquatic"], 
		L["Mechanical"]  = GetNamedSubClasses(17)

		-- Quest Items (12)
		L["Quest"] = GetNamedSubClasses(12)

		-- Miscellaneous (15)
		L["Junk"], L["Reagent"], L["Companion"], L["Pets"], L["Holiday"], L["Other"], L["Mount"] = GetNamedSubClasses(15)

		-- WoW Token (18)
		L["WoW Token"] = GetNamedSubClasses(18)


		-- The following are as far as I'm aware not directly used in-game.
		-- I'm only listing them here because they exist as return values.

		-- Reagent (5)
		L["Reagent"], L["Keystone"] = GetNamedSubClasses(5) 

		-- Money (10)
		L["Money(OBSOLETE)"] = GetNamedSubClasses(10)

		-- Key (13)
		L["Key"], L["Lockpick"] = GetNamedSubClasses(13)

		-- I have no idea what this was
		L["Permanent"] = GetNamedSubClasses(14)

	elseif ENGINE_MOP then
		L["Weapon"], L["Armor"], L["Container"], L["Consumable"], L["Glyph"], L["Trade Goods"], 
		L["Recipe"], L["Gem"], L["Miscellaneous"], L["Quest"], L["Battle Pets"] = GetAuctionItemClasses()

		L["One-Handed Axes"], L["Two-Handed Axes"], L["Bows"], L["Guns"], L["One-Handed Maces"], L["Two-Handed Maces"], 
		L["Polearms"], L["One-Handed Swords"], L["Two-Handed Swords"], L["Staves"], L["Fist Weapons"], 
		L["Miscellaneous"], L["Daggers"], L["Thrown"], L["Crossbows"], L["Wands"], L["Fishing Poles"] = GetAuctionItemSubClasses(1)
		L["Miscellaneous"], L["Cloth"], L["Leather"], L["Mail"], L["Plate"], L["Cosmetic"], L["Shields"] = GetAuctionItemSubClasses(2)
		L["Bag"], L["Herb Bag"], L["Enchanting Bag"], L["Engineering Bag"], L["Gem Bag"], L["Mining Bag"], 
		L["Leatherworking Bag"], L["Inscription Bag"], L["Tackle Box"], L["Cooking Bag"] = GetAuctionItemSubClasses(3)
		L["Food & Drink"], L["Potion"], L["Elixir"], L["Flask"], L["Bandage"], L["Item Enhancement"], L["Scroll"], L["Other"] = GetAuctionItemSubClasses(4)
		L["Warrior"], L["Paladin"], L["Hunter"], L["Rogue"], L["Priest"], 
		L["Death Knight"], L["Shaman"], L["Mage"], L["Warlock"], L["Monk"], L["Druid"] = GetAuctionItemSubClasses(5)
		L["Elemental"], L["Cloth"], L["Leather"], L["Metal & Stone"], L["Cooking"], L["Herb"], L["Enchanting"], L["Jewelcrafting"], L["Parts"], 
		L["Devices"], L["Explosives"], L["Materials"], L["Other"], L["Item Enchantment"] = GetAuctionItemSubClasses(6)
		L["Book"], L["Leatherworking"], L["Tailoring"], L["Engineering"], L["Blacksmithing"], L["Cooking"], L["Alchemy"], L["First Aid"], 
		L["Enchanting"], L["Fishing"], L["Jewelcrafting"], L["Inscription"] = GetAuctionItemSubClasses(7)
		L["Red"], L["Blue"], L["Yellow"], L["Purple"], L["Green"], L["Orange"], L["Meta"], L["Simple"], L["Prismatic"], L["Cogwheel"] = GetAuctionItemSubClasses(8)
		L["Junk"], L["Reagent"], L["Companion"], L["Pets"], L["Holiday"], L["Other"], L["Mount"] = GetAuctionItemSubClasses(9)

	elseif ENGINE_CATA then
		L["Weapon"], L["Armor"], L["Container"], L["Consumable"], L["Glyph"], L["Trade Goods"], 
		L["Recipe"], L["Gem"], L["Miscellaneous"], L["Quest"] = GetAuctionItemClasses()

		L["One-Handed Axes"], L["Two-Handed Axes"], L["Bows"], L["Guns"], L["One-Handed Maces"], L["Two-Handed Maces"], 
		L["Polearms"], L["One-Handed Swords"], L["Two-Handed Swords"], L["Staves"], L["Fist Weapons"], 
		L["Miscellaneous"], L["Daggers"], L["Thrown"], L["Crossbows"], L["Wands"], L["Fishing Poles"] = GetAuctionItemSubClasses(1)
		L["Miscellaneous"], L["Cloth"], L["Leather"], L["Mail"], L["Plate"], L["Shields"], L["Relic"] = GetAuctionItemSubClasses(2)
		L["Bag"], L["Herb Bag"], L["Enchanting Bag"], L["Engineering Bag"], L["Gem Bag"], L["Mining Bag"], 
		L["Leatherworking Bag"], L["Inscription Bag"], L["Tackle Box"] = GetAuctionItemSubClasses(3)
		L["Food & Drink"], L["Potion"], L["Elixir"], L["Flask"], L["Bandage"], L["Item Enhancement"], L["Scroll"], L["Other"] = GetAuctionItemSubClasses(4)
		L["Warrior"], L["Paladin"], L["Hunter"], L["Rogue"], L["Priest"], 
		L["Death Knight"], L["Shaman"], L["Mage"], L["Warlock"], L["Druid"] = GetAuctionItemSubClasses(5)
		L["Elemental"], L["Cloth"], L["Leather"], L["Metal & Stone"], L["Meat"], L["Herb"], L["Enchanting"], L["Jewelcrafting"], L["Parts"], 
		L["Devices"], L["Explosives"], L["Materials"], L["Other"], L["Item Enchantment"] = GetAuctionItemSubClasses(6)
		L["Book"], L["Leatherworking"], L["Tailoring"], L["Engineering"], L["Blacksmithing"], L["Cooking"], L["Alchemy"], L["First Aid"], 
		L["Enchanting"], L["Fishing"], L["Jewelcrafting"], L["Inscription"] = GetAuctionItemSubClasses(7)
		L["Red"], L["Blue"], L["Yellow"], L["Purple"], L["Green"], L["Orange"], L["Meta"], L["Simple"], L["Prismatic"], L["Cogwheel"] = GetAuctionItemSubClasses(8)
		L["Junk"], L["Reagent"], L["Pet"], L["Holiday"], L["Other"], L["Mount"] = GetAuctionItemSubClasses(9)

	else
		L["Weapon"], L["Armor"], L["Container"], L["Consumable"], L["Glyph"], L["Trade Goods"], 
		L["Projectile"], L["Quiver"], L["Recipe"], L["Gem"], L["Miscellaneous"], L["Quest"] = GetAuctionItemClasses()

		L["One-Handed Axes"], L["Two-Handed Axes"], L["Bows"], L["Guns"], L["One-Handed Maces"], L["Two-Handed Maces"], 
		L["Polearms"], L["One-Handed Swords"], L["Two-Handed Swords"], L["Staves"], L["Fist Weapons"], 
		L["Miscellaneous"], L["Daggers"], L["Thrown"], L["Crossbows"], L["Wands"], L["Fishing Poles"] = GetAuctionItemSubClasses(1)
		L["Miscellaneous"], L["Cloth"], L["Leather"], L["Mail"], L["Plate"], L["Shields"], L["Librams"], L["Idols"], L["Totems"], L["Sigils"] = GetAuctionItemSubClasses(2)
		L["Bag"], L["Soul Bag"], L["Herb Bag"], L["Enchanting Bag"], L["Engineering Bag"], L["Gem Bag"], L["Mining Bag"], 
		L["Leatherworking Bag"], L["Inscription Bag"] = GetAuctionItemSubClasses(3)
		L["Food & Drink"], L["Potion"], L["Elixir"], L["Flask"], L["Bandage"], L["Item Enhancement"], L["Scroll"], L["Other"] = GetAuctionItemSubClasses(4)
		L["Warrior"], L["Paladin"], L["Hunter"], L["Rogue"], L["Priest"], 
		L["Death Knight"], L["Shaman"], L["Mage"], L["Warlock"], L["Druid"] = GetAuctionItemSubClasses(5)
		L["Elemental"], L["Cloth"], L["Leather"], L["Metal & Stone"], L["Meat"], L["Herb"], L["Enchanting"], L["Jewelcrafting"], L["Parts"], 
		L["Devices"], L["Explosives"], L["Materials"], L["Other"], L["Armor Enchantment"], L["Weapon Enchantment"] = GetAuctionItemSubClasses(6)
		L["Arrow"], L["Bullet"] = GetAuctionItemSubClasses(7) 
		L["Quiver"], L["Ammo"], L["Pouch"] = GetAuctionItemSubClasses(8)
		L["Book"], L["Leatherworking"], L["Tailoring"], L["Engineering"], L["Blacksmithing"], L["Cooking"], L["Alchemy"], L["First Aid"], 
		L["Enchanting"], L["Fishing"], L["Jewelcrafting"], L["Inscription"] = GetAuctionItemSubClasses(9)
		L["Red"], L["Blue"], L["Yellow"], L["Purple"], L["Green"], L["Orange"], L["Meta"], L["Simple"], L["Prismatic"] = GetAuctionItemSubClasses(10)
		L["Junk"], L["Reagent"], L["Pet"], L["Holiday"], L["Other"], L["Mount"] = GetAuctionItemSubClasses(11)

	end

	return L
end

