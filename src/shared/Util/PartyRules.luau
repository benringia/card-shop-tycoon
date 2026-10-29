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

export type ChangeKind = "joined" | "swapped" | "left"
export type Change = { slot: number, kind: ChangeKind, before: string?, after: string? }

-- What changed between two parties (slot -> beastId), slot by slot: a card joined an empty slot, swapped in
-- for another, or left
function PartyRules.changes(before: { [number]: string }, after: { [number]: string }, size: number): { Change }
	local list: { Change } = {}
	for slot = 1, size do
		local was, now = before[slot], after[slot]
		if was ~= now then
			local kind: ChangeKind = if was == nil then "joined" elseif now == nil then "left" else "swapped"
			table.insert(list, { slot = slot, kind = kind, before = was, after = now })
		end
	end
	return list
end

-- The toast for a change: "Cindercub swapped in for Ashbeak!"
function PartyRules.changeText(kind: ChangeKind, inName: string?, outName: string?): string
	if kind == "joined" then
		return `{inName or "A card"} joined your party!`
	elseif kind == "swapped" then
		return `{inName or "A card"} swapped in for {outName or "a card"}!`
	end
	return `{outName or "A card"} left your party`
end

return PartyRules
