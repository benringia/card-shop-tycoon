--!strict
-- Combat maths shared by the fight simulation, the server and the client's fight bar.
-- Pure (no requires, no Roblox APIs): callers pass Config/Combat and Config/Wild in, so tests/ run it in Lune.
local CombatMath = {}

type Combat = {
	ATTACK_BASE: number,
	SPD_REFERENCE: number,
	ATTACK_MIN: number,
	ATTACK_MAX: number,
	DAMAGE_SPREAD: number,
	STRONG: number,
	WEAK: number,
	BEATS: { [string]: { string } },
	RUN_BASE: number,
	RUN_PER_SPD: number,
	RUN_MIN: number,
	RUN_MAX: number,
	RUN_ELITE_PENALTY: number,
}

type Wild = {
	SPECIES: { [string]: { element: string, hp: number, atk: number, spd: number } },
	MONSTER_GROWTH: number,
	ELITE_STAT_MULTIPLIER: number,
	ELITE_REWARD_MULTIPLIER: number,
	XP_BASE: number,
	XP_EXPONENT: number,
	CASH_PER_LEVEL: number,
	DROP_CHANCE: number,
	ELITE_DROP_CHANCE: number,
}

function CombatMath.getAttackInterval(combat: Combat, spd: number): number
	if spd <= 0 then
		return combat.ATTACK_MAX
	end
	return math.clamp(combat.ATTACK_BASE * combat.SPD_REFERENCE / spd, combat.ATTACK_MIN, combat.ATTACK_MAX)
end

local function beats(combat: Combat, a: string, b: string): boolean
	local list = combat.BEATS[a]
	return list ~= nil and table.find(list, b) ~= nil
end

function CombatMath.getElementMultiplier(combat: Combat, attacker: string, defender: string): (number, ("strong" | "weak")?)
	if beats(combat, attacker, defender) then
		return combat.STRONG, "strong"
	elseif beats(combat, defender, attacker) then
		return combat.WEAK, "weak"
	end
	return 1, nil
end

-- roll in [0, 1): 0 is -SPREAD, 0.5 is exact, near 1 is +SPREAD
function CombatMath.getDamage(combat: Combat, atk: number, multiplier: number, roll: number): number
	local spread = 1 + combat.DAMAGE_SPREAD * (2 * roll - 1)
	return math.max(1, math.round(atk * multiplier * spread))
end

function CombatMath.getRunChance(combat: Combat, leaderSpd: number, monsterSpd: number, elite: boolean): number
	local chance = math.clamp(combat.RUN_BASE + combat.RUN_PER_SPD * (leaderSpd - monsterSpd), combat.RUN_MIN, combat.RUN_MAX)
	if elite then
		chance = math.max(combat.RUN_MIN, chance - combat.RUN_ELITE_PENALTY)
	end
	return chance
end

-- XP each party card gets: an even share, rounded down, but at least 1 when there is anything to share
function CombatMath.splitXp(total: number, count: number): number
	if total <= 0 or count <= 0 then
		return 0
	end
	return math.max(1, math.floor(total / count))
end

function CombatMath.getMonsterStats(wild: Wild, species: string, level: number, elite: boolean): { hp: number, atk: number, spd: number }?
	local base = wild.SPECIES[species]
	if not base then
		return nil
	end
	local growth = 1 + wild.MONSTER_GROWTH * (math.max(1, level) - 1)
	local boost = if elite then wild.ELITE_STAT_MULTIPLIER else 1
	return {
		hp = math.round(base.hp * growth * boost),
		atk = math.round(base.atk * growth * boost),
		spd = math.round(base.spd * (if elite then 1.1 else 1)),
	}
end

function CombatMath.getRewards(wild: Wild, level: number, elite: boolean): { xp: number, cash: number, dropChance: number }
	local boost = if elite then wild.ELITE_REWARD_MULTIPLIER else 1
	return {
		xp = math.round(wild.XP_BASE * math.max(1, level) ^ wild.XP_EXPONENT) * boost,
		cash = math.round(wild.CASH_PER_LEVEL * math.max(1, level) * 100) / 100 * boost,
		dropChance = if elite then wild.ELITE_DROP_CHANCE else wild.DROP_CHANCE,
	}
end

return CombatMath
