local _, T = ...
local L = T.L
local C = T.Color

local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("SimpleAddonManager_MenuFrame")

--- @type SimpleAddonManager
local frame = T.AddonFrame
local module = frame:RegisterModule("AddonList")

local BANNED_ADDON = "BANNED"
local SECURE_PROTECTED_ADDON = "SECURE_PROTECTED"
local SECURE_ADDON = "SECURE"

local function AddonTooltipBuildDepsString(addonIndex)
	local deps = { frame.compat.GetAddOnDependencies(addonIndex) }
	local depsString = "";
	for i, name in ipairs(deps) do
		local color = C.white
		if (not frame:IsAddonInstalled(name)) then
			color = C.red
		elseif (frame:IsAddonSelected(name)) then
			color = C.green
		end
		if (i == 1) then
			depsString = ADDON_DEPENDENCIES .. color:WrapText(name)
		else
			depsString = depsString .. ", " .. color:WrapText(name)
		end
	end
	return depsString;
end

local function AddonTooltipBuildChildrenString(children)
	local childrenString = "";
	local first = true
	for name, _ in pairs(children) do
		local color = C.white
		if (not frame:IsAddonInstalled(name)) then
			color = C.red
		elseif (frame:IsAddonSelected(name)) then
			color = C.green
		end
		if (first) then
			first = false
			childrenString = L["AddOns: "] .. color:WrapText(name)
		else
			childrenString = childrenString .. ", " .. color:WrapText(name)
		end
	end
	return childrenString;
end

local function EnableAllDeps(addonIndex)
	local requiredDeps = { frame.compat.GetAddOnDependencies(addonIndex) }
	for _, depName in ipairs(requiredDeps) do
		if (frame:IsAddonInstalled(depName)) then
			frame:EnableAddOn(depName)
			EnableAllDeps(depName)
		end
	end
end

local function CreateAddonChildrenList(name)
	local list = {}
	for i = 1, frame.compat.GetNumAddOns() do
		local addon = frame.compat.GetAddOnInfo(i)
		local requiredDeps = { frame.compat.GetAddOnDependencies(i) }
		for _, depName in ipairs(requiredDeps) do
			if (depName == name) then
				list[addon] = true
				break
			end
		end
	end
	return list
end

local function SetAllChildren(children, state)
	for name, _ in pairs(children) do
		if (frame:IsAddonInstalled(name)) then
			if (state) then
				frame:EnableAddOn(name)
			else
				frame:DisableAddOn(name)
			end
		end
	end
end

local function SetCategory(addonName, state, categoryTable, categoryName)
	categoryTable[categoryName] = categoryTable[categoryName] or { name = categoryName }
	categoryTable[categoryName].addons = categoryTable[categoryName].addons or {}
	categoryTable[categoryName].addons[addonName] = state or nil
end

local function SetCategoryForAllChildren(children, state, categoryTable, categoryName)
	for name, _ in pairs(children) do
		SetCategory(name, state, categoryTable, categoryName)
	end
end

