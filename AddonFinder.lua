local ADDON_NAME, T = ...
local L = T.L
local C = T.Color

--- @type SimpleAddonManager
local frame = T.AddonFrame
local module = frame:RegisterModule("AddonFinder")

function module:StopSearch()
	local db = frame:GetDb()
	for addon, v in pairs(db.addonFinder.initialAddons) do
		if (v.selected) then
			frame:EnableAddOn(addon)
		end
	end
	db.addonFinder.isSearching = false
end

function module:StartSearch()
	local db = frame:GetDb()
	if (db.addonFinder and db.addonFinder.isSearching) then
		local searching = db.addonFinder.searchingAddons
		frame:ShowYesNoCancelDialog(
				L(
						"Search in progress...\nStatus: enabled: ${enabled}, disabled: ${disabled}\nThe addon you are looking for has been disabled?",
						{
							enabled = (searching.enabled and #searching.enabled) or 0,
							disabled = (searching.disabled and #searching.disabled) or 0,
						}
				),
				function()
					module:ContinueSearch(true)
					return true
				end,
				function()
					module:ContinueSearch(false)
					return true
				end,
				function()
					module:StopSearch()
					ReloadUI()
				end
		)
	else
		frame:ShowConfirmDialog(
				L["Start binary search?\nMake sure to save your profile first, just in case."],
				function()
					local addons = {}
					local activeAddons = {}
					for i = 1, frame.compat.GetNumAddOns() do
						local name, _, _, loadable, reason = frame.compat.GetAddOnInfo(i)
						local selected = frame:IsAddonSelected(name)
						addons[name] = {
							selected = selected,
						}
						local isLoaded = loadable or reason == "DEMAND_LOADED"
						if (selected and isLoaded) then
							table.insert(activeAddons, name)
						end
					end
					db.addonFinder = {
						isSearching = true,
						initialAddons = addons,
						searchingAddons = {
							enabled = {},
							disabled = {},
						}
					}
					module:BinarySearch(activeAddons)
				end
		)
	end
end

function module:BinarySearch(addons)
	if (#addons <= 1) then
		return
	end
	frame:DisableAllAddOns()
	frame:EnableAddOn(ADDON_NAME)
	local half = #addons / 2
	local enabled = {}
	local disabled = {}
	for i, v in ipairs(addons) do
		if (i <= half) then
			frame:EnableAddOn(v)
			table.insert(enabled, v)
		else
			table.insert(disabled, v)
		end
	end
	local db = frame:GetDb()
	db.addonFinder.searchingAddons = {
		enabled = enabled,
		disabled = disabled,
	}
	ReloadUI()
end

function module:ContinueSearch(answer)
	local db = frame:GetDb()
	local addons
	if (answer) then
		addons = db.addonFinder.searchingAddons.disabled or {}
	else
		addons = db.addonFinder.searchingAddons.enabled or {}
	end
	if (#addons <= 1) then
		module:StopSearch()
		frame:Update()
		frame:ShowConfirmDialog(
				L("Result: ${name}", { name = addons[1] or L["Not Found!"] })  .. "\n" .. L["Your AddOns were restored, reload UI?"],
				function()
					ReloadUI()
				end
		)
	else
		module:BinarySearch(addons)
	end
end

frame:HookScript("OnShow", function()
	local db = frame:GetDb()
	if (db.addonFinder and db.addonFinder.isSearching) then
		module:StartSearch()
	end
end)