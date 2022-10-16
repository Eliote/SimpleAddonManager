-- Default locale
local ADDON_NAME, PRIVATE_TABLE = ...

if GetLocale() ~= "esES" then
	return
end

local L = PRIVATE_TABLE.L

--@localization(locale="esES", format="lua_additive_table")@
