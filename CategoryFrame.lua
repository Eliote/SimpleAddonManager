local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("ElioteAddonList_MenuFrame")

--- @type ElioteAddonList
local frame = ElioteAddonList

local function CategoryMenu(categoryName)
	local menu = {
		{ text = categoryName, isTitle = true, notCheckable = true },
		{
			text = "Rename",
			notCheckable = true,
			func = function()
				frame:ShowInputDialog(
						"Enter the new name for the category '" .. categoryName .. "'",
						function(text)
							local db = frame:GetDb()
							if db.categories[text] then
								return
							end
							db.categories[text] = db.categories[categoryName]
							db.categories[categoryName] = nil
							db.categories[text].name = text
							local selectedItems = frame.CategoryFrame.ScrollFrame.selectedItems
							if (selectedItems[categoryName]) then
								selectedItems[text] = selectedItems[categoryName]
								selectedItems[categoryName] = nil
							end
							frame:Update()
						end
				)
			end
		},
		{
			text = "Delete",
			notCheckable = true,
			func = function()
				frame:ShowConfirmDialog(
						"Delete category '" .. categoryName .. "'?",
						function()
							local db = frame:GetDb()
							db.categories[categoryName] = nil
							frame.CategoryFrame.ScrollFrame.selectedItems[categoryName] = nil
							frame:Update()
						end
				)
			end
		},
	}

	return menu
end

local function tablelength(T)
	if not T then
		return 0
	end
	local count = 0
	for _ in pairs(T) do
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
	local name = self:GetParent().categoryName
	local enabled = IsCategorySelected(name)
	local newValue = not enabled
	self:SetChecked(newValue)
	if (newValue) then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		frame.CategoryFrame.ScrollFrame.selectedItems[name] = true
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		frame.CategoryFrame.ScrollFrame.selectedItems[name] = nil
	end
	frame:UpdateListFilters()
	frame.CategoryFrame.ScrollFrame.update()
end

local function CategoryButtonOnClick(self, mouseButton)
	if (mouseButton == "LeftButton") then
		ToggleCategory(self.EnabledButton)
	else
		EDDM.EasyMenu(CategoryMenu(self.categoryName), dropdownFrame, "cursor", 0, 0, "MENU")
	end
end

local function CategoryButtonOnEnter(self)
	local name = self.categoryName
	local userTable, tocTable = frame:GetCategoryTable(name)
	GameTooltip:ClearLines();
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("LEFT", self, "RIGHT")
	GameTooltip:AddLine(name, 1, 1, 1);
	if (not userTable) then
		GameTooltip:AddLine("Category created from addon metadata");
	else
		GameTooltip:AddLine("User created category");
	end
	GameTooltip:AddLine("\n");
	GameTooltip:AddDoubleLine("Manually added:", userTable and tablelength(userTable.addons) or 0, nil, nil, nil, 1, 1, 1);
	local fromTocCount = tocTable and tablelength(tocTable.addons) or 0
	if (fromTocCount > 0) then
		GameTooltip:AddDoubleLine("From toc:", tocTable and tablelength(tocTable.addons) or 0, nil, nil, nil, 1, 1, 1);
	end
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
			local userCategory, tocCategory = frame:GetCategoryTable(categoryKey)
			local category = userCategory or tocCategory
			button.Name:SetText((not userCategory and "|cFFFFFF00" or "") .. category.name)
			local enabled = IsCategorySelected(category.name)

			button.categoryName = category.name
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
	frame:ShowInputDialog("Enter the category name", function(text)
		local db = frame:GetDb()
		db.categories = db.categories or {}
		if (db.categories[text]) then
			return
		end

		db.categories[text] = { name = text, addons = {} }
		frame.CategoryFrame.ScrollFrame.updateDb()
		frame.CategoryFrame.ScrollFrame.update()
	end)
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
	local categoriesList = frame:TableKeysToSortedList(db.categories, categoryTocTable)
	frame.CategoryFrame.ScrollFrame.sortedItemsList = categoriesList
end

local function OnSizeChangedScrollFrame(self)
	local offsetBefore = self:GetValue()
	HybridScrollFrame_CreateButtons(self:GetParent(), "ElioteAddonCategoryItem")
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

function frame:GetCategoryTable(name)
	local userCategory, tocCategory = self:GetCategoryTables()
	return userCategory[name], tocCategory[name]
end

function frame:GetCategoryTables()
	local db = self:GetDb()
	local userCategory = db.categories
	local tocCategory = categoryTocTable
	return userCategory, tocCategory
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
	self.CategoryFrame.NewButton:SetText("New Category")
	self.CategoryFrame.NewButton:SetScript("OnClick", OnClickNewButton)

	self.CategoryFrame.SelectAllButton = CreateFrame("Button", nil, self.CategoryFrame, "UIPanelButtonTemplate")
	self.CategoryFrame.SelectAllButton:SetPoint("TOPLEFT", 8, 23)
	self.CategoryFrame.SelectAllButton:SetSize((self.CATEGORY_SIZE_W / 2) - 4, 20)
	self.CategoryFrame.SelectAllButton:SetText("Select All")
	self.CategoryFrame.SelectAllButton:SetScript("OnClick", SetAll)
	self.CategoryFrame.SelectAllButton.value = true

	self.CategoryFrame.ClearSelectionButton = CreateFrame("Button", nil, self.CategoryFrame, "UIPanelButtonTemplate")
	self.CategoryFrame.ClearSelectionButton:SetPoint("TOPRIGHT", -8, 23)
	self.CategoryFrame.ClearSelectionButton:SetSize((self.CATEGORY_SIZE_W / 2) - 4, 20)
	self.CategoryFrame.ClearSelectionButton:SetText("Select None")
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

	HybridScrollFrame_CreateButtons(self.CategoryFrame.ScrollFrame, "ElioteAddonCategoryItem")
end