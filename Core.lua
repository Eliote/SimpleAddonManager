local ADDON_NAME, T = ...

local C = T.Color

local orderedCharList
local selectedCharIndex -- [0] for all characters, [1] for player name
local playerName

--- @class SimpleAddonManager
local frame = CreateFrame("Frame", ADDON_NAME, UIParent, "ButtonFrameTemplate")
ButtonFrameTemplate_HidePortrait(frame)
frame:Hide()
T.AddonFrame = frame
frame.MIN_SIZE_W = 470
frame.MIN_SIZE_H = 400
frame.CATEGORY_SIZE_W = 250
frame:SetFrameStrata("FULLSCREEN")
frame:SetPoint("CENTER", 0, 24)
frame:SetSize(frame.MIN_SIZE_W, frame.MIN_SIZE_H)
frame:SetResizable(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
if (frame.SetResizeBounds) then
	frame.SetMinResize = function(self, w, h)
		self:SetResizeBounds(w, h)
		local cw, ch = self:GetSize()
		self:SetSize(cw < w and w or cw, ch < h and h or ch)
	end
end
frame:SetMinResize(frame.MIN_SIZE_W, frame.MIN_SIZE_H)
frame:SetScript("OnMouseDown", function(self)
	self:StartMoving()
end)
frame:SetScript("OnMouseUp", function(self)
	self:StopMovingOrSizing()
end)
frame:SetScript("OnHide", function()
	StaticPopup_Hide("SimpleAddonManager_Dialog")
end)
table.insert(UISpecialFrames, frame:GetName()) -- Register frame to be closed with ESC

function frame:GetDb()
	return SimpleAddonManagerDB
end

StaticPopupDialogs["SimpleAddonManager_Dialog"] = {
	button1 = OKAY,
	button2 = CANCEL,
	timeout = 0,
	whileDead = true,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent()
		if (parent.button1:IsEnabled() and parent.enterClicksFirstButton) then
			parent.button1:Click()
		end
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
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
	if (defaults[1]) then
		error("array with defaults is not supported!")
	end
	for k, v in pairs(defaults) do
		if (db[k] == nil) then
			db[k] = v
		elseif (type(v) == "table") then
			frame:CreateDefaultOptions(db[k], v)
		end
	end
end

function frame:ShowDialog(dialogInfo)
	local dialog = StaticPopupDialogs["SimpleAddonManager_Dialog"]
	dialog.text = dialogInfo.text
	dialog.OnAccept = dialogInfo.funcAccept
	dialog.OnCancel = dialogInfo.funcCancel
	dialog.OnAlt = dialogInfo.funcAlt
	dialog.OnShow = function(self, ...)
		self:SetFrameStrata("FULLSCREEN_DIALOG")
		self:ClearAllPoints()
		self:SetPoint("TOP", frame, "TOP", 0, -120)
		self.OldStrata = self:GetFrameStrata()
		if (self.editBox) then
			self.editBox:SetText("")
		end
		if (dialogInfo.funcOnShow) then
			dialogInfo.funcOnShow(self, ...)
		end
	end
	dialog.OnHide = function(self)
		self:ClearAllPoints()
		self:SetFrameStrata(self.OldStrata)
		self.OldStrata = nil
	end
	dialog.hasEditBox = dialogInfo.hasEditBox
	dialog.button1 = dialogInfo.button1 or OKAY
	if (dialogInfo.button2 == false) then
		dialog.button2 = nil
	else
		dialog.button2 = dialogInfo.button2 or CANCEL
	end
	dialog.button3 = dialogInfo.button3
	dialog.enterClicksFirstButton = not dialogInfo.button3
	dialog.hideOnEscape = dialogInfo.hideOnEscape
	dialog.showAlert = dialogInfo.showAlert
	StaticPopup_Show("SimpleAddonManager_Dialog")
end

function frame:ShowInputDialog(text, func, funcOnShow)
	self:ShowDialog({
		text = text,
		hasEditBox = true,
		funcAccept = function(self)
			func(self.editBox:GetText())
		end,
		funcOnShow = funcOnShow,
		hideOnEscape = true,
	})
end

function frame:ShowConfirmDialog(text, func)
	self:ShowDialog({
		text = text,
		funcAccept = func,
		hideOnEscape = true,
	})
end

function frame:ShowWarningDialog(text, func)
	self:ShowDialog({
		text = text,
		funcAccept = func,
		hideOnEscape = true,
		showAlert = true,
		button1 = CONTINUE,
	})
end

function frame:ShowYesNoDialog(text, funcYes, funcNo)
	self:ShowDialog({
		text = text,
		funcAccept = funcYes,
		funcCancel = funcNo,
		button1 = YES,
		button2 = NO,
		hideOnEscape = not funcNo
	})
end

function frame:ShowYesNoCancelDialog(text, funcYes, funcNo, funcCancel)
	self:ShowDialog({
		text = text,
		funcAccept = funcYes,
		funcCancel = funcNo,
		button1 = YES,
		button2 = NO,
		button3 = CANCEL,
		funcAlt = funcCancel,
	})
end

function frame:IsAddonSelected(nameOrIndex, forSome, character)
	if (forSome) then
		local state = frame.compat.GetAddOnEnableState(nameOrIndex, nil)
		return state == 1
	end
	local char = character or frame:GetSelectedCharName()
	if (character == true) then
		char = nil
	end
	local state = frame.compat.GetAddOnEnableState(nameOrIndex, char)
	return state == 2
end

function frame:GetSelectedCharIndex()
	return selectedCharIndex or 0
end

function frame:GetSelectedCharName()
	if (selectedCharIndex >= 1) then return orderedCharList[selectedCharIndex + 1].name end
	return nil
end

function frame:SetSelectedCharIndex(value)
	selectedCharIndex = value
	frame:GetDb().config.selectedCharacter = value
end

function frame:GetCharList()
	return orderedCharList
end

function frame:Update()
	if (frame.initialized) then
		frame:UpdateCategoryFrame()
		frame:UpdateListFilters()
		frame:UpdateOkButton()
	end
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

	frame.initialized = true

	for _, module in pairs(frame:GetModules()) do
		if (module.PreInitialize) then
			module:PreInitialize()
		end
	end

	for _, module in pairs(frame:GetModules()) do
		if (module.Initialize) then
			module:Initialize()
		end
	end
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

function frame:TableAsSortedPairList(t, filter)
	local list = {}
	for key, v in pairs(t) do
		if (filter == nil or filter(key, v)) then
			table.insert(list, {
				key = key,
				name = key:lower(),
				value = v
			})
		end
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
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

function frame:GetModules()
	return modules
end

local addonsInitialState = {}
function frame:GetAddonsInitialState(character)
	return addonsInitialState[character or true] -- true represents "all"/nil
end

function frame:IsAddonInstalled(indexOrName)
	local _, _, _, _, reason = frame.compat.GetAddOnInfo(indexOrName)
	return reason ~= "MISSING"
end

function frame:EnableAddOn(indexOrName)
	local c = frame:GetSelectedCharName()
	frame.compat.EnableAddOn(indexOrName, c)
end

function frame:DisableAddOn(indexOrName)
	local c = frame:GetSelectedCharName()
	frame.compat.DisableAddOn(indexOrName, c)
end

function frame:EnableAllAddOns()
	local c = frame:GetSelectedCharName()
	frame.compat.EnableAllAddOns(c)
end

function frame:DisableAllAddOns()
	local c = frame:GetSelectedCharName()
	frame.compat.DisableAllAddOns(c)
end

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
function frame:GetAddOnMetadata(addon, field)
	return GetAddOnMetadata(addon, field)
end

-- When entering/leaving lfg, realm returns nil. Cache to avoid errors.
local nameCache, realmCache, classColor
function frame:GetCurrentPlayerInfo()
	if (nameCache == nil) then
		nameCache, realmCache = UnitNameUnmodified("player")
		if (realmCache == nil or realmCache == "") then
			realmCache = select(2, UnitFullName("player"))
		end
		classColor = RAID_CLASS_COLORS[select(2, UnitClass("player"))] or C.white
	end
	return {
		id = nameCache .. "-" .. realmCache,
		name = nameCache,
		realm = realmCache,
		color = classColor
	}
end

frame:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")

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
		hookMenuButton = true,
		characterList = {},
	})

	selectedCharIndex = SimpleAddonManagerDB.config.selectedCharacter or 0
	-- after reload, select the current character if any other is selected
	if (selectedCharIndex > 1) then
		selectedCharIndex = 1
	end

	frame:HookMenuButton()

	for _, v in pairs(modules) do
		if (v.OnLoad) then
			v:OnLoad()
		end
	end
