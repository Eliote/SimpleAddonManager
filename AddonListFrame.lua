local _, T = ...
local L = T.L
local C = T.Color

local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("SimpleAddonManager_MenuFrame")

--- @type SimpleAddonManager
local SAM = T.AddonFrame
local module = SAM:RegisterModule("AddonList")
SAM.AddonList = module
module.events = {}

local BANNED_ADDON = "BANNED"
local SECURE_PROTECTED_ADDON = "SECURE_PROTECTED"
local SECURE_ADDON = "SECURE"

local AddonTooltip = CreateFrame("GameTooltip", "SAM_ADDON_LIST_TOOLTIP", SAM, "GameTooltipTemplate");

local function AddonTooltipBuildDepsString(addonIndex)
	local deps = { SAM.compat.GetAddOnDependencies(addonIndex) }
	local depsString = "";
	for i, name in ipairs(deps) do
		local color = C.white
		if (not SAM:IsAddonInstalled(name)) then
			color = C.red
		elseif (SAM:IsAddonSelected(name)) then
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
		if (not SAM:IsAddonInstalled(name)) then
			color = C.red
		elseif (SAM:IsAddonSelected(name)) then
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
	local requiredDeps = { SAM.compat.GetAddOnDependencies(addonIndex) }
	for _, depName in ipairs(requiredDeps) do
		if (SAM:IsAddonInstalled(depName)) then
			SAM:EnableAddOn(depName)
			EnableAllDeps(depName)
		end
	end
end

local function CreateAddonChildrenList(name)
	local list = {}
	for i = 1, SAM.compat.GetNumAddOns() do
		local addon = SAM.compat.GetAddOnInfo(i)
		local requiredDeps = { SAM.compat.GetAddOnDependencies(i) }
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
		if (SAM:IsAddonInstalled(name)) then
			if (state) then
				SAM:EnableAddOn(name)
			else
				SAM:DisableAddOn(name)
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
	if (not SAM:IsAddonInstalled(addon.index)) then
		return
	end
	local addonIndex = addon.index
	local name, title, _, _, reason = SAM.compat.GetAddOnInfo(addonIndex)
	local menu = {
		{ text = title, isTitle = true, notCheckable = true },
	}

	if (SAM:IsAddonInstalled(addonIndex)) then
		table.insert(menu, {
			text = L["Lock Addon"],
			tooltipOnButton = true,
			tooltipTitle = "",
			tooltipText = L["Tip: You can also alt-click the addon in the list to lock/unlock it"],
			func = function(_, _, _, checked)
				SAM:GetModule("Lock"):SetLockState(addonIndex, not checked)
				SAM:Update()
			end,
			checked = function()
				return SAM:GetModule("Lock"):IsAddonLocked(addonIndex)
			end,
		})
	end

	if (not SAM.compat.IsAddOnLoaded(addonIndex) and SAM.compat.IsAddOnLoadOnDemand(addonIndex) and reason == "DEMAND_LOADED") then
		table.insert(menu, {
			text = L["Load AddOn"],
			func = function()
				SAM:Update()
			end,
			notCheckable = true,
		})
	end

	if (SAM.compat.GetAddOnDependencies(addonIndex)) then
		table.insert(menu, {
			text = L["Enable this Addon and its dependencies"],
			func = function()
				SAM:EnableAddOn(addonIndex)
				EnableAllDeps(addonIndex)
				SAM:Update()
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
				SAM:EnableAddOn(addonIndex)
				SetAllChildren(children, true)
				SAM:Update()
			end,
			notCheckable = true,
			tooltipOnButton = true,
			tooltipTitle = title,
			tooltipText = AddonTooltipBuildChildrenString(children)
		})
		table.insert(menu, {
			text = L["Disable this and every AddOn that depends on it"],
			func = function()
				SAM:DisableAddOn(addonIndex)
				SetAllChildren(children, false)
				SAM:Update()
			end,
			notCheckable = true,
			tooltipOnButton = true,
			tooltipTitle = title,
			tooltipText = AddonTooltipBuildChildrenString(children)
		})
	end

	table.insert(menu, T.separatorInfo)
	table.insert(menu, { text = L["Categories"], isTitle = true, notCheckable = true })

	local userCategories, tocCategories = SAM:GetCategoryTables()
	local sortedCategories = SAM:TableKeysToSortedList(userCategories, tocCategories)
	for _, categoryName in ipairs(sortedCategories) do
		local categoryDb = userCategories[categoryName]
		local tocCategory = tocCategories[categoryName]
		local isInToc = tocCategory and tocCategory.addons and tocCategory.addons[name]
		table.insert(menu, {
			text = SAM:LocalizeCategoryName(categoryName, not isInToc) .. (isInToc and (" " .. C.yellow:WrapText(L["(Automatically in category)"])) or ""),
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

				SAM:Update()
			end,
		})
	end
	table.insert(menu, T.separatorInfo)
	table.insert(menu, T.closeMenuInfo)
	return menu
