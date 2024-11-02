local _, T = ...
local L = T.L
local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("SimpleAddonManager_MenuFrame")

--- @type SimpleAddonManager
local frame = T.AddonFrame
local module = frame:RegisterModule("Profile")

local function MigrateProfileAddonsTable()
	local db = frame:GetDb()
	if (not db.setsVersion) then
		if (db.sets) then
			for _, profile in pairs(db.sets) do
				local newTable = {}
				for _, addon in ipairs(profile.addons) do
					newTable[addon] = true
				end
				profile.addonsCount = #profile.addons
				profile.addons = newTable
			end
		end
		if (db.autoProfile) then
			for _, profile in pairs(db.autoProfile) do
				local newTable = {}
				for _, addon in ipairs(profile.addons) do
					newTable[addon] = true
				end
				profile.addonsCount = #profile.addons
				profile.addons = newTable
			end
		end
		db.setsVersion = 1
	end
end

local function AddonsInProfilesRec(profiles)
	local recMark = {}
	local addons = {}

	local function walkProfile(name)
		if (recMark[name]) then
			return
		end
		recMark[name] = true

		local db = frame:GetDb()
		if (not db.sets[name]) then
			return
		end
		for addon, v in pairs(db.sets[name].addons) do
			if (v) then
				addons[addon] = true
			end
		end

		if (not db.sets[name].subSets) then
			return false
		end
		for sName, enabled in pairs(db.sets[name].subSets) do
			if (enabled) then
				walkProfile(sName)
			end
		end
	end

	for sName, enabled in pairs(profiles) do
		if (enabled) then
			walkProfile(sName)
		end
	end

	return addons
end

local function SaveCurrentAddonsToProfile(profileName, depAware)
	local db = frame:GetDb()
	local enabledAddons = {}
	local count = frame.compat.GetNumAddOns()
	db.sets[profileName] = db.sets[profileName] or {}
	local subSets = db.sets[profileName].subSets or {}
	local addonsCount = 0
	local subSetsAddons = depAware and AddonsInProfilesRec(subSets) or {}
	for i = 1, count do
		local name = frame.compat.GetAddOnInfo(i)
		if not subSetsAddons[name] and frame:IsAddonSelected(i) then
			enabledAddons[name] = true
			addonsCount = addonsCount + 1
		end
	end
	db.sets[profileName].addons = enabledAddons
	db.sets[profileName].addonsCount = addonsCount
	db.sets[profileName].subSets = subSets
end

function module:LoadAddonsFromProfile(profileName, keepEnabledAddons)
	local addons = AddonsInProfilesRec({ [profileName] = true })
	if (not keepEnabledAddons) then
		frame:DisableAllAddOns()
	end
	for name, _ in pairs(addons) do
		frame:EnableAddOn(name)
	end
	frame:Update()
end

function module:ShowLoadProfileAndReloadUIDialog(profile)
	frame:ShowConfirmDialog(
			L("Load profile '${profile}' and reload UI?", { profile = profile }),
			function()
				module:LoadAddonsFromProfile(profile)
				ReloadUI()
			end
	)
end

