local _, T = ...

local function CreateColor(hex)
	local color = CreateColorFromHexString(hex)
	color.WrapText = color.WrapTextInColorCode
	return color
end

T.Color = {
	red = CreateColor("FFFF1919"),
	green = CreateColor("FF19FF19"),
	yellow = CreateColor("FFFFC700"),
	orange = CreateColor("FFFFA700"),
	white = CreateColor("FFFFFFFF"),
	grey = CreateColor("FF808080"),
}