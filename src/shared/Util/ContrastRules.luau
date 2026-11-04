--!strict
-- Text contrast (WCAG 2): how well one colour reads on another, from their relative luminance. Colours are { r, g, b }
-- lists of 0-255. Config/CreamTheme is checked with it (spec 2026-11-03-cream-windows-design). Pure, Lune-tested.
local ContrastRules = {}

local function channel(value: number): number
	local c = value / 255
	return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

-- Relative luminance, 0 (black) to 1 (white)
function ContrastRules.luminance(rgb: { number }): number
	return 0.2126 * channel(rgb[1]) + 0.7152 * channel(rgb[2]) + 0.0722 * channel(rgb[3])
end

-- The contrast ratio of two colours, 1 (the same) to 21 (black on white), whichever way round
function ContrastRules.ratio(a: { number }, b: { number }): number
	local la, lb = ContrastRules.luminance(a), ContrastRules.luminance(b)
	local light, dark = math.max(la, lb), math.min(la, lb)
	return (light + 0.05) / (dark + 0.05)
end

-- The colour's angle on the colour wheel, 0-360 (red 0, yellow 60, green 120, blue 240): colours that mean different
-- things must sit far enough apart to tell at a glance, even when they're all dark enough to read
function ContrastRules.hue(rgb: { number }): number
	local r, g, b = rgb[1] / 255, rgb[2] / 255, rgb[3] / 255
	local high, low = math.max(r, g, b), math.min(r, g, b)
	local span = high - low
	if span == 0 then
		return 0 -- a grey has no hue
	end
	local angle = if high == r then ((g - b) / span) % 6 elseif high == g then (b - r) / span + 2 else (r - g) / span + 4
	return angle * 60
end

return ContrastRules
