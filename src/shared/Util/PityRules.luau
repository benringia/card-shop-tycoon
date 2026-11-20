--!strict
-- Bad-luck protection for packs (Config/PackOdds PITY): after enough packs without a Legendary (or an Epic or better),
-- the next pack's hit slot is raised to one. Pure (no requires, no Roblox APIs): callers pass the config in, so tests/
-- and the economy simulator (tools/economy) run it in Lune. The server keeps the counts (PackService, saved).
local PityRules = {}

-- packs opened since the last Legendary / Epic or better; firstDone: they've had their first Legendary
export type State = { legendary: number, epic: number, firstDone: boolean }
-- FIRST_LEGENDARY_PACKS / LEGENDARY_PACKS nil: no Legendary guarantee (the game's since 2026-11-20)
type Pity = { FIRST_LEGENDARY_PACKS: number?, LEGENDARY_PACKS: number?, EPIC_PACKS: number }

local function readCount(value: unknown): number
	return if typeof(value) == "number" and value == value and value >= 0 and value ~= math.huge then math.floor(value) else 0
end

-- A saved state made safe (missing or bad counts start from 0)
function PityRules.read(saved: unknown): State
	local data: any = if typeof(saved) == "table" then saved else {}
	return { legendary = readCount(data.legendary), epic = readCount(data.epic), firstDone = data.firstDone == true }
end

-- How many packs the current Legendary guarantee spans (the first one's is shorter); nil: there is none
function PityRules.legendaryCap(pity: Pity, state: State): number?
	if state.firstDone then
		return pity.LEGENDARY_PACKS
	end
	return pity.FIRST_LEGENDARY_PACKS or pity.LEGENDARY_PACKS
end

-- One pack opened whose best natural pull is `best`: the rarity pity raises its hit slot to (nil = leave it), and
-- the counts after it. rank orders the rarities (Config/PackOdds RANK).
function PityRules.open(pity: Pity, rank: { [string]: number }, state: State, best: string): (string?, State)
	local legendaryRank, epicRank = rank.Legendary or math.huge, rank.Epic or math.huge
	local sinceLegendary, sinceEpic = state.legendary + 1, state.epic + 1
	local bestRank = rank[best] or 0
	local forced: string? = nil
	local cap = PityRules.legendaryCap(pity, state)
	if cap and bestRank < legendaryRank and sinceLegendary >= cap then
		forced = "Legendary"
	elseif bestRank < epicRank and sinceEpic >= pity.EPIC_PACKS then
		forced = "Epic"
	end
	local finalRank = if forced then rank[forced] else bestRank
	if finalRank >= legendaryRank then
		return forced, { legendary = 0, epic = 0, firstDone = true }
	elseif finalRank >= epicRank then
		return forced, { legendary = sinceLegendary, epic = 0, firstDone = state.firstDone }
	end
	return forced, { legendary = sinceLegendary, epic = sinceEpic, firstDone = state.firstDone }
end

-- Packs left until each guarantee, the Legendary's (nil: there is none) and the Epic's: 1 means the very next pack
function PityRules.remaining(pity: Pity, state: State): (number?, number)
	local cap = PityRules.legendaryCap(pity, state)
	return if cap then math.max(1, cap - state.legendary) else nil, math.max(1, pity.EPIC_PACKS - state.epic)
end

return PityRules