end

local function Checkbox_SetAddonState(self, _, addonIndex)
	local checkedTexture = self.CheckedTexture
	checkedTexture:SetVertexColor(1, 1, 1)
	checkedTexture:SetDesaturated(false)
	self.LockIcon:Hide()

	local isLocked = SAM:GetModule("Lock"):IsAddonLocked(addonIndex)
	if (isLocked) then
		self.LockIcon:Show()
	end

	local togglingAll = SAM:GetSelectedCharIndex() == 0
	if (not togglingAll) then
		local enabled = SAM:IsAddonSelected(addonIndex)
		self:SetChecked(enabled)
	else
		local enabledState = SAM.compat.GetAddOnEnableState(addonIndex)
		local isEnabledByAll = enabledState == 2
		local isEnabledBySome = enabledState == 1
		if (isEnabledByAll) then
			self:SetChecked(true)
		elseif (isEnabledBySome) then
			self:SetChecked(true)
			local charGuid = SAM:GetLoggedCharGuid()
			local isEnabledByMe = SAM.compat.GetAddOnEnableState(addonIndex, charGuid) == 2
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
	local _, _, _, _, _, security = SAM.compat.GetAddOnInfo(addonIndex)
	if (security == BANNED_ADDON) then
		return
	end

	if (IsAltKeyDown()) then
		local lockModule = SAM:GetModule("Lock")
		local isLocking = not lockModule:IsAddonLocked(addonIndex)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_FAER_TAB)
		if (isLocking) then
			lockModule:LockAddon(addonIndex)
		else
			lockModule:UnlockAddon(addonIndex)
		end
	else
		local isEnabling = not SAM:IsAddonSelected(addonIndex)
		if (isEnabling) then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			SAM:EnableAddOn(addonIndex)
		else
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			SAM:DisableAddOn(addonIndex)
		end
		Checkbox_SetAddonState(self, isEnabling, addonIndex)
	end

	SAM:Update()
end

local function AddonButtonOnClick(self, mouseButton)
	if (mouseButton == "LeftButton") then
		ToggleAddon(self.EnabledButton)
	else
		EDDM.EasyMenu(AddonRightClickMenu(self.addon), dropdownFrame, "cursor", 0, 0, "MENU")
	end
end

local function ProfilesInAddon(name)
	local db = SAM:GetDb()
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
	local userTable, tocTable, fixedTable = SAM:GetCategoryTables()

	local resultText = ""
	local sep = ""
	for _, categoryTable in pairs(userTable) do
		if (categoryTable.addons[name]) then
			resultText = resultText .. sep .. SAM:LocalizeCategoryName(categoryTable.name, userTable)
			sep = ", "
		end
	end

	for _, categoryTable in pairs(tocTable) do
		if (categoryTable.addons[name]) then
			resultText = resultText .. sep .. SAM:LocalizeCategoryName(categoryTable.name, tocTable)
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