end

function frame:InitAddonStateFor(character)
	if (addonsInitialState[character]) then return end

	-- load initial state
	addonsInitialState[character] = {}
	for addonIndex = 1, frame.compat.GetNumAddOns() do
		local addonName = frame.compat.GetAddOnInfo(addonIndex)
		addonsInitialState[character][addonName] = frame:IsAddonSelected(addonIndex, nil, character)
	end
end

function frame:ClearInitialState()
	addonsInitialState = {}
	frame:InitAddonStateFor(true)
	frame:InitAddonStateFor(playerName)
	local selectedChar = frame:GetSelectedCharName()
	if (selectedChar) then
		frame:InitAddonStateFor(selectedChar)
	end
end

function frame:PLAYER_ENTERING_WORLD(...)
	playerName = UnitName("player")

	local isInitialLogin, isReloadingUi = ...
	if (isInitialLogin or isReloadingUi) then
		-- init player list
		local realm = GetRealmName()
		local charList = frame:GetDb().config.characterList
		charList[realm] = charList[realm] or {}

		local _, classFile = UnitClass("player")
		charList[realm][playerName] = { class = classFile }

		orderedCharList = {}
		for name, v in pairs(charList[realm]) do
			if (v and name ~= playerName) then
				table.insert(orderedCharList, { name = name, class = v.class })
			end
		end
		table.sort(orderedCharList, function(a, b) return a.name < b.name end)
		table.insert(orderedCharList, 1, { name = ALL })
		table.insert(orderedCharList, 2, { name = playerName, class = classFile })

		-- load initial state
		frame:InitAddonStateFor(true)
		frame:InitAddonStateFor(playerName)
	end

	for _, v in pairs(modules) do
		if (v.OnPlayerEnteringWorld) then
			v:OnPlayerEnteringWorld(...)
		end
	end
