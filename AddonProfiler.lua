local _, T = ...
local L = T.L
local C = T.Color

--- @type SimpleAddonManager
local SAM = T.AddonFrame
local module = SAM:RegisterModule("AddonProfiler", "AddonList", "Category")

local function FormatProfilerPercent(pct)
	local color = C.white
	if (pct > 50) then color = C.yellow end
	if (pct > 80) then color = C.red end
	return color:WrapText(string.format("%.2f", pct)) .. C.white:WrapText("%")
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

local function MovePoint(frame, point, x, y)
	local _, relativeTo, relativePoint, offsetX, offsetY = frame:GetPointByName(point)
	frame:SetPoint(point, relativeTo, relativePoint, offsetX + x, offsetY + y)
end

function module:GetOverallMetricPercent(metric)
	if (not C_AddOnProfiler or not C_AddOnProfiler.IsEnabled()) then
		return ""
	end
	local app = C_AddOnProfiler.GetApplicationMetric(metric)
	if app <= 0 then
		return FormatProfilerPercent(0)
	end
	local overall = C_AddOnProfiler.GetOverallMetric(metric)
	local percent = overall / app
	return FormatProfilerPercent(percent * 100.0) .. GetWarningFor(percent)
end

function module:GetAddonMetricPercent(addonName, metric)
	if (not C_AddOnProfiler or not C_AddOnProfiler.IsEnabled()) then
		return ""
	end
	local overall = C_AddOnProfiler.GetOverallMetric(metric)
	local addon = C_AddOnProfiler.GetAddOnMetric(addonName, metric)
	local relative = overall
	if (C_AddOnProfiler.GetApplicationMetric) then
		local app = C_AddOnProfiler.GetApplicationMetric(metric)
		relative = app - overall + addon
	end
	if relative <= 0 then
		return ""
	end
	local percent = addon / relative
	return FormatProfilerPercent(percent * 100.0) .. GetWarningFor(percent)
end

function module:UpdateCPU()
	if (not module:CanShow()) then return end
	SAM.ProfilerFrame.CurrentCPU:SetText(
			C.yellow:WrapText(L["CPU: "]) .. module:GetOverallMetricPercent(Enum.AddOnProfilerMetric.RecentAverageTime)
	)
	SAM.ProfilerFrame.AverageCPU:SetText(
			C.yellow:WrapText(L["Average CPU: "]) .. module:GetOverallMetricPercent(Enum.AddOnProfilerMetric.SessionAverageTime)
	)
	SAM.ProfilerFrame.PeakCPU:SetText(
			C.yellow:WrapText(L["Peak CPU: "]) .. module:GetOverallMetricPercent(Enum.AddOnProfilerMetric.PeakTime)
	)
end

local timeElapsed = 0
function module:OnUpdate(elapsed)
	timeElapsed = timeElapsed + elapsed
	if (timeElapsed > 0.5) then
		timeElapsed = 0
		module:UpdateCPU()
	end
end

function module:CanShow()
	return C_AddOnProfiler and C_AddOnProfiler.IsEnabled() and C_AddOnProfiler.GetApplicationMetric
end

function module:PreInitialize()
	SAM.ProfilerFrame = CreateFrame("Frame", nil, SAM)
	SAM.ProfilerFrame.Divider = SAM.ProfilerFrame:CreateTexture(nil, "ARTWORK")
	SAM.ProfilerFrame.CurrentCPU = SAM.ProfilerFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	SAM.ProfilerFrame.AverageCPU = SAM.ProfilerFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	SAM.ProfilerFrame.PeakCPU = SAM.ProfilerFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite")
end

local profilerSizeFrame = 30

function module:Initialize()
	SAM.ProfilerFrame:SetPoint("TOPLEFT", 12, -64)
	SAM.ProfilerFrame:SetPoint("TOPRIGHT", SAM.ScrollFrame, "TOPRIGHT")
	SAM.ProfilerFrame:SetHeight(profilerSizeFrame)
	SAM.ProfilerFrame:SetScript("OnUpdate", module.OnUpdate)

	SAM.ProfilerFrame.Divider:SetAtlas("Options_HorizontalDivider", true)
	SAM.ProfilerFrame.Divider:SetPoint("BOTTOMLEFT", SAM.ProfilerFrame, "BOTTOMLEFT", 10, 4)
	SAM.ProfilerFrame.Divider:SetPoint("BOTTOMRIGHT", SAM.ProfilerFrame, "BOTTOMRIGHT", -10, 4)

	SAM.ProfilerFrame.CurrentCPU:SetPoint("LEFT", 8, 2)
	SAM.ProfilerFrame.AverageCPU:SetPoint("CENTER", 0, 2)
	SAM.ProfilerFrame.PeakCPU:SetPoint("RIGHT", -8, 2)

	module:UpdateCPU()
end

local movedFrames = false

function module:OnShow()
	if (module:CanShow()) then
		SAM.ProfilerFrame:SetScript("OnUpdate", module.OnUpdate)
		if (not movedFrames) then
			MovePoint(SAM.ScrollFrame, "TOPLEFT", 0, -profilerSizeFrame)
			MovePoint(SAM.ScrollFrame.ScrollBar, "TOPLEFT", 0, profilerSizeFrame)
			MovePoint(SAM.CategoryFrame, "TOPLEFT", 0, profilerSizeFrame)
			movedFrames = true
		end
		SAM.ProfilerFrame:Show()
	else
		SAM.ProfilerFrame:SetScript("OnUpdate", nil)
		SAM.ProfilerFrame:Hide()
		if (movedFrames) then
			MovePoint(SAM.ScrollFrame, "TOPLEFT", 0, profilerSizeFrame)
			MovePoint(SAM.ScrollFrame.ScrollBar, "TOPLEFT", 0, -profilerSizeFrame)
			MovePoint(SAM.CategoryFrame, "TOPLEFT", 0, -profilerSizeFrame)
			movedFrames = false
		end
	end
end
