--!strict
-- The cotton candy buttons' colour rules (spec 2026-11-03-cotton-candy-ui-design), on { r, g, b } lists of 0-255.
-- Pure, Lune-tested (tests/SoftColors); callers pass Config/BabyColors in.
local SoftColors = {}

export type Shades = { fill: { number }, light: { number }, deep: { number } }

local DARKEN = 0.35 -- a colour of its own (not a baby colour) gets a deep shade this much darker

local function same(a: { number }, b: { number }): boolean
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

-- Plum text on light fills (butter, white), white text everywhere else
function SoftColors.textOn(fill: { number }, lightLuma: number): "ink" | "white"
	local luma = (0.299 * fill[1] + 0.587 * fill[2] + 0.114 * fill[3]) / 255
	return if luma > lightLuma then "ink" else "white"
end

-- The deep shade under a fill: its baby colour's own, else the fill darkened
function SoftColors.deepOf(fill: { number }, colors: { [string]: Shades }): { number }
	for _, shades in colors do
		if same(shades.fill, fill) then
			return shades.deep
		end
	end
	return { fill[1] * (1 - DARKEN), fill[2] * (1 - DARKEN), fill[3] * (1 - DARKEN) }
end

return SoftColors
