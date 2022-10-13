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
							if db.categories[text] then return end
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


frame.CategoryFrame = CreateFrame("Frame", nil, frame)
frame.CategoryFrame:SetPoint("TOPLEFT", frame.ScrollFrame, "TOPRIGHT", 20, 30)
frame.CategoryFrame:SetPoint("BOTTOMRIGHT", 0, 30)

frame.CategoryFrame.NewButton = CreateFrame("Button", nil, frame.CategoryFrame, "OptionsButtonTemplate")
frame.CategoryFrame.NewButton:SetPoint("TOP", 0, 0)
frame.CategoryFrame.NewButton:SetSize(frame.CATEGORY_SIZE_W - 50, 22)
frame.CategoryFrame.NewButton:SetText("New Category")
frame.CategoryFrame.NewButton:SetScript("OnClick", function()
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
end)

-- create the hybrid scroll frame
local categoryScrollFrame = CreateFrame("ScrollFrame", nil, frame.CategoryFrame, "HybridScrollFrameTemplate")
frame.CategoryFrame.ScrollFrame = categoryScrollFrame
categoryScrollFrame:SetPoint("TOPLEFT", 0, -30)
categoryScrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)
categoryScrollFrame.selectedItems = {}

-- add a scroll bar
categoryScrollFrame.ScrollBar = CreateFrame("Slider", nil, categoryScrollFrame, "HybridScrollBarTemplate")
categoryScrollFrame.ScrollBar:SetPoint("TOPLEFT", categoryScrollFrame, "TOPRIGHT", 1, -16)
categoryScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", categoryScrollFrame, "BOTTOMRIGHT", 1, 12)
categoryScrollFrame.ScrollBar.doNotHide = true

local function tablelength(T)
	if not T then return 0 end
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

local function IsCategorySelected(name)
	local item = categoryScrollFrame.selectedItems[name]
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
		categoryScrollFrame.selectedItems[name] = true
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		categoryScrollFrame.selectedItems[name] = nil
	end
	frame:UpdateListFilters()
	categoryScrollFrame.update()
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
	GameTooltip:SetOwner(frame, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT")
	GameTooltip:AddLine(name, 1, 1, 1);
	if (not userTable) then
		GameTooltip:AddLine("Category created from addon metadata");
	else
		GameTooltip:AddLine("User created category");
	end
	GameTooltip:AddLine("\n");
	GameTooltip:AddDoubleLine("Manually added:", userTable and tablelength(userTable.addons) or 0, nil, nil, nil, 1, 1, 1);
	GameTooltip:AddDoubleLine("From toc:", tocTable and tablelength(tocTable.addons) or 0, nil, nil, nil, 1, 1, 1);
	GameTooltip:Show()
end

local function CategoryButtonOnLeave()
	GameTooltip:Hide()
end

categoryScrollFrame.update = function()
	local buttons = HybridScrollFrame_GetButtons(categoryScrollFrame);
	local offset = HybridScrollFrame_GetOffset(categoryScrollFrame);
	local buttonHeight;
	local count = #(categoryScrollFrame.sortedItemsList)

	for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex]
		button:SetPoint("LEFT", categoryScrollFrame)
		button:SetPoint("RIGHT", categoryScrollFrame)

		local relativeButtonIndex = buttonIndex + offset
		buttonHeight = button:GetHeight()

		if relativeButtonIndex <= count then
			local categoryKey = categoryScrollFrame.sortedItemsList[relativeButtonIndex]
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

	HybridScrollFrame_Update(categoryScrollFrame, count * buttonHeight, categoryScrollFrame:GetHeight())
end

-- this will create listview items using the template define, the number of buttons is determined by the
HybridScrollFrame_CreateButtons(categoryScrollFrame, "ElioteAddonCategoryItem")

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

local categoryTocTable = {}

categoryScrollFrame.updateDb = function()
	local db = frame:GetDb()
	db.categories = db.categories or {}
	categoryTocTable = BuildCategoryTableFromToc()
	local categoriesList = frame:TableKeysToSortedList(db.categories, categoryTocTable)
	categoryScrollFrame.sortedItemsList = categoriesList
end

function frame:GetCategoryTable(name)
	local userCategory, tocCategory = frame:GetCategoryTables()
	return userCategory[name], tocCategory[name]
end

function frame:GetCategoryTables()
	local db = frame:GetDb()
	local userCategory = db.categories
	local tocCategory = categoryTocTable
	return userCategory, tocCategory
end

categoryScrollFrame:SetScript("OnShow", function()
	categoryTocTable = BuildCategoryTableFromToc()
	categoryScrollFrame.updateDb()
	categoryScrollFrame.update()
end)

categoryScrollFrame:SetScript("OnSizeChanged", function()
	local offsetBefore = categoryScrollFrame.ScrollBar:GetValue()
	HybridScrollFrame_CreateButtons(categoryScrollFrame, "ElioteAddonCategoryItem")
	categoryScrollFrame.ScrollBar:SetValue(offsetBefore)
	categoryScrollFrame.update()
end)

function frame:SelectedCategories()
	return categoryScrollFrame.selectedItems
end
