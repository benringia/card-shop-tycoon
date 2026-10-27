--!strict
-- Bad-luck protection for packs (Config/PackOdds PITY): after enough packs without a Legendary (or an Epic or better),
-- the next pack's hit slot is raised to one. Pure (no requires, no Roblox APIs): callers pass the config in, so tests/
-- and the economy simulator (tools/economy) run it in Lune. The server keeps the counts (PackService, saved).
local PityRules = {}

-- packs opened since the last Legendary / Epic or better; firstDone: they've had their first Legendary
export type State = { legendary: number, epic: number, firstDone: boolean }
type Pity = { FIRST_LEGENDARY_PACKS: number, LEGENDARY_PACKS: number, EPIC_PACKS: number }

local function readCount(value: unknown): number
	return if typeof(value) == "number" and value == value and value >= 0 and value ~= math.huge then math.floor(value) else 0
end

-- A saved state made safe (missing or bad counts start from 0)
function PityRules.read(saved: unknown): State
	local data: any = if typeof(saved) == "table" then saved else {}
	return { legendary = readCount(data.legendary), epic = readCount(data.epic), firstDone = data.firstDone == true }
end

-- How many packs the current Legendary guarantee spans: the first one's is shorter
function PityRules.legendaryCap(pity: Pity, state: State): number
	return if state.firstDone then pity.LEGENDARY_PACKS else pity.FIRST_LEGENDARY_PACKS
end

-- One pack opened whose best natural pull is `best`: the rarity pity raises its hit slot to (nil = leave it), and
-- the counts after it. rank orders the rarities (Config/PackOdds RANK).
function PityRules.open(pity: Pity, rank: { [string]: number }, state: State, best: string): (string?, State)
	local legendaryRank, epicRank = rank.Legendary or math.huge, rank.Epic or math.huge
	local sinceLegendary, sinceEpic = state.legendary + 1, state.epic + 1
	local bestRank = rank[best] or 0
	local forced: string? = nil
	if bestRank < legendaryRank and sinceLegendary >= PityRules.legendaryCap(pity, state) then
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

-- Packs left until each guarantee: 1 means the very next pack
function PityRules.remaining(pity: Pity, state: State): (number, number)
	return math.max(1, PityRules.legendaryCap(pity, state) - state.legendary), math.max(1, pity.EPIC_PACKS - state.epic)
end

return PityRules
