local _, T = ...

--- @type SimpleAddonManager
local frame = T.AddonFrame

SLASH_SIMPLEADDONMANAGER1, SLASH_SIMPLEADDONMANAGER1 = '/sam', '/simpleaddonmanager'
function SlashCmdList.SIMPLEADDONMANAGER()
	frame:Show()
end