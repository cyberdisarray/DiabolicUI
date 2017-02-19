local ADDON, Engine = ...
local path = ([[Interface\AddOns\%s\media\]]):format(ADDON)

-- The purpose of this database is to contain static values 
-- with information about layout, sizes, textures, etc, 
-- that several modules in the UI need access to, 
-- without having to rely on any of those modules 
-- to provide those values.

Engine:NewStaticConfig("Data: Constants", {
	-- Maps
	MINIMAP_SIZE = 290, -- size of the big Minimap

	-- ActionButton Sizes
	BUTTON_SIZE_VEHICLE = 64, -- button size with a vehicle UI
	BUTTON_SIZE_SINGLE = 50, -- button size with a single action bar
	BUTTON_SIZE_DOUBLE = 44, -- button size with two action bars
	BUTTON_SIZE_TRIPLE = 36, -- button size with three action bars

	-- ActionButton Numbers
	NUM_ACTIONBAR_SLOTS = NUM_ACTIONBAR_BUTTONS or 12, -- number of buttons on a standard bar
	NUM_PET_SLOTS = NUM_PET_ACTION_SLOTS or 10, -- number of pet buttons
	NUM_POSSESS_SLOTS = NUM_POSSESS_SLOTS or 2, -- number of possess buttons
	NUM_STANCE_SLOTS = NUM_SHAPESHIFT_SLOTS or 10, -- number of stance buttons
	NUM_VEHICLE_SLOTS = VEHICLE_MAX_ACTIONBUTTONS or 6, -- number of vehicle buttons

	-- Textures
	BLANK_TEXTURE = [[Interface\ChatFrame\ChatFrameBackground]], -- used as a single color texture
	EMPTY_TEXTURE = path .. [[textures\DiabolicUI_Texture_16x16_Empty.tga]]	-- Used to hide UI elements

})