local function CharactersWithAddon(name)
	local charTbl = {}
	local charList = CopyTable(SAM:GetCharList())
	table.remove(charList, 1) -- remove "ALL"
	-- resort the table, the original keeps the current char at the start
	table.sort(charList, function(a, b) return a.name < b.name end)

	for _, info in ipairs(charList) do
		if SAM.compat.GetAddOnEnableState(name, info.guid) == 2 then
			local _, _, _, hex = GetClassColor(info.class)
			tinsert(charTbl, WrapTextInColorCode(info.name, hex))
		end
	end

	if #charList == #charTbl then
		return L["Enabled for all characters"]
	end

	local limit = 5
	local max = #charTbl
	if (#charTbl > limit and not IsShiftKeyDown()) then
		charTbl[limit + 1] = C.grey:WrapText(L["Hold shift to show all"])
		max = limit + 1
	end

	-- Make the list of character.
	return string.join(", ", unpack(charTbl, 1, max))
end

local function AddLineIfNotEmpty(ttp, title, info)
	if (not info or info == "") then return end
	ttp:AddLine(title .. info);
end

local function IsMemoryUsageEnabled()
	-- "-1" = Disabled, "0" = Update on show.
	-- That's why we check if greater OR equals to zero here.
	return SAM:GetDb().config.memoryUpdate >= 0
end

local function UpdateTooltip(self)
	local addonIndex = self.addon.index
	local name, title, notes, _, reason, security = SAM.compat.GetAddOnInfo(addonIndex)

	AddonTooltip:ClearLines();
	AddonTooltip:SetOwner(self, "ANCHOR_NONE")
	AddonTooltip:SetPoint("LEFT", self, "RIGHT")
	if (security == BANNED_ADDON) then
		AddonTooltip:SetText(ADDON_BANNED_TOOLTIP);
	else
		if (title) then
			AddonTooltip:AddLine(title);
			AddonTooltip:AddLine(name, 0.7, 0.7, 0.7);
			--AddonTooltip:AddLine("debug: '" .. self.addon.name .. "'|r");
			--AddonTooltip:AddLine("dept: '" .. self.addon.dept .. "'|r");
			--AddonTooltip:AddLine("reason: '" .. (reason or "null") .. "'|r");
		else
			AddonTooltip:AddLine(name);
		end
		if (reason == "MISSING") then
			AddonTooltip:AddLine(C.red:WrapText(L["This addons is not installed!"]), nil, nil, nil, true);
			return
		end
		local version = SAM:GetAddOnMetadata(addonIndex, "Version")
		if (version) then
			AddonTooltip:AddLine(L["Version: "] .. C.white:WrapText(version));
		end
		local author = SAM:GetAddOnMetadata(addonIndex, "Author")
		if (author) then
			AddonTooltip:AddLine(L["Author: "] .. C.white:WrapText(strtrim(author)));
		end
		local loaded = SAM.compat.IsAddOnLoaded(addonIndex);
		if (loaded and SAM.AddonProfiler:IsProfilerEnabled()) then
			local profiler = SAM.AddonProfiler
			AddLineIfNotEmpty(AddonTooltip, L["CPU: "], profiler:GetAddonMetricPercent(name, Enum.AddOnProfilerMetric.RecentAverageTime));
			AddLineIfNotEmpty(AddonTooltip, L["Average CPU: "], profiler:GetAddonMetricPercent(name, Enum.AddOnProfilerMetric.SessionAverageTime));
			AddLineIfNotEmpty(AddonTooltip, L["Peak CPU: "], profiler:GetAddonMetricPercent(name, Enum.AddOnProfilerMetric.PeakTime));
			AddLineIfNotEmpty(AddonTooltip, L["Encounter CPU: "], profiler:GetAddonMetricPercent(name, Enum.AddOnProfilerMetric.EncounterAverageTime));
			AddLineIfNotEmpty(AddonTooltip, L["Ticks over 5ms: "], profiler:GetAddonMetricCount(name, Enum.AddOnProfilerMetric.CountTimeOver5Ms));
			AddLineIfNotEmpty(AddonTooltip, L["Ticks over 10ms: "], profiler:GetAddonMetricCount(name, Enum.AddOnProfilerMetric.CountTimeOver10Ms));
			AddLineIfNotEmpty(AddonTooltip, L["Ticks over 50ms: "], profiler:GetAddonMetricCount(name, Enum.AddOnProfilerMetric.CountTimeOver50Ms));
			AddLineIfNotEmpty(AddonTooltip, L["Ticks over 100ms: "], profiler:GetAddonMetricCount(name, Enum.AddOnProfilerMetric.CountTimeOver100Ms));
			AddLineIfNotEmpty(AddonTooltip, L["Ticks over 500ms: "], profiler:GetAddonMetricCount(name, Enum.AddOnProfilerMetric.CountTimeOver500Ms));
		end
		if (loaded and security ~= SECURE_PROTECTED_ADDON and security ~= SECURE_ADDON and IsMemoryUsageEnabled()) then
			local mem = GetAddOnMemoryUsage(addonIndex)
			AddonTooltip:AddLine(L["Memory: "] .. C.white:WrapText(SAM:FormatMemory(mem)));
		end
		AddonTooltip:AddLine(AddonTooltipBuildDepsString(addonIndex), nil, nil, nil, true);
		if (self.addon.warning) then
			AddonTooltip:AddLine(self.addon.warning, nil, nil, nil, true);
		end
		local profilesForAddon = ProfilesInAddon(name)
		if profilesForAddon ~= "" then
			AddonTooltip:AddLine(L["Profiles: "] .. C.white:WrapText(profilesForAddon), nil, nil, nil, true);
		end
		local categoriesForAddon = CategoriesForAddon(name)
		if categoriesForAddon ~= "" then
			AddonTooltip:AddLine(L["Categories: "] .. C.white:WrapText(categoriesForAddon), nil, nil, nil, true);
		end

		local charactersWithAddon = CharactersWithAddon(name)
		if charactersWithAddon ~= "" then
			AddonTooltip:AddLine(L["Characters: "] .. C.white:WrapText(charactersWithAddon), nil, nil, nil, true);
		end

		AddonTooltip:AddLine(" ");
		AddonTooltip:AddLine(notes, 1.0, 1.0, 1.0, true);
		AddonTooltip:AddLine(" ");
		AddonTooltip:AddLine("|A:newplayertutorial-icon-mouse-rightbutton:0:0|a " .. L["Right-click to edit"]);
	end
	AddonTooltip:Show()
end

function module:UpdateTooltip()
	if (module.CurrentButtonTooltip and AddonTooltip:IsShown()) then
		UpdateTooltip(module.CurrentButtonTooltip)
	end
end

local function AddonButtonOnEnter(self)
	UpdateTooltip(self)
	module.CurrentButtonTooltip = self
	AddonTooltip:Show()
end

local function AddonButtonOnLeave(_)
	module.CurrentButtonTooltip = nil
	AddonTooltip:Hide()
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
	SAM:ToggleAddonCollapsed(addon.key, addon.parentKey)
	SAM:Update()
end

local function DeptMargin(dept)
	return 13 * (dept or 0)
end

local function GetTitleWithIcon(addon)
	local addonIndex = addon.index
	local name, title = SAM.compat.GetAddOnInfo(addonIndex)
	local titleText = title or name
	local version = ""

	if (SAM:GetDb().config.showVersions and addon.exists) then
		version = SAM:GetAddOnMetadata(addonIndex, "Version")
		version = (version and C.grey:WrapText(" (" .. version .. ")")) or ""
	end

	if (not SAM:GetDb().config.hideIcons) then
		local iconTexture = SAM:GetAddOnMetadata(addonIndex, "IconTexture");
		local iconAtlas = SAM:GetAddOnMetadata(addonIndex, "IconAtlas");
		if iconTexture and CreateSimpleTextureMarkup then
			titleText = CreateSimpleTextureMarkup(iconTexture, 20, 20) .. " " .. titleText;
		elseif iconAtlas and CreateAtlasMarkup then
			titleText = CreateAtlasMarkup(iconAtlas, 20, 20) .. " " .. titleText;
		end
	end
	return titleText .. version
end

local function JoinString(sep, ...)
	local s = ""
	local res = ""
	for i = 1, select("#", ...) do
		local text = select(i, ...)
		if (text and text ~= "") then
			res = res .. s .. text
			s = sep
		end
	end
	return res
end

local function DataWithIcon(icon, data)
	if (data and data ~= "") then
		return icon .. " " .. data
	end
	return ""
end

local function UpdateButtonProfiling(self)
	local addon = self.addon
	local loaded = SAM.compat.IsAddOnLoaded(addon.index);
	if (loaded) then
		local profiler = SAM:GetModule("AddonProfiler")
		local curr = ""
		local avg = ""
		local peak = ""
		local enc = ""
		local db = SAM:GetDb().config.profiling
		if (db.cpuShowCurrent) then
			curr = DataWithIcon(
					profiler.IconCurrent,
					profiler:GetAddonMetricPercent(addon.index, Enum.AddOnProfilerMetric.RecentAverageTime, true)
			)
		end
		if (db.cpuShowAverage) then
			avg = DataWithIcon(
					profiler.IconAverage,
					profiler:GetAddonMetricPercent(addon.index, Enum.AddOnProfilerMetric.SessionAverageTime, true)
			)
		end
		if (db.cpuShowEncounter) then
			enc = DataWithIcon(
					profiler.IconEncounter,
					profiler:GetAddonMetricPercent(addon.index, Enum.AddOnProfilerMetric.EncounterAverageTime, true)
			--C.white:WrapText("1.23%")
			)
		end
		if (db.cpuShowPeak) then
			peak = DataWithIcon(
					profiler.IconPeak,
					profiler:GetAddonMetricPercent(addon.index, Enum.AddOnProfilerMetric.PeakTime, true)
			)
		end
		self.Status:SetText(JoinString(C.grey:WrapText(" | "), curr, avg, enc, peak))
	end
end

local wowExpMargin = LE_EXPANSION_LEVEL_CURRENT >= 9 and 4 or 0

local function UpdateList()
	local buttons = HybridScrollFrame_GetButtons(SAM.AddonListFrame.ScrollFrame);
	local offset = HybridScrollFrame_GetOffset(SAM.AddonListFrame.ScrollFrame);
	local buttonHeight;
	local addons = SAM:GetAddonsList()
	local count = #addons
	local isInTreeMode = SAM:GetDb().config.addonListStyle == "tree"
	local showProfiling = SAM.AddonProfiler:IsProfilerEnabled()

	for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex]
		button:SetPoint("LEFT", SAM.AddonListFrame.ScrollFrame)
		button:SetPoint("RIGHT", SAM.AddonListFrame.ScrollFrame)

		local relativeButtonIndex = buttonIndex + offset
		buttonHeight = button:GetHeight()

		if relativeButtonIndex <= count then
			local addon = addons[relativeButtonIndex]
			local addonIndex = addon.index
			local _, _, _, loadable, reason, security = SAM.compat.GetAddOnInfo(addonIndex)
			local loaded = SAM.compat.IsAddOnLoaded(addonIndex)
			local enabled = SAM:IsAddonSelected(addonIndex)

			button.ExpandOrCollapseButton:SetScript("OnClick", ExpandOrCollapseButtonOnClick)
			local showExpandOrCollapseButton = isInTreeMode and addon.children and next(addon.children)
			local isCollapsed = SAM:IsAddonCollapsed(addon.key, addon.parentKey)
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

			if (loaded and showProfiling) then
				UpdateButtonProfiling(button)
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

	HybridScrollFrame_Update(SAM.AddonListFrame.ScrollFrame, count * buttonHeight, SAM.AddonListFrame.ScrollFrame:GetHeight())
