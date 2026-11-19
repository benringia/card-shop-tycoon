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

local RANK = { Common = 1, Rare = 2, ["Very Rare"] = 3, Epic = 4, Legendary = 5 }

-- Whether a pulled card stands out among many (Open 10's best pulls, owner 2026-11-17): `from` or better
function RevealRules.standsOut(rarity: string, from: string): boolean
	local rank = RANK[rarity]
	return rank ~= nil and rank >= (RANK[from] or math.huge)
end

-- Whether a card's creature bursts out of it on the stage (Config/CardReveal CREATURE): an Epic, a Legendary, a Frontier
-- card or a card the player never had. `ready` false: its model isn't fully downloaded yet (a new player's first
-- packs), so it stays in its card rather than show rough (owner 2026-11-19); nil: not asked
function RevealRules.comesAlive(rarity: string, isNew: boolean, frontier: boolean, ready: boolean?): boolean
	if ready == false then
		return false
	end
	return isNew or frontier or (RANK[rarity] or 0) >= RANK.Epic
end

-- Whether a card tears the sky as it's revealed (Config/CardReveal SKY_TEAR; owner 2026-11-18, pick C): a Legendary,
-- foil or not, in Open 1 and Open 10
function RevealRules.tearsSky(rarity: string, sky: { rarity: string }): boolean
	return rarity == sky.rarity
end

-- Whether a pack trembles before the tear (Config/CardReveal PACK_TELL): its best card is `rarity` or better, or a Very
-- Rare when `roll` (0-1) falls under `fakeOut`
function RevealRules.packTell(tell: { rarity: string, fakeOut: number }, rarities: { string }, roll: number): boolean
	local best = 0
	for _, rarity in rarities do
		best = math.max(best, RANK[rarity] or 0)
	end
	if best >= (RANK[tell.rarity] or math.huge) then
		return true
	end
	return best == RANK["Very Rare"] and roll < tell.fakeOut
end

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
