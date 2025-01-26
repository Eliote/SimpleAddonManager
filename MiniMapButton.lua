local ADDON_NAME, T = ...
local L = T.L
local EDDM = LibStub("ElioteDropDownMenu-1.0")
local dropdownFrame = EDDM.UIDropDownMenu_GetOrCreate("SimpleAddonManager_MenuFrame")

--- @type SimpleAddonManager
local SAM = T.AddonFrame
local module = SAM:RegisterModule("Minimap")

local title = SAM:GetAddOnMetadata(ADDON_NAME, "Title") or ADDON_NAME

local IS_MAINLINE = WOW_PROJECT_MAINLINE == WOW_PROJECT_ID
local ICON_MOUSE_LEFT = IS_MAINLINE and "|A:newplayertutorial-icon-mouse-leftbutton:0:0|a " or ""
local ICON_MOUSE_RIGHT = IS_MAINLINE and "|A:newplayertutorial-icon-mouse-rightbutton:0:0|a " or ""

local broker = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
	type = "launcher",
	icon = "133742",
	label = title,
	OnTooltipShow = function(ttp)
		ttp:AddLine(title)
		ttp:AddLine(ICON_MOUSE_LEFT .. L["Left-click to open"])
		ttp:AddLine(ICON_MOUSE_RIGHT .. L["Right-click to show profile menu"])

		if (not SAM:GetDb().config.showMemoryInBrokerTtp) then
			return
		end

		local topAddOns = {}
		local maxAddons = 10

		UpdateAddOnMemoryUsage()

		local totalMem = 0
		for addonIndex = 1, SAM.compat.GetNumAddOns() do
			local mem = GetAddOnMemoryUsage(addonIndex)
			totalMem = totalMem + mem
			for i = 1, maxAddons do
				if (topAddOns[i] == nil or topAddOns[i].value < mem) then
					table.insert(topAddOns, i, {
						value = mem,
						name = SAM.compat.GetAddOnInfo(addonIndex)
					})
					break
				end
			end
		end

		if (totalMem > 0) then
			ttp:AddLine("\n")
			ttp:AddDoubleLine(L["AddOns Total Memory"], SAM:FormatMemory(totalMem), 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)

			for i = 1, maxAddons do
				if (topAddOns[i].value == 0) then
					break
				end
				ttp:AddDoubleLine(topAddOns[i].name, SAM:FormatMemory(topAddOns[i].value), 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
			end
		end
	end,
	OnClick = function(_, button)
		if (button == "LeftButton") then
			SAM:Show()
		else
			module:ShowMenuDropDown()
		end
	end
})
local ldbIcon = LibStub("LibDBIcon-1.0")

function module:OnLoad()
	local db = SAM:GetDb()
	SAM:CreateDefaultOptions(SimpleAddonManagerDB.config, {
		minimap = { hide = false }
	})
	ldbIcon:Register(ADDON_NAME, broker, db.config.minimap)
end

function module:ToggleMinimapButton()
	local db = SAM:GetDb()
	db.config.minimap.hide = not db.config.minimap.hide
	if (db.config.minimap.hide) then
		ldbIcon:Hide(ADDON_NAME)
	else
		ldbIcon:Show(ADDON_NAME)
	end
end

function module:ShowMenuDropDown()
	local menu = {
		{ text = broker.label, isTitle = true, notCheckable = true },
		{ text = L["Load Profile"], isTitle = true, notCheckable = true },
	}

	local db = SAM:GetDb()
	local setsList = SAM:TableAsSortedPairList(db.sets)

	for _, pair in ipairs(setsList) do
		local profileName = pair.key
		table.insert(menu, {
			text = profileName,
			notCheckable = true,
			func = function()
				SAM:GetModule("Profile"):ShowLoadProfileAndReloadUIDialog(profileName)
			end
		})
	end

	table.insert(menu, T.separatorInfo)
	table.insert(menu, T.closeMenuInfo)

	EDDM.ToggleEasyMenu(menu, dropdownFrame, "cursor", 0, 0, "MENU")
end