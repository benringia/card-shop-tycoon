--!strict
-- A title's gradient (Config/Titles `gradient`): its colours spread evenly left to right. Two for most titles,
-- Creator's rainbow has five (spec 2026-11-27-live-admin-creator-design). Used by the name tag (TitleController) and
-- the character window's Titles tab (CharacterController).
local TitleGradient = {}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

function TitleGradient.sequence(colors: { { number } }): ColorSequence
	if #colors < 2 then
		return ColorSequence.new(rgb(colors[1]))
	end
	local points = {}
	for index, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), rgb(color)))
	end
	return ColorSequence.new(points)
end

return TitleGradient
