local _, T = ...
local L = T.L
local C = T.Color
local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("SimpleAddonManager_MenuFrame")

--- @type SimpleAddonManager
local SAM = T.AddonFrame
local module = SAM:RegisterModule("Category")

local function CategoryMenu(categoryKey, categoryName)
	local db = SAM:GetDb()
	local menu = {
		{ text = categoryName, isTitle = true, notCheckable = true },
		{
			text = L["Rename"],
			notCheckable = true,
			disabled = db.categories[categoryKey] == nil,
			func = function()
				SAM:ShowInputDialog(
						L("Enter the new name for the category '${category}'", { category = categoryName }),
						function(text)
							if db.categories[text] or not SAM:ValidateCategoryName(text) then
								return
							end
							db.categories[text] = db.categories[categoryKey]
							db.categories[categoryKey] = nil
							db.categories[text].name = text
							local selectedItems = SAM.CategoryFrame.ScrollFrame.selectedItems
							if (selectedItems[categoryKey]) then
								selectedItems[text] = selectedItems[categoryKey]
								selectedItems[categoryKey] = nil
							end
							SAM:Update()
						end,
						function(self)
							self:GetEditBox():SetText(categoryName)
							self:GetEditBox():HighlightText()
						end
				)
			end
		},
		{
			text = L["Delete"],
			notCheckable = true,
			disabled = db.categories[categoryKey] == nil,
			func = function()
				SAM:ShowConfirmDialog(
						L("Delete category '${category}'?", { category = categoryKey }),
						function()
							db.categories[categoryKey] = nil
							SAM.CategoryFrame.ScrollFrame.selectedItems[categoryKey] = nil
							SAM:Update()
						end
				)
			end
		},
		T.separatorInfo,
		{
			text = L["Enable Addons"],
			notCheckable = true,
			disabled = db.categories[categoryKey] == nil,
			func = function()
				module:EnableCategory(categoryKey)
			end
		},
		{
			text = L["Disable Addons"],
			notCheckable = true,
			disabled = db.categories[categoryKey] == nil,
			func = function()
				module:DisableCategory(categoryKey)
			end
		},
		T.separatorInfo,
		T.closeMenuInfo,
	}

	return menu
end

local function CommonCountFunction(self)
	local count = 0
	for addonIndex = 1, SAM.compat.GetNumAddOns() do
		if (self:addons(addonIndex)) then
			count = count + 1
		end
	end
	return count
end

local fixedCategories = {
	["!!!!!_00_ENABLED_CATEGORY"] = {
		type = "fixed",
		name = C.green:WrapText(L["Enabled Addons"]),
		description = L["Currently Enabled Addons"],
		addons = function(_, key)
			return SAM:IsAddonSelected(key)
		end,
		count = CommonCountFunction
	},
	["!!!!!_01_DISABLED_CATEGORY"] = {
		type = "fixed",
		name = C.green:WrapText(L["Disabled Addons"]),
		description = L["Currently Disabled Addons"],
		addons = function(_, key)
			return not SAM:IsAddonSelected(key)
		end,
		count = CommonCountFunction
	},
	["!!!!!_02_ACTIVE_CATEGORY"] = {
		type = "fixed",
		name = C.green:WrapText(L["Active Addons"]),
		description = L["Addons enabled and loaded, or ready to be loaded on demand."],
		addons = function(_, key)
			local _, _, _, loadable, reason = SAM.compat.GetAddOnInfo(key)
			return loadable or reason == "DEMAND_LOADED"
		end,
		count = CommonCountFunction
	},
	["!!!!!_03_UNCATEGORIZED_CATEGORY"] = {
		type = "fixed",
		name = C.green:WrapText(L["Uncategorized Addons"]),
		description = L["Addons not in any category. It will be taken into account if you are viewing or not auto-generated categories."],
		prepare = function(self)
			local cache = {}
			local user, toc = SAM:GetCategoryTables()
			for _, v in pairs(user) do
				MergeTable(cache, v.addons)
			end
			for _, v in pairs(toc) do
				MergeTable(cache, v.addons)
			end
			self.cache = cache
		end,
		addons = function(self, key)
			local name = SAM.compat.GetAddOnInfo(key)
			return not self.cache[name]
		end,
		count = function(self)
			self:prepare()
			return CommonCountFunction(self)
		end
	},
	["!!!!!_04_LOCKED_CATEGORY"] = {
		type = "fixed",
		name = C.green:WrapText(L["Locked Addons"]),
		addons = function(_, key)
			return SAM:GetModule("Lock"):IsAddonLocked(key)
		end,
		count = CommonCountFunction
	},
	["!!!!!_55_CHANGING_STATE"] = {
		type = "fixed",
		name = C.red:WrapText(L["Addons being modified"]),
		description = L["Addons being modified in this session"],
		addons = function(_, key)
			return SAM:DidAddonStateChanged(key, SAM:GetSelectedCharGuid())
		end,
		show = function()
			return SAM:DidAnyAddonStateChanged(SAM:GetSelectedCharGuid())
		end,
		count = CommonCountFunction
	},
}

