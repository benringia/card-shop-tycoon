--!strict
-- The level pill's XP (owner 2026-11-03, round 3 pick B "big number, thin bar"; spec 2026-11-03-windows-round3-design):
-- the XP into this level big and exact, the level's total small after it, a count-up when it changes. Pure,
-- Lune-tested.
local XpPill = {}

-- 1234567 -> "1,234,567"
local function withCommas(n: number): string
	local text = tostring(math.floor(math.max(0, n)))
	local grouped = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	return (string.gsub(grouped, "^,", ""))
end

-- "99,800 XP"; "MAX" at the top level (a span of 0 or less)
function XpPill.amount(into: number, span: number): string
	if span <= 0 then
		return "MAX"
	end
	return `{withCommas(into)} XP`
end

-- "/ 226,000"; nothing at the top level
function XpPill.total(span: number): string
	if span <= 0 then
		return ""
	end
	return `/ {withCommas(span)}`
end

-- The number shown `t` (0-1) of the way through a count from `from` to `to`: eased out, whole numbers, never past `to`
function XpPill.countUp(from: number, to: number, t: number): number
	local progress = math.clamp(t, 0, 1)
	local eased = 1 - (1 - progress) ^ 3
	local shown = from + (to - from) * eased
	if progress >= 1 then
		return to
	end
	return if to >= from then math.min(math.floor(shown), to) else math.max(math.ceil(shown), to)
end

return XpPill
