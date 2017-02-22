local ADDON, Engine = ...
local path = ([[Interface\AddOns\%s\media\]]):format(ADDON)
local MINIMAP_SIZE = Engine:GetConstant("MINIMAP_SIZE") 

Engine:NewStaticConfig("Objectives", {
	-- This will contain both current pvp objectives (flags, timers, points, etc), 
	-- waves of enemies in dungeons and raid instances, 
	-- as well as class order hall information. 
	zoneinfo = {

	},

	-- Our own custom quest and objectives tracker. 
	-- As most other things this is a work in progress, 
	-- and elements will be added as they are created. 
	tracker = {
		size = {},
		points = {
			{ "TOPRIGHT", "UICenter", "TOPRIGHT", -(20 + 1.5), -(64 + MINIMAP_SIZE + 10) },
			{ "TOPLEFT", "UICenter", "TOPRIGHT", -(20 + MINIMAP_SIZE - 3), -(64 + MINIMAP_SIZE + 10) },
			{ "BOTTOMRIGHT", "UICenter", "BOTTOMRIGHT", -(20 + 3.5), 220 } 
		},
		header = {
			height = 25,
			points = {
				{ "TOPLEFT", 0, 0 },
				{ "TOPRIGHT", 0, 0 }
			},
			title = {
				position = { "LEFT", 0, 0 },
				normalFont = DiabolicFont_HeaderRegular16White
			},
			button = {
				size = { 22, 21 },
				position = { "RIGHT", -4, 0 },
				textureSize = { 32, 32 },
				texturePosition = { "CENTER", 0, 0 }, 
				textures = {
					enabled = path .. [[textures\DiabolicUI_ExpandCollapseButton_22x21.tga]],
					disabled = path .. [[textures\DiabolicUI_ExpandCollapseButton_22x21_Disabled.tga]]
				},
				texcoords = {
					maximized = { 0/64, 32/64, 0/64, 32/64 },
					minimized = { 0/64, 32/64, 32/64, 64/64 },
					maximizedHighlight = { 32/64, 64/64, 0/64, 32/64 },
					minimizedHighlight = { 32/64, 64/64, 32/64, 64/64 },
					disabled = { 0, 1, 0, 1 }
				}
			}
		},
		body = {
			margins = {
				left = 0, 
				right = 0,
				top = -2,
				bottom = 0
			},
			entry = {
				topMargin = 16,

				-- Flashing message ("NEW!", "UPDATE!", "COMPLET!" and so on)
				flash = {
					height = 18,
					normalFont = DiabolicFont_HeaderRegular18Text
				},
				-- Quest/Objective titles
				title = {
					height = 12,
					maxLines = 6,
					lineSpacing = 7,
					leftMargin = 0, 
					rightMargin = 56, -- space for quest items
					normalFont = DiabolicFont_SansRegular12Title
				},
				item = {
					size = { 26, 26 },
					glow = {
						size = { 32, 32 },
						backdrop = {
							bgFile = nil, 
							edgeFile = path .. [[textures\DiabolicUI_GlowBorder_128x16.tga]],
							edgeSize = 4,
							tile = false,
							tileSize = 0,
							insets = {
								left = 0,
								right = 0,
								top = 0,
								bottom = 0
							}
						}
					},
					border = {
						size = { 26, 26 },
						backdrop = {
							bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
							edgeFile = [[Interface\ChatFrame\ChatFrameBackground]],
							edgeSize = 1,
							tile = false,
							tileSize = 0,
							insets = {
								left = -1,
								right = -1,
								top = -1,
								bottom = -1
							}
						}
					},
					shade = path .. [[textures\DiabolicUI_Shade_64x64.tga]]
				},
				-- Objectives (e.g "Kill many wolves: 0/many")
				objective = {
					topOffset = 10, -- offset of first objective from title
					height = 12,
					maxLines = 6,
					lineSpacing = 4,
					leftMargin = 30, -- space for dots
					rightMargin = 56, -- space for quest items
					topMargin = 6, -- margin before every objective
					bottomMargin = 12, -- margin after ALL objectives are listed
					dotAdjust = -2,
					normalFont = DiabolicFont_SansRegular12White
				},
				-- Completed quest (e.g "Return to some NPC at some place")
				-- This has pretty much the same settings as the objectives, 
				-- but we separate them since I intend to upgrade it later.
				complete = {
					height = 12,
					maxLines = 6,
					lineSpacing = 4,
					leftMargin = 30, -- space for dots
					rightMargin = 56, -- space for quest items,
					topMargin = 10,
					bottomMargin = 0, -- something else is being added, can't seem to figure out what :S 
					dotAdjust = -2,
					normalFont = DiabolicFont_SansRegular12White
				}
			}
		}
	}
})
