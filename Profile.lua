local _, T = ...
local L = T.L
local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("SimpleAddonManager_MenuFrame")

--- @type SimpleAddonManager
local frame = T.AddonFrame
local module = frame:RegisterModule("Profiles")

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

local function ProfilesDropDownCreate()
	local menu = {
		{ text = L["Profiles"], isTitle = true, notCheckable = true },
	}
	local db = frame:GetDb()

	local setsList = {}
	for key, v in pairs(db.sets) do
		table.insert(setsList, {
			key = key,
			name = key:lower(),
			value = v
		})
	end
	table.sort(setsList, function(a, b) return a.name < b.name end)

	for _, pair in ipairs(setsList) do
		local profileName, set = pair.key, pair.value
		local setMenu = {
			text = profileName,
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{ text = profileName, isTitle = true, notCheckable = true },
				{ text = #set.addons .. " AddOns", notCheckable = true },
				T.separatorInfo,
				{
					text = L["Save"],
					notCheckable = true,
					func = function()
						frame:ShowConfirmDialog(
								L("Save current addons in profile '${profile}'?", { profile = profileName }),
								function()
									SaveCurrentAddonsToSet(profileName)
								end
						)
					end
				},
				{
					text = L["Load"],
					notCheckable = true,
					func = function()
						frame:ShowConfirmDialog(
								L("Load the profile '${profile}'?", { profile = profileName }),
								function()
									local enabledAddons = db.sets[profileName].addons
									local character = frame:GetCharacter()
									DisableAllAddOns(character)
									for _, name in ipairs(enabledAddons) do
										EnableAddOn(name, character)
									end
									frame:Update()
								end
						)
					end
				},
				{
					text = L["Rename"],
					notCheckable = true,
					func = function()
						frame:ShowInputDialog(
								L("Enter the new name for the profile '${profile}'", { profile = profileName }),
								function(text)
									db.sets[text] = db.sets[profileName]
									db.sets[profileName] = nil
								end
						)
					end
				},
				{
					text = L["Delete"],
					notCheckable = true,
					func = function()
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
						SaveCurrentAddonsToSet(text)
					end
			)
		end,
		notCheckable = true
	})
	table.insert(menu, T.separatorInfo)
	table.insert(menu, T.closeMenuInfo)

	return menu
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
