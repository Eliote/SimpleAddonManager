-- Default locale
local ADDON_NAME, PRIVATE_TABLE = ...

if GetLocale() ~= "zhCN" then
	return
end

local L = PRIVATE_TABLE.L

--@localization(locale="zhCN", format="lua_additive_table")@
