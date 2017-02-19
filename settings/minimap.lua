local Addon, Engine = ...
local C = Engine:GetStaticConfig("Data: Colors")
local path = ([[Interface\AddOns\%s\media\]]):format(Addon)
local MINIMAP_SIZE = Engine:GetConstant("MINIMAP_SIZE") 

Engine:NewStaticConfig("Minimap", {
	size = { MINIMAP_SIZE, MINIMAP_SIZE }, 
	point = { "TOPRIGHT", "UICenter", "TOPRIGHT", -20, -64 }, -- -20, -50
	map = {
		size = { MINIMAP_SIZE + 10, MINIMAP_SIZE + 10 }, 
		point = { "TOPLEFT", -5, 5 },
		mask = path..[[textures\DiabolicUI_Minimap_316x316_Mask.tga]]
	},
	widgets = {
		group = {
			size = { 60, 30 },
			point = { "BOTTOMLEFT", "Minimap", "BOTTOMLEFT", 16.5, 4.5 }, 
			fontAnchor = { "BOTTOMLEFT", "Minimap", "BOTTOMLEFT", 16.5, 13.5 },
			fontColor = C.General.Highlight, 
			normalFont = DiabolicFont_SansRegular12
		},
		mail = {
			size = { 40, 40 },
			point = { "BOTTOMRIGHT", -12, 10 }, 
			texture = path .. [[textures\DiabolicUI_40x40_MenuIconGrid.tga]],
			texture_size = { 256, 256 },
			texcoord = { 0/255, 39/255, 120/255, 159/255 }
		},
		worldmap = {
			size = { 40, 40 },
			point = { "TOPRIGHT", -12, -10 }, 
			texture = path .. [[textures\DiabolicUI_40x40_MenuIconGrid.tga]],
			texture_size = { 256, 256 },
			texcoord = { 200/255, 239/255, 0/255, 39/255 }
		}
	},
	text = {
		zone = {
			point = { "TOPRIGHT", "UICenter", "TOPRIGHT", -23.5, -(10.5 + 12) },
			normalFont = DiabolicFont_HeaderRegular16
		},
		time = {
			point = { "TOPRIGHT", "UICenter", "TOPRIGHT", -23.5, -(30.5 + 10) },
			normalFont = DiabolicFont_SansRegular14
		},
		coordinates = {
			point = { "BOTTOM", "Minimap", "BOTTOM", 0, 12.5 },
			normalFont = DiabolicFont_SansBold12
		}
	},
	textures = {
		backdrop = {
			size = { 256, 256 },
			point = { "TOPLEFT", -48, 48 },
			path = path..[[textures\DiabolicUI_Minimap_160x160_Backdrop.tga]]
		},
		border = {
			size = { 256, 256 },
			point = { "TOPLEFT", -48, 48 },
			path = path..[[textures\DiabolicUI_Minimap_160x160_Border.tga]]
		}
	}	
})