local function ProfilesDropDownCreate()
	local menu = {
		{ text = L["Profiles"], isTitle = true, notCheckable = true },
	}
	local db = frame:GetDb()

	local me = frame:GetCurrentPlayerInfo().id
	local charsTable = frame:TableAsSortedPairList(db.autoProfile, function(k)
		return k ~= me
	end)
	local charsMenuList = {}
	table.insert(menu, {
		text = L["Characters"],
		notCheckable = true,
		hasArrow = true,
		menuList = charsMenuList
	})

	for _, pair in ipairs(charsTable) do
		local info = pair.value
		local title = "|c" .. info.playerColor .. info.playerId .. "|r"
		local charMenu = {
			text = title,
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{ text = title, isTitle = true, notCheckable = true },
				{ text = info.addonsCount .. " AddOns", notCheckable = true },
				T.separatorInfo,
				{
					text = L["Load"],
					notCheckable = true,
					func = function()
						EDDM.CloseDropDownMenus();
						frame:ShowConfirmDialog(
								L("Load the AddOns from '${char}'?", { char = title }),
								function()
									local enabledAddons = info.addons
									frame:DisableAllAddOns()
									for name, _ in pairs(enabledAddons) do
										frame:EnableAddOn(name)
									end
									frame:Update()
								end
						)
					end
				},
			}
		}
		table.insert(charsMenuList, charMenu)
	end

	table.insert(charsMenuList, {
		text = L["Clear list"],
		notCheckable = true,
		hasArrow = false,
		func = function()
			frame:ShowConfirmDialog(
					L["Are you sure you want to remove all automatic character profiles?"],
					function()
						db.autoProfile = {}
					end
			)
		end
	})

	table.insert(menu, T.separatorInfo)

	local setsList = frame:TableAsSortedPairList(db.sets)

	local function createSubSetsMenuListFor(profileName, parent)
		local subSetsMenuList = {
			{ text = profileName, isTitle = true, notCheckable = true },
		}
		for _, subPair in ipairs(setsList) do
			local subProfileName, subSet = subPair.key, subPair.value
			if (profileName ~= subProfileName) then
				table.insert(subSetsMenuList, function()
					return {
						text = subProfileName,
						checked = function()
							return parent.subSets[subProfileName]
						end,
						func = function()
							parent.subSets[subProfileName] = not parent.subSets[subProfileName]
						end,
						hasArrow = parent.subSets[subProfileName],
						menuList = createSubSetsMenuListFor(subProfileName, subSet)
					}
				end)
			end
		end
		return subSetsMenuList
	end

	local function addonsIn(set)
		local list = frame:TableAsSortedPairList(set.addons)
		local maxPerMenu = 30

		local function next(from)
			local menu = {}
			for i = from, from + maxPerMenu do
				if (i == from + maxPerMenu and list[i]) then
					table.insert(menu, function()
						return {
							text = L["..."],
							notCheckable = true,
							hasArrow = true,
							menuList = next(i)
						}
					end)
					break
				end
				if (not list[i]) then
					break
				end
				table.insert(menu, { text = list[i].key, notCheckable = true })
			end

			return menu
		end

		return next(1)
	end

	for _, pair in ipairs(setsList) do
		local profileName, set = pair.key, pair.value
		set.subSets = set.subSets or {}

		local subSetsMenuList = createSubSetsMenuListFor(profileName, set)

		local setMenu = {
			text = profileName,
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{ text = profileName, isTitle = true, notCheckable = true },
				function()
					return {
						text = set.addonsCount .. " AddOns",
						notCheckable = true,
						hasArrow = true,
						menuList = addonsIn(set),
					}
				end,
				T.separatorInfo,
				{
					text = L["Save (*)"],
					tooltipOnButton = true,
					tooltipTitle = L["Ignore addons included in dependent profiles."],
					tooltipText = "",
					notCheckable = true,
					func = function()
						EDDM.CloseDropDownMenus();
						frame:ShowConfirmDialog(
								L("Save current addons, ignoring addons included in dependent profiles, into profile '${profile}'?", { profile = profileName }),
								function()
									SaveCurrentAddonsToProfile(profileName, true)
								end
						)
					end
				},
				{
					text = L["Save"],
					notCheckable = true,
					func = function()
						EDDM.CloseDropDownMenus();
						frame:ShowConfirmDialog(
								L("Save current addons in profile '${profile}'?", { profile = profileName }),
								function()
									SaveCurrentAddonsToProfile(profileName)
								end
						)
					end
				},
				T.separatorInfo,
				{
					text = L["Load"],
					notCheckable = true,
					func = function()
						EDDM.CloseDropDownMenus();
						frame:ShowConfirmDialog(
								L("Load the profile '${profile}'?", { profile = profileName }),
								function()
									module:LoadAddonsFromProfile(profileName)
								end
						)
					end
				},
				{
					text = L["Enable Addons"],
					notCheckable = true,
					func = function()
						EDDM.CloseDropDownMenus();
						frame:ShowConfirmDialog(
								L("Enable addons from the profile '${profile}'?", { profile = profileName }),
								function()
									module:LoadAddonsFromProfile(profileName, true)
								end
						)
					end
				},
				{
					text = L["Profile dependencies"],
					notCheckable = true,
					hasArrow = true,
					menuList = subSetsMenuList,
				},
				T.separatorInfo,
				{
					text = L["Rename"],
					notCheckable = true,
					func = function()
						EDDM.CloseDropDownMenus();
						frame:ShowInputDialog(
								L("Enter the new name for the profile '${profile}'", { profile = profileName }),
								function(text)
									db.sets[text] = db.sets[profileName]
									db.sets[profileName] = nil
								end,
								function(self)
									self.editBox:SetText(profileName)
									self.editBox:HighlightText()
								end
						)
					end
				},
				{
					text = L["Delete"],
					notCheckable = true,
					func = function()
						EDDM.CloseDropDownMenus();
						frame:ShowConfirmDialog(
								L("Delete the profile '${profile}'?", { profile = profileName }),
								function()
									db.sets[profileName] = nil
								end
						)
					end
				},
			}
		}
		table.insert(menu, setMenu)
	end

	table.insert(menu, T.separatorInfo)
	table.insert(menu, {
		text = L["Create new profile"],
		func = function()
			frame:ShowInputDialog(
					L["Enter the name for the new profile"],
					function(text)
						SaveCurrentAddonsToProfile(text)
					end
			)
		end,
		notCheckable = true
	})
	table.insert(menu, T.separatorInfo)
	table.insert(menu, T.closeMenuInfo)

	return menu
end

function module:OnLoad()
	MigrateProfileAddonsTable()
end

function module:PreInitialize()
	frame.SetsButton = Mixin(
			CreateFrame("Button", nil, frame, "UIPanelButtonTemplate"),
			EDDM.HandlesGlobalMouseEventMixin
	)
end

function module:Initialize()
	frame.SetsButton:SetPoint("LEFT", frame.CharacterDropDown.Button, "RIGHT", 4, 0)
	frame.SetsButton:SetSize(80, 22)
	frame.SetsButton:SetText(L["Profiles"])
	frame.SetsButton:SetScript("OnClick", function()
		EDDM.ToggleEasyMenu(ProfilesDropDownCreate(), dropdownFrame, frame.SetsButton, 0, 0, "MENU")
	end)
end

function module:UpdatePlayerProfileAddons()
	local playerInfo = frame:GetCurrentPlayerInfo()
	local db = frame:GetDb()
	db.autoProfile = db.autoProfile or {}

	local addons = {}
	local addonsCount = 1
	for addonIndex = 1, frame.compat.GetNumAddOns() do
		local addonName = frame.compat.GetAddOnInfo(addonIndex)
		if (frame.compat.GetAddOnEnableState(addonIndex, playerInfo.name) > 0) then
			addons[addonName] = true
			addonsCount = addonsCount + 1
		end
	end

	db.autoProfile[playerInfo.id] = {
		addons = addons,
		addonsCount = addonsCount,
		playerId = playerInfo.id,
		playerColor = playerInfo.color.colorStr
	}
end

function module:OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
	if (isInitialLogin or isReloadingUi) then
		module:UpdatePlayerProfileAddons()
	end
end

function module:OnPlayerLeavingWorld()
	module:UpdatePlayerProfileAddons()
end