local ADDON_NAME, T = ...

local C = T.Color

local orderedCharList
local selectedCharIndex -- [0] for all characters, [1] for player name
local playerName
local playerGuid

--- @class SimpleAddonManager
local SAM = CreateFrame("Frame", ADDON_NAME, UIParent, "ButtonFrameTemplate")
ButtonFrameTemplate_HidePortrait(SAM)
SAM:Hide()
T.AddonFrame = SAM
SAM.MIN_SIZE_W = 470
SAM.MIN_SIZE_H = 400
SAM.CATEGORY_SIZE_W = 250
SAM:SetFrameStrata("FULLSCREEN")
SAM:SetPoint("CENTER", 0, 24)
SAM:SetSize(SAM.MIN_SIZE_W, SAM.MIN_SIZE_H)
SAM:SetResizable(true)
SAM:SetMovable(true)
SAM:EnableMouse(true)
SAM:SetClampedToScreen(true)
if (SAM.SetResizeBounds) then
	SAM.SetMinResize = function(self, w, h)
		self:SetResizeBounds(w, h)
		local cw, ch = self:GetSize()
		self:SetSize(cw < w and w or cw, ch < h and h or ch)
	end
end
SAM:SetMinResize(SAM.MIN_SIZE_W, SAM.MIN_SIZE_H)
SAM:SetScript("OnMouseDown", function(self)
	self:StartMoving()
end)
SAM:SetScript("OnMouseUp", function(self)
	self:StopMovingOrSizing()
end)
table.insert(UISpecialFrames, SAM:GetName()) -- Register frame to be closed with ESC

function SAM:GetDb()
	return SimpleAddonManagerDB
end

