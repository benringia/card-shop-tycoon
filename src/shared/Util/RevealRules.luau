--!strict
-- How big a card's reveal is, from its rarity, foil and set (pure, Lune-tested). Config: Config/CardReveal.
export type Plan = {
	tease: number,
	shake: number,
	dim: number,
	rays: boolean,
	flash: boolean,
	spotlight: boolean,
	burst: number,
	confetti: number,
	banner: string?,
}

export type RevealConfig = {
	BY_RARITY: { [string]: Plan },
	FRONTIER: Plan,
	FOIL: { MIN_TEASE: number, EXTRA_BURST: number, PREFIX: string },
}

local RevealRules = {}

function RevealRules.plan(config: RevealConfig, rarity: string, foil: boolean, frontier: boolean): Plan
	local tier = if frontier then config.FRONTIER else (config.BY_RARITY[rarity] or config.BY_RARITY.Common)
	local plan = table.clone(tier)
	if not foil then
		return plan
	end
	plan.tease = math.max(plan.tease, config.FOIL.MIN_TEASE)
	plan.burst += config.FOIL.EXTRA_BURST
	plan.banner = if plan.banner then config.FOIL.PREFIX .. plan.banner else (string.gsub(config.FOIL.PREFIX, "%s+$", "")) .. "!"
	return plan
end

return RevealRules