end

local function OnSizeChanged(self)
	local offsetBefore = self:GetValue()
	HybridScrollFrame_CreateButtons(self:GetParent(), "SimpleAddonManagerAddonItem")
	self:SetValue(offsetBefore)
	self:GetParent().update()
end

local function UpdateMemory()
	UpdateAddOnMemoryUsage()
	module:UpdateTooltip()
end

local function OnShow()
	local update = SAM:GetDb().config.memoryUpdate
	SAM:UpdateMemoryTickerPeriod(update)
	if (IsMemoryUsageEnabled()) then
		UpdateMemory()
	end
	SAM.AddonListFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
end

local function OnHide()
	SAM:UpdateMemoryTickerPeriod(0)
	SAM.AddonListFrame:UnregisterEvent("MODIFIER_STATE_CHANGED")
end

function module.events:MODIFIER_STATE_CHANGED(key, down)
	if (key == "LSHIFT" or key == "RSHIFT") then
		module:UpdateTooltip()
	end
end

function SAM:UpdateMemoryTickerPeriod(period)
	if (self.MemoryUpdateTicker) then
		self.MemoryUpdateTicker:Cancel()
		self.MemoryUpdateTicker = nil
	end
	if (period > 0) then
		self.MemoryUpdateTicker = C_Timer.NewTicker(period, UpdateMemory)
	end
