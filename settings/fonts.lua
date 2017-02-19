local Addon, Engine = ...
local path = ([[Interface\AddOns\%s\media\fonts\]]):format(Addon)

Engine:NewStaticConfig("Fonts", {
	fonts = {
		text_normal = {
			path = path .. "NotoSans-Bold.ttf", -- DejaVuSans
			locales = {
				enUS  = true,
				enGB = true,
				deDE = true,
				esES = true,
				esMX = true,
				frFR = true,
				itIT = true,
				ptBR = true,
				ptPT = true,
				ruRU = true
			}
		},
		text_narrow = {
			path = path .. "NotoSans-Bold.ttf", -- DejaVuSansCondensed
			locales = {
				enUS  = true,
				enGB = true,
				deDE = true,
				esES = true,
				esMX = true,
				frFR = true,
				itIT = true,
				ptBR = true,
				ptPT = true,
				ruRU = true
			}
		},
		text_serif = {
			path = path .. "NotoSans-Bold.ttf", -- DejaVuSerifCondensed
			locales = {
				enUS  = true,
				enGB = true,
				deDE = true,
				esES = true,
				esMX = true,
				frFR = true,
				itIT = true,
				ptBR = true,
				ptPT = true,
				ruRU = true
			}
		},
		text_serif_italic = {
			path = path .. "NotoSans-Bold.ttf", -- DejaVuSerifCondensed-Italic
			locales = {
				enUS  = true,
				enGB = true,
				deDE = true,
				esES = true,
				esMX = true,
				frFR = true,
				itIT = true,
				ptBR = true,
				ptPT = true,
				ruRU = true
			}
		},
		header_normal = {
			path = path .. "ExocetBlizzardMedium.ttf",
			locales = {
				enUS  = true,
				enGB = true,
				deDE = true,
				esES = true,
				esMX = true,
				frFR = true,
				itIT = true,
				ptBR = true,
				ptPT = true,
				ruRU = true,
				koKR = true,
				zhTW = true
			}
		},
		header_light = {
			path = path .. "ExocetBlizzardLight.ttf",
			locales = {
				enUS  = true,
				enGB = true,
				deDE = true,
				esES = true,
				esMX = true,
				frFR = true,
				itIT = true,
				ptBR = true,
				ptPT = true,
				ruRU = true,
				koKR = true,
				zhTW = true
			}
		},
		number = {
			path = path .. "Sylfaen.ttf",
			locales = {
				enUS = true,
				enGB = true,
				deDE = true,
				esES = true,
				esMX = true,
				frFR = true,
				itIT = true,
				ptBR = true,
				ptPT = true,
				ruRU = true
			}
		},
		damage = {
			path = path .. "Coalition.ttf", -- Coalition has high res
			locales = {
				enUS = true,
				enGB = true,
				deDE = true,
				esES = true,
				esMX = true,
				frFR = true,
				itIT = true,
				ptBR = true,
				ptPT = true
			}
		}
	}
})
