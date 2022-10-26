local _, T = ...
local L = T.L
local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("SimpleAddonManager_MenuFrame")

--- @type SimpleAddonManager
local frame = T.AddonFrame
local module = frame:RegisterModule("Category")

local function CategoryMenu(categoryKey, categoryName)
	local db = frame:GetDb()
	local menu = {
		{ text = categoryName, isTitle = true, notCheckable = true },
		{
			text = L["Rename"],
			notCheckable = true,
			disabled = db.categories[categoryKey] == nil,
			func = function()
				frame:ShowInputDialog(
						L("Enter the new name for the category '${category}'", { category = categoryName }),
						function(text)
							if db.categories[text] or not frame:ValidateCategoryName(text) then
								return
							end
							db.categories[text] = db.categories[categoryKey]
							db.categories[categoryKey] = nil
							db.categories[text].name = text
							local selectedItems = frame.CategoryFrame.ScrollFrame.selectedItems
							if (selectedItems[categoryKey]) then
								selectedItems[text] = selectedItems[categoryKey]
								selectedItems[categoryKey] = nil
							end
							frame:Update()
						end
				)
			end
		},
		{
			text = L["Delete"],
			notCheckable = true,
			disabled = db.categories[categoryKey] == nil,
			func = function()
				frame:ShowConfirmDialog(
						L("Delete category '${category}'?", { category = categoryKey }),
						function()
							db.categories[categoryKey] = nil
							frame.CategoryFrame.ScrollFrame.selectedItems[categoryKey] = nil
							frame:Update()
						end
				)
			end
		},
		T.separatorInfo,
		T.closeMenuInfo,
	}

	return menu
end

