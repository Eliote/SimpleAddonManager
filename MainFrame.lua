local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("ElioteAddonList_MenuFrame")

--- @type ElioteAddonList
local frame = ElioteAddonList

ButtonFrameTemplate_HidePortrait(frame)

local function CharacterDropDown_Initialize()
	local selectedValue = frame:GetCharacter() == true
	local info = {
		text = ALL,
		value = true,
		func = function(self)
			local value = self.value
			frame:SetCharacter(value)
			EDDM.UIDropDownMenu_SetSelectedValue(frame.CharacterDropDown, value)
			frame.ScrollFrame.update()
		end,
		checked = selectedValue
	};
	EDDM.UIDropDownMenu_AddButton(info);

	info.text = UnitName("player")
	info.value = UnitName("player")
	info.checked = not selectedValue
	EDDM.UIDropDownMenu_AddButton(info);
end

local separatorInfo = {
	text = "",
	hasArrow = false,
	dist = 0,
	isTitle = true,
	isUninteractable = true,
	notCheckable = true,
	iconOnly = true,
	icon = "Interface\\Common\\UI-TooltipDivider-Transparent",
	tCoordLeft = 0,
	tCoordRight = 1,
	tCoordTop = 0,
	tCoordBottom = 1,
	tSizeX = 0,
	tSizeY = 8,
	tFitDropDownSizeX = true,
	iconInfo = {
		tCoordLeft = 0,
		tCoordRight = 1,
		tCoordTop = 0,
		tCoordBottom = 1,
		tSizeX = 0,
		tSizeY = 8,
		tFitDropDownSizeX = true
	},
};

local closeMenuInfo = {
	text = CANCEL,
	hasArrow = false,
	notCheckable = true,
};

local function SaveCurrentAddonsToSet(setName)
	local db = frame:GetDb()
	local enabledAddons = {}
	local count = GetNumAddOns()
	for i = 1, count do
		if frame:IsAddonSelected(i) then
			local name = GetAddOnInfo(i)
			table.insert(enabledAddons, name)
		end
	end
	db.sets[setName] = db.sets[setName] or {}
	db.sets[setName].addons = enabledAddons
end

local function SetsDropDownCreate()
	local menu = {
		{ text = "Sets", isTitle = true, notCheckable = true },
	}
	local db = frame:GetDb()

	for setName, set in pairs(db.sets) do
		local setMenu = {
			text = setName,
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{ text = setName, isTitle = true, notCheckable = true },
				{ text = #set.addons .. " AddOns", notCheckable = true },
				separatorInfo,
				{
					text = "Save",
					notCheckable = true,
					func = function()
						frame:ShowConfirmDialog(
								"Save current addons to this set '" .. setName .. "'?",
								function()
									SaveCurrentAddonsToSet(setName)
								end
						)
					end
				},
				{
					text = "Load",
					notCheckable = true,
					func = function()
						frame:ShowConfirmDialog(
								"Load the set '" .. setName .. "'?",
								function()
									local enabledAddons = db.sets[setName].addons
									local character = frame:GetCharacter()
									DisableAllAddOns(character)
									for _, name in ipairs(enabledAddons) do
										EnableAddOn(name, character)
									end
									frame.ScrollFrame.update()
								end
						)
					end
				},
				{
					text = "Rename",
					notCheckable = true,
					func = function()
						frame:ShowInputDialog(
								"Enter the new name for the set '" .. setName .. "'",
								function(text)
									db.sets[text] = db.sets[setName]
									db.sets[setName] = nil
								end
						)
					end
				},
				{
					text = "Delete",
					notCheckable = true,
					func = function()
						frame:ShowConfirmDialog(
								"Delete the set '" .. setName .. "'?",
								function()
									db.sets[setName] = nil
								end
						)
					end
				},
			}
		}
		table.insert(menu, setMenu)
	end

	table.insert(menu, separatorInfo)
	table.insert(menu, {
		text = "Create new set",
		func = function()
			frame:ShowInputDialog(
					"Type the name for the new set",
					function(text)
						SaveCurrentAddonsToSet(text)
					end
			)
		end,
		notCheckable = true
	})

	return menu
end

