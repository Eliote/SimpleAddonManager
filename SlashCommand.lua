local ADDON_NAME, T = ...
local L = T.L

--- @type SimpleAddonManager
local SAM = T.AddonFrame
local CommandsModule = {}
local Commands = {
	open = {
		usage = "open",
		args = {},
		func = function()
			SAM:Show()
		end,
	},
	profile = {
		usage = 'profile "Name" [OPTION]...',
		args = {
			{ desc = 'Name: Profile name', required = true },
			{
				desc = [==[Reload option (optional):
- ask: Show confirmation popup (default)
- reload: Reload the UI
- ignore: Apply changes without reload]==],
				required = false
			},
			{
				desc = [==[Load option (optional):
- load: Load the profile (default)
- enable: Enable all addons from the profile
- disable: Disable all addons from the profile]==],
				required = false
			},
		},
		func = function(profile, ...)
			local db = SAM:GetDb()
			if (not db.sets[profile]) then
				CommandsModule:Print(L("Profile '${profile}' not found!", { profile = profile }))
				return
			else
				local args = { ... }
				local reloadOptions = { "ask", "reload", "ignore" }
				local error, reloadType = CommandsModule:FindUniqueOptionInArgs(args, reloadOptions, "ask")
				if (error) then return CommandsModule:Print(reloadType) end

				local loadOptions = { "load", "enable", "disable" }
				local error, loadType = CommandsModule:FindUniqueOptionInArgs(args, loadOptions, "load")
				if (error) then return CommandsModule:Print(loadType) end

				if (loadType == "load") then
					if (reloadType == "ask") then
						SAM:GetModule("Profile"):ShowLoadProfileAndReloadUIDialog(profile)
					else
						SAM:GetModule("Profile"):LoadAddonsFromProfile(profile)
						if (reloadType == "reload") then
							ReloadUI()
						end
					end
				elseif (loadType == "enable") then
					if (reloadType == "ask") then
						SAM:ShowConfirmDialog(
								L("Enable addons from the profile '${profile}' and reload UI?", { profile = profile }),
								function()
									SAM:GetModule("Profile"):LoadAddonsFromProfile(profile, true)
									ReloadUI()
								end
						)
					else
						SAM:GetModule("Profile"):LoadAddonsFromProfile(profile, true)
						if (reloadType == "reload") then
							ReloadUI()
						end
					end
				elseif (loadType == "disable") then
					if (reloadType == "ask") then
						SAM:ShowConfirmDialog(
								L("Disable addons from the profile '${profile}' and reload UI?", { profile = profile }),
								function()
									SAM:GetModule("Profile"):UnloadAddonsFromProfile(profile)
									ReloadUI()
								end
						)
					else
						SAM:GetModule("Profile"):UnloadAddonsFromProfile(profile)
						if (reloadType == "reload") then
							ReloadUI()
						end
					end
				end
			end
		end,
	},
	category = {
		usage = 'category "name" [OPTION]...',
		args = {
			{ desc = 'Name: Category name', required = true },
			{
				desc = [==[Reload option (optional):
- ask: Show confirmation popup (default)
- reload: Reload the UI
- ignore: Apply changes without reload]==],
				required = false
			},
			{
				desc = [==[Load option (optional):
- enable: Enable all addons from the category
- disable: Disable all addons from the category]==],
				required = false
			},
		},
		func = function (category,...)
			local db = SAM:GetDb()
			if (not db.categories[category]) then
				CommandsModule:Print(L("Category '${category}' not found!", { category = category }))
				return
			else
				local args = { ... }
				local reloadOptions = { "ask", "reload", "ignore" }
				local error, reloadType = CommandsModule:FindUniqueOptionInArgs(args, reloadOptions, "ask")
				if (error) then return CommandsModule:Print(reloadType) end

				local loadOptions = {"enable", "disable" }
				local error, loadType = CommandsModule:FindUniqueOptionInArgs(args, loadOptions, "load")
				if (error) then return CommandsModule:Print(loadType) end

				if (loadType == "enable") then
					if (reloadType == "ask") then
						SAM:ShowConfirmDialog(
								L("Enable addons from the category '${category}' and reload UI?", { category = category }),
								function()
									SAM:GetModule("Category"):EnableCategory(category)
									ReloadUI()
								end
						)
					else
						SAM:GetModule("Category"):EnableCategory(category)
						if (reloadType == "reload") then
							ReloadUI()
						end
					end
				elseif (loadType == "disable") then
					if (reloadType == "ask") then
						SAM:ShowConfirmDialog(
								L("Disable addons from the category '${category}' and reload UI?", { category = category }),
								function()
									SAM:GetModule("Category"):DisableCategory(category)
									ReloadUI()
								end
						)
					else
						SAM:GetModule("Category"):DisableCategory(category)
						if (reloadType == "reload") then
							ReloadUI()
						end
					end
				end
			end
		end
	},
}

LibStub("AceConsole-3.0"):Embed(CommandsModule)

setmetatable(CommandsModule, {
	__tostring = function()
		return (SAM:GetAddOnMetadata(ADDON_NAME, "Title"))
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

function CommandsModule:FindUniqueOptionInArgs(args, options, default)
	local found
	local optionsMap = {}
	for _, option in ipairs(options) do
		optionsMap[option] = true
	end
	for _, arg in ipairs(args) do
		if (optionsMap[arg]) then
			if (found) then
				return true, L("(Duplicated option) You should only use one: ${a} ${b}", {a = found, b = arg})
			end
			found = arg
		end
	end
	return false, found or default
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
