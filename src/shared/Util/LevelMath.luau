--!strict
-- Shop level maths: XP needed per level and the level for an XP total, levels 1 to MAX_LEVEL (Config/Levels).
-- Pure (no requires, no Roblox APIs): callers pass Config/Levels in, so tests/ can run it in Lune.
local LevelMath = {}

type Late = { from: number, full: number, times: number }
type Config = { BASE_XP: number, POWER: number, ROUND_TO: number, MAX_LEVEL: number, FIGHT_XP_PER_CASH: number?, LATE: Late? }

-- Shop XP for a sale (its total) or a pack ripped from your stock (its market price: what selling it would give; owner
-- 2026-11-16): the amount rounded, at least `minXp`
function LevelMath.saleXp(amount: number, minXp: number): number
	if amount ~= amount or amount == math.huge or amount == -math.huge then
		return minXp
	end
	return math.max(minXp, math.round(amount))
end

-- Shop XP for a won fight (a monster, a Dungeon room, a boss; owner 2026-11-17): FIGHT_XP_PER_CASH of the cash it
-- paid, rounded, at least 1
function LevelMath.fightXp(cash: number, config: Config): number
	return LevelMath.saleXp(cash * (config.FIGHT_XP_PER_CASH or 0), 1)
end

-- Each config's totals by level, worked out once (the late levels are a sum)
local totals: { [Config]: { number } } = setmetatable({}, { __mode = "k" }) :: any

local function totalsOf(config: Config): { number }
	local known = totals[config]
	if known then
		return known
	end
	local late = config.LATE
	local list: { number } = {}
	local raw, last = 0, 0 -- the unrounded total, and the plain curve's at the level before
	for level = 1, config.MAX_LEVEL do
		local plain = if level <= 1 then 0 else config.BASE_XP * (level - 1) ^ config.POWER
		if late and level > late.from then
			-- past LATE.from: the plain curve's step times a factor climbing from 1 to LATE.times by LATE.full
			local factor = 1 + (late.times - 1) * math.clamp((level - late.from) / math.max(1, late.full - late.from), 0, 1)
			raw += (plain - last) * factor
		else
			raw = plain
		end
		last = plain
		list[level] = math.round(raw / config.ROUND_TO) * config.ROUND_TO
	end
	totals[config] = list
	return list
end

-- Total XP needed to reach this level (levels past the cap cost what the cap does): BASE_XP x (level - 1) ^ POWER,
-- and past Config/Levels LATE.from each level's step costs more (owner 2026-11-20)
function LevelMath.getRequiredXp(config: Config, level: number): number
	local capped = math.min(math.floor(level), config.MAX_LEVEL)
	if capped <= 1 then
		return 0
	end
	return totalsOf(config)[capped]
end

function LevelMath.getLevelForXp(config: Config, xp: number): number
	if xp ~= xp or xp <= 0 then
		return 1
	end
	local level = 1
	while level < config.MAX_LEVEL and xp >= LevelMath.getRequiredXp(config, level + 1) do
		level += 1
	end
	return level
end

-- XP earned inside the current level, and the XP that level spans (0 at the cap: the HUD shows MAX)
function LevelMath.getProgress(config: Config, xp: number): (number, number)
	local level = LevelMath.getLevelForXp(config, xp)
	local floor = LevelMath.getRequiredXp(config, level)
	if level >= config.MAX_LEVEL then
		return math.max(0, xp - floor), 0
	end
	return math.max(0, xp - floor), LevelMath.getRequiredXp(config, level + 1) - floor
end

return LevelMath
