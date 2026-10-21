--!strict
-- The summoned creature's perk: its element picks the kind, rarity and stars set how strong it is.
-- Pure (no requires, no Roblox APIs): callers pass Config/Party in, so tests/ can run it in Lune.
local PartyRules = {}

export type Perk = { kind: string, value: number }
type Config = {
	PERKS: { [string]: { kind: string, base: number } },
	RARITY_MULTIPLIER: { [string]: number },
	STAR_BONUS: number,
}

local TEXT = {
	Hype = "customers %d%% more often",
	Calm = "customers wait %d%% longer",
	Express = "deliveries %d%% faster",
	Hustle = "you walk %d%% faster",
	Haggle = "customers %d%% more likely to buy",
}

function PartyRules.getPerk(config: Config, element: string, rarity: string, stars: number): Perk?
	local perk = config.PERKS[element]
	if not perk then
		return nil
	end
	local multiplier = config.RARITY_MULTIPLIER[rarity] or 1
	return { kind = perk.kind, value = perk.base * multiplier * (1 + config.STAR_BONUS * math.max(0, stars)) }
end

-- "Hype: customers 5% more often"
function PartyRules.describe(perk: Perk): string
	local text = TEXT[perk.kind] or "%d%%"
	return `{perk.kind}: {string.format(text, math.round(perk.value * 100))}`
end

return PartyRules