StaticPopupDialogs["SimpleAddonManager_Dialog"] = {
	button1 = OKAY,
	button2 = CANCEL,
	timeout = 0,
	whileDead = true,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent()
		local button = parent.GetButton1 and parent:GetButton1() or parent.button1
		if (button:IsEnabled() and parent.enterClicksFirstButton) then
			button:Click()
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

function SAM:CreateDefaultOptions(db, defaults)
	if (defaults[1]) then
		error("array with defaults is not supported!")
	end
	for k, v in pairs(defaults) do
		if (db[k] == nil) then
			db[k] = v
		elseif (type(v) == "table") then
			SAM:CreateDefaultOptions(db[k], v)
		end
	end
end

local function GetEditBoxCompat(self)
    return self.editBox
end

function SAM:ShowDialog(dialogInfo)
	local dialog = StaticPopupDialogs["SimpleAddonManager_Dialog"]
	dialog.text = dialogInfo.text
	dialog.OnAccept = dialogInfo.funcAccept
	dialog.OnCancel = dialogInfo.funcCancel
	dialog.OnAlt = dialogInfo.funcAlt
	dialog.OnShow = function(self, ...)
		self:SetFrameStrata("FULLSCREEN_DIALOG")
		if (not dialogInfo.outsideFrame) then
			self:ClearAllPoints()
			self:SetPoint("TOP", SAM, "TOP", 0, -120)
		end
		self.OldStrata = self:GetFrameStrata()
		if (not self.GetEditBox) then
		    self.GetEditBox = GetEditBoxCompat
		end
		if (self:GetEditBox()) then
			self:GetEditBox():SetText("")
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

function SAM:ShowInputDialog(text, func, funcOnShow, button2)
	self:ShowDialog({
		text = text,
		hasEditBox = true,
		funcAccept = function(self)
			func(self:GetEditBox():GetText())
		end,
		funcOnShow = funcOnShow,
		hideOnEscape = true,
		button2 = button2,
	})
end

function SAM:ShowConfirmDialog(text, func)
	self:ShowDialog({
		text = text,
		funcAccept = func,
		hideOnEscape = true,
	})
end

function SAM:ShowWarningDialog(text, func)
	self:ShowDialog({
		text = text,
		funcAccept = func,
		hideOnEscape = true,
		showAlert = true,
		button1 = CONTINUE,
	})
end

function SAM:ShowYesNoDialog(text, funcYes, funcNo)
	self:ShowDialog({
		text = text,
		funcAccept = funcYes,
		funcCancel = funcNo,
		button1 = YES,
		button2 = NO,
		hideOnEscape = not funcNo
	})
end

function SAM:ShowYesNoCancelDialog(text, funcYes, funcNo, funcCancel)
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

function SAM:IsAddonSelected(nameOrIndex, forSome, charGuid)
	if (forSome) then
		local state = SAM.compat.GetAddOnEnableState(nameOrIndex, nil)
		return state == 1
	end
	local guid = charGuid or SAM:GetSelectedCharGuid()
	if (charGuid == true) then
		guid = nil
	end
	local state = SAM.compat.GetAddOnEnableState(nameOrIndex, guid)
	return state == 2
end

function SAM:GetSelectedCharIndex()
	return selectedCharIndex or 0
end

function SAM:GetSelectedCharGuid()
	if (selectedCharIndex >= 1) then return orderedCharList[selectedCharIndex + 1].guid end
	return nil
end

function SAM:SetSelectedCharIndex(value)
	selectedCharIndex = value
	SAM:GetDb().config.selectedCharacter = value
end

function SAM:GetCharList()
	return orderedCharList
end

function SAM:GetLoggedCharGuid()
	return playerGuid
end

function SAM:Update()
	if (SAM.initialized) then
		SAM:UpdateCategoryFrame()
		SAM:UpdateListFilters()
		SAM:UpdateOkButton()
	end
end

SAM:SetScript("OnShow", function()
	SAM:Initialize()

	for _, module in SAM:ModulesIterator() do
		if (module.OnShow) then
			module:OnShow()
		end
	end

	SAM:Update()
	SAM:SetCategoryVisibility(SAM:GetDb().isCategoryFrameVisible, false)

	local db = SAM:GetDb()
	if (db.config.autofocusSearch) then
		SAM.SearchBox:SetFocus()
	end
end)

SAM:SetScript("OnHide", function()
	StaticPopup_Hide("SimpleAddonManager_Dialog")

	for _, module in SAM:ModulesIterator() do
		if (module.OnHide) then
			module:OnHide()
		end
	end
end)

function SAM:Initialize()
	if (SAM.initialized) then
		return
	end

	SAM.initialized = true

	for _, module in SAM:ModulesIterator() do
		if (module.PreInitialize) then
			module:PreInitialize()
		end
	end

	for _, module in SAM:ModulesIterator() do
		if (module.Initialize) then
			module:Initialize()
		end
	end
end

function SAM:TableKeysToSortedList(...)
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

function SAM:TableAsSortedPairList(t, filter)
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

function SAM:FormatMemory(value)
	if (value >= 1000) then
		value = value / 1000
		return format("%.2f MB", value)
	else
		return format("%.2f KB", value)
	end
end

local modules = {}
local modulesDeps = {}
local modulesDepsDirty = true
local modulesOrder = {}
function SAM:RegisterModule(name, ...)
	if (modules[name]) then
		error("Module '" .. name .. "' already exists!")
	end
	local module = {}
	modules[name] = module
	modulesDepsDirty = true
	modulesDeps[name] = { }
	for i, v in ipairs({ ... }) do
		modulesDeps[name][v] = true
	end
	return module
end

function SAM:GetModule(name)
	return modules[name]
end

function SAM:GetModules()
	return modules
end

function SAM:ModulesIterator()
	if (modulesDepsDirty) then
		local order = {}
		local nodes = {}
		local permMarkNode = {}
		local tempMarkNode = {}
		for m, _ in pairs(modules) do
			nodes[m] = true
		end

		local function visit(nodeName)
			if (permMarkNode[nodeName]) then return end
			if (tempMarkNode[nodeName]) then
				error("Cycle detected! " .. nodeName .. "")
			end

			tempMarkNode[nodeName] = true

			for name, _ in pairs(modules) do
				if (modulesDeps[nodeName][name]) then
					visit(name)
				end
			end

			permMarkNode[nodeName] = true
			nodes[nodeName] = nil
			table.insert(order, nodeName)
		end

		local safeLimit = 1000
		while (safeLimit > 0) do
			safeLimit = safeLimit - 1
			local n = next(nodes)
			if (not n) then break end
			visit(n)
		end

		modulesDepsDirty = false
		modulesOrder = order
	end

	local i = 0
	return function()
		i = i + 1
		if (i <= #modulesOrder) then
			local name = modulesOrder[i]
			return modulesOrder[i], modules[name]
		end
	end
end

local addonsInitialState = {}
function SAM:GetAddonsInitialState(charGuid)
	return addonsInitialState[charGuid or true] -- true represents "all"/nil
end

function SAM:IsAddonInstalled(indexOrName)
	local _, _, _, _, reason = SAM.compat.GetAddOnInfo(indexOrName)
	return reason ~= "MISSING"
end

function SAM:EnableAddOn(indexOrName)
	local c = SAM:GetSelectedCharGuid()
	SAM.compat.EnableAddOn(indexOrName, c)
end

function SAM:DisableAddOn(indexOrName)
	if (SAM:GetModule("Lock"):IsAddonLocked(indexOrName)) then return end
	local c = SAM:GetSelectedCharGuid()
	SAM.compat.DisableAddOn(indexOrName, c)
end

function SAM:EnableAllAddOns()
	local c = SAM:GetSelectedCharGuid()
	SAM.compat.EnableAllAddOns(c)
end

function SAM:DisableAllAddOns()
	local c = SAM:GetSelectedCharGuid()
	SAM.compat.DisableAllAddOns(c)
end

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
function SAM:GetAddOnMetadata(addon, field)
	return GetAddOnMetadata(addon, field)
end

-- When entering/leaving lfg, realm returns nil. Cache to avoid errors.
local playerInfoCache
function SAM:GetLoggedPlayerInfo()
	if (playerInfoCache == nil) then
		local name, realm = UnitNameUnmodified("player")
		if (realm == nil or realm == "") then
			realm = select(2, UnitFullName("player"))
		end
		playerInfoCache = {
			id = name .. "-" .. realm,
			name = name,
			realm = realm,
			color = RAID_CLASS_COLORS[select(2, UnitClass("player"))] or C.white,
			guid = playerGuid,
		}
	end
	return playerInfoCache
end

SAM:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)
SAM:RegisterEvent("ADDON_LOADED")
SAM:RegisterEvent("PLAYER_ENTERING_WORLD")
SAM:RegisterEvent("PLAYER_LEAVING_WORLD")

function SAM:ADDON_LOADED(name)
	if name ~= ADDON_NAME then
		return
	end

	self:UnregisterEvent("ADDON_LOADED")

	SimpleAddonManagerDB = SimpleAddonManagerDB or {}
	SimpleAddonManagerDB.sets = SimpleAddonManagerDB.sets or {}
	SimpleAddonManagerDB.categories = SimpleAddonManagerDB.categories or {}
	SimpleAddonManagerDB.config = SimpleAddonManagerDB.config or {}

	SAM:CreateDefaultOptions(SimpleAddonManagerDB.config, {
		showVersions = false,
		hookMenuButton = true,
		characterList2 = {},
	})

	selectedCharIndex = SimpleAddonManagerDB.config.selectedCharacter or 0
	-- after reload, select the current character if any other is selected
	if (selectedCharIndex > 1) then
		selectedCharIndex = 1
	end

	SAM:HookMenuButton()

	for _, v in SAM:ModulesIterator() do
		if (v.OnLoad) then
			v:OnLoad()
		end
	end
end

function SAM:InitAddonStateFor(charGuid)
	if (addonsInitialState[charGuid]) then return end

	-- load initial state
	addonsInitialState[charGuid] = {}
	for addonIndex = 1, SAM.compat.GetNumAddOns() do
		local addonName = SAM.compat.GetAddOnInfo(addonIndex)
		addonsInitialState[charGuid][addonName] = SAM:IsAddonSelected(addonIndex, nil, charGuid)
	end
end

function SAM:ClearInitialState()
	addonsInitialState = {}
	SAM:InitAddonStateFor(true)
	SAM:InitAddonStateFor(playerGuid)
	local selectedCharGuid = SAM:GetSelectedCharGuid()
	if (selectedCharGuid) then
		SAM:InitAddonStateFor(selectedCharGuid)
	end
end

function SAM:PLAYER_ENTERING_WORLD(...)
	playerName = UnitNameUnmodified("player")
	playerGuid = UnitGUID("player")

	local isInitialLogin, isReloadingUi = ...
	if (isInitialLogin or isReloadingUi) then
		-- init player list
		local realm = GetRealmName()
		local charList = SAM:GetDb().config.characterList2
		charList[realm] = charList[realm] or {}

		local _, classFile = UnitClass("player")
		local playerData = { class = classFile, name = playerName, guid = playerGuid }
		charList[realm][playerGuid] = playerData

		orderedCharList = {}
		for guid, v in pairs(charList[realm]) do
			if (v and guid ~= playerGuid) then
				table.insert(orderedCharList, v)
			end
		end
		table.sort(orderedCharList, function(a, b) return a.name < b.name end)
		table.insert(orderedCharList, 1, { name = ALL, guid = true })
		table.insert(orderedCharList, 2, playerData)

		-- load initial state
		SAM:InitAddonStateFor(true)
		SAM:InitAddonStateFor(playerGuid)
	end

	for _, v in SAM:ModulesIterator() do
		if (v.OnPlayerEnteringWorld) then
			v:OnPlayerEnteringWorld(...)
		end
	end
end

function SAM:PLAYER_LEAVING_WORLD(...)
	for _, v in SAM:ModulesIterator() do
		if (v.OnPlayerLeavingWorld) then
			v:OnPlayerLeavingWorld(...)
		end
	end
end

function SAM:HookMenuButton()
	if (SAM.isMenuHooked or not SAM:GetDb().config.hookMenuButton) then
		return
	end

	GameMenuFrame:HookScript("OnShow", function()
		local function overrideSetScript(widget)
			local original = widget:GetScript("OnClick")
			widget:SetScript("OnClick", function()
				if (SAM:GetDb().config.hookMenuButton) then
					PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
					HideUIPanel(GameMenuFrame)
					ShowUIPanel(SAM)
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

	SAM.isMenuHooked = true
end

function SAM.HybridScrollFrame_ShiftAwareOnScrollWheel(self, delta, step)
	step = step or self.stepSize or self.buttonHeight
	if (IsShiftKeyDown()) then
		step = step * 10;
	end
	HybridScrollFrame_OnMouseWheel(self, delta, step)
end
