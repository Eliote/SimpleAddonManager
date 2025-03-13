-- Default locale
local ADDON_NAME, PRIVATE_TABLE = ...

if GetLocale() ~= "ruRU" then
	return
end

local L = PRIVATE_TABLE.L

--@localization(locale="ruRU", format="lua_additive_table")@
