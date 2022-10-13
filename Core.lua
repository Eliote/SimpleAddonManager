local ADDON_NAME = ...

--- @class ElioteAddonList
local frame = CreateFrame("Frame", "ElioteAddonList", UIParent, "ButtonFrameTemplate")
frame:Hide()
frame.MIN_SIZE_W = 470
frame.MIN_SIZE_H = 300
frame.CATEGORY_SIZE_W = 250

function frame:GetDb()
	return ElioteAddonListDB
end

StaticPopupDialogs["ElioteAddonList_Dialog"] = {
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

function frame:ShowDialog(text, hasEditBox, func)
	local dialog = StaticPopupDialogs["ElioteAddonList_Dialog"]
	dialog.text = text
	dialog.OnAccept = func
	dialog.hasEditBox = hasEditBox
	StaticPopup_Show("ElioteAddonList_Dialog")
end

function frame:ShowInputDialog(text, func)
	frame:ShowDialog(text, true, function(self)
		func(self.editBox:GetText())
	end)
end

function frame:ShowConfirmDialog(text, func)
	frame:ShowDialog(text, false, func)
end

function frame:IsAddonSelected(index)
	local character = frame:GetCharacter()
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
	frame.CategoryFrame.ScrollFrame.updateDb()
	frame.CategoryFrame.ScrollFrame.update()
	frame:UpdateListFilters()
end

frame:SetScript("OnShow", function()
	frame.ForceLoadCheck:SetChecked(not IsAddonVersionCheckEnabled())
	local db = frame:GetDb()
	frame:SetCategoryVisibility(db.isCategoryFrameVisible, false)
	frame.CategoryFrame.ScrollFrame.updateDb()
	frame.CategoryFrame.ScrollFrame.update()
	frame.ScrollFrame.update()
end)

function frame:TableKeysToSortedList(...)
	local list = {}
	local added = {}
	for _, t in ipairs({...}) do
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


frame:RegisterEvent("ADDON_LOADED")
function frame:ADDON_LOADED(name)
	if name ~= ADDON_NAME then
		return
	end

	ElioteAddonListDB = ElioteAddonListDB or {}
	ElioteAddonListDB.sets = ElioteAddonListDB.sets or {}
	ElioteAddonListDB.categories = ElioteAddonListDB.categories or {}

	frame:Update()
	frame:UnregisterEvent("ADDON_LOADED")
	frame:Show()
end