local function tablelength(t)
	if not t then
		return 0
	end
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

local function IsCategorySelected(name)
	local item = SAM.CategoryFrame.ScrollFrame.selectedItems[name]
	if item == nil or item == false then
		return false
	end
	return true
end

local function ToggleCategory(self)
	local key = self:GetParent().categoryKey
	local enabled = IsCategorySelected(key)
	local newValue = not enabled
	self:SetChecked(newValue)
	if (newValue) then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		SAM.CategoryFrame.ScrollFrame.selectedItems[key] = true
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		SAM.CategoryFrame.ScrollFrame.selectedItems[key] = nil
	end
	SAM:UpdateListFilters()
	SAM.CategoryFrame.ScrollFrame.update()
end

local function SetAllCategories(value)
	-- when disabling the categories, we only need to clear the selection table
	if (not value) then
		for name, _ in pairs(SAM.CategoryFrame.ScrollFrame.selectedItems) do
			SAM.CategoryFrame.ScrollFrame.selectedItems[name] = value
		end
	else
		-- we purposely ignore the "fix" table when enabling all categories
		local user, toc, _ = SAM:GetCategoryTables()
		for name, _ in pairs(user) do
			SAM.CategoryFrame.ScrollFrame.selectedItems[name] = value
		end
		for name, _ in pairs(toc) do
			SAM.CategoryFrame.ScrollFrame.selectedItems[name] = value
		end
	end
end

local function IsAnythingElseSelected(target)
	local items = SAM.CategoryFrame.ScrollFrame.selectedItems
	for name, _ in pairs(items) do
		if (target ~= name and SAM.CategoryFrame.ScrollFrame.selectedItems[name]) then
			return true
		end
	end
end

local function CategoryButtonOnClick(self, mouseButton)
	if (mouseButton == "LeftButton") then
		if (not IsShiftKeyDown()) then
			local isSelected = IsCategorySelected(self.categoryKey)
			local isTheOnlySelected = isSelected and not IsAnythingElseSelected(self.categoryKey)
			SetAllCategories(nil) -- clear everything
			if (isTheOnlySelected) then
				-- If this is the only category selected, we reselect it after the clear.
				-- This way the [ToggleCategory] will deselect it and update everything properly.
				SAM.CategoryFrame.ScrollFrame.selectedItems[self.categoryKey] = true
			end
		end
		ToggleCategory(self.EnabledButton)
	elseif (self.category.type ~= "fixed") then
		EDDM.EasyMenu(CategoryMenu(self.categoryKey, self.categoryName), dropdownFrame, "cursor", 0, 0, "MENU")
	end
end

local function CategoryButtonOnEnter(self)
	local name = self.categoryName
	local key = self.categoryKey
	local userTable, tocTable, fixedTable = SAM:GetCategoryTable(key)
	GameTooltip:ClearLines();
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("LEFT", self, "RIGHT")
	GameTooltip:AddLine(SAM:LocalizeCategoryName(name, userTable), 1, 1, 1);
	if (tocTable) then
		GameTooltip:AddLine(L["Category created from addons metadata"], nil, nil, nil, true);
	elseif (fixedTable) then
		GameTooltip:AddLine(self.category.description, nil, nil, nil, true);
	else
		GameTooltip:AddLine(L["User created category"], nil, nil, nil, true);
	end
	GameTooltip:AddLine("\n");
	if (fixedTable) then
		GameTooltip:AddDoubleLine(L["Addons:"], self.category:count(), nil, nil, nil, 1, 1, 1);
	else
		GameTooltip:AddDoubleLine(L["Manually added:"], userTable and tablelength(userTable.addons) or 0, nil, nil, nil, 1, 1, 1);
		local fromTocCount = tocTable and tablelength(tocTable.addons) or 0
		if (fromTocCount > 0) then
			GameTooltip:AddDoubleLine(L["Automatically added:"], tocTable and tablelength(tocTable.addons) or 0, nil, nil, nil, 1, 1, 1);
		end
	end
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("|A:newplayertutorial-icon-mouse-rightbutton:0:0|a " .. L["Right-click to edit"]);
	GameTooltip:Show()