end

function frame:PLAYER_LEAVING_WORLD(...)
	for _, v in pairs(modules) do
		if (v.OnPlayerLeavingWorld) then
			v:OnPlayerLeavingWorld(...)
		end
	end
end

function frame:HookMenuButton()
	if (frame.isMenuHooked or not frame:GetDb().config.hookMenuButton) then
		return
	end

	GameMenuFrame:HookScript("OnShow", function()
		local function overrideSetScript(widget)
			local original = widget:GetScript("OnClick")
			widget:SetScript("OnClick", function()
				if (frame:GetDb().config.hookMenuButton) then
					PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
					HideUIPanel(GameMenuFrame)
					ShowUIPanel(frame)
				else
					original()
				end
			end)
		end

		if GameMenuButtonAddons then
			-- Old way
			overrideSetScript(GameMenuButtonAddons)
		else
			-- TWW
			for widget in GameMenuFrame.buttonPool:EnumerateActive() do
				if widget:GetText() == ADDONS then
					overrideSetScript(widget)
					break
				end
			end
		end
	end)

	frame.isMenuHooked = true
end

function frame.HybridScrollFrame_ShiftAwareOnScrollWheel(self, delta, step)
	step = step or self.stepSize or self.buttonHeight
	if (IsShiftKeyDown()) then
		step = step * 10;
	end
	HybridScrollFrame_OnMouseWheel(self, delta, step)
end
