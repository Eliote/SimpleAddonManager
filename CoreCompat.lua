local _, T = ...

--- @type SimpleAddonManager
local frame = T.AddonFrame

frame.compat = {
	EnableAddOn = EnableAddOn or C_AddOns.EnableAddOn,
	DisableAddOn = DisableAddOn or C_AddOns.DisableAddOn,
	IsAddOnLoaded = IsAddOnLoaded or C_AddOns.IsAddOnLoaded,
	EnableAllAddOns = EnableAllAddOns or C_AddOns.EnableAllAddOns,
	DisableAllAddOns = DisableAllAddOns or C_AddOns.DisableAllAddOns,
	GetAddOnInfo = GetAddOnInfo or C_AddOns.GetAddOnInfo,
	GetAddOnDependencies = GetAddOnDependencies or C_AddOns.GetAddOnDependencies,
	GetNumAddOns = GetNumAddOns or C_AddOns.GetNumAddOns,
	SaveAddOns = SaveAddOns or C_AddOns.SaveAddOns,
	ResetAddOns = ResetAddOns or C_AddOns.ResetAddOns,
	IsAddonVersionCheckEnabled = IsAddonVersionCheckEnabled or C_AddOns.IsAddonVersionCheckEnabled,
	SetAddonVersionCheck = SetAddonVersionCheck or C_AddOns.SetAddonVersionCheck,
	IsAddOnLoadOnDemand = IsAddOnLoadOnDemand or C_AddOns.IsAddOnLoadOnDemand,
}

local GetAddOnEnableState
if (GetAddOnEnableState ~= nil) then
	frame.compat.GetAddOnEnableState = function(nameOrIndex, character)
		GetAddOnEnableState(character, nameOrIndex) -- the old API has inverted parameters
	end
else
	frame.compat.GetAddOnEnableState = C_AddOns.GetAddOnEnableState
end