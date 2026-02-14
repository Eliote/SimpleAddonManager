local ADDON_NAME, T = ...
local L = T.L

--- @type SimpleAddonManager
local SAM = T.AddonFrame
local module = SAM:RegisterModule("Main")

local function CharacterDropDownGenerator(owner, root)
	local charList = SAM:GetCharList()
	for i, v in ipairs(charList) do
		local zeroIndex = i - 1
		if (zeroIndex == 2) then
			root:CreateDivider()
		end
		local name = v.name
		local coloredName = name
		if (v.class) then
			local _, _, _, hex = GetClassColor(v.class)
			coloredName = "|c" .. hex .. coloredName .. "|r"
		end

		root:CreateRadio(
			coloredName,
			function(index)
				return SAM:GetSelectedCharIndex() == index
			end,
			function(index)
				SAM:InitAddonStateFor(v.guid)
				SAM:SetSelectedCharIndex(index)
				SAM.AddonListFrame.ScrollFrame.update()
			end,
			zeroIndex
		)
	end
end

function SAM:DidAddonStateChanged(addonNameOrIndex, charGuid)
	local initiallyEnabledAddons = SAM:GetAddonsInitialState(charGuid)
	local state = SAM:IsAddonSelected(addonNameOrIndex, nil, charGuid)
	local name = SAM.compat.GetAddOnInfo(addonNameOrIndex)
	local initialState = initiallyEnabledAddons[name]
	if (state ~= initialState) then
		return true
	end
end

function SAM:DidAnyAddonStateChanged(charGuid)
	for addonIndex = 1, SAM.compat.GetNumAddOns() do
		if (SAM:DidAddonStateChanged(addonIndex, charGuid)) then
			return true
		end
	end
end

function SAM:UpdateOkButton()
	if (SAM:DidAnyAddonStateChanged(SAM:GetLoggedCharGuid())) then
		SAM.edited = true
		SAM.OkButton:SetText(L["Reload UI"])
	else
		SAM.edited = false
		SAM.OkButton:SetText(OKAY)
	end
end

function module:PreInitialize()
	SAM.Sizer = CreateFrame("Button", nil, SAM, "PanelResizeButtonTemplate")
	SAM.CharacterDropDown = CreateFrame("DropdownButton", nil, SAM, "WowStyle1DropdownTemplate")
	SAM.CancelButton = CreateFrame("Button", nil, SAM, "UIPanelButtonTemplate")
	SAM.OkButton = CreateFrame("Button", nil, SAM, "UIPanelButtonTemplate")
	SAM.EnableAllButton = CreateFrame("Button", nil, SAM, "UIPanelButtonTemplate")
	SAM.DisableAllButton = CreateFrame("Button", nil, SAM, "UIPanelButtonTemplate")
end

function module:Initialize()
	local addonName = SAM:GetAddOnMetadata(ADDON_NAME, "Title")
	if (SAM.TitleText) then
		SAM.TitleText:SetText(addonName)
	elseif (SAM.TitleContainer and SAM.TitleContainer.TitleText) then
		SAM.TitleContainer.TitleText:SetText(addonName)
	end

	SAM.Sizer:SetScript("OnMouseDown", function()
		SAM:StartSizing("BOTTOMRIGHT", true)
	end)
	SAM.Sizer:SetScript("OnMouseUp", function()
		SAM:StopMovingOrSizing()
	end)
	SAM.Sizer:SetPoint("BOTTOMRIGHT", -4, 4)

	SAM.CharacterDropDown:SetPoint("TOPLEFT", 10, -30)
	SAM.CharacterDropDown:SetWidth(120)
	SAM.CharacterDropDown:SetupMenu(CharacterDropDownGenerator)

	SAM.CancelButton:SetPoint("BOTTOMRIGHT", -22, 4)
	SAM.CancelButton:SetSize(100, 22)
	SAM.CancelButton:SetText(CANCEL)
	SAM.CancelButton:SetScript("OnClick", function()
		SAM:GetModule("Lock"):RollbackChanges()

		SAM.compat.ResetAddOns()
		SAM.AddonListFrame.ScrollFrame.update()
		SAM:Hide()
	end)

	SAM.OkButton:SetPoint("TOPRIGHT", SAM.CancelButton, "TOPLEFT", 0, 0)
	SAM.OkButton:SetSize(100, 22)
	SAM.OkButton:SetText(OKAY)
	SAM.OkButton:SetScript("OnClick", function()
		SAM:GetModule("Lock"):ConfirmChanges()

		SAM.compat.SaveAddOns()
		if (SAM.edited) then
			ReloadUI()
		else
			SAM:ClearInitialState()
			SAM.AddonListFrame.ScrollFrame.update()
			SAM:Hide()
		end
	end)

	SAM.EnableAllButton:SetPoint("BOTTOMLEFT", 6, 4)
	SAM.EnableAllButton:SetSize(120, 22)
	SAM.EnableAllButton:SetText(ENABLE_ALL_ADDONS)
	SAM.EnableAllButton:SetScript("OnClick", function()
		for _, addon in pairs(SAM:GetAddonsList()) do
			if (not addon.isSecure) then
				SAM:EnableAddOn(addon.index)
			end
		end
		SAM:Update()
	end)

	SAM.DisableAllButton:SetPoint("TOPLEFT", SAM.EnableAllButton, "TOPRIGHT", 0, 0)
	SAM.DisableAllButton:SetSize(120, 22)
	SAM.DisableAllButton:SetText(DISABLE_ALL_ADDONS)
	SAM.DisableAllButton:SetScript("OnClick", function()
		local addonsList = SAM:GetAddonsList()
		local isSAMLocked = SAM:GetModule("Lock"):IsAddonLocked(ADDON_NAME)
		local disablingMe = false

		-- if SAM is locked, there's no need to ask if you want to keep it. [DisableAddon] will ignore it!
		if (not isSAMLocked) then
			for _, addon in pairs(addonsList) do
				if (addon.key == ADDON_NAME) then
					disablingMe = SAM:IsAddonSelected(ADDON_NAME)
					break
				end
			end
		end
		local function disableList()
			for _, addon in pairs(addonsList) do
				if (not addon.isSecure) then
					SAM:DisableAddOn(addon.index)
				end
			end
			SAM:Update()
		end
		if (disablingMe) then
			SAM:ShowYesNoDialog(
					L["Also disable Simple Addon Manager?"],
					function()
						disableList()
					end,
					function()
						disableList()
						SAM:EnableAddOn(ADDON_NAME)
					end
			)
		else
			disableList()
		end
	end)
end
