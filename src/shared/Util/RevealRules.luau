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
RevealRules.RANK = RANK -- shared, so Open 50's best pulls (BulkOpenController) rank with the same order

-- Whether a card gets the Frontier show (Config/CardReveal FRONTIER, Legendary-sized): a Frontier card turning up
-- outside its own pack. A Frontier Pack (owner 2026-11-23, pick B; Config/Packs `set`, none = First Spark) holds only
-- Frontier cards, so there each reveals by its rarity
function RevealRules.frontierShow(cardSet: string?, packSet: string?): boolean
	return cardSet == "Frontier" and packSet ~= "Frontier"
end

-- Whether a pulled card stands out among many (Open 10's best pulls, owner 2026-11-17): `from` or better
function RevealRules.standsOut(rarity: string, from: string): boolean
	local rank = RANK[rarity]
	return rank ~= nil and rank >= (RANK[from] or math.huge)
end

-- Whether a bulk opening's reveal can be cut short by a tap (Robux round, spec 2026-11-28-robux-round-design; owner:
-- Open 10 "unskippable", only Open 50 skippable): more packs than Open 10's
function RevealRules.skippable(packs: number, openMany: number): boolean
	return packs > openMany
end

-- Open 50's grid (Quick Open): the pulls `from` and up, best rarity first (ties in pull order), at most `limit` of them;
-- also how many were below `from` (straight to the binder) and how many best pulls the cap left out
function RevealRules.bestPulls(rarities: { string }, from: string, rank: { [string]: number }, limit: number): ({ number }, number, number)
	local bar = rank[from] or math.huge
	local picks: { number } = {}
	local below = 0
	for index, rarity in rarities do
		if (rank[rarity] or 0) >= bar then
			table.insert(picks, index)
		else
			below += 1
		end
	end
	table.sort(picks, function(a: number, b: number): boolean
		local rankA, rankB = rank[rarities[a]] or 0, rank[rarities[b]] or 0
		if rankA ~= rankB then
			return rankA > rankB
		end
		return a < b
	end)
	local over = math.max(0, #picks - limit)
	for _ = 1, over do
		table.remove(picks)
	end
	return picks, below, over
end

-- Whether a card's creature bursts out of it on the stage (Config/CardReveal CREATURE): an Epic, a Legendary, a Frontier
-- card or a card the player never had. `ready` false: its model isn't fully downloaded yet (a new player's first
-- packs), so it stays in its card rather than show rough (owner 2026-11-19); nil: not asked. `on` false: creature
-- models are switched off in pack openings (owner 2026-11-20; Config/CardReveal CREATURE.on): never
function RevealRules.comesAlive(rarity: string, isNew: boolean, frontier: boolean, ready: boolean?, on: boolean?): boolean
	if ready == false or on == false then
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
