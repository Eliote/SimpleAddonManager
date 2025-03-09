local _, T = ...
local L = T.L
local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("SimpleAddonManager_MenuFrame")

--- @type SimpleAddonManager
local SAM = T.AddonFrame
local module = SAM:RegisterModule("Options")

local function MemoryUpdateMenuList()
	local db = SAM:GetDb()
	local menu = {}
	local periods = { -1, 0, 5, 10, 15, 30 }
	local periodDesc = {
		[-1] = DISABLE,
		[0] = L["Update only when opening the main window"],
	}
	for _, v in ipairs(periods) do
		table.insert(menu, {
			text = periodDesc[v] or L("${n} seconds", { n = v }),
			checked = function()
				return db.config.memoryUpdate == v
			end,
			func = function()
				db.config.memoryUpdate = v
				SAM:UpdateMemoryTickerPeriod(v)
			end,
		})
	end
	return menu
end

local function CPUUpdateMenuList()
	local db = SAM:GetDb()
	local menu = {}
	local periods = { 0, 0.1, 0.25, 0.5, 1, 5 }
	for _, v in ipairs(periods) do
		table.insert(menu, {
			text = (v == 0) and DISABLE or L("${n} seconds", { n = v }),
			checked = function()
				return db.config.profiling.cpuUpdate == v
			end,
			func = function()
				db.config.profiling.cpuUpdate = v
				SAM:GetModule("AddonProfiler"):OnShow()
				SAM:Update()
			end,
		})
	end
	return menu
end