local function ConfigDropDownCreate()
	local db = frame:GetDb()
	return {
		{ text = "Options", isTitle = true, notCheckable = true },
		separatorInfo,
		{
			text = ADDON_FORCE_LOAD,
			checked = not IsAddonVersionCheckEnabled(),
			func = function(_, _, _, checked)
				SetAddonVersionCheck(checked)
				frame:Update()
			end,
		},
		{
			text = "Hide autogenerated categories",
			checked = db.config.hideTocCategories,
			func = function()
				db.config.hideTocCategories = not db.config.hideTocCategories
				frame:Update()
			end,
		},
		{
			text = "Autofocus search bar when opening the UI",
			checked = db.config.autofocusSearch,
			func = function()
				db.config.autofocusSearch = not db.config.autofocusSearch
			end,
		},
		{
			text = "Show versions",
			checked = db.config.showVersions,
			func = function()
				db.config.showVersions = not db.config.showVersions
				frame:Update()
			end,
		},
		separatorInfo,
		{
			text = "Sort",
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "By internal name",
					checked = function()
						return db.config.sorting == "name"
					end,
					func = function()
						db.config.sorting = "name"
						frame:Update()
					end,
				},
				{
					text = "By title",
					checked = function()
						return db.config.sorting == "title"
					end,
					func = function()
						db.config.sorting = "title"
						frame:Update()
					end,
				},
				{
					text = "None",
					checked = function()
						return db.config.sorting == nil
					end,
					func = function()
						db.config.sorting = false
						frame:Update()
					end,
				},
			},
		},
		separatorInfo,
		closeMenuInfo
	}
end

function frame:SetCategoryVisibility(show, resize)
	local fw = frame:GetWidth()
	if (show) then
		frame.CategoryButton.icon:SetAtlas("common-icon-backarrow")
		frame.ScrollFrame:SetPoint("BOTTOMRIGHT", (-30 - frame.CATEGORY_SIZE_W), 30)
		if (resize) then
			frame:SetWidth(math.max(frame.MIN_SIZE_W, fw + frame.CATEGORY_SIZE_W))
		end
		frame.CategoryButton:SetPoint("TOPRIGHT", (-7 - frame.CATEGORY_SIZE_W), -27)
		frame:SetMinResize(frame.MIN_SIZE_W + frame.CATEGORY_SIZE_W, frame.MIN_SIZE_H)
		frame.CategoryFrame:Show()
	else
		frame.CategoryButton.icon:SetAtlas("common-icon-forwardarrow")
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

local function AddonsFromCategories(categories)
	if categories == nil or next(categories) == nil then
		return nil
	end
	local m = {}
	for categoryName, _ in pairs(categories) do
		local userTable, tocTable = frame:GetCategoryTable(categoryName)
		if (userTable) then
			for name, _ in pairs(userTable.addons) do
				m[name] = true
			end
		end
		if (tocTable) then
			for name, _ in pairs(tocTable.addons) do
				m[name] = true
			end
		end
	end
	return m
end

local addons = {}

local function SortAddons()
	local db = frame:GetDb()
	if (not db.config.sorting) then
		return
	end

	if (db.config.sorting == "name") then
		table.sort(addons, function(a, b)
			return a.name < b.name
		end)
	elseif (db.config.sorting == "title") then
		table.sort(addons, function(a, b)
			return a.title < b.title
		end)
	end
end

local function CreateList(filter, categories)
	addons = {}
	local categoriesAddons = AddonsFromCategories(categories)
	local count = GetNumAddOns()
	for addonIndex = 1, count do
		local name, title = GetAddOnInfo(addonIndex)
		if (categoriesAddons == nil or categoriesAddons[name]) then
			if (name:upper():match(filter:upper()) or (title and title:upper():match(filter:upper()))) then
				table.insert(addons, {
					index = addonIndex,
					name = name:gsub(".-([%w].*)", "%1"):gsub("[_-]", " "):lower(),
					title = (title or name):lower()
				})
			end
		end
	end
	SortAddons()
end

function frame:GetAddonsList()
	return addons
end

function frame:UpdateListFilters()
	CreateList(frame.SearchBox:GetText(), frame:SelectedCategories())
	frame.ScrollFrame.update()
end

