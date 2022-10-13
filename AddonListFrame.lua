local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("ElioteAddonList_MenuFrame")

--- @type ElioteAddonList
local frame = ElioteAddonList

local function AddonRightClickMenu(addonIndex)
	local name, title = GetAddOnInfo(addonIndex)
	local menu = {
		{ text = title, isTitle = true, notCheckable = true },
		{ text = "Categories: ", isTitle = true, notCheckable = true },
	}
	local userCategories, tocCategories = frame:GetCategoryTables()
	local sortedCategories = frame:TableKeysToSortedList(userCategories, tocCategories)
	for _, categoryName in ipairs(sortedCategories) do
		local categoryDb = userCategories[categoryName]
		local tocCategory = tocCategories[categoryName]
		local isInToc = tocCategory and tocCategory.addons and tocCategory.addons[name]
		table.insert(menu, {
			text = categoryName .. (isInToc and " |cFFFFFF00(Automatically in category)" or ""),
			checked = categoryDb and categoryDb.addons and categoryDb.addons[name],
			keepShownOnClick = true,
			func = function(_, _, _, checked)
				userCategories[categoryName] = userCategories[categoryName] or { name = categoryName }
				userCategories[categoryName].addons = userCategories[categoryName].addons or {}
				userCategories[categoryName].addons[name] = checked or nil
				frame:Update()
			end,
		})
	end
	return menu
end

-- create the hybrid scroll frame
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "HybridScrollFrameTemplate")
frame.ScrollFrame = scrollFrame
scrollFrame:SetPoint("TOPLEFT", 7, -64)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 30)

-- add a scroll bar
scrollFrame.ScrollBar = CreateFrame("Slider", nil, scrollFrame, "HybridScrollBarTemplate")
scrollFrame.ScrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 1, -16)
scrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 1, 12)
scrollFrame.ScrollBar.doNotHide = true
scrollFrame.ScrollBar:HookScript("OnValueChanged", function(_, value)
	frame.scrollOffset = value
end)

local function AddonTooltipBuildDepsString(...)
	local deps = "";
	for i = 1, select("#", ...) do
		if (i == 1) then
			deps = ADDON_DEPENDENCIES .. select(i, ...);
		else
			deps = deps .. ", " .. select(i, ...);
		end
	end
	return deps;
end

local function ToggleAddon(self)
	local addonIndex = self:GetParent().addonIndex
	local newValue = not frame:IsAddonSelected(addonIndex)
	frame.edited = true
	frame.OkButton:SetText("Reload UI")
	self:SetChecked(newValue)
	if (newValue) then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		local character = frame:GetCharacter()
		EnableAddOn(addonIndex, character)
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		local character = frame:GetCharacter()
		DisableAddOn(addonIndex, character)
	end
	scrollFrame.update()
end

local function AddonButtonOnClick(self, mouseButton)
	if (mouseButton == "LeftButton") then
		ToggleAddon(self.EnabledButton)
	else
		EDDM.EasyMenu(AddonRightClickMenu(self.addonIndex), dropdownFrame, "cursor", 0, 0, "MENU")
	end
end

local function AddonButtonOnEnter(self)
	local name, title, notes, _, _, security = GetAddOnInfo(self.addonIndex)

	GameTooltip:ClearLines();
	GameTooltip:SetOwner(frame, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT")
	if (security == "BANNED") then
		GameTooltip:SetText(ADDON_BANNED_TOOLTIP);
	else
		if (title) then
			GameTooltip:AddLine(title);
		else
			GameTooltip:AddLine(name);
		end
		GameTooltip:AddLine(notes, 1.0, 1.0, 1.0, true);
		GameTooltip:AddLine(AddonTooltipBuildDepsString(GetAddOnDependencies(self.addonIndex)));
	end

	GameTooltip:Show()
end

local function AddonButtonOnLeave()
	GameTooltip:Hide()
end

scrollFrame.update = function()
	local buttons = HybridScrollFrame_GetButtons(scrollFrame);
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttonHeight;
	local addons = frame:GetAddonsList()
	local count = #addons

	for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex]
		button:SetPoint("LEFT", scrollFrame)
		button:SetPoint("RIGHT", scrollFrame)

		local relativeButtonIndex = buttonIndex + offset
		buttonHeight = button:GetHeight() -- set the button height var to use in the update call later

		if relativeButtonIndex <= count then
			local addonIndex = addons[relativeButtonIndex].index
			local _, title, _, loadable, reason = GetAddOnInfo(addonIndex)
			--local loaded = IsAddOnLoaded(addonRealIndex)
			local enabled = frame:IsAddonSelected(addonIndex)

			button.Name:SetText(title)
			if (loadable or (enabled and (reason == "DEP_DEMAND_LOADED" or reason == "DEMAND_LOADED"))) then
				button.Name:SetTextColor(1.0, 0.78, 0.0);
			elseif enabled then
				button.Name:SetTextColor(1.0, 0.1, 0.1);
			else
				button.Name:SetTextColor(0.5, 0.5, 0.5);
			end

			button.addonIndex = addonIndex
			button.Status:SetText((not loadable and reason and _G["ADDON_" .. reason]) or "")
			button.Status:SetTextColor(0.5, 0.5, 0.5);

			button.EnabledButton:SetChecked(enabled)
			button.EnabledButton:SetScript("OnClick", ToggleAddon)

			button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			button:SetScript("OnClick", AddonButtonOnClick)
			button:SetScript("OnEnter", AddonButtonOnEnter)
			button:SetScript("OnLeave", AddonButtonOnLeave)

			button:Show()
		else
			button:Hide()
		end
	end

	HybridScrollFrame_Update(scrollFrame, count * buttonHeight, scrollFrame:GetHeight())
end

-- this will create listview items using the template define, the number of buttons is determined by the
HybridScrollFrame_CreateButtons(scrollFrame, "ElioteAddonListItem")

scrollFrame:SetScript("OnSizeChanged", function()
	local offsetBefore = scrollFrame.ScrollBar:GetValue()
	HybridScrollFrame_CreateButtons(scrollFrame, "ElioteAddonListItem")
	scrollFrame.ScrollBar:SetValue(offsetBefore)
	scrollFrame.update()
end)