local function AddonRightClickMenu(addon)
	if (not frame:IsAddonInstalled(addon.index)) then
		return
	end
	local addonIndex = addon.index
	local name, title, _, _, reason = frame.compat.GetAddOnInfo(addonIndex)
	local menu = {
		{ text = title, isTitle = true, notCheckable = true },
	}

	if (frame:IsAddonInstalled(addonIndex)) then
		table.insert(menu, {
			text = L["Lock Addon"],
			tooltipOnButton = true,
			tooltipTitle = "",
			tooltipText = L["Tip: You can also alt-click the addon in the list to lock/unlock it"],
			func = function(_, _, _, checked)
				frame:GetModule("Lock"):SetLockState(addonIndex, not checked)
				frame:Update()
			end,
			checked = function()
				return frame:GetModule("Lock"):IsAddonLocked(addonIndex)
			end,
		})
	end

	if (not frame.compat.IsAddOnLoaded(addonIndex) and frame.compat.IsAddOnLoadOnDemand(addonIndex) and reason == "DEMAND_LOADED") then
		table.insert(menu, {
			text = L["Load AddOn"],
			func = function()
				frame:Update()
			end,
			notCheckable = true,
		})
	end

	if (frame.compat.GetAddOnDependencies(addonIndex)) then
		table.insert(menu, {
			text = L["Enable this Addon and its dependencies"],
			func = function()
				frame:EnableAddOn(addonIndex)
				EnableAllDeps(addonIndex)
				frame:Update()
			end,
			notCheckable = true,
			tooltipOnButton = true,
			tooltipTitle = title,
			tooltipText = AddonTooltipBuildDepsString(addonIndex)
		})
	end

	local children = CreateAddonChildrenList(name)
	if (next(children)) then
		table.insert(menu, {
			text = L["Enable this and every AddOn that depends on it"],
			func = function()
				frame:EnableAddOn(addonIndex)
				SetAllChildren(children, true)
				frame:Update()
			end,
			notCheckable = true,
			tooltipOnButton = true,
			tooltipTitle = title,
			tooltipText = AddonTooltipBuildChildrenString(children)
		})
		table.insert(menu, {
			text = L["Disable this and every AddOn that depends on it"],
			func = function()
				frame:DisableAddOn(addonIndex)
				SetAllChildren(children, false)
				frame:Update()
			end,
			notCheckable = true,
			tooltipOnButton = true,
			tooltipTitle = title,
			tooltipText = AddonTooltipBuildChildrenString(children)
		})
	end

	table.insert(menu, T.separatorInfo)
	table.insert(menu, { text = L["Categories"], isTitle = true, notCheckable = true })

	local userCategories, tocCategories = frame:GetCategoryTables()
	local sortedCategories = frame:TableKeysToSortedList(userCategories, tocCategories)
	for _, categoryName in ipairs(sortedCategories) do
		local categoryDb = userCategories[categoryName]
		local tocCategory = tocCategories[categoryName]
		local isInToc = tocCategory and tocCategory.addons and tocCategory.addons[name]
		table.insert(menu, {
			text = frame:LocalizeCategoryName(categoryName, not isInToc) .. (isInToc and (" " .. C.yellow:WrapText(L["(Automatically in category)"])) or ""),
			tooltipOnButton = true,
			tooltipTitle = categoryName,
			tooltipText = L["Hold shift to add/remove AddOns that depends on it as well"],
			checked = function()
				return categoryDb and categoryDb.addons and categoryDb.addons[name]
			end,
			keepShownOnClick = true,
			func = function(_, _, _, checked)
				SetCategory(name, checked, userCategories, categoryName)

				if (IsShiftKeyDown()) then
					SetCategoryForAllChildren(children, checked, userCategories, categoryName)
				end

				frame:Update()
			end,
		})
	end
	table.insert(menu, T.separatorInfo)
	table.insert(menu, T.closeMenuInfo)
	return menu
end

local function Checkbox_SetAddonState(self, enabled, addonIndex)
	local checkedTexture = self.CheckedTexture
	checkedTexture:SetVertexColor(1, 1, 1)
	checkedTexture:SetDesaturated(false)
	self.LockIcon:Hide()

	local isLocked = frame:GetModule("Lock"):IsAddonLocked(addonIndex)
	if (isLocked) then
		self.LockIcon:Show()
	end

	if (enabled) then
		self:SetChecked(true)
	else
		local togglingMe = frame:GetSelectedCharIndex() >= 1
		local enabledSome = (not togglingMe) and frame:IsAddonSelected(addonIndex, true)
		if (enabledSome) then
			self:SetChecked(true)
			local character = frame:GetSelectedCharName()
			local isEnabledByMe = frame.compat.GetAddOnEnableState(addonIndex, character) == 2
			if (isEnabledByMe) then
				checkedTexture:SetVertexColor(0.4, 1.0, 0.4)
			else
				checkedTexture:SetDesaturated(true)
			end
		else
			self:SetChecked(false)
		end
	end
