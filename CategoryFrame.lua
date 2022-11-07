local _, T = ...
local L = T.L
local C = T.Color
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

local function CommonCountFunction(self)
	local count = 0
	for addonIndex = 1, GetNumAddOns() do
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
			return frame:IsAddonSelected(key)
		end,
		count = CommonCountFunction
	},
	["!!!!!_01_DISABLED_CATEGORY"] = {
		type = "fixed",
		name = C.green:WrapText(L["Disabled Addons"]),
		description = L["Currently Disabled Addons"],
		addons = function(_, key)
			return not frame:IsAddonSelected(key)
		end,
		count = CommonCountFunction
	},
	["!!!!!_02_ACTIVE_CATEGORY"] = {
		type = "fixed",
		name = C.green:WrapText(L["Active Addons"]),
		description = L["Addons enabled and loaded, or ready to be loaded on demand."],
		addons = function(_, key)
			local _, _, _, loadable, reason = GetAddOnInfo(key)
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
			local user, toc = frame:GetCategoryTables()
			for _, v in pairs(user) do
				MergeTable(cache, v.addons)
			end
			for _, v in pairs(toc) do
				MergeTable(cache, v.addons)
			end
			self.cache = cache
		end,
		addons = function(self, key)
			local name = GetAddOnInfo(key)
			return not self.cache[name]
		end,
		count = function(self)
			self:prepare()
			return CommonCountFunction(self)
		end
	},
	["!!!!!_55_CHANGING_STATE"] = {
		type = "fixed",
		name = C.red:WrapText(L["Addons being modified"]),
		description = L["Addons being modified in this session"],
		addons = function(_, key)
			return frame:DidAddonStateChanged(key)
		end,
		show = function()
			return frame:DidAnyAddonStateChanged()
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
				button.Name:SetText(C.yellow:WrapText(frame:LocalizeCategoryName(category.name)))
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
		frame:UpdateCategoryFrame()
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
	local db = frame:GetDb()
	db.categories = db.categories or {}
	if (db.config.hideTocCategories) then
		categoryTocTable = {}
	else
		categoryTocTable = BuildCategoryTableFromToc()
	end
	local auto = BuildAutoGeneratedCategories()
	local categoriesList = frame:TableKeysToSortedList(db.categories, categoryTocTable, auto)
	frame.CategoryFrame.ScrollFrame.sortedItemsList = categoriesList
	local selectedItems = frame.CategoryFrame.ScrollFrame.selectedItems
	for k, _ in pairs(selectedItems) do
		if (not db.categories[k] and not categoryTocTable[k] and not auto[k]) then
			selectedItems[k] = nil
		end
	end
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
	local userCategories = db.categories
	local tocCategories = categoryTocTable
	return userCategories, tocCategories, fixedCategories
end

function frame:SelectedCategories()
	return self.CategoryFrame.ScrollFrame.selectedItems
end

function frame:UpdateCategoryFrame()
	self.CategoryFrame.ScrollFrame.updateDb()
	self.CategoryFrame.ScrollFrame.update()
end


function frame:SetCategoryVisibility(show, resize)
	local fw = frame:GetWidth()
	if (show) then
		SquareButton_SetIcon(frame.CategoryButton, "LEFT")
		frame.ScrollFrame:SetPoint("BOTTOMRIGHT", (-30 - frame.CATEGORY_SIZE_W), 30)
		if (resize) then
			frame:SetWidth(math.max(frame.MIN_SIZE_W, fw + frame.CATEGORY_SIZE_W))
		end
		frame.CategoryButton:SetPoint("TOPRIGHT", (-7 - frame.CATEGORY_SIZE_W), -27)
		frame:SetMinResize(frame.MIN_SIZE_W + frame.CATEGORY_SIZE_W, frame.MIN_SIZE_H)
		frame.CategoryFrame:Show()
	else
		SquareButton_SetIcon(frame.CategoryButton, "RIGHT")
		frame.ScrollFrame:SetPoint("BOTTOMRIGHT", -30, 30)
		if (resize) then
			frame:SetWidth(math.max(frame.MIN_SIZE_W, fw - frame.CATEGORY_SIZE_W))
		end
		frame.CategoryButton:SetPoint("TOPRIGHT", -7, -27)
		frame:SetMinResize(frame.MIN_SIZE_W, frame.MIN_SIZE_H)
		frame.CategoryFrame:Hide()
	end
	frame.ScrollFrame.update()
	frame.CategoryFrame.ScrollFrame.update()
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

function module:PreInitialize()
	frame.CategoryFrame = CreateFrame("Frame", nil, frame)
	frame.CategoryFrame.NewButton = CreateFrame("Button", nil, frame.CategoryFrame, "UIPanelButtonTemplate")
	frame.CategoryFrame.SelectAllButton = CreateFrame("Button", nil, frame.CategoryFrame, "UIPanelButtonTemplate")
	frame.CategoryFrame.ClearSelectionButton = CreateFrame("Button", nil, frame.CategoryFrame, "UIPanelButtonTemplate")
	frame.CategoryFrame.ScrollFrame = CreateFrame("ScrollFrame", nil, frame.CategoryFrame, "HybridScrollFrameTemplate")
	frame.CategoryFrame.ScrollFrame.ScrollBar = CreateFrame("Slider", nil, frame.CategoryFrame.ScrollFrame, "HybridScrollBarTemplate")
	frame.CategoryButton = CreateFrame("Button", nil, frame, "UIPanelSquareButton")
end

function module:Initialize()
	frame.CategoryFrame:SetPoint("TOPLEFT", frame.ScrollFrame, "TOPRIGHT", 20, 0)
	frame.CategoryFrame:SetPoint("BOTTOMRIGHT", 0, 30)

	frame.CategoryFrame.NewButton:SetPoint("TOP", 0, 43)
	frame.CategoryFrame.NewButton:SetSize(frame.CATEGORY_SIZE_W - 50, 20)
	frame.CategoryFrame.NewButton:SetText(L["New Category"])
	frame.CategoryFrame.NewButton:SetScript("OnClick", OnClickNewButton)

	frame.CategoryFrame.SelectAllButton:SetPoint("TOPLEFT", 8, 23)
	frame.CategoryFrame.SelectAllButton:SetSize((frame.CATEGORY_SIZE_W / 2) - 4, 20)
	frame.CategoryFrame.SelectAllButton:SetText(L["Select All"])
	frame.CategoryFrame.SelectAllButton:SetScript("OnClick", SetAll)
	frame.CategoryFrame.SelectAllButton.value = true

	frame.CategoryFrame.ClearSelectionButton:SetPoint("TOPRIGHT", -8, 23)
	frame.CategoryFrame.ClearSelectionButton:SetSize((frame.CATEGORY_SIZE_W / 2) - 4, 20)
	frame.CategoryFrame.ClearSelectionButton:SetText(L["Select None"])
	frame.CategoryFrame.ClearSelectionButton:SetScript("OnClick", SetAll)
	frame.CategoryFrame.ClearSelectionButton.value = nil

	frame.CategoryFrame.ScrollFrame:SetPoint("TOPLEFT", 0, 0)
	frame.CategoryFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)
	frame.CategoryFrame.ScrollFrame.selectedItems = {}
	frame.CategoryFrame.ScrollFrame.update = UpdateCategoryList
	frame.CategoryFrame.ScrollFrame.updateDb = UpdateListVariables

	frame.CategoryFrame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", frame.CategoryFrame.ScrollFrame, "TOPRIGHT", 1, -16)
	frame.CategoryFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", frame.CategoryFrame.ScrollFrame, "BOTTOMRIGHT", 1, 12)
	frame.CategoryFrame.ScrollFrame.ScrollBar:SetScript("OnSizeChanged", OnSizeChangedScrollFrame)
	frame.CategoryFrame.ScrollFrame.ScrollBar.doNotHide = true

	frame.CategoryButton:SetPoint("TOPRIGHT", -7, -27)
	frame.CategoryButton:SetSize(30, 30)
	frame.CategoryButton.icon:SetTexture("Interface\\Buttons\\SquareButtonTextures")
	frame.CategoryButton:SetScript("OnClick", function()
		local db = frame:GetDb()
		db.isCategoryFrameVisible = not db.isCategoryFrameVisible
		frame:SetCategoryVisibility(db.isCategoryFrameVisible, true)
	end)

	UpdateListVariables()

	HybridScrollFrame_CreateButtons(frame.CategoryFrame.ScrollFrame, "SimpleAddonManagerCategoryItem")
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