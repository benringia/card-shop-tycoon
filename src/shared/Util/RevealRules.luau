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
	banner: string?,
	shards: number,
	goldShards: boolean,
	cinematic: boolean,
	alive: boolean,
	glintRate: number,
	moteRate: number,
	tilt: number,
	holo: boolean?, -- a foil card: a holo shimmer runs over its face (set by plan; the config tiers leave it out)
}

export type RevealConfig = {
	BY_RARITY: { [string]: Plan },
	FRONTIER: Plan,
	FOIL: { MIN_TEASE: number, EXTRA_BURST: number, PREFIX: string },
}

local RevealRules = {}

function RevealRules.plan(config: RevealConfig, rarity: string, foil: boolean, frontier: boolean): Plan
	local tier = if frontier then config.FRONTIER else (config.BY_RARITY[rarity] or config.BY_RARITY.Common)
	local plan = table.clone(tier) :: Plan
	plan.holo = foil
	if not foil then
		return plan
	end
	plan.tease = math.max(plan.tease, config.FOIL.MIN_TEASE)
	plan.burst += config.FOIL.EXTRA_BURST
	plan.banner = if plan.banner then config.FOIL.PREFIX .. plan.banner else (string.gsub(config.FOIL.PREFIX, "%s+$", "")) .. "!"
	return plan
end

-- An effect's particle count for the player's graphics level (UserGameSettings.SavedQualityLevel: 1-10, 0 =
-- Automatic): a quarter at level 1 rising to all of it from level 6; never none when there was some
function RevealRules.scaleCount(count: number, quality: number): number
	if count <= 0 then
		return 0
	end
	local share = if quality <= 0 then 1 else math.clamp(0.25 + (quality - 1) / 5 * 0.75, 0.25, 1)
	return math.max(1, math.floor(count * share + 0.5))
end

return RevealRules