end

local function ToggleAddon(self)
	local addonIndex = self:GetParent().addon.index
	local _, _, _, _, _, security = frame.compat.GetAddOnInfo(addonIndex)
	if (security == BANNED_ADDON) then
		return
	end

	if (IsAltKeyDown()) then
		local lockModule = frame:GetModule("Lock")
		local isLocking = not lockModule:IsAddonLocked(addonIndex)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_FAER_TAB)
		if (isLocking) then
			lockModule:LockAddon(addonIndex)
		else
			lockModule:UnlockAddon(addonIndex)
		end
	else
		local isEnabling = not frame:IsAddonSelected(addonIndex)
		Checkbox_SetAddonState(self, isEnabling, addonIndex)
		if (isEnabling) then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			frame:EnableAddOn(addonIndex)
		else
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			frame:DisableAddOn(addonIndex)
		end
	end

	frame:Update()
end

local function AddonButtonOnClick(self, mouseButton)
	if (mouseButton == "LeftButton") then
		ToggleAddon(self.EnabledButton)
	else
		EDDM.EasyMenu(AddonRightClickMenu(self.addon), dropdownFrame, "cursor", 0, 0, "MENU")
	end
end

local function ProfilesInAddon(name)
	local db = frame:GetDb()
	local setsList = db.sets
	local profilesForAddon = ""
	local profilesTable = {}
	for profileNameTable, subPair in pairs(setsList) do
		local list = subPair.addons
		for i, _ in pairs(list) do
			if name == i then
				table.insert(profilesTable, profileNameTable)
			end
		end
	end

	table.sort(profilesTable)
	for _, profileName in ipairs(profilesTable) do
		profilesForAddon = profilesForAddon .. profileName .. ", "
	end
	-- Remove Last 2 Characters cause whitespace and ','
	profilesForAddon = string.sub(profilesForAddon, 0, strlen(profilesForAddon) - 2)
	return profilesForAddon
end

local function CategoriesForAddon(name)
	local userTable, tocTable, fixedTable = frame:GetCategoryTables()

	local resultText = ""
	local sep = ""
	for _, categoryTable in pairs(userTable) do
		if (categoryTable.addons[name]) then
			resultText = resultText .. sep .. frame:LocalizeCategoryName(categoryTable.name, userTable)
			sep = ", "
		end
	end

	for _, categoryTable in pairs(tocTable) do
		if (categoryTable.addons[name]) then
			resultText = resultText .. sep .. frame:LocalizeCategoryName(categoryTable.name, tocTable)
			sep = ", "
		end
	end

	for _, categoryTable in pairs(fixedTable) do
		if (categoryTable.prepare) then categoryTable:prepare() end
		if (categoryTable:addons(name)) then
			resultText = resultText .. sep .. categoryTable.name
			sep = ", "
		end
	end

	return resultText
end

local function FormatProfilerPercent(pct)
	local color = C.white
	if (pct > 50) then color = C.yellow end
	if (pct > 80) then color = C.red end
	return color:WrapText(string.format("%.2f", pct)) .. C.white:WrapText(" %");
end

local function GetAddonMetricPercent(addonName, metric)
	if (not C_AddOnProfiler or not C_AddOnProfiler.IsEnabled()) then
		return ""
	end
	local overall = C_AddOnProfiler.GetOverallMetric(metric)
	local addon = C_AddOnProfiler.GetAddOnMetric(addonName, metric)
	if overall <= 0 then
		return ""
	end
	local percent = addon / overall
	return FormatProfilerPercent(percent * 100.0)
end

local function AddLineIfNotEmpty(ttp, title, info)
	if (not info or info == "") then return end
	ttp:AddLine(title .. info);
end

