-- Default locale
local ADDON_NAME, PRIVATE_TABLE = ...
local L = {}
local localizationMetatable = {
	__index = function(_, key)
		return key
	end,
	__call = function(self, locale, tab)
		return (self[locale]:gsub('($%b{})', function(w)
			return tab[w:sub(3, -2)] or w
		end))
	end
}
setmetatable(L, localizationMetatable)

PRIVATE_TABLE.L = L