end

local function CategoryButtonOnLeave()
	GameTooltip:Hide()
end

local function UpdateCategoryList()
	local buttons = HybridScrollFrame_GetButtons(SAM.CategoryFrame.ScrollFrame);
	local offset = HybridScrollFrame_GetOffset(SAM.CategoryFrame.ScrollFrame);
	local buttonHeight;
	local count = #(SAM.CategoryFrame.ScrollFrame.sortedItemsList)

	for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex]
		button:SetPoint("LEFT", SAM.CategoryFrame.ScrollFrame)
		button:SetPoint("RIGHT", SAM.CategoryFrame.ScrollFrame)

		local relativeButtonIndex = buttonIndex + offset
		buttonHeight = button:GetHeight()

		if relativeButtonIndex <= count then
			local categoryKey = SAM.CategoryFrame.ScrollFrame.sortedItemsList[relativeButtonIndex]
			local userCategory, tocCategory, fixed = SAM:GetCategoryTable(categoryKey)
			local category = userCategory or tocCategory or fixed
			if (userCategory) then
				button.Name:SetText(category.name)
			elseif (fixed) then
				button.Name:SetText(category.name)
			else
				button.Name:SetText(C.yellow:WrapText(SAM:LocalizeCategoryName(category.name)))
			end
			local enabled = IsCategorySelected(categoryKey)

			button.categoryName = category.name
			button.categoryKey = categoryKey
			button.category = category
			button.EnabledButton:SetChecked(enabled)
			button.EnabledButton:SetScript("OnClick", ToggleCategory)

			button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			button:SetScript("OnClick", CategoryButtonOnClick)

			button:SetScript("OnEnter", CategoryButtonOnEnter)
			button:SetScript("OnLeave", CategoryButtonOnLeave)

			button:Show()
		else
			button:Hide()
		end
	end

	HybridScrollFrame_Update(SAM.CategoryFrame.ScrollFrame, count * buttonHeight, SAM.CategoryFrame.ScrollFrame:GetHeight())
end

local function BuildCategoryTableFromToc(targetTable, metaField)
	local count = SAM.compat.GetNumAddOns()
	for addonIndex = 1, count do
		local value = SAM:GetAddOnMetadata(addonIndex, metaField) -- or SAM:GetAddOnMetadata(addonIndex, "X-Category")
		if value then
			value = strtrim(value)
			targetTable[value] = targetTable[value] or { addons = {} }
			local name = SAM.compat.GetAddOnInfo(addonIndex)
			targetTable[value].addons[name] = true
			targetTable[value].name = value
		end
	end
	return targetTable
end

local function OnClickNewButton()
	SAM:ShowInputDialog(L["Enter the category name"], function(text)
		local db = SAM:GetDb()
		db.categories = db.categories or {}
		if (db.categories[text] or not SAM:ValidateCategoryName(text)) then
			return
		end

		db.categories[text] = { name = text, addons = {} }
		SAM:UpdateCategoryFrame()
	end)
end

local function BuildAutoGeneratedCategories()
	local t = {}
	for k, v in pairs(fixedCategories) do
		if (v.show == nil) then
			t[k] = v
		elseif (v.show()) then
			t[k] = v
		end
	end
	return t
end

local categoryTocTable = {}

local function UpdateListVariables()
	local db = SAM:GetDb()
	db.categories = db.categories or {}
	categoryTocTable = {}
	if (db.config.showTocXCategory) then
		BuildCategoryTableFromToc(categoryTocTable, "X-Category")
	end
	if (db.config.showTocCategory) then
		BuildCategoryTableFromToc(categoryTocTable, "Category")
	end
	local auto = BuildAutoGeneratedCategories()
	local categoriesList = SAM:TableKeysToSortedList(db.categories, categoryTocTable, auto)
	SAM.CategoryFrame.ScrollFrame.sortedItemsList = categoriesList
	local selectedItems = SAM.CategoryFrame.ScrollFrame.selectedItems
	for k, _ in pairs(selectedItems) do
		if (not db.categories[k] and not categoryTocTable[k] and not auto[k]) then
			selectedItems[k] = nil
		end
	end
