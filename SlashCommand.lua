local ADDON_NAME, T = ...
local L = T.L

--- @type SimpleAddonManager
local frame = T.AddonFrame
local CommandsModule = {}
local Commands = {
	open = {
		usage = "open",
		args = {},
		func = function()
			frame:Show()
		end,
	},
	profile = {
		usage = 'profile "Name" [Reload option]',
		args = {
			{ desc = 'Name: Profile name', required = true },
			{
				desc = [==[Reload option (optional):
- ask: Show confirmation popup (default)
- reload: Loads the profile and reloads the UI
- ignore: Only loads the profile]==],
				required = false
			}
		},
		func = function(profile, reloadType)
			local db = frame:GetDb()
			if (not db.sets[profile]) then
				CommandsModule:Print(L("Profile '${profile}' not found!", { profile = profile }))
			else
				reloadType = reloadType or "ask"
				if (reloadType == "ask") then
					frame:GetModule("Profile"):ShowLoadProfileAndReloadUIDialog(profile)
				else
					frame:GetModule("Profile"):LoadAddonsFromProfile(profile)
					if (reloadType == "reload") then
						ReloadUI()
					end
				end
			end
		end,
	}
}

LibStub("AceConsole-3.0"):Embed(CommandsModule)

setmetatable(CommandsModule, {
	__tostring = function()
		return (frame:GetAddOnMetadata(ADDON_NAME, "Title"))
	end
})

CommandsModule:RegisterChatCommand("sam", "HandleCMD")
CommandsModule:RegisterChatCommand("simpleaddonmanager", "HandleCMD")

local function HasMissingParam(list, max, reg)
	for i = 1, max do
		if (list[i] == nil and reg.args[i].required) then
			return true
		end
	end
end

function CommandsModule:UsageMessage(cmd)
	local registry = Commands[cmd]
	local args = {}
	for _, v in ipairs(registry.args) do
		table.insert(args, v.desc .. "\n")
	end
	return "\nUsage: /sam", registry.usage, "\n", unpack(args)
end

local function JointToString(...)
	local text = ""
	for _, v in ipairs({ ... }) do
		text = text .. " " .. v
	end
	return text
end

function CommandsModule:PrintUsage(cmd)
	if (not cmd) then
		local text = "\nCommands:"
		for i, registry in pairs(Commands) do
			text = text .. "\n" .. "/sam " .. registry.usage
		end
		self:Print(text)
	else
		self:Print(self:UsageMessage(cmd))
	end
end

function CommandsModule:HandleCMD(msg)
	local command, nextPos = self:GetArgs(msg, 1)
	local commandRegistry = Commands[command]
	if (commandRegistry) then
		local numArgs = #commandRegistry.args or 0
		local args = { self:GetArgs(msg, numArgs, nextPos) }
		if (HasMissingParam(args, numArgs, commandRegistry)) then
			self:PrintUsage(command)
		else
			commandRegistry.func(unpack(args))
		end
	elseif (command == nil) then
		Commands.open.func()
	else
		self:PrintUsage()
	end
end
