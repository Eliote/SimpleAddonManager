local _, T = ...

--- @type SimpleAddonManager
local SAM = T.AddonFrame

local function getFunction(fun)
	return (C_AddOns and C_AddOns[fun]) or _G[fun]
end

SAM.compat = {
	EnableAddOn = getFunction("EnableAddOn"),
	DisableAddOn = getFunction("DisableAddOn"),
	IsAddOnLoaded = getFunction("IsAddOnLoaded"),
	EnableAllAddOns = getFunction("EnableAllAddOns"),
	DisableAllAddOns = getFunction("DisableAllAddOns"),
	GetAddOnInfo = getFunction("GetAddOnInfo"),
	GetAddOnDependencies = getFunction("GetAddOnDependencies"),
	GetNumAddOns = getFunction("GetNumAddOns"),
	SaveAddOns = getFunction("SaveAddOns"),
	ResetAddOns = getFunction("ResetAddOns"),
	IsAddonVersionCheckEnabled = getFunction("IsAddonVersionCheckEnabled"),
	SetAddonVersionCheck = getFunction("SetAddonVersionCheck"),
	IsAddOnLoadOnDemand = getFunction("IsAddOnLoadOnDemand"),
	GetAddOnEnableState = (C_AddOns and C_AddOns.GetAddOnEnableState) or function(nameOrIndex, character)
		return GetAddOnEnableState(character, nameOrIndex) -- the old API has inverted parameters
	end
}