end

function SAM:LocalizeCategoryName(name, isUserCategory)
	if (isUserCategory or not SAM:GetDb().config.localizeCategoryName) then
		return name
	end
	return rawget(L, string.lower(name)) or name
end

local function OnSizeChangedScrollFrame(self)
	local offsetBefore = self:GetValue()
	HybridScrollFrame_CreateButtons(self:GetParent(), "SimpleAddonManagerCategoryItem")
	self:SetValue(offsetBefore)
	self:GetParent().update()
end

local function SetAllAndUpdate(self)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	SetAllCategories(self.value)
	SAM:Update()
end

function SAM:ValidateCategoryName(name)
	if (fixedCategories[name]) then
		return false
	end
	return true
end

function SAM:GetCategoryTable(name)
	local userCategory, tocCategory, fixedCategory = self:GetCategoryTables()
	return userCategory[name], tocCategory[name], fixedCategory[name]
end

function SAM:GetCategoryTables()
	local db = self:GetDb()
	local userCategories = db.categories
	local tocCategories = categoryTocTable
	return userCategories, tocCategories, fixedCategories
end

function SAM:SelectedCategories()
	return self.CategoryFrame.ScrollFrame.selectedItems
end

function SAM:UpdateCategoryFrame()
	self.CategoryFrame.ScrollFrame.updateDb()
	self.CategoryFrame.ScrollFrame.update()
end

function SAM:SetCategoryVisibility(show, resize)
	local fw = SAM:GetWidth()
	if (show) then
		SquareButton_SetIcon(SAM.CategoryButton, "LEFT")
		SAM.AddonListFrame:SetPoint("BOTTOMRIGHT", (SAM.AddonListFrame.rightPadding - SAM.CATEGORY_SIZE_W), 30)
		if (resize) then
			SAM:SetWidth(math.max(SAM.MIN_SIZE_W, fw + SAM.CATEGORY_SIZE_W))
		end
		SAM.CategoryButton:SetPoint("TOPRIGHT", (-7 - SAM.CATEGORY_SIZE_W), -27)
		SAM:SetMinResize(SAM.MIN_SIZE_W + SAM.CATEGORY_SIZE_W, SAM.MIN_SIZE_H)
		SAM.CategoryFrame:Show()
	else
		SquareButton_SetIcon(SAM.CategoryButton, "RIGHT")
		SAM.AddonListFrame:SetPoint("BOTTOMRIGHT", SAM.AddonListFrame.rightPadding, 30)
		if (resize) then
			SAM:SetWidth(math.max(SAM.MIN_SIZE_W, fw - SAM.CATEGORY_SIZE_W))
		end
		SAM.CategoryButton:SetPoint("TOPRIGHT", -7, -27)
		SAM:SetMinResize(SAM.MIN_SIZE_W, SAM.MIN_SIZE_H)
		SAM.CategoryFrame:Hide()
	end
	SAM.AddonListFrame.ScrollFrame.update()
	SAM.CategoryFrame.ScrollFrame.update()
end

local function RenameInvalidDb(table, name, index)
	local db = SAM:GetDb()
	index = (index or 0) + 1
	local newName = name .. "_" .. index
	if (db.categories[newName]) then
		return RenameInvalidDb(table, newName, index)
	end
	db.categories[newName] = table
	table.name = newName
end

function module:EnableCategory(categoryKey)
	local db = SAM:GetDb()
	for name, _ in pairs(db.categories[categoryKey].addons) do
		SAM:EnableAddOn(name)
	end
	SAM:Update()
end

function module:DisableCategory(categoryKey)
	local db = SAM:GetDb()
	for name, _ in pairs(db.categories[categoryKey].addons) do
		SAM:DisableAddOn(name)
	end
	SAM:Update()
end

