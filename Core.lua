local ADDON_NAME, T = ...

--- @class SimpleAddonManager
local frame = CreateFrame("Frame", ADDON_NAME, UIParent, "ButtonFrameTemplate")
frame:Hide()
T.AddonFrame = frame
frame.MIN_SIZE_W = 470
frame.MIN_SIZE_H = 300
frame.CATEGORY_SIZE_W = 250
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
table.insert(UISpecialFrames, frame:GetName()) -- Register frame to be closed with ESC

function frame:GetDb()
	return SimpleAddonManagerDB
end

StaticPopupDialogs["SimpleAddonManager_Dialog"] = {
	button1 = OKAY,
	button2 = CANCEL,
	OnShow = function(self)
		if (self.editBox) then
			self.editBox:SetText("")
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

T.separatorInfo = {
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

T.spacer = {
	text = "",
	hasArrow = false,
	isTitle = false,
	isUninteractable = true,
	notCheckable = true,
	disabled = true,
};

T.closeMenuInfo = {
	text = CANCEL,
	hasArrow = false,
	notCheckable = true,
};

function frame:CreateDefaultOptions(db, defaults)
	for k, v in pairs(defaults) do
		if (db[k] == nil) then
			db[k] = v
		end
	end
end

function frame:ShowDialog(text, hasEditBox, func)
	local dialog = StaticPopupDialogs["SimpleAddonManager_Dialog"]
	dialog.text = text
	dialog.OnAccept = func
	dialog.hasEditBox = hasEditBox
	StaticPopup_Show("SimpleAddonManager_Dialog")
end

function frame:ShowInputDialog(text, func)
	self:ShowDialog(text, true, function(self)
		func(self.editBox:GetText())
	end)
end

function frame:ShowConfirmDialog(text, func)
	self:ShowDialog(text, false, func)
end

function frame:IsAddonSelected(index)
	local character = self:GetCharacter()
	if (character == true) then
		character = nil;
	end
	return GetAddOnEnableState(character, index) > 0
end

local character = true -- name of the character, or [nil] for current character, or [true] for all characters on the realm
function frame:GetCharacter()
	return character
end

function frame:SetCharacter(value)
	character = value
end

function frame:Update()
	self.CategoryFrame.ScrollFrame.updateDb()
	self.CategoryFrame.ScrollFrame.update()
	self:UpdateListFilters()
end

frame:SetScript("OnShow", function()
	frame:Initialize()
	frame:Update()
	frame:SetCategoryVisibility(frame:GetDb().isCategoryFrameVisible, false)

	local db = frame:GetDb()
	if (db.config.autofocusSearch) then
		frame.SearchBox:SetFocus()
	end
end)

function frame:Initialize()
	if (frame.initialized) then
		return
	end

	frame:CreateMainFrame()
	frame:CreateAddonListFrame()
	frame:CreateCategoryFrame()
	frame.initialized = true
end

function frame:TableKeysToSortedList(...)
	local list = {}
	local added = {}
	for _, t in ipairs({ ... }) do
		for k, _ in pairs(t) do
			if not added[k] then
				table.insert(list, k)
				added[k] = true
			end
		end
	end
	table.sort(list)
	return list
end

function frame:FormatMemory(value)
	if (value >= 1000) then
		value = value / 1000
		return format("%.2f MB", value)
	else
		return format("%.2f KB", value)
	end
end

local modules = {}
function frame:RegisterModule(name)
	if (modules[name]) then
		error("Module '" .. name .. "' already exists!")
	end
	local module = {}
	modules[name] = module
	return module
end

function frame:GetModule(name)
	return modules[name]
end

frame:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)
frame:RegisterEvent("ADDON_LOADED")
function frame:ADDON_LOADED(name)
	if name ~= ADDON_NAME then
		return
	end

	self:UnregisterEvent("ADDON_LOADED")

	SimpleAddonManagerDB = SimpleAddonManagerDB or {}
	SimpleAddonManagerDB.sets = SimpleAddonManagerDB.sets or {}
	SimpleAddonManagerDB.categories = SimpleAddonManagerDB.categories or {}
	SimpleAddonManagerDB.config = SimpleAddonManagerDB.config or {}

	frame:CreateDefaultOptions(SimpleAddonManagerDB.config, {
		showVersions = false,
		sorting = "smart",
		hookMenuButton = true,
		searchBy = { name = true, title = true, author = false }
	})

	frame:HookMenuButton()

	for _, v in pairs(modules) do
		if (v.OnLoad) then
			v:OnLoad()
		end
	end
end

function frame:HookMenuButton()
	if (frame.isMenuHooked or not frame:GetDb().config.hookMenuButton) then
		return
	end

	GameMenuFrame:HookScript("OnShow", function()
		local original = GameMenuButtonAddons:GetScript("OnClick")
		GameMenuButtonAddons:SetScript("OnClick", function()
			if (frame:GetDb().config.hookMenuButton) then
				PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
				HideUIPanel(GameMenuFrame)
				ShowUIPanel(frame)
			else
				original()
			end
		end)
	end)

	frame.isMenuHooked = true
end