local function IsProfilerEnabled()
	return C_AddOnProfiler and C_AddOnProfiler.IsEnabled()
end

local function UpdateTooltip(self)
	local addonIndex = self.addon.index
	local name, title, notes, _, reason, security = frame.compat.GetAddOnInfo(addonIndex)

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
			GameTooltip:AddLine(C.red:WrapText(L["This addons is not installed!"]), nil, nil, nil, true);
			return
		end
		local version = frame:GetAddOnMetadata(addonIndex, "Version")
		if (version) then
			GameTooltip:AddLine(L["Version: "] .. C.white:WrapText(version));
		end
		local author = frame:GetAddOnMetadata(addonIndex, "Author")
		if (author) then
			GameTooltip:AddLine(L["Author: "] .. C.white:WrapText(strtrim(author)));
		end
		local loaded = frame.compat.IsAddOnLoaded(addonIndex);
		if (loaded and IsProfilerEnabled()) then
			AddLineIfNotEmpty(GameTooltip, L["CPU: "], GetAddonMetricPercent(name, Enum.AddOnProfilerMetric.RecentAverageTime));
			AddLineIfNotEmpty(GameTooltip, L["Average CPU: "], GetAddonMetricPercent(name, Enum.AddOnProfilerMetric.SessionAverageTime));
			AddLineIfNotEmpty(GameTooltip, L["Peak CPU: "], GetAddonMetricPercent(name, Enum.AddOnProfilerMetric.PeakTime));
			AddLineIfNotEmpty(GameTooltip, L["Encounter CPU: "], GetAddonMetricPercent(name, Enum.AddOnProfilerMetric.EncounterAverageTime));
		end
		if (loaded and security ~= SECURE_PROTECTED_ADDON and security ~= SECURE_ADDON) then
			local mem = GetAddOnMemoryUsage(addonIndex)
			GameTooltip:AddLine(L["Memory: "] .. C.white:WrapText(frame:FormatMemory(mem)));
		end
		GameTooltip:AddLine(AddonTooltipBuildDepsString(addonIndex), nil, nil, nil, true);
		if (self.addon.warning) then
			GameTooltip:AddLine(self.addon.warning, nil, nil, nil, true);
		end
		local profilesForAddon = ProfilesInAddon(name)
		if profilesForAddon ~= "" then
			GameTooltip:AddLine(L["Profiles: "] .. C.white:WrapText(profilesForAddon), nil, nil, nil, true);
		end
		local categoriesForAddon = CategoriesForAddon(name)
		if categoriesForAddon ~= "" then
			GameTooltip:AddLine(L["Categories: "] .. C.white:WrapText(categoriesForAddon), nil, nil, nil, true);
		end

		GameTooltip:AddLine(" ");
		GameTooltip:AddLine(notes, 1.0, 1.0, 1.0, true);
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine("|A:newplayertutorial-icon-mouse-rightbutton:0:0|a " .. L["Right-click to edit"]);
	end
	GameTooltip:Show()
end

local time = 0
local function UpdateTooltipThrottled(self)
	local ctime = GetTime()
	if (ctime - time > 1) then
		time = ctime
		UpdateTooltip(self)
	end
end

local function AddonButtonOnEnter(self)
	if (frame:GetDb().config.memoryUpdate > 0 or IsProfilerEnabled()) then
		self.UpdateTooltip = UpdateTooltipThrottled
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

local function DeptMargin(dept)
	return 13 * (dept or 0)
end