function module:PreInitialize()
	SAM.CategoryFrame = CreateFrame("Frame", nil, SAM)
	SAM.CategoryFrame.NewButton = CreateFrame("Button", nil, SAM.CategoryFrame, "UIPanelButtonTemplate")
	SAM.CategoryFrame.SelectAllButton = CreateFrame("Button", nil, SAM.CategoryFrame, "UIPanelButtonTemplate")
	SAM.CategoryFrame.ClearSelectionButton = CreateFrame("Button", nil, SAM.CategoryFrame, "UIPanelButtonTemplate")
	SAM.CategoryFrame.ScrollFrame = CreateFrame("ScrollFrame", nil, SAM.CategoryFrame, "HybridScrollFrameTemplate")
	SAM.CategoryFrame.ScrollFrame:SetScript("OnMouseWheel", SAM.HybridScrollFrame_ShiftAwareOnScrollWheel)
	SAM.CategoryFrame.ScrollFrame.ScrollBar = CreateFrame("Slider", nil, SAM.CategoryFrame.ScrollFrame, "HybridScrollBarTemplate")
	SAM.CategoryButton = CreateFrame("Button", nil, SAM, "UIPanelSquareButton")
end

function module:Initialize()
	SAM.CategoryFrame:SetPoint("TOPLEFT", SAM.AddonListFrame, "TOPRIGHT", 0, 0)
	SAM.CategoryFrame:SetPoint("BOTTOMRIGHT", 0, 30)

	SAM.CategoryFrame.NewButton:SetPoint("TOP", 0, 43)
	SAM.CategoryFrame.NewButton:SetSize(SAM.CATEGORY_SIZE_W - 50, 20)
	SAM.CategoryFrame.NewButton:SetText(L["New Category"])
	SAM.CategoryFrame.NewButton:SetScript("OnClick", OnClickNewButton)

	SAM.CategoryFrame.SelectAllButton:SetPoint("TOPLEFT", 8, 23)
	SAM.CategoryFrame.SelectAllButton:SetSize((SAM.CATEGORY_SIZE_W / 2) - 4, 20)
	SAM.CategoryFrame.SelectAllButton:SetText(L["Select All"])
	SAM.CategoryFrame.SelectAllButton:SetScript("OnClick", SetAllAndUpdate)
	SAM.CategoryFrame.SelectAllButton.value = true

	SAM.CategoryFrame.ClearSelectionButton:SetPoint("TOPRIGHT", -8, 23)
	SAM.CategoryFrame.ClearSelectionButton:SetSize((SAM.CATEGORY_SIZE_W / 2) - 4, 20)
	SAM.CategoryFrame.ClearSelectionButton:SetText(L["Select None"])
	SAM.CategoryFrame.ClearSelectionButton:SetScript("OnClick", SetAllAndUpdate)
	SAM.CategoryFrame.ClearSelectionButton.value = nil

	SAM.CategoryFrame.ScrollFrame:SetPoint("TOPLEFT", 0, 0)
	SAM.CategoryFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)
	SAM.CategoryFrame.ScrollFrame.selectedItems = {}
	SAM.CategoryFrame.ScrollFrame.update = UpdateCategoryList
	SAM.CategoryFrame.ScrollFrame.updateDb = UpdateListVariables

	SAM.CategoryFrame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", SAM.CategoryFrame.ScrollFrame, "TOPRIGHT", 1, -16)
	SAM.CategoryFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", SAM.CategoryFrame.ScrollFrame, "BOTTOMRIGHT", 1, 12)
	SAM.CategoryFrame.ScrollFrame.ScrollBar:SetScript("OnSizeChanged", OnSizeChangedScrollFrame)
	SAM.CategoryFrame.ScrollFrame.ScrollBar.doNotHide = true

	SAM.CategoryButton:SetPoint("TOPRIGHT", -7, -27)
	SAM.CategoryButton:SetSize(30, 30)
	SAM.CategoryButton.icon:SetTexture("Interface\\Buttons\\SquareButtonTextures")
	SAM.CategoryButton:SetScript("OnClick", function()
		local db = SAM:GetDb()
		db.isCategoryFrameVisible = not db.isCategoryFrameVisible
		SAM:SetCategoryVisibility(db.isCategoryFrameVisible, true)
	end)

	UpdateListVariables()

	HybridScrollFrame_CreateButtons(SAM.CategoryFrame.ScrollFrame, "SimpleAddonManagerCategoryItem")
end

function module:OnLoad()
	local db = SAM:GetDb()
	SAM:CreateDefaultOptions(db.config, {
		localizeCategoryName = true
	})

	-- rename invalid categories
	for k, _ in pairs(fixedCategories) do
		if (db.categories[k]) then
			local oldTable = db.categories[k]
			db.categories[k] = nil
			RenameInvalidDb(oldTable, k)
		end
	end
end