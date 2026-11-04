--!strict
-- Shop level maths: XP needed per level and the level for an XP total, levels 1 to MAX_LEVEL (Config/Levels).
-- Pure (no requires, no Roblox APIs): callers pass Config/Levels in, so tests/ can run it in Lune.
local LevelMath = {}

type Config = { BASE_XP: number, POWER: number, ROUND_TO: number, MAX_LEVEL: number }

-- Total XP needed to reach this level (levels past the cap cost what the cap does)
function LevelMath.getRequiredXp(config: Config, level: number): number
	local capped = math.min(math.floor(level), config.MAX_LEVEL)
	if capped <= 1 then
		return 0
	end
	return math.round(config.BASE_XP * (capped - 1) ^ config.POWER / config.ROUND_TO) * config.ROUND_TO
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