end

function module:PreInitialize()
	SAM.AddonListFrame = CreateFrame("Frame", nil, SAM)
	SAM.AddonListFrame.ScrollFrame = CreateFrame("ScrollFrame", nil, SAM.AddonListFrame, "HybridScrollFrameTemplate")
	SAM.AddonListFrame.ScrollFrame:SetScript("OnMouseWheel", SAM.HybridScrollFrame_ShiftAwareOnScrollWheel)
	SAM.AddonListFrame.ScrollFrame.ScrollBar = CreateFrame("Slider", nil, SAM.AddonListFrame.ScrollFrame, "HybridScrollBarTemplate")
end

function module:Initialize()
	SAM.AddonListFrame.rightPadding = -9
	SAM.AddonListFrame:Hide()
	SAM.AddonListFrame:SetPoint("TOPLEFT", 7, -64)
	SAM.AddonListFrame:SetPoint("BOTTOMRIGHT", SAM.AddonListFrame.rightPadding, 30)
	SAM.AddonListFrame:SetScript("OnShow", OnShow)
	SAM.AddonListFrame:SetScript("OnHide", OnHide)
	SAM.AddonListFrame:SetScript("OnEvent", function(self, event, ...)
		module.events[event](self, ...)
	end)
	SAM.AddonListFrame:Show()

	SAM.AddonListFrame.ScrollFrame:SetPoint("TOPLEFT")
	SAM.AddonListFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", -20, 0)
	SAM.AddonListFrame.ScrollFrame.update = UpdateList

	SAM.AddonListFrame.ScrollFrame.ScrollBar:ClearAllPoints()
	SAM.AddonListFrame.ScrollFrame.ScrollBar:SetPoint("TOPRIGHT", SAM.AddonListFrame, "TOPRIGHT", 0, -16)
	SAM.AddonListFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", SAM.AddonListFrame, "BOTTOMRIGHT", 0, 12)
	SAM.AddonListFrame.ScrollFrame.ScrollBar:SetScript("OnSizeChanged", OnSizeChanged)
	SAM.AddonListFrame.ScrollFrame.ScrollBar.doNotHide = true

	HybridScrollFrame_CreateButtons(SAM.AddonListFrame.ScrollFrame, "SimpleAddonManagerAddonItem")
end

function module:OnLoad()
	local db = SAM:GetDb()
	SAM:CreateDefaultOptions(db.config, {
		memoryUpdate = -1,
		hideIcons = false,
	})
end
