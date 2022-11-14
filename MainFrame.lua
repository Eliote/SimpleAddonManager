local ADDON_NAME, T = ...
local L = T.L
local EDDM = LibStub("ElioteDropDownMenu-1.0")

--- @type SimpleAddonManager
local frame = T.AddonFrame
local module = frame:RegisterModule("Main")

local function CharacterDropDown_Initialize()
	local selectedValue = frame:GetCharacter() == true
	local info = {
		text = ALL,
		value = true,
		func = function(self)
			local value = self.value
			frame:SetCharacter(value)
			EDDM.UIDropDownMenu_SetSelectedValue(frame.CharacterDropDown, value)
			frame.ScrollFrame.update()
		end,
		checked = selectedValue
	};
	EDDM.UIDropDownMenu_AddButton(info);

	info.text = UnitName("player")
	info.value = UnitName("player")
	info.checked = not selectedValue
	EDDM.UIDropDownMenu_AddButton(info);
end

function frame:DidAddonStateChanged(addonNameOrIndex)
	local initiallyEnabledAddons = frame:GetAddonsInitialState()
	local state = frame:IsAddonSelected(addonNameOrIndex)
	local name = GetAddOnInfo(addonNameOrIndex)
	local initialState = initiallyEnabledAddons[name]
	if (state ~= initialState) then
		return true
	end
end

function frame:DidAnyAddonStateChanged()
	for addonIndex = 1, GetNumAddOns() do
		if (frame:DidAddonStateChanged(addonIndex)) then
			return true
		end
	end
end

function frame:UpdateOkButton()
	if (frame:DidAnyAddonStateChanged()) then
		frame.edited = true
		frame.OkButton:SetText(L["Reload UI"])
	else
		frame.edited = false
		frame.OkButton:SetText(OKAY)
	end
end

function module:PreInitialize()
	frame.Sizer = CreateFrame("Button", nil, frame, "PanelResizeButtonTemplate")
	frame.CharacterDropDown = EDDM.UIDropDownMenu_Create("SAM_CharacterDropDown", frame)
	frame.CancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.OkButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.EnableAllButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.DisableAllButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
end

function module:Initialize()
	local addonName = GetAddOnMetadata(ADDON_NAME, "Title")
	if (frame.TitleText) then
		frame.TitleText:SetText(addonName)
	elseif (frame.TitleContainer and frame.TitleContainer.TitleText) then
		frame.TitleContainer.TitleText:SetText(addonName)
	end

	frame.Sizer:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT", true)
	end)
	frame.Sizer:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
	end)
	frame.Sizer:SetPoint("BOTTOMRIGHT", -4, 4)

	frame.CharacterDropDown:SetPoint("TOPLEFT", 0, -30)
	EDDM.UIDropDownMenu_Initialize(frame.CharacterDropDown, CharacterDropDown_Initialize)
	EDDM.UIDropDownMenu_SetSelectedValue(frame.CharacterDropDown, true)

	frame.CancelButton:SetPoint("BOTTOMRIGHT", -24, 4)
	frame.CancelButton:SetSize(100, 22)
	frame.CancelButton:SetText(CANCEL)
	frame.CancelButton:SetScript("OnClick", function()
		ResetAddOns()
		frame.ScrollFrame.update()
		frame:Hide()
	end)

	frame.OkButton:SetPoint("TOPRIGHT", frame.CancelButton, "TOPLEFT", 0, 0)
	frame.OkButton:SetSize(100, 22)
	frame.OkButton:SetText(OKAY)
	frame.OkButton:SetScript("OnClick", function()
		SaveAddOns()
		frame.ScrollFrame.update()
		frame:Hide()
		if (frame.edited) then
			ReloadUI()
		end
	end)

	frame.EnableAllButton:SetPoint("BOTTOMLEFT", 4, 4)
	frame.EnableAllButton:SetSize(120, 22)
	frame.EnableAllButton:SetText(ENABLE_ALL_ADDONS)
	frame.EnableAllButton:SetScript("OnClick", function()
		for _, addon in pairs(frame:GetAddonsList()) do
			frame:EnableAddOn(addon.index)
		end
		frame:Update()
	end)

	frame.DisableAllButton:SetPoint("TOPLEFT", frame.EnableAllButton, "TOPRIGHT", 0, 0)
	frame.DisableAllButton:SetSize(120, 22)
	frame.DisableAllButton:SetText(DISABLE_ALL_ADDONS)
	frame.DisableAllButton:SetScript("OnClick", function()
		local addonsList = frame:GetAddonsList()
		local disablingMe = false
		for _, addon in pairs(addonsList) do
			if (addon.key == ADDON_NAME) then
				disablingMe = frame:IsAddonSelected(ADDON_NAME)
				break
			end
		end
		local function disableList()
			for _, addon in pairs(addonsList) do
				frame:DisableAddOn(addon.index)
			end
			frame:Update()
		end
		if (disablingMe) then
			frame:ShowYesNoDialog(
					L["Also disable Simple Addon Manager?"],
					function()
						disableList()
					end,
					function()
						disableList()
						frame:EnableAddOn(ADDON_NAME)
					end
			)
		else
			disableList()
		end
	end)
end
