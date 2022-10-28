local _, T = ...
local L = T.L
local C = T.Color

local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("SimpleAddonManager_MenuFrame")

--- @type SimpleAddonManager
local frame = T.AddonFrame
local module = frame:RegisterModule("AddonList")

local BANNED_ADDON = "BANNED"

local function AddonTooltipBuildDepsString(addonIndex)
	local deps = { GetAddOnDependencies(addonIndex) }
	local depsString = "";
	for i, name in ipairs(deps) do
		local color = C.white
		if (not frame:IsAddonInstalled(name)) then
			color = C.red
		end
		if (i == 1) then
			depsString = ADDON_DEPENDENCIES .. color:WrapText(name)
		else
			depsString = depsString .. ", " .. color:WrapText(name)
		end
	end
	return depsString;
end

local function EnableAllDeps(addonIndex)
	local requiredDeps = { GetAddOnDependencies(addonIndex) }
	for _, depName in pairs(requiredDeps) do
		if (frame:IsAddonInstalled(depName)) then
			EnableAddOn(depName)
			EnableAllDeps(depName)
		end
	end
end

local function AddonRightClickMenu(addonIndex)
	local name, title = GetAddOnInfo(addonIndex)
	local menu = {
		{ text = title, isTitle = true, notCheckable = true },
	}

	if (GetAddOnDependencies(addonIndex)) then
		table.insert(menu, {
			text = L["Enable this Addon and its dependencies"],
			func = function()
				EnableAddOn(addonIndex)
				EnableAllDeps(addonIndex)
				frame:Update()
			end,
			notCheckable = true,
			tooltipOnButton = true,
			tooltipTitle = title,
			tooltipText = AddonTooltipBuildDepsString(addonIndex)
		})
	end
	table.insert(menu, T.spacer)
	table.insert(menu, { text = L["Categories"], isTitle = true, notCheckable = true })

	local userCategories, tocCategories = frame:GetCategoryTables()
	local sortedCategories = frame:TableKeysToSortedList(userCategories, tocCategories)
	for _, categoryName in ipairs(sortedCategories) do
		local categoryDb = userCategories[categoryName]
		local tocCategory = tocCategories[categoryName]
		local isInToc = tocCategory and tocCategory.addons and tocCategory.addons[name]
		table.insert(menu, {
			text = frame:LocalizeCategoryName(categoryName, not isInToc) .. (isInToc and (" |cFFFFFF00" .. L["(Automatically in category)"]) or ""),
			checked = function()
				return categoryDb and categoryDb.addons and categoryDb.addons[name]
			end,
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

local function ToggleAddon(self)
	local addonIndex = self:GetParent().addon.index
	local _, _, _, _, _, security = GetAddOnInfo(addonIndex)
	if (security == BANNED_ADDON) then
		return
	end

	local newValue = not frame:IsAddonSelected(addonIndex)
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
	frame:Update()
end

local function AddonButtonOnClick(self, mouseButton)
	if (mouseButton == "LeftButton") then
		ToggleAddon(self.EnabledButton)
	else
		EDDM.EasyMenu(AddonRightClickMenu(self.addon.index), dropdownFrame, "cursor", 0, 0, "MENU")
	end
end

local function UpdateTooltip(self)
	local addonIndex = self.addon.index
	local name, title, notes, _, reason, security = GetAddOnInfo(addonIndex)

	GameTooltip:ClearLines();
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("LEFT", self, "RIGHT")
	if (security == BANNED_ADDON) then
		GameTooltip:SetText(ADDON_BANNED_TOOLTIP);
	else
		if (title) then
			GameTooltip:AddLine(title);
			GameTooltip:AddLine(name, 0.7, 0.7, 0.7);
			--GameTooltip:AddLine("debug: '" .. self.addon.name .. "'|r");
			--GameTooltip:AddLine("dept: '" .. self.addon.dept .. "'|r");
			--GameTooltip:AddLine("reason: '" .. (reason or "null") .. "'|r");
		else
			GameTooltip:AddLine(name);
		end
		if (reason == "MISSING") then
			GameTooltip:AddLine(C.red:WrapText(L["UNKNOWN_ADDON_TTP_MESSAGE"]), nil, nil, nil, true);
			return
		end
		local version = GetAddOnMetadata(addonIndex, "Version")
		if (version) then
			GameTooltip:AddLine(L["Version: "] .. "|cFFFFFFFF" .. version .. "|r");
		end
		local author = GetAddOnMetadata(addonIndex, "Author")
		if (author) then
			GameTooltip:AddLine(L["Author: "] .. "|cFFFFFFFF" .. strtrim(author) .. "|r");
		end
		if (IsAddOnLoaded(addonIndex)) then
			local mem = GetAddOnMemoryUsage(addonIndex)
			GameTooltip:AddLine(L["Memory: "] .. "|cFFFFFFFF" .. frame:FormatMemory(mem) .. "|r");
		end
		GameTooltip:AddLine(AddonTooltipBuildDepsString(addonIndex), nil, nil, nil, true);
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine(notes, 1.0, 1.0, 1.0, true);
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine("|A:newplayertutorial-icon-mouse-rightbutton:0:0|a " .. L["Right-click to edit"]);
	end
	GameTooltip:Show()
end

local function AddonButtonOnEnter(self)
	if (frame:GetDb().config.memoryUpdate > 0) then
		self.UpdateTooltip = UpdateTooltip
	end
	UpdateTooltip(self)
	GameTooltip:Show()
end

local function AddonButtonOnLeave(self)
	self.UpdateTooltip = nil
	GameTooltip:Hide()
end

local function ShouldColorStatus(enabled, loaded, reason)
	if (reason == "DEP_DEMAND_LOADED" or reason == "DEMAND_LOADED") then
		return false
	end
	return (enabled and not loaded) or
			(enabled and loaded and reason == "INTERFACE_VERSION")
end

local function UpdateExpandOrCollapseButtonState(button, isCollapsed)
	if (isCollapsed) then
		button:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up");
	else
		button:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up");
	end
end

local function ExpandOrCollapseButtonOnClick(self)
	local addon = self:GetParent().addon
	frame:ToggleAddonCollapsed(addon.key, addon.parentKey)
	frame:Update()
end

local function deptMargin(dept)
	return 13 * (dept or 0)
end

local function UpdateList()
	local buttons = HybridScrollFrame_GetButtons(frame.ScrollFrame);
	local offset = HybridScrollFrame_GetOffset(frame.ScrollFrame);
	local buttonHeight;
	local addons = frame:GetAddonsList()
	local count = #addons
	local isInTreeMode = frame:GetDb().config.addonListStyle == "tree"

	for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex]
		button:SetPoint("LEFT", frame.ScrollFrame)
		button:SetPoint("RIGHT", frame.ScrollFrame)

		local relativeButtonIndex = buttonIndex + offset
		buttonHeight = button:GetHeight()

		if relativeButtonIndex <= count then
			local addon = addons[relativeButtonIndex]
			local addonIndex = addon.index
			local name, title, _, loadable, reason, security = GetAddOnInfo(addonIndex)
			local loaded = IsAddOnLoaded(addonIndex)
			local enabled = frame:IsAddonSelected(addonIndex)
			local version = ""

			if (frame:GetDb().config.showVersions) then
				version = GetAddOnMetadata(addonIndex, "Version")
				version = (version and " |cff808080(" .. version .. ")|r") or ""
			end

			button.ExpandOrCollapseButton:SetScript("OnClick", ExpandOrCollapseButtonOnClick)
			local showExpandOrCollapseButton = isInTreeMode and addon.children and next(addon.children)
			local isCollapsed = frame:IsAddonCollapsed(addon.key, addon.parentKey)
			if showExpandOrCollapseButton then
				button.ExpandOrCollapseButton:Show()
				UpdateExpandOrCollapseButtonState(
						button.ExpandOrCollapseButton,
						isCollapsed
				)
			else
				button.ExpandOrCollapseButton:Hide()
			end

			local expandOrCollapseButtonSize = isInTreeMode and button.ExpandOrCollapseButton:GetWidth() or 0
			local margin = deptMargin(addon.dept) + expandOrCollapseButtonSize
			button.Name:SetPoint("TOPLEFT", 30 + margin, 0)
			button.EnabledButton:SetPoint("LEFT", 4 + margin, 0)

			button.Name:SetText((title or name) .. version)

			if (loadable or (enabled and (reason == "DEP_DEMAND_LOADED" or reason == "DEMAND_LOADED"))) then
				button.Name:SetTextColor(1.0, 0.78, 0.0);
			elseif enabled then
				button.Name:SetTextColor(1.0, 0.1, 0.1);
			elseif reason == "MISSING" then
				button.Name:SetTextColor(C.red:GetRGB());
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
			button.EnabledButton:SetEnabled(security ~= BANNED_ADDON and addon.exists)

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

local function UpdateMemory()
	UpdateAddOnMemoryUsage()
end

local function OnShow()
	frame:UpdateMemoryTickerPeriod(frame:GetDb().config.memoryUpdate)
	UpdateMemory()
end

local function OnHide()
	frame:UpdateMemoryTickerPeriod(0)
end

function frame:UpdateMemoryTickerPeriod(period)
	if (self.MemoryUpdateTicker) then
		self.MemoryUpdateTicker:Cancel()
		self.MemoryUpdateTicker = nil
	end
	if (period > 0) then
		self.MemoryUpdateTicker = C_Timer.NewTicker(period, UpdateMemory)
	end
end

function frame:CreateAddonListFrame()
	self.ScrollFrame = CreateFrame("ScrollFrame", nil, self, "HybridScrollFrameTemplate")
	self.ScrollFrame:Hide()
	self.ScrollFrame:SetPoint("TOPLEFT", 7, -64)
	self.ScrollFrame:SetPoint("BOTTOMRIGHT", -30, 30)
	self.ScrollFrame:SetScript("OnShow", OnShow)
	self.ScrollFrame:SetScript("OnHide", OnHide)
	self.ScrollFrame.update = UpdateList
	self.ScrollFrame:Show()

	self.ScrollFrame.ScrollBar = CreateFrame("Slider", nil, self.ScrollFrame, "HybridScrollBarTemplate")
	self.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", self.ScrollFrame, "TOPRIGHT", 1, -16)
	self.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", self.ScrollFrame, "BOTTOMRIGHT", 1, 12)
	self.ScrollFrame.ScrollBar:SetScript("OnSizeChanged", OnSizeChanged)
	self.ScrollFrame.ScrollBar.doNotHide = true

	HybridScrollFrame_CreateButtons(self.ScrollFrame, "SimpleAddonManagerAddonItem")
end

function module:OnLoad()
	local db = frame:GetDb()
	frame:CreateDefaultOptions(db.config, {
		memoryUpdate = 0
	})
end