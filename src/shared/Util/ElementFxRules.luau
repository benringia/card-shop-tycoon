--!strict
-- How strong a card's element effect is, from its grade and stars (pure, Lune-tested). Config: Config/ElementFx.
export type IntensityConfig = { BASE: number, GRADE: { [string]: number }, PER_STAR: number, MAX_STARS: number }

local ElementFxRules = {}

-- 0..1: Grade C with no stars is BASE; better grades and more stars add up to 1 (Grade S, every star)
function ElementFxRules.intensity(config: IntensityConfig, grade: string, stars: number): number
	local starCount = math.clamp(stars, 0, config.MAX_STARS)
	return math.clamp(config.BASE + (config.GRADE[grade] or 0) + config.PER_STAR * starCount, 0, 1)
end

-- A { low, high } config pair at this intensity
function ElementFxRules.at(range: { number }, intensity: number): number
	return range[1] + (range[2] - range[1]) * intensity
end

return ElementFxRules
