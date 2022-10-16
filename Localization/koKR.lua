-- Default locale
local ADDON_NAME, PRIVATE_TABLE = ...

if GetLocale() ~= "koKR" then
	return
end

local L = PRIVATE_TABLE.L

--@localization(locale="koKR", format="lua_additive_table")@
