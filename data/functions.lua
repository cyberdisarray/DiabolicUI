local _, Engine = ...
local C = Engine:GetStaticConfig("Data: Colors")
local F = {}


-- Lua API
local math_floor = math.floor
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack

-- Get the current client locale
local gameLocale = GetLocale()



-- Number abbreviations
---------------------------------------------------------------------	
F.Short = (gameLocale == "zhCN") and function(value)
	value = tonumber(value)
	if not value then return "" end
	if value >= 1e8 then
		return ("%.1f亿"):format(value / 1e8):gsub("%.?0+([km])$", "%1")
	elseif value >= 1e4 or value <= -1e3 then
		return ("%.1f万"):format(value / 1e4):gsub("%.?0+([km])$", "%1")
	else
		return tostring(math_floor(value))
	end 
end

or function(value)
	value = tonumber(value)
	if not value then return "" end
	if value >= 1e9 then
		return ("%.1fb"):format(value / 1e9):gsub("%.?0+([kmb])$", "%1")
	elseif value >= 1e6 then
		return ("%.1fm"):format(value / 1e6):gsub("%.?0+([kmb])$", "%1")
	elseif value >= 1e3 or value <= -1e3 then
		return ("%.1fk"):format(value / 1e3):gsub("%.?0+([kmb])$", "%1")
	else
		return tostring(math_floor(value))
	end	
end


-- Colorize a piece of text with the given color
---------------------------------------------------------------------
F.Colorize = function(str, ...)
	local r, g, b = ...
	if type(r) == "table" then
		r, g, b = unpack(r)
	elseif type(r) == "string" then
		r, g, b = unpack(C.General[r])
	end
	return ("|cff%02X%02X%02X%s|r"):format(math_floor(r*255), math_floor(g*255), math_floor(b*255), str)
end



Engine:NewStaticConfig("Data: Functions", F)
