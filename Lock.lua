local ADDON_NAME, T = ...
local L = T.L

--- @type SimpleAddonManager
local frame = T.AddonFrame
local module = frame:RegisterModule("Lock")

function module:IsAddonLocked(nameOrIndex)
	local name = frame.compat.GetAddOnInfo(nameOrIndex)
	local locks = module:GetLockedAddons()
	local state = locks[name]
	return state and state.enabled
end

function module:LockAddon(nameOrIndex)
	module:SetLockState(nameOrIndex, true)
end

function module:UnlockAddon(nameOrIndex)
	module:SetLockState(nameOrIndex, false)
end

function module:SetLockState(nameOrIndex, isLocking)
	local previousState = module:IsAddonLocked(nameOrIndex)
	local name = frame.compat.GetAddOnInfo(nameOrIndex)
	local locks = module:GetLockedAddons()
	if (isLocking) then
		-- enable the addon for everyone
		frame.compat.EnableAddOn(nameOrIndex, nil)

		locks[name] = locks[name] or {}
		locks[name].enabled = isLocking
	else
		locks[name] = nil
	end

	if (module.changingLocks[name] == nil) then
		module.changingLocks[name] = { old = previousState or false }
	end
end

function module:RollbackChanges()
	-- rollback the locks changes
	for addon, state in pairs(module.changingLocks) do
		local isLocked = module:IsAddonLocked(addon)
		if (isLocked and state.old == false) then
			module:UnlockAddon(addon)
		elseif (not isLocked and state.old == true) then
			module:LockAddon(addon)
		end
	end
	module.changingLocks = {}
end

function module:ConfirmChanges()
	module.changingLocks = {}
end

function module:GetLockedAddons()
	return frame:GetDb().lock.addons
end

function module:OnLoad()
	local db = frame:GetDb()
	frame:CreateDefaultOptions(db, {
		lock = {
			addons = { [ADDON_NAME] = { enabled = true } },
			canShowWarning = true,
		}
	})
end

function module:Initialize()
	module.changingLocks = {}

end

function module:OnPlayerEnteringWorld()
	local locks = module:GetLockedAddons()
	local me = UnitName("player")
	local showWarning = false
	for addon, state in pairs(locks) do
		if (frame:IsAddonInstalled(addon) and not frame:IsAddonSelected(addon, nil, me) and state.enabled) then
			frame:EnableAddOn(addon)
			showWarning = true
		end
	end
	local canShowWarning = frame:GetDb().lock.canShowWarning
	if (showWarning and canShowWarning) then
		frame:ShowDialog({
			text = L["Some locked addons had to be re-enabled during login. Do you want to reload UI to apply?"],
			funcAccept = function()
				ReloadUI()
			end,
			button1 = L["Reload UI"],
			button2 = CANCEL,
			hideOnEscape = true,
			outsideFrame = true,
		})
	end
end
