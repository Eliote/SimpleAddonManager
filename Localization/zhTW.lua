-- Default locale
local ADDON_NAME, PRIVATE_TABLE = ...

if GetLocale() ~= "zhTW" then
	return
end

local L = PRIVATE_TABLE.L

--@localization(locale="zhTW", format="lua_additive_table")@
