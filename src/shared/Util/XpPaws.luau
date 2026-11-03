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

-- A number short enough for the pill: 640, 9.6k, 90k, 1.5M, 12M (no ".0", never negative)
function XpPaws.short(n: number): string
	local value = math.max(0, n)
	local function trimmed(x: number, unit: string): string
		local text = string.format("%.1f", x)
		text = string.gsub(text, "%.0$", "")
		return text .. unit
	end
	if value < 1000 then
		return tostring(math.floor(value))
	elseif value < 10000 then
		return trimmed(value / 1000, "k")
	elseif value < 1000000 then
		return `{math.round(value / 1000)}k`
	elseif value < 10000000 then
		return trimmed(value / 1000000, "M")
	end
	return `{math.round(value / 1000000)}M`
end

-- The XP line under the paws (owner 2026-11-03: the numbers in view, not in a tooltip): "90k / 226k", "MAX" at the top
function XpPaws.label(into: number, span: number): string
	if span <= 0 then
		return "MAX"
	end
	return `{XpPaws.short(into)} / {XpPaws.short(span)}`
end

return XpPaws
