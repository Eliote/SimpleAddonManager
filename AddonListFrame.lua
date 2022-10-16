local _, T = ...
local L = T.L
local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("SimpleAddonManager_MenuFrame")

--- @type SimpleAddonManager
local frame = T.AddonFrame

local function AddonRightClickMenu(addonIndex)
	local name, title = GetAddOnInfo(addonIndex)
	local menu = {
		{ text = title, isTitle = true, notCheckable = true },
		T.spacer,
		{ text = L["Categories: "], isTitle = true, notCheckable = true },
	}
	local userCategories, tocCategories = frame:GetCategoryTables()
	local sortedCategories = frame:TableKeysToSortedList(userCategories, tocCategories)
	for _, categoryName in ipairs(sortedCategories) do
		local categoryDb = userCategories[categoryName]
		local tocCategory = tocCategories[categoryName]
		local isInToc = tocCategory and tocCategory.addons and tocCategory.addons[name]
		table.insert(menu, {
			text = categoryName .. (isInToc and (" |cFFFFFF00" .. L["(Automatically in category)"]) or ""),
			checked = categoryDb and categoryDb.addons and categoryDb.addons[name],
			keepShownOnClick = true,
			func = function(_, _, _, checked)
				userCategories[categoryName] = userCategories[categoryName] or { name = categoryName }
				userCategories[categoryName].addons = userCategories[categoryName].addons or {}
				userCategories[categoryName].addons[name] = checked or nil
				frame:Update()
			end,
		})
	end
	table.insert(menu, T.separatorInfo)
	table.insert(menu, T.closeMenuInfo)
	return menu
end

local function AddonTooltipBuildDepsString(...)
	local deps = "";
	for i = 1, select("#", ...) do
		if (i == 1) then
			deps = ADDON_DEPENDENCIES .. "|cFFFFFFFF" .. select(i, ...);
		else
			deps = deps .. ", " .. select(i, ...);
		end
	end
	return deps;
end

local function ToggleAddon(self)
	local addonIndex = self:GetParent().addon.index
	local newValue = not frame:IsAddonSelected(addonIndex)
	frame.edited = true
	frame.OkButton:SetText(L["Reload UI"])
	self:SetChecked(newValue)
	if (newValue) then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		local character = frame:GetCharacter()
		EnableAddOn(addonIndex, character)
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		local character = frame:GetCharacter()
		DisableAddOn(addonIndex, character)
	end
	frame.ScrollFrame.update()
end

local function AddonButtonOnClick(self, mouseButton)
	if (mouseButton == "LeftButton") then
		ToggleAddon(self.EnabledButton)
	else
		EDDM.EasyMenu(AddonRightClickMenu(self.addon.index), dropdownFrame, "cursor", 0, 0, "MENU")
	end
end

local function AddonButtonOnEnter(self)
	local addonIndex = self.addon.index
	local name, title, notes, _, _, security = GetAddOnInfo(addonIndex)

	GameTooltip:ClearLines();
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("LEFT", self, "RIGHT")
	if (security == "BANNED") then
		GameTooltip:SetText(ADDON_BANNED_TOOLTIP);
	else
		if (title) then
			GameTooltip:AddLine(title);
			GameTooltip:AddLine(name, 0.7, 0.7, 0.7);
			--GameTooltip:AddLine("debug: '" .. self.addon.name .. "'|r");
		else
			GameTooltip:AddLine(name);
		end
		local version = GetAddOnMetadata(addonIndex, "Version")
		if (version) then
			GameTooltip:AddLine(L["Version: "] .. "|cFFFFFFFF" .. version .. "|r");
		end
		local author = GetAddOnMetadata(addonIndex, "Author")
		if (author) then
			GameTooltip:AddLine(L["Author: "] .. "|cFFFFFFFF" .. strtrim(author) .. "|r");
		end
		GameTooltip:AddLine(AddonTooltipBuildDepsString(GetAddOnDependencies(addonIndex)), nil, nil, nil, true);
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine(notes, 1.0, 1.0, 1.0, true);
	end

	GameTooltip:Show()
