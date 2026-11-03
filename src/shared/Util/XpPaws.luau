--!strict
-- The level pill's XP paws (spec 2026-11-03-hud-creature-pals-design): `count` paw prints fill left to right with
-- progress through the level, each one gradually. Pure, Lune-tested.
local XpPaws = {}

-- Each paw's fill, 0-1, for `into` XP of a level that takes `span`; a span of 0 or less (the top level) fills them all
function XpPaws.fills(into: number, span: number, count: number): { number }
	local progress = if span <= 0 then count else math.clamp(into / span, 0, 1) * count
	local fills = table.create(count, 0)
	for index = 1, count do
		fills[index] = math.clamp(progress - (index - 1), 0, 1)
	end
	return fills
end

return XpPaws
