local ADDON_NAME, T = ...
local L = T.L

--- @type SimpleAddonManager
local frame = T.AddonFrame
local module = frame:RegisterModule("Minimap")

local title = GetAddOnMetadata(ADDON_NAME, "Title") or ADDON_NAME
local leftClickButtonIcon = "|A:newplayertutorial-icon-mouse-leftbutton:0:0|a "

local broker = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
	type = "launcher",
	icon = "133742",
	label = title,
	OnTooltipShow = function(ttp)
		ttp:AddLine(title)
		ttp:AddLine(leftClickButtonIcon .. L["Left-click to open"])

		local topAddOns = {}
		local maxAddons = 10

		UpdateAddOnMemoryUsage();

		local totalMem = 0;
		for addonIndex = 1, GetNumAddOns() do
			local mem = GetAddOnMemoryUsage(addonIndex)
			totalMem = totalMem + mem
			for i = 1, maxAddons do
				if (topAddOns[i] == nil or topAddOns[i].value < mem) then
					table.insert(topAddOns, i, {
						value = mem,
						name = GetAddOnInfo(addonIndex)
					})
					break
				end
			end
		end

		if (totalMem > 0) then
			ttp:AddLine("\n")
			ttp:AddDoubleLine(L["AddOns Total Memory"], frame:FormatMemory(totalMem), 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)

			for i = 1, maxAddons do
				if (topAddOns[i].value == 0) then
					break
				end
				ttp:AddDoubleLine(topAddOns[i].name, frame:FormatMemory(topAddOns[i].value), 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
			end
		end
	end,
	OnClick = function()
		frame:Show()
	end
})
local ldbIcon = LibStub("LibDBIcon-1.0")

function module:OnLoad()
	local db = frame:GetDb()
	frame:CreateDefaultOptions(SimpleAddonManagerDB.config, {
		minimap = { hide = false }
	})
	ldbIcon:Register(ADDON_NAME, broker, db.config.minimap)
end

function module:ToggleMinimapButton()
	local db = frame:GetDb()
	db.config.minimap.hide = not db.config.minimap.hide
	if (db.config.minimap.hide) then
		ldbIcon:Hide(ADDON_NAME)
	else
		ldbIcon:Show(ADDON_NAME)
	end
end
