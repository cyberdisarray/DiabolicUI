local ADDON, Engine = ...
local path = ([[Interface\AddOns\%s\media\]]):format(ADDON)

-- Lua API
local math_ceil = math.ceil

Engine:NewStaticConfig("NamePlates", {
	size = { 64 + 8, 8 + 4 + 8 },
	widgets = {
		health = {
			size = { 64 + 8, 8 },
			place = { "TOPLEFT", 0, 0 },
			value = {
				fontObject = DiabolicUnitFrameNumberSmall
			}
		},
		cast = {
			size = { 64 - 8, 8 },
			place = { "TOPLEFT", 0, -(8 + 4) }
		},
		auras = {
			place = { "TOP", 0, 4 + 12 + 4 + 28 }, -- above the name
			rowsize = math_ceil((64 + 8 + 4)/(28 + 2)), -- maximum number of auras per row
			padding = 2, -- space between auras
			button = {
				size = { 28, 28 },
				anchor = "BOTTOMLEFT", 
				icon = {
					size = { 22, 22 }, -- should be main size - 6
					texCoord = { 5/64, 59/64, 5/64, 59/64 },
					place = { "TOPLEFT", 2, -2 } -- relative to the scaffold, which is 1px inset into the button
				},
				time = {
					place = { "TOPLEFT", 1, -1 }, 
					fontObject = GameFontNormalSmall,
					fontStyle = "THINOUTLINE",
					fontSize = 9,
					shadowOffset = { 1.25, -1.25 },
					shadowColor = { 0, 0, 0, 1 }
				},
				count = {
					place = { "BOTTOMRIGHT", -1, 1 }, 
					fontObject = GameFontNormalSmall,
					fontStyle = "THINOUTLINE",
					fontSize = 9,
					shadowOffset = { 1.25, -1.25 },
					shadowColor = { 0, 0, 0, 1 }
				}
			}
		},
	},
	textures = {
		bar_shade = {
			size = { 128 + 16, 32 },
			position = { "CENTER", 0, 4 },
			color = { 0, 0, 0, .5 },
			path = path .. [[textures\DiabolicUI_Tooltip_Header_TitleBackground.tga]]
		},
		bar_glow = {
			size = { 128 + 16, 32 },
			position = { "TOP", 0, 12 }, -- TOPLEFT, -32, 12
			path = path .. [[statusbars\DiabolicUI_StatusBar_64x8_Glow_Warcraft.tga]]
		},
		bar_backdrop = {
			size = { 64 + 8, 8 },
			position = { "TOPLEFT", 0, 0 },
			path = path .. [[statusbars\DiabolicUI_StatusBar_64x8_Backdrop_Warcraft.tga]]
		},
		bar_texture = {
			size = { 64 + 8, 8 },
			position = { "TOPLEFT", 0, 0 },
			path = path .. [[statusbars\DiabolicUI_StatusBar_64x8_Normal_Warcraft.tga]]
		},
		bar_overlay = {
			size = { 64 + 8, 8 },
			position = { "TOPLEFT", 0, 0 },
			path = path .. [[statusbars\DiabolicUI_StatusBar_64x8_Overlay_Warcraft.tga]]
		},
		bar_threat = {
			size = { 64 + 8, 8 },
			position = { "TOPLEFT", 0, 0 },
			path = path .. [[statusbars\DiabolicUI_StatusBar_64x8_Threat_Warcraft.tga]]
		},
		cast_border = {
			size = {},
			position = {},
			path = path .. [[statusbars\]]
		},
		cast_shield = {
			size = {},
			position = {},
			path = path .. [[statusbars\]]
		}
	}
})