end

local function AddonButtonOnLeave()
	GameTooltip:Hide()
end

local function ShouldColorStatus(enabled, loaded, reason)
	if (reason == "DEP_DEMAND_LOADED" or reason == "DEMAND_LOADED") then
		return false
	end
	return (enabled and not loaded) or
			(enabled and loaded and reason == "INTERFACE_VERSION")
end

local function UpdateList()
	local buttons = HybridScrollFrame_GetButtons(frame.ScrollFrame);
	local offset = HybridScrollFrame_GetOffset(frame.ScrollFrame);
	local buttonHeight;
	local addons = frame:GetAddonsList()
	local count = #addons

	for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex]
		button:SetPoint("LEFT", frame.ScrollFrame)
		button:SetPoint("RIGHT", frame.ScrollFrame)

		local relativeButtonIndex = buttonIndex + offset
		buttonHeight = button:GetHeight()

		if relativeButtonIndex <= count then
			local addon = addons[relativeButtonIndex]
			local addonIndex = addon.index
			local name, title, _, loadable, reason = GetAddOnInfo(addonIndex)
			local loaded = IsAddOnLoaded(addonIndex)
			local enabled = frame:IsAddonSelected(addonIndex)
			local version = ""

			if (frame:GetDb().config.showVersions) then
				version = GetAddOnMetadata(addonIndex, "Version")
				version = (version and " |cff808080(" .. version .. ")|r") or ""
			end

			button.Name:SetText((title or name) .. version)

			if (loadable or (enabled and (reason == "DEP_DEMAND_LOADED" or reason == "DEMAND_LOADED"))) then
				button.Name:SetTextColor(1.0, 0.78, 0.0);
			elseif enabled then
				button.Name:SetTextColor(1.0, 0.1, 0.1);
			else
				button.Name:SetTextColor(0.5, 0.5, 0.5);
			end

			button.addon = addon
			button.Status:SetTextColor(0.5, 0.5, 0.5);
			button.Status:SetText((not loadable and reason and _G["ADDON_" .. reason]) or "")
			if (ShouldColorStatus(enabled, loaded, reason)) then
				button.Status:SetTextColor(1.0, 0.1, 0.1);
				if (reason == nil) then
					button.Status:SetText(REQUIRES_RELOAD)
				end
			end

			button.EnabledButton:SetChecked(enabled)
			button.EnabledButton:SetScript("OnClick", ToggleAddon)

			button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			button:SetScript("OnClick", AddonButtonOnClick)
			button:SetScript("OnEnter", AddonButtonOnEnter)
			button:SetScript("OnLeave", AddonButtonOnLeave)

			button:Show()
		else
			button:Hide()
		end
	end

	HybridScrollFrame_Update(frame.ScrollFrame, count * buttonHeight, frame.ScrollFrame:GetHeight())
end

local function OnSizeChanged(self)
	local offsetBefore = self:GetValue()
	HybridScrollFrame_CreateButtons(self:GetParent(), "SimpleAddonManagerAddonItem")
	self:SetValue(offsetBefore)
	self:GetParent().update()
end

function frame:CreateAddonListFrame()
	self.ScrollFrame = CreateFrame("ScrollFrame", nil, self, "HybridScrollFrameTemplate")
	self.ScrollFrame:SetPoint("TOPLEFT", 7, -64)
	self.ScrollFrame:SetPoint("BOTTOMRIGHT", -30, 30)
	self.ScrollFrame.update = UpdateList

	self.ScrollFrame.ScrollBar = CreateFrame("Slider", nil, self.ScrollFrame, "HybridScrollBarTemplate")
	self.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", self.ScrollFrame, "TOPRIGHT", 1, -16)
	self.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", self.ScrollFrame, "BOTTOMRIGHT", 1, 12)
	self.ScrollFrame.ScrollBar:SetScript("OnSizeChanged", OnSizeChanged)
	self.ScrollFrame.ScrollBar.doNotHide = true

	HybridScrollFrame_CreateButtons(self.ScrollFrame, "SimpleAddonManagerAddonItem")
end