local function GetTitleWithIcon(addon)
	local addonIndex = addon.index
	local name, title = frame.compat.GetAddOnInfo(addonIndex)
	local titleText = title or name
	local version = ""

	if (frame:GetDb().config.showVersions and addon.exists) then
		version = frame:GetAddOnMetadata(addonIndex, "Version")
		version = (version and C.grey:WrapText(" (" .. version .. ")")) or ""
	end

	if (not frame:GetDb().config.hideIcons) then
		local iconTexture = frame:GetAddOnMetadata(addonIndex, "IconTexture");
		local iconAtlas = frame:GetAddOnMetadata(addonIndex, "IconAtlas");
		if iconTexture and CreateSimpleTextureMarkup then
			titleText = CreateSimpleTextureMarkup(iconTexture, 20, 20) .. " " .. titleText;
		elseif iconAtlas and CreateAtlasMarkup then
			titleText = CreateAtlasMarkup(iconAtlas, 20, 20) .. " " .. titleText;
		end
	end
	return titleText .. version
end

local wowExpMargin = LE_EXPANSION_LEVEL_CURRENT >= 9 and 4 or 0

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
			local _, _, _, loadable, reason, security = frame.compat.GetAddOnInfo(addonIndex)
			local loaded = frame.compat.IsAddOnLoaded(addonIndex)
			local enabled = frame:IsAddonSelected(addonIndex)

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
			local marginCorrection = isInTreeMode and 3 or 0
			local margin = DeptMargin(addon.dept) + expandOrCollapseButtonSize + marginCorrection + wowExpMargin
			button.Name:SetPoint("TOPLEFT", 30 + margin, 0)
			button.EnabledButton:SetPoint("LEFT", 4 + margin, 0)

			button.Name:SetText(GetTitleWithIcon(addon))

			if (loadable or (enabled and (reason == "DEP_DEMAND_LOADED" or reason == "DEMAND_LOADED"))) then
				button.Name:SetTextColor(C.yellow:GetRGB());
			elseif enabled then
				button.Name:SetTextColor(C.red:GetRGB());
			elseif reason == "MISSING" then
				button.Name:SetTextColor(C.red:GetRGB());
			else
				button.Name:SetTextColor(C.grey:GetRGB());
			end

			button.addon = addon
			button.Status:SetTextColor(C.grey:GetRGB());
			button.Status:SetText((not loaded and not loadable and reason and _G["ADDON_" .. reason]) or "")
			if (ShouldColorStatus(enabled, loaded, reason)) then
				button.Status:SetTextColor(C.red:GetRGB());
				if (reason == nil) then
					button.Status:SetText(REQUIRES_RELOAD)
				end
			end

			Checkbox_SetAddonState(button.EnabledButton, enabled, addonIndex)
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

function module:PreInitialize()
	frame.ScrollFrame = CreateFrame("ScrollFrame", nil, frame, "HybridScrollFrameTemplate")
	frame.ScrollFrame:SetScript("OnMouseWheel", frame.HybridScrollFrame_ShiftAwareOnScrollWheel)
	frame.ScrollFrame.ScrollBar = CreateFrame("Slider", nil, frame.ScrollFrame, "HybridScrollBarTemplate")
end

function module:Initialize()
	frame.ScrollFrame:Hide()
	frame.ScrollFrame:SetPoint("TOPLEFT", 7, -64)
	frame.ScrollFrame:SetPoint("BOTTOMRIGHT", -30, 30)
	frame.ScrollFrame:SetScript("OnShow", OnShow)
	frame.ScrollFrame:SetScript("OnHide", OnHide)
	frame.ScrollFrame.update = UpdateList
	frame.ScrollFrame:Show()

	frame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", frame.ScrollFrame, "TOPRIGHT", 1, -16)
	frame.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", frame.ScrollFrame, "BOTTOMRIGHT", 1, 12)
	frame.ScrollFrame.ScrollBar:SetScript("OnSizeChanged", OnSizeChanged)
	frame.ScrollFrame.ScrollBar.doNotHide = true

	HybridScrollFrame_CreateButtons(frame.ScrollFrame, "SimpleAddonManagerAddonItem")
end

function module:OnLoad()
	local db = frame:GetDb()
	frame:CreateDefaultOptions(db.config, {
		memoryUpdate = 0,
		hideIcons = false,
	})
end