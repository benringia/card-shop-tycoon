--!strict
-- The soft colour filter's sums (Config/SoftFilter). Pure, Lune-tested.
local SoftFilter = {}

export type Config = { ON: boolean, saturation: number, contrast: number, FLOOR: number }

-- A look's saturation and contrast with the filter on top: calmer, never under the floor because of it (a look that
-- is under it on purpose stays as it is)
function SoftFilter.grade(saturation: number, contrast: number, cfg: Config): (number, number)
	if not cfg.ON then
		return saturation, contrast
	end
	local floor = math.min(saturation, cfg.FLOOR)
	return math.max(saturation + cfg.saturation, floor), contrast + cfg.contrast
end

return SoftFilter
