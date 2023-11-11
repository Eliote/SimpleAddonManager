local _, T = ...
local L = T.L
local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("SimpleAddonManager_MenuFrame")

--- @type SimpleAddonManager
local frame = T.AddonFrame
local module = frame:RegisterModule("Search")

local function SearchResultDropDownCreate()
	local userCategories, tocCategories = frame:GetCategoryTables()
	local sortedCategories = frame:TableKeysToSortedList(userCategories, tocCategories)
	local addons = frame:GetAddonsList()
	local function categoriesMenu(add)
		local menu = {}
		for _, categoryName in ipairs(sortedCategories) do
			table.insert(menu, {
				text = categoryName,
				notCheckable = true,
				func = function()
					for _, addon in ipairs(addons) do
						local name = frame.compat.GetAddOnInfo(addon.index)
						if (not add and (not userCategories[categoryName] or not userCategories[categoryName].addons)) then
							-- there is nothing to remove, avoid creating custom category
							return
						end
						userCategories[categoryName] = userCategories[categoryName] or { name = categoryName }
						userCategories[categoryName].addons = userCategories[categoryName].addons or {}
						userCategories[categoryName].addons[name] = add
						EDDM.CloseDropDownMenus()
					end

					frame:Update()
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
	frame.SearchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
	frame.ResultOptionsButton = Mixin(
			CreateFrame("Button", nil, frame, "UIPanelSquareButton"),
			EDDM.HandlesGlobalMouseEventMixin
	)
end

function module:Initialize()
	frame.SearchBox:SetPoint("LEFT", frame.SetsButton, "RIGHT", 8, 0)
	frame.SearchBox:SetSize(120, 20)
	frame.SearchBox:SetScript("OnTextChanged", function(self)
		SearchBoxTemplate_OnTextChanged(self)
		frame:UpdateListFilters()
		if (frame.SearchBox:GetText() == "") then
			frame.ResultOptionsButton:Hide()
		else
			frame.ResultOptionsButton:Show()
		end
	end)

	frame.ResultOptionsButton:SetPoint("LEFT", frame.SearchBox, "RIGHT", 1, 0)
	frame.ResultOptionsButton:SetSize(26, 26)
	frame.ResultOptionsButton.icon:SetAtlas("transmog-icon-downarrow")
	frame.ResultOptionsButton.icon:SetTexCoord(0, 1, 0, 1)
	frame.ResultOptionsButton.icon:SetSize(15, 9)
	frame.ResultOptionsButton:SetScript("OnClick", function()
		EDDM.ToggleEasyMenu(SearchResultDropDownCreate(), dropdownFrame, frame.ResultOptionsButton, 0, 0, "MENU")
	end)
end
