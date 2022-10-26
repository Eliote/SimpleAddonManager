local _, T = ...

local function WrapText(self, text)
	return WrapTextInColor(text, self)
end

local function CreateColor(hex)
	local color = CreateColorFromHexString(hex)
	color.WrapText = WrapText
	return color
end

T.Color = {
	red = CreateColor("FFFF1919"),
	green = CreateColor("FF19FF19"),
	yellow = CreateColor("FFFFC700"),
	white = CreateColor("FFFFFFFF"),
}