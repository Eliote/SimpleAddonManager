-- Default locale
local ADDON_NAME, PRIVATE_TABLE = ...

if GetLocale() ~= "deDE" then
	return
end

local L = PRIVATE_TABLE.L

--@localization(locale="deDE", format="lua_additive_table")@
