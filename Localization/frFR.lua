-- Default locale
local ADDON_NAME, PRIVATE_TABLE = ...

if GetLocale() ~= "frFR" then
	return
end

local L = PRIVATE_TABLE.L

--@localization(locale="frFR", format="lua_additive_table")@