local function ConfigDropDownCreate()
	local db = SAM:GetDb()
	return {
		{ text = L["Options"], isTitle = true, notCheckable = true },
		{
			text = ADDON_FORCE_LOAD,
			checked = function()
				return not SAM.compat.IsAddonVersionCheckEnabled()
			end,
			func = function(_, _, _, checked)
				SAM.compat.SetAddonVersionCheck(checked)
				SAM:Update()
			end,
		},
		{
			text = L["Replace original Addon wow menu button"],
			checked = function()
				return db.config.hookMenuButton
			end,
			func = function()
				db.config.hookMenuButton = not db.config.hookMenuButton
				if (db.config.hookMenuButton) then
					SAM:HookMenuButton()
				end
			end,
		},
		{
			text = L["Show minimap button"],
			checked = function()
				return not db.config.minimap.hide
			end,
			func = function()
				SAM:GetModule("Minimap"):ToggleMinimapButton()
			end,
		},
		{
			text = L["Show memory usage in broker/minimap tooltip"],
			checked = function()
				return db.config.showMemoryInBrokerTtp
			end,
			func = function()
				db.config.showMemoryInBrokerTtp = not db.config.showMemoryInBrokerTtp
			end,
		},
		{
			text = L["Show warning dialog when a disabled but locked addon is detected"],
			checked = function()
				return db.lock.canShowWarning
			end,
			func = function()
				db.lock.canShowWarning = not db.lock.canShowWarning
				SAM:Update()
			end,
		},
		{
			text = L["Memory Update"],
			notCheckable = true,
			hasArrow = true,
			menuList = MemoryUpdateMenuList(),
		},
		{
			text = L["CPU Update"],
			notCheckable = true,
			hasArrow = true,
			disabled = not C_AddOnProfiler or not C_AddOnProfiler.IsEnabled(),
			menuList = CPUUpdateMenuList(),
			tooltipOnButton = not C_AddOnProfiler or not C_AddOnProfiler.IsEnabled(),
			tooltipTitle = L["CPU data is not available in this version of WoW."],
			tooltipText = "",
		},
		{
			text = L["CPU Visibility"],
			notCheckable = true,
			hasArrow = true,
			disabled = not C_AddOnProfiler or not C_AddOnProfiler.IsEnabled(),
			menuList = {
				{
					text = L["Show Current"],
					checked = function()
						return db.config.profiling.cpuShowCurrent
					end,
					func = function(_, _, _, value)
						db.config.profiling.cpuShowCurrent = not value
						SAM:Update()
					end,
				},
				{
					text = L["Show Average"],
					checked = function()
						return db.config.profiling.cpuShowAverage
					end,
					func = function(_, _, _, value)
						db.config.profiling.cpuShowAverage = not value
						SAM:Update()
					end,
				},
				{
					text = L["Show Encounter"],
					checked = function()
						return db.config.profiling.cpuShowEncounter
					end,
					func = function(_, _, _, value)
						db.config.profiling.cpuShowEncounter = not value
						SAM:Update()
					end,
				},
				{
					text = L["Show Peak"],
					checked = function()
						return db.config.profiling.cpuShowPeak
					end,
					func = function(_, _, _, value)
						db.config.profiling.cpuShowPeak = not value
						SAM:Update()
					end,
				},
			},
			tooltipOnButton = not C_AddOnProfiler or not C_AddOnProfiler.IsEnabled(),
			tooltipTitle = L["CPU data is not available in this version of WoW."],
			tooltipText = "",
		},
		T.separatorInfo,
		{ text = L["List Options"], isTitle = true, notCheckable = true },
		{
			text = L["Show versions in AddOns list"],
			checked = function()
				return db.config.showVersions
			end,
			func = function()
				db.config.showVersions = not db.config.showVersions
				SAM:Update()
			end,
		},
		{
			text = L["View AddOn list as dependency tree"],
			checked = function()
				return db.config.addonListStyle == "tree"
			end,
			func = function(_, _, _, value)
				db.config.addonListStyle = (not value) and "tree" or "list"
				SAM:Update()
			end,
		},
		{
			text = L["Show Blizzard addons found in dependencies"],
			checked = function()
				return db.config.showSecureAddons
			end,
			func = function()
				local isEnabling = not db.config.showSecureAddons
				if (isEnabling) then
					SAM:ShowWarningDialog(
							L["Be careful with this option, enabling/disabling Blizzard Addons might have unintended consequences!"],
							function()
								db.config.showSecureAddons = true
								SAM:Update()
							end
					)
				else
					db.config.showSecureAddons = false
					SAM:Update()
				end
			end,
		},
		{
			text = L["Hide icons"],
			checked = function()
				return db.config.hideIcons
			end,
			func = function()
				db.config.hideIcons = not db.config.hideIcons
				SAM:Update()
			end,
		},
		{
			text = L["Collapse all"],
			notCheckable = true,
			func = function()
				for _, v in pairs(SAM:GetAddonsList()) do
					SAM:SetAddonCollapsed(v.key, v.parentKey, true)
				end
				SAM:Update()
			end,
			disabled = db.config.addonListStyle ~= "tree",
		},
		{
			text = L["Expand all"],
			notCheckable = true,
			func = function()
				SAM:GetDb().collapsedAddons = {}
				SAM:Update()
			end,
			disabled = db.config.addonListStyle ~= "tree",
		},
		{
			text = L["Sort by"],
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{ text = L["A-Z"], isTitle = true, notCheckable = true },
				{
					text = L["Name (improved)"],
					checked = function()
						return db.config.sorting == "smart"
					end,
					func = function()
						db.config.sorting = "smart"
						SAM:Update()
					end,
				},
				{
					text = L["Internal name"],
					checked = function()
						return db.config.sorting == "name"
					end,
					func = function()
						db.config.sorting = "name"
						SAM:Update()
					end,
				},
				{
					text = L["Title"],
					checked = function()
						return db.config.sorting == "title"
					end,
					func = function()
						db.config.sorting = "title"
						SAM:Update()
					end,
				},
				{
					text = L["None"],
					checked = function()
						return not db.config.sorting
					end,
					func = function()
						db.config.sorting = false
						SAM:Update()
					end,
				},
				T.separatorInfo,
				{ text = L["CPU Usage"], isTitle = true, notCheckable = true },
				{
					text = L["Current"],
					checked = function()
						return db.config.sortingCpu == "current"
					end,
					func = function()
						db.config.sortingCpu = "current"
						SAM:Update()
					end,
				},
				{
					text = L["Average"],
					checked = function()
						return db.config.sortingCpu == "average"
					end,
					func = function()
						db.config.sortingCpu = "average"
						SAM:Update()
					end,
				},
				{
					text = L["Encounter"],
					checked = function()
						return db.config.sortingCpu == "encounter"
					end,
					func = function()
						db.config.sortingCpu = "encounter"
						SAM:Update()
					end,
				},
				{
					text = L["Peak"],
					checked = function()
						return db.config.sortingCpu == "peak"
					end,
					func = function()
						db.config.sortingCpu = "peak"
						SAM:Update()
					end,
				},
				{
					text = L["None"],
					checked = function()
						return not db.config.sortingCpu
					end,
					func = function()
						db.config.sortingCpu = false
						SAM:Update()
					end,
				},
			},
		},
		T.separatorInfo,
		{ text = L["Category Options"], isTitle = true, notCheckable = true },
		{
			text = L["Show autogenerated custom categories (X-Category)"],
			checked = function()
				return db.config.showTocXCategory
			end,
			func = function()
				db.config.showTocXCategory = not db.config.showTocXCategory
				SAM:Update()
			end,
		},
		{
			text = L["Show autogenerated categories"],
			checked = function()
				return db.config.showTocCategory
			end,
			func = function()
				db.config.showTocCategory = not db.config.showTocCategory
				SAM:Update()
			end,
		},
		{
			text = L["Localize autogenerated categories name"],
			checked = function()
				return db.config.localizeCategoryName
			end,
			func = function()
				db.config.localizeCategoryName = not db.config.localizeCategoryName
				SAM:Update()
			end,
		},
		T.separatorInfo,
		{ text = L["Search Options"], isTitle = true, notCheckable = true },
		{
			text = L["Autofocus searchbar when opening the UI"],
			checked = function()
				return db.config.autofocusSearch
			end,
			func = function()
				db.config.autofocusSearch = not db.config.autofocusSearch
			end,
		},
		{
			text = L["Search By"],
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = L["Internal name"],
					checked = function()
						return db.config.searchBy.name
					end,
					func = function()
						db.config.searchBy.name = not db.config.searchBy.name
						SAM:Update()
					end,
				},
				{
					text = L["Title"],
					checked = function()
						return db.config.searchBy.title
					end,
					func = function()
						db.config.searchBy.title = not db.config.searchBy.title
						SAM:Update()
					end,
				},
				{
					text = L["Author"],
					checked = function()
						return db.config.searchBy.author
					end,
					func = function()
						db.config.searchBy.author = not db.config.searchBy.author
						SAM:Update()
					end,
				},
			},
		},
		T.separatorInfo,
		{ text = L["Utilities"], isTitle = true, notCheckable = true },
		{
			text = L["AddOn binary search"] .. " (beta)",
			notCheckable = true,
			func = function()
				SAM:GetModule("AddonFinder"):StartSearch()
			end,
			disabled = db.addonFinder and db.addonFinder.isSearching,
		},
		T.separatorInfo,
		T.closeMenuInfo
	}
end

function module:OnLoad()
	SAM:CreateDefaultOptions(SAM:GetDb().config, {
		showMemoryInBrokerTtp = true,
		showTocXCategory = false,
		showTocCategory = true,
	})
end

function module:PreInitialize()
	SAM.ConfigButton = Mixin(
			CreateFrame("Button", nil, SAM, "UIPanelSquareButton"),
			EDDM.HandlesGlobalMouseEventMixin
	)
end

function module:Initialize()
	SAM.ConfigButton:SetPoint("RIGHT", SAM.CategoryButton, "LEFT", -4, 0)
	SAM.ConfigButton:SetSize(30, 30)
	SAM.ConfigButton.icon:SetAtlas("OptionsIcon-Brown")
	SAM.ConfigButton.icon:SetTexCoord(0, 1, 0, 1)
	SAM.ConfigButton.icon:SetSize(16, 16)
	SAM.ConfigButton:SetScript("OnClick", function()
		EDDM.ToggleEasyMenu(ConfigDropDownCreate(), dropdownFrame, SAM.ConfigButton, 0, 0, "MENU")
	end)
end