function frame:CreateMainFrame()
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetPoint("CENTER", 0, 24)
	frame:SetSize(frame.MIN_SIZE_W, frame.MIN_SIZE_H)
	frame:SetResizable(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	if (frame.SetResizeBounds) then
		frame.SetMinResize = frame.SetResizeBounds
	end
	frame:SetMinResize(frame.MIN_SIZE_W, frame.MIN_SIZE_H)
	frame:SetScript("OnMouseDown", function(self)
		self:StartMoving()
	end)
	frame:SetScript("OnMouseUp", function(self)
		self:StopMovingOrSizing()
	end)

	frame.TitleText:SetText(ADDON_LIST)

	frame.Sizer = CreateFrame("Button", nil, frame, "PanelResizeButtonTemplate")
	frame.Sizer:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT", true)
	end)
	frame.Sizer:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
	end)
	frame.Sizer:SetPoint("BOTTOMRIGHT", -4, 4)

	frame.CharacterDropDown = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
	frame.CharacterDropDown:SetPoint("TOPLEFT", 0, -30)
	frame.CharacterDropDown.Button:SetScript("OnMouseDown", function(self)
		if self:IsEnabled() then
			EDDM.ToggleDropDownMenu(nil, nil, self:GetParent());
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		end
	end)
	EDDM.UIDropDownMenu_Initialize(frame.CharacterDropDown, CharacterDropDown_Initialize)
	EDDM.UIDropDownMenu_SetSelectedValue(frame.CharacterDropDown, true)

	frame.CancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.CancelButton:SetPoint("BOTTOMRIGHT", -24, 4)
	frame.CancelButton:SetSize(100, 22)
	frame.CancelButton:SetText(CANCEL)
	frame.CancelButton:SetScript("OnClick", function()
		ResetAddOns()
		frame.ScrollFrame.update()
		frame:Hide()
	end)

	frame.OkButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.OkButton:SetPoint("TOPRIGHT", frame.CancelButton, "TOPLEFT", 0, 0)
	frame.OkButton:SetSize(100, 22)
	frame.OkButton:SetText(OKAY)
	frame.OkButton:SetScript("OnClick", function()
		SaveAddOns()
		frame.ScrollFrame.update()
		frame:Hide()
		if (frame.edited) then
			ReloadUI()
		end
	end)

	frame.EnableAllButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.EnableAllButton:SetPoint("BOTTOMLEFT", 4, 4)
	frame.EnableAllButton:SetSize(120, 22)
	frame.EnableAllButton:SetText(ENABLE_ALL_ADDONS)
	frame.EnableAllButton:SetScript("OnClick", function()
		local character = frame:GetCharacter()
		EnableAllAddOns(character)
		frame.ScrollFrame.update()
	end)

	frame.DisableAllButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.DisableAllButton:SetPoint("TOPLEFT", frame.EnableAllButton, "TOPRIGHT", 0, 0)
	frame.DisableAllButton:SetSize(120, 22)
	frame.DisableAllButton:SetText(DISABLE_ALL_ADDONS)
	frame.DisableAllButton:SetScript("OnClick", function()
		local character = frame:GetCharacter()
		DisableAllAddOns(character)
		frame.ScrollFrame.update()
	end)

	frame.CategoryButton = CreateFrame("Button", nil, frame, "UIPanelSquareButton")
	frame.CategoryButton:SetPoint("TOPRIGHT", -7, -27)
	frame.CategoryButton:SetSize(30, 30)
	frame.CategoryButton.icon:SetAtlas("common-icon-forwardarrow")
	frame.CategoryButton.icon:SetTexCoord(0, 1, 0, 1)
	frame.CategoryButton.icon:SetSize(15, 15)
	frame.CategoryButton:SetScript("OnClick", function()
		local db = frame:GetDb()
		db.isCategoryFrameVisible = not db.isCategoryFrameVisible
		frame:SetCategoryVisibility(db.isCategoryFrameVisible, true)
	end)

	frame.SetsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.SetsButton:SetPoint("LEFT", frame.CharacterDropDown.Button, "RIGHT", 4, 0)
	frame.SetsButton:SetSize(80, 22)
	frame.SetsButton:SetText("Sets")
	frame.SetsButton:SetScript("OnClick", function()
		EDDM.EasyMenu(SetsDropDownCreate(), dropdownFrame, frame.SetsButton, 0, 0, "MENU")
	end)

	frame.SearchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
	frame.SearchBox:SetPoint("LEFT", frame.SetsButton, "RIGHT", 8, 0)
	frame.SearchBox:SetSize(130, 20)
	frame.SearchBox:SetScript("OnTextChanged", function(self)
		SearchBoxTemplate_OnTextChanged(self)
		frame:UpdateListFilters()
	end)

	frame.ConfigButton = CreateFrame("Button", nil, frame, "UIPanelSquareButton")
	frame.ConfigButton:SetPoint("RIGHT", frame.CategoryButton, "LEFT", -4, 0)
	frame.ConfigButton:SetSize(30, 30)
	frame.ConfigButton.icon:SetAtlas("OptionsIcon-Brown")
	frame.ConfigButton.icon:SetTexCoord(0, 1, 0, 1)
	frame.ConfigButton.icon:SetSize(16, 16)
	frame.ConfigButton:SetScript("OnClick", function()
		EDDM.EasyMenu(ConfigDropDownCreate(), dropdownFrame, frame.ConfigButton, 0, 0, "MENU")
	end)
end