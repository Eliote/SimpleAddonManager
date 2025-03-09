local _, T = ...
local L = T.L
local C = T.Color

--- @type SimpleAddonManager
local SAM = T.AddonFrame
local module = SAM:RegisterModule("AddonProfiler", "AddonList", "Category")
SAM.AddonProfiler = module

module.IconCurrent = CreateSimpleTextureMarkup([[Interface\AddOns\SimpleAddonManager\Icons\current]], 16, 16)
module.IconAverage = CreateSimpleTextureMarkup([[Interface\AddOns\SimpleAddonManager\Icons\average]], 16, 16)
module.IconEncounter = CreateSimpleTextureMarkup([[Interface\AddOns\SimpleAddonManager\Icons\weapon]], 16, 16)
module.IconPeak = CreateSimpleTextureMarkup([[Interface\AddOns\SimpleAddonManager\Icons\peak]], 16, 16)

local function FormatProfilerPercent(pct)
	local color = C.white
	if (pct > 25) then color = C.yellow end
	if (pct > 50) then color = C.orange end
	if (pct > 80) then color = C.red end
	return color:WrapText(string.format("%.2f", pct)) .. C.white:WrapText("%")
end

local function FormatProfilerCount(count)
	local color = C.white
	return color:WrapText(count)
end

local function GetCVarNumber(name)
	-- if the CVar doesn't exist, the GetCVar returns "nothing" (not even nil) and the tonumber fails
	local number = tonumber(GetCVar(name) or nil)
	return number or tonumber(GetCVarDefault(name) or nil)
end

local function GetWarningFor(percent)
	local warningPercent = GetCVarNumber("addonPerformanceMsgWarning") or -1
	if (warningPercent > 0.0 and warningPercent < 1.0 and percent > warningPercent) then
		return " " .. CreateSimpleTextureMarkup([[Interface\DialogFrame\DialogIcon-AlertNew-16]], 16, 16)
	end
	return ""
end

function module:GetOverallMetricPercent(metric, def)
	if (not C_AddOnProfiler or not C_AddOnProfiler.IsEnabled()) then
		return ""
	end
	local app = C_AddOnProfiler.GetApplicationMetric and C_AddOnProfiler.GetApplicationMetric(metric) or 0
	if app <= 0 then
		return def or FormatProfilerPercent(0)
	end
	local overall = C_AddOnProfiler.GetOverallMetric(metric)
	local percent = overall / app
	return FormatProfilerPercent(percent * 100.0) .. GetWarningFor(percent)
end

function module:GetAddonMetricPercent(addonName, metric, warningInLeftSide, def)
	if (not C_AddOnProfiler or not C_AddOnProfiler.IsEnabled()) then
		return def or ""
	end
	local overall = C_AddOnProfiler.GetOverallMetric(metric)
	local addon = C_AddOnProfiler.GetAddOnMetric(addonName, metric)
	local relative = overall
	if (C_AddOnProfiler.GetApplicationMetric) then
		local app = C_AddOnProfiler.GetApplicationMetric(metric)
		relative = app - overall + addon
	end
	if relative <= 0 then
		return def or ""
	end
	local percent = addon / relative
	if (warningInLeftSide) then
		return GetWarningFor(percent) .. FormatProfilerPercent(percent * 100.0)
	end
	return FormatProfilerPercent(percent * 100.0) .. GetWarningFor(percent)
end

function module:GetAddonMetricCount(addonName, metric)
	if (not C_AddOnProfiler or not C_AddOnProfiler.IsEnabled()) then
		return ""
	end
	local count = C_AddOnProfiler.GetAddOnMetric(addonName, metric) or 0
	return FormatProfilerCount(count)
end

