local _, T = ...
local L = T.L
local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("SimpleAddonManager_MenuFrame")

--- @type SimpleAddonManager
local SAM = T.AddonFrame
local module = SAM:RegisterModule("Search")

local function SearchResultDropDownCreate()
	local userCategories, tocCategories = SAM:GetCategoryTables()
	local sortedCategories = SAM:TableKeysToSortedList(userCategories, tocCategories)
	local addons = SAM:GetAddonsList()
	local function categoriesMenu(add)
		local menu = {}
		for _, categoryName in ipairs(sortedCategories) do
			table.insert(menu, {
				text = categoryName,
				notCheckable = true,
				func = function()
					for _, addon in ipairs(addons) do
						local name = SAM.compat.GetAddOnInfo(addon.index)
						if (not add and (not userCategories[categoryName] or not userCategories[categoryName].addons)) then
							-- there is nothing to remove, avoid creating custom category
							return
						end
						userCategories[categoryName] = userCategories[categoryName] or { name = categoryName }
						userCategories[categoryName].addons = userCategories[categoryName].addons or {}
						userCategories[categoryName].addons[name] = add
						EDDM.CloseDropDownMenus()
					end

					SAM:Update()
				end,
			})
		end
		return menu
	end

	local menu = {
		{ text = L("Results: ${results}", { results = #addons }), isTitle = true, notCheckable = true },
		{
			text = L["Add search results to category"],
			notCheckable = true,
			hasArrow = true,
			menuList = categoriesMenu(true)
		},
		{
			text = L["Remove search results from category"],
			notCheckable = true,
			hasArrow = true,
			menuList = categoriesMenu(nil)
		}
	}

	table.insert(menu, T.separatorInfo)
	table.insert(menu, T.closeMenuInfo)

	return menu
end

function module:PreInitialize()
	SAM.SearchBox = CreateFrame("EditBox", nil, SAM, "SearchBoxTemplate")
	SAM.ResultOptionsButton = Mixin(
			CreateFrame("Button", nil, SAM, "UIPanelSquareButton"),
			EDDM.HandlesGlobalMouseEventMixin
	)
end

function module:Initialize()
	SAM.SearchBox:SetPoint("LEFT", SAM.SetsButton, "RIGHT", 8, 0)
	SAM.SearchBox:SetSize(120, 20)
	SAM.SearchBox:SetScript("OnTextChanged", function(self)
		SearchBoxTemplate_OnTextChanged(self)
		SAM:UpdateListFilters()
		if (SAM.SearchBox:GetText() == "") then
			SAM.ResultOptionsButton:Hide()
		else
			SAM.ResultOptionsButton:Show()
		end
	end)

	SAM.ResultOptionsButton:SetPoint("LEFT", SAM.SearchBox, "RIGHT", 1, 0)
	SAM.ResultOptionsButton:SetSize(26, 26)
	SAM.ResultOptionsButton.icon:SetAtlas("transmog-icon-downarrow")
	SAM.ResultOptionsButton.icon:SetTexCoord(0, 1, 0, 1)
	SAM.ResultOptionsButton.icon:SetSize(15, 9)
	SAM.ResultOptionsButton:SetScript("OnClick", function()
		EDDM.ToggleEasyMenu(SearchResultDropDownCreate(), dropdownFrame, SAM.ResultOptionsButton, 0, 0, "MENU")
	end)
end
