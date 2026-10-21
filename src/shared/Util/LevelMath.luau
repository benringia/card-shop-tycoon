--!strict
-- Shop level maths: XP needed per level and the level for an XP total. Levels 1 to 10 come from the
-- table in Config/Levels; after that each step grows by XP_GROWTH, with no level cap.
-- Pure (no requires, no Roblox APIs): callers pass Config/Levels in, so tests/ can run it in Lune.
local LevelMath = {}

type Config = { XP_REQUIRED: { number }, XP_GROWTH: number, LEVEL_LIMIT: number }

-- Total XP needed to reach this level
function LevelMath.getRequiredXp(config: Config, level: number): number
	local table_ = config.XP_REQUIRED
	local count = #table_
	if level <= count then
		return table_[math.max(1, math.floor(level))]
	end
	local lastStep = table_[count] - table_[count - 1]
	local total = table_[count]
	for extra = 1, math.floor(level) - count do
		total += math.round(lastStep * config.XP_GROWTH ^ extra)
	end
	return total
end

function LevelMath.getLevelForXp(config: Config, xp: number): number
	if xp ~= xp or xp <= 0 then
		return 1
	end
	local level = 1
	while level < config.LEVEL_LIMIT and xp >= LevelMath.getRequiredXp(config, level + 1) do
		level += 1
	end
	return level
end

-- XP earned inside the current level, and the XP that level spans (there is always a next level)
function LevelMath.getProgress(config: Config, xp: number): (number, number)
	local level = LevelMath.getLevelForXp(config, xp)
	local floor = LevelMath.getRequiredXp(config, level)
	return math.max(0, xp - floor), LevelMath.getRequiredXp(config, level + 1) - floor
end

return LevelMath
