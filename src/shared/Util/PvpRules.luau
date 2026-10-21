--!strict
-- PvP bet and record rules, shared by the server (enforces) and the challenge popup (previews).
-- Pure (no requires, no Roblox APIs): callers pass Config/Pvp in, so tests/ run it in Lune.
local PvpRules = {}

type Config = { CAP_PER_LEVEL: number, BET_STEP: number }
export type Record = { wins: number, losses: number, draws: number }

-- Highest bet two players can make: neither can bet more than they have, nor more than the lower shop level allows
function PvpRules.getBetCap(config: Config, cashA: number, cashB: number, levelA: number, levelB: number): number
	local cap = math.min(cashA, cashB, config.CAP_PER_LEVEL * math.min(levelA, levelB))
	return math.max(0, math.floor(cap / config.BET_STEP) * config.BET_STEP)
end

-- 0 (Friendly) or a whole number of steps, up to the cap
function PvpRules.isValidBet(config: Config, bet: unknown, cap: number): boolean
	if typeof(bet) ~= "number" or bet ~= bet or bet < 0 or bet > cap or bet ~= math.floor(bet) then
		return false
	end
	return bet % config.BET_STEP == 0
end

-- What a player gets back from the pot
function PvpRules.getPayout(outcome: string, bet: number): number
	return if outcome == "win" then bet * 2 elseif outcome == "draw" then bet else 0
end

local function count(value: unknown): number
	return if typeof(value) == "number" and value == value and value > 0 and value ~= math.huge then math.floor(value) else 0
end

function PvpRules.sanitizeRecord(raw: unknown): Record
	local data: any = if typeof(raw) == "table" then raw else {}
	return { wins = count(data.wins), losses = count(data.losses), draws = count(data.draws) }
end

function PvpRules.addResult(record: Record, outcome: string): Record
	return {
		wins = record.wins + (if outcome == "win" then 1 else 0),
		losses = record.losses + (if outcome == "lose" then 1 else 0),
		draws = record.draws + (if outcome == "draw" then 1 else 0),
	}
end

return PvpRules