local fixedCategories = {
	["!!!!!_00_ENABLED_CATEGORY"] = {
		type = "fixed",
		name = "|cFF19FF19" .. L["Enabled Addons"],
		description = L["Currently Enabled Addons"],
		addons = function(key)
			return frame:IsAddonSelected(key)
		end,
		count = function()
			local count = 0
			for addonIndex = 1, GetNumAddOns() do
				if (frame:IsAddonSelected(addonIndex)) then
					count = count + 1
				end
			end
			return count
		end
	},
	["!!!!!_01_DISABLED_CATEGORY"] = {
		type = "fixed",
		name = "|cFF19FF19" .. L["Disabled Addons"],
		description = L["Currently Disabled Addons"],
		addons = function(key)
			return not frame:IsAddonSelected(key)
		end,
		count = function()
			local count = 0
			for addonIndex = 1, GetNumAddOns() do
				if (not frame:IsAddonSelected(addonIndex)) then
					count = count + 1
				end
			end
			return count
		end
	},
	["!!!!!_03_CHANGING_STATE"] = {
		type = "fixed",
		name = "|cFFFF1919" .. L["Addons being modified"],
		description = L["Addons being modified in this session"],
		addons = function(key)
			return frame:DidAddonStateChanged(key)
		end,
		show = function() return frame:DidAnyAddonStateChanged() end,
		count = function()
			local count = 0
			for addonIndex = 1, GetNumAddOns() do
				if (frame:DidAddonStateChanged(addonIndex)) then
					count = count + 1
				end
			end
			return count
		end
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
	local item = frame.CategoryFrame.ScrollFrame.selectedItems[name]
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
		frame.CategoryFrame.ScrollFrame.selectedItems[key] = true
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		frame.CategoryFrame.ScrollFrame.selectedItems[key] = nil
	end
	frame:UpdateListFilters()
	frame.CategoryFrame.ScrollFrame.update()
end

local function CategoryButtonOnClick(self, mouseButton)
	if (mouseButton == "LeftButton") then
		ToggleCategory(self.EnabledButton)
	elseif (self.category.type ~= "fixed") then
		EDDM.EasyMenu(CategoryMenu(self.categoryKey, self.categoryName), dropdownFrame, "cursor", 0, 0, "MENU")
	end
end

local function CategoryButtonOnEnter(self)
	local name = self.categoryName
	local key = self.categoryKey
	local userTable, tocTable, fixedTable = frame:GetCategoryTable(key)
	GameTooltip:ClearLines();
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("LEFT", self, "RIGHT")
	GameTooltip:AddLine(frame:LocalizeCategoryName(name, userTable), 1, 1, 1);
	if (tocTable) then
		GameTooltip:AddLine(L["Category created from addons metadata"], nil, nil, nil, true);
	elseif (fixedTable) then
		GameTooltip:AddLine(self.category.description, nil, nil, nil, true);
	else
		GameTooltip:AddLine(L["User created category"], nil, nil, nil, true);
	end
	GameTooltip:AddLine("\n");
	if (fixedTable) then
		GameTooltip:AddDoubleLine(L["Addons:"], self.category.count(), nil, nil, nil, 1, 1, 1);
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
	local buttons = HybridScrollFrame_GetButtons(frame.CategoryFrame.ScrollFrame);
	local offset = HybridScrollFrame_GetOffset(frame.CategoryFrame.ScrollFrame);
	local buttonHeight;
	local count = #(frame.CategoryFrame.ScrollFrame.sortedItemsList)

	for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex]
		button:SetPoint("LEFT", frame.CategoryFrame.ScrollFrame)
		button:SetPoint("RIGHT", frame.CategoryFrame.ScrollFrame)

		local relativeButtonIndex = buttonIndex + offset
		buttonHeight = button:GetHeight()

		if relativeButtonIndex <= count then
			local categoryKey = frame.CategoryFrame.ScrollFrame.sortedItemsList[relativeButtonIndex]
			local userCategory, tocCategory, fixed = frame:GetCategoryTable(categoryKey)
			local category = userCategory or tocCategory or fixed
			if (userCategory) then
				button.Name:SetText(category.name)
			elseif (fixed) then
				button.Name:SetText(category.name)
			else
				button.Name:SetText("|cFFFFFF19" .. frame:LocalizeCategoryName(category.name))
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

	HybridScrollFrame_Update(frame.CategoryFrame.ScrollFrame, count * buttonHeight, frame.CategoryFrame.ScrollFrame:GetHeight())
end

local function BuildCategoryTableFromToc()
	local table = {}
	local count = GetNumAddOns()
	for addonIndex = 1, count do
		local value = GetAddOnMetadata(addonIndex, "X-Category")
		if value then
			value = strtrim(value)
			table[value] = table[value] or { addons = {} }
			local name = GetAddOnInfo(addonIndex)
			table[value].addons[name] = true
			table[value].name = value
		end
	end
	return table
end

local function OnClickNewButton()
	frame:ShowInputDialog(L["Enter the category name"], function(text)
		local db = frame:GetDb()
		db.categories = db.categories or {}
		if (db.categories[text] or not frame:ValidateCategoryName(text)) then
			return
		end

		db.categories[text] = { name = text, addons = {} }
		frame.CategoryFrame.ScrollFrame.updateDb()
		frame.CategoryFrame.ScrollFrame.update()
	end)
end

local function BuildFixedCategories()
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
	local db = frame:GetDb()
	db.categories = db.categories or {}
	if (db.config.hideTocCategories) then
		categoryTocTable = {}
	else
		categoryTocTable = BuildCategoryTableFromToc()
	end
	local categoriesList = frame:TableKeysToSortedList(db.categories, categoryTocTable, BuildFixedCategories())
	frame.CategoryFrame.ScrollFrame.sortedItemsList = categoriesList
end

function frame:LocalizeCategoryName(name, isUserCategory)
	if (isUserCategory or not frame:GetDb().config.localizeCategoryName) then
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

local function SetAll(self)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	local user, toc = frame:GetCategoryTables()
	for name, _ in pairs(user) do
		frame.CategoryFrame.ScrollFrame.selectedItems[name] = self.value
	end
	for name, _ in pairs(toc) do
		frame.CategoryFrame.ScrollFrame.selectedItems[name] = self.value
	end
	frame:Update()
end

function frame:ValidateCategoryName(name)
	if (fixedCategories[name]) then
		return false
	end
	return true
end

function frame:GetCategoryTable(name)
	local userCategory, tocCategory, fixedCategory = self:GetCategoryTables()
	return userCategory[name], tocCategory[name], fixedCategory[name]
end

function frame:GetCategoryTables()
	local db = self:GetDb()
	local userCategory = db.categories
	local tocCategory = categoryTocTable
	return userCategory, tocCategory, fixedCategories
end

function frame:SelectedCategories()
	return self.CategoryFrame.ScrollFrame.selectedItems
end

function frame:CreateCategoryFrame()
	self.CategoryFrame = CreateFrame("Frame", nil, self)
	self.CategoryFrame:SetPoint("TOPLEFT", self.ScrollFrame, "TOPRIGHT", 20, 0)
	self.CategoryFrame:SetPoint("BOTTOMRIGHT", 0, 30)

	self.CategoryFrame.NewButton = CreateFrame("Button", nil, self.CategoryFrame, "UIPanelButtonTemplate")
	self.CategoryFrame.NewButton:SetPoint("TOP", 0, 43)
	self.CategoryFrame.NewButton:SetSize(self.CATEGORY_SIZE_W - 50, 20)
	self.CategoryFrame.NewButton:SetText(L["New Category"])
	self.CategoryFrame.NewButton:SetScript("OnClick", OnClickNewButton)

	self.CategoryFrame.SelectAllButton = CreateFrame("Button", nil, self.CategoryFrame, "UIPanelButtonTemplate")
	self.CategoryFrame.SelectAllButton:SetPoint("TOPLEFT", 8, 23)
	self.CategoryFrame.SelectAllButton:SetSize((self.CATEGORY_SIZE_W / 2) - 4, 20)
	self.CategoryFrame.SelectAllButton:SetText(L["Select All"])
	self.CategoryFrame.SelectAllButton:SetScript("OnClick", SetAll)
	self.CategoryFrame.SelectAllButton.value = true

	self.CategoryFrame.ClearSelectionButton = CreateFrame("Button", nil, self.CategoryFrame, "UIPanelButtonTemplate")
	self.CategoryFrame.ClearSelectionButton:SetPoint("TOPRIGHT", -8, 23)
	self.CategoryFrame.ClearSelectionButton:SetSize((self.CATEGORY_SIZE_W / 2) - 4, 20)
	self.CategoryFrame.ClearSelectionButton:SetText(L["Select None"])
	self.CategoryFrame.ClearSelectionButton:SetScript("OnClick", SetAll)
	self.CategoryFrame.ClearSelectionButton.value = nil

	self.CategoryFrame.ScrollFrame = CreateFrame("ScrollFrame", nil, self.CategoryFrame, "HybridScrollFrameTemplate")
	self.CategoryFrame.ScrollFrame:SetPoint("TOPLEFT", 0, 0)
	self.CategoryFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)
	self.CategoryFrame.ScrollFrame.selectedItems = {}
	self.CategoryFrame.ScrollFrame.update = UpdateCategoryList
	self.CategoryFrame.ScrollFrame.updateDb = UpdateListVariables

	self.CategoryFrame.ScrollFrame.ScrollBar = CreateFrame("Slider", nil, self.CategoryFrame.ScrollFrame, "HybridScrollBarTemplate")
	self.CategoryFrame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", self.CategoryFrame.ScrollFrame, "TOPRIGHT", 1, -16)
	self.CategoryFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", self.CategoryFrame.ScrollFrame, "BOTTOMRIGHT", 1, 12)
	self.CategoryFrame.ScrollFrame.ScrollBar:SetScript("OnSizeChanged", OnSizeChangedScrollFrame)
	self.CategoryFrame.ScrollFrame.ScrollBar.doNotHide = true

	UpdateListVariables()

	HybridScrollFrame_CreateButtons(self.CategoryFrame.ScrollFrame, "SimpleAddonManagerCategoryItem")
end

local function RenameInvalidDb(table, name, index)
	local db = frame:GetDb()
	index = (index or 0) + 1
	local newName = name .. "_" .. index
	if (db.categories[newName]) then
		return RenameInvalidDb(table, newName, index)
	end
	db.categories[newName] = table
	table.name = newName
end

function module:OnLoad()
	local db = frame:GetDb()
	frame:CreateDefaultOptions(db.config, {
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