function module:UpdateCPU()
	if (not module:CanShow()) then return end
	SAM.ProfilerFrame.CurrentCPU:SetText(
			module:GetOverallMetricPercent(Enum.AddOnProfilerMetric.RecentAverageTime)
	)
	SAM.ProfilerFrame.AverageCPU:SetText(
			module:GetOverallMetricPercent(Enum.AddOnProfilerMetric.SessionAverageTime)
	)
	SAM.ProfilerFrame.EncounterCPU:SetText(
			module:GetOverallMetricPercent(Enum.AddOnProfilerMetric.EncounterAverageTime, "--")
	)
	SAM.ProfilerFrame.PeakCPU:SetText(
			module:GetOverallMetricPercent(Enum.AddOnProfilerMetric.PeakTime)
	)
end

local function EnableTicker()
	module:UpdateProfilingTickerPeriod(SAM:GetDb().config.profiling.cpuUpdate)
end

local function DisableTicker()
	module:UpdateProfilingTickerPeriod(0)
end

function module:UpdateProfilingTickerPeriod(period)
	if (module.CpuUpdateTicker) then
		module.CpuUpdateTicker:Cancel()
		module.CpuUpdateTicker = nil
	end
	if (period > 0) then
		module.CpuUpdateTicker = C_Timer.NewTicker(period, function()
			module:UpdateCPU()
			SAM.AddonList:UpdateTooltip()
			if (SAM:GetDb().config.sortingCpu) then
				SAM:UpdateListFilters()
			else
				SAM.AddonListFrame.ScrollFrame.update()
			end
		end)
	end
end

function module:IsProfilerEnabled()
	return C_AddOnProfiler and C_AddOnProfiler.IsEnabled() and SAM:GetDb().config.profiling.cpuUpdate > 0
end

function module:CanShow()
	return C_AddOnProfiler and C_AddOnProfiler.IsEnabled() and C_AddOnProfiler.GetApplicationMetric and SAM:GetDb().config.profiling.cpuUpdate > 0
end

function module:PreInitialize()
	SAM.ProfilerFrame = CreateFrame("Frame", nil, SAM)

	SAM.ProfilerFrame.Divider = SAM.ProfilerFrame:CreateTexture(nil, "ARTWORK")

	SAM.ProfilerFrame.Left = CreateFrame("Frame", nil, SAM.ProfilerFrame)
	SAM.ProfilerFrame.Right = CreateFrame("Frame", nil, SAM.ProfilerFrame)

	SAM.ProfilerFrame.Left.CurrentCPUButton = CreateFrame("Button", nil, SAM.ProfilerFrame.Left)
	SAM.ProfilerFrame.Left.AverageCPUButton = CreateFrame("Button", nil, SAM.ProfilerFrame.Left)
	SAM.ProfilerFrame.Right.EncounterCPUButton = CreateFrame("Button", nil, SAM.ProfilerFrame.Right)
	SAM.ProfilerFrame.Right.PeakCPUButton = CreateFrame("Button", nil, SAM.ProfilerFrame.Right)

	SAM.ProfilerFrame.Left.CurrentCPUButton.Label = SAM.ProfilerFrame.Left.CurrentCPUButton:CreateFontString(nil, "ARTWORK", "GameFontNormalTiny")
	SAM.ProfilerFrame.Left.AverageCPUButton.Label = SAM.ProfilerFrame.Left.AverageCPUButton:CreateFontString(nil, "ARTWORK", "GameFontNormalTiny")
	SAM.ProfilerFrame.Right.EncounterCPUButton.Label = SAM.ProfilerFrame.Right.EncounterCPUButton:CreateFontString(nil, "ARTWORK", "GameFontNormalTiny")
	SAM.ProfilerFrame.Right.PeakCPUButton.Label = SAM.ProfilerFrame.Right.PeakCPUButton:CreateFontString(nil, "ARTWORK", "GameFontNormalTiny")

	SAM.ProfilerFrame.CurrentCPU = SAM.ProfilerFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	SAM.ProfilerFrame.AverageCPU = SAM.ProfilerFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	SAM.ProfilerFrame.EncounterCPU = SAM.ProfilerFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	SAM.ProfilerFrame.PeakCPU = SAM.ProfilerFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite")
end

local function OrderIconFor(field)
	if (SAM:GetDb().config.sortingCpu == field) then
		return " " .. CreateAtlasMarkup("dropdown-hover-arrow", 10, 10)
	end
	return ""
end

local function UpdateLabels()
	SAM.ProfilerFrame.Left.CurrentCPUButton.Label:SetText(module.IconCurrent .. " " .. L["Current CPU"] .. OrderIconFor("current"))
	SAM.ProfilerFrame.Left.AverageCPUButton.Label:SetText(module.IconAverage .. " " .. L["Average CPU"] .. OrderIconFor("average"))
	SAM.ProfilerFrame.Right.EncounterCPUButton.Label:SetText(module.IconEncounter .. " " .. L["Encounter CPU"] .. OrderIconFor("encounter"))
	SAM.ProfilerFrame.Right.PeakCPUButton.Label:SetText(module.IconPeak .. " " .. L["Peak CPU"] .. OrderIconFor("peak"))
end

local function OnClickCpuLabel(self)
	local field = self.sort
	local current = SAM:GetDb().config.sortingCpu
	if (field == current) then
		SAM:GetDb().config.sortingCpu = false
	else
		SAM:GetDb().config.sortingCpu = field
	end
	UpdateLabels()
	SAM:Update()
end

local profilerSizeFrame = 36

function module:Initialize()
	SAM.ProfilerFrame:Hide()
	--SAM.ProfilerFrame:SetScript("OnShow", OnShow)
	--SAM.ProfilerFrame:SetScript("OnHide", OnHide)
	SAM.ProfilerFrame:SetPoint("TOPLEFT", SAM.AddonListFrame, "TOPLEFT", 0, -2)
	SAM.ProfilerFrame:SetPoint("TOPRIGHT", SAM.AddonListFrame, "TOPRIGHT", -18, -2)
	SAM.ProfilerFrame:SetHeight(profilerSizeFrame)

	SAM.ProfilerFrame.Divider:SetAtlas("Options_HorizontalDivider", true)
	SAM.ProfilerFrame.Divider:SetPoint("BOTTOMLEFT", SAM.ProfilerFrame, "BOTTOMLEFT", 10, 4)
	SAM.ProfilerFrame.Divider:SetPoint("BOTTOMRIGHT", SAM.ProfilerFrame, "BOTTOMRIGHT", -10, 4)

	SAM.ProfilerFrame.Left:SetPoint("TOPLEFT", 8, -1)
	SAM.ProfilerFrame.Left:SetPoint("BOTTOMRIGHT", SAM.ProfilerFrame, "BOTTOM", 0, 8)
	SAM.ProfilerFrame.Right:SetPoint("TOPLEFT", SAM.ProfilerFrame, "TOP", 0, -1)
	SAM.ProfilerFrame.Right:SetPoint("BOTTOMRIGHT", -8, 8)

	local titleHeight = 13
	SAM.ProfilerFrame.Left.CurrentCPUButton:SetPoint("TOPLEFT", SAM.ProfilerFrame.Left)
	SAM.ProfilerFrame.Left.CurrentCPUButton:SetPoint("BOTTOMRIGHT", SAM.ProfilerFrame.Left, "BOTTOM")
	SAM.ProfilerFrame.Left.CurrentCPUButton:SetHighlightAtlas("voicechat-channellist-row-highlight", "ADD")
	SAM.ProfilerFrame.Left.CurrentCPUButton:SetScript("OnClick", OnClickCpuLabel)
	SAM.ProfilerFrame.Left.CurrentCPUButton.sort = "current"

	SAM.ProfilerFrame.Left.AverageCPUButton:SetPoint("TOPLEFT", SAM.ProfilerFrame.Left, "TOP")
	SAM.ProfilerFrame.Left.AverageCPUButton:SetPoint("BOTTOMRIGHT", SAM.ProfilerFrame.Left)
	SAM.ProfilerFrame.Left.AverageCPUButton:SetHighlightAtlas("voicechat-channellist-row-highlight", "ADD")
	SAM.ProfilerFrame.Left.AverageCPUButton:SetScript("OnClick", OnClickCpuLabel)
	SAM.ProfilerFrame.Left.AverageCPUButton.sort = "average"

	SAM.ProfilerFrame.Right.EncounterCPUButton:SetPoint("TOPLEFT", SAM.ProfilerFrame.Right)
	SAM.ProfilerFrame.Right.EncounterCPUButton:SetPoint("BOTTOMRIGHT", SAM.ProfilerFrame.Right, "BOTTOM")
	SAM.ProfilerFrame.Right.EncounterCPUButton:SetHighlightAtlas("voicechat-channellist-row-highlight", "ADD")
	SAM.ProfilerFrame.Right.EncounterCPUButton:SetScript("OnClick", OnClickCpuLabel)
	SAM.ProfilerFrame.Right.EncounterCPUButton.sort = "encounter"

	SAM.ProfilerFrame.Right.PeakCPUButton:SetPoint("TOPLEFT", SAM.ProfilerFrame.Right, "TOP")
	SAM.ProfilerFrame.Right.PeakCPUButton:SetPoint("BOTTOMRIGHT", SAM.ProfilerFrame.Right)
	SAM.ProfilerFrame.Right.PeakCPUButton:SetHighlightAtlas("voicechat-channellist-row-highlight", "ADD")
	SAM.ProfilerFrame.Right.PeakCPUButton:SetScript("OnClick", OnClickCpuLabel)
	SAM.ProfilerFrame.Right.PeakCPUButton.sort = "peak"

	SAM.ProfilerFrame.Left.CurrentCPUButton.Label:SetPoint("TOP")
	SAM.ProfilerFrame.Left.AverageCPUButton.Label:SetPoint("TOP")
	SAM.ProfilerFrame.Right.EncounterCPUButton.Label:SetPoint("TOP")
	SAM.ProfilerFrame.Right.PeakCPUButton.Label:SetPoint("TOP")

	UpdateLabels()

	SAM.ProfilerFrame.CurrentCPU:SetPoint("TOP", SAM.ProfilerFrame.Left.CurrentCPUButton, "TOP", 0, -titleHeight)
	SAM.ProfilerFrame.AverageCPU:SetPoint("TOP", SAM.ProfilerFrame.Left.AverageCPUButton, "TOP", 0, -titleHeight)
	SAM.ProfilerFrame.EncounterCPU:SetPoint("TOP", SAM.ProfilerFrame.Right.EncounterCPUButton, "TOP", 0, -titleHeight)
	SAM.ProfilerFrame.PeakCPU:SetPoint("TOP", SAM.ProfilerFrame.Right.PeakCPUButton, "TOP", 0, -titleHeight)

	SAM.AddonListFrame.ScrollFrame:SetPoint("TOPLEFT", SAM.ProfilerFrame, "BOTTOMLEFT")

	module:UpdateCPU()
end

function module:OnShow()
	SAM.AddonListFrame.ScrollFrame:SetPoint("TOPLEFT")
	SAM.ProfilerFrame:Hide()

	if (module:CanShow()) then
		SAM.AddonListFrame.ScrollFrame:SetPoint("TOPLEFT", SAM.ProfilerFrame, "BOTTOMLEFT")
		SAM.ProfilerFrame:Show()
	end

	if (C_AddOnProfiler and C_AddOnProfiler.IsEnabled()) then
		EnableTicker()
	end
end

function module:OnHide()
	DisableTicker()
end

function module:OnLoad()
	local db = SAM:GetDb()
	SAM:CreateDefaultOptions(db.config, {
		profiling = {
			cpuUpdate = 1.0,
			cpuShowCurrent = true,
			cpuShowAverage = false,
			cpuShowPeak = false,
			cpuShowEncounter = false,
		}
	})
end