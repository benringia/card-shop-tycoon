--!strict
-- Shop job maths: work speed from SPD, mistakes from Power, job slots from shop level and the pass.
-- Pure (no requires, no Roblox APIs): callers pass Config/Jobs in, so tests/ can run it in Lune.
local JobRules = {}

type Config = {
	REFERENCE_SPD: number,
	SPEED_EXPONENT: number,
	SPEED_MIN: number,
	SPEED_MAX: number,
	MISTAKE_MAX: number,
	MISTAKE_MIN: number,
	MISTAKE_POWER_LOW: number,
	MISTAKE_POWER_HIGH: number,
	UNLOCK_LEVEL: number,
	FREE_SLOTS: number,
	PASS_SLOTS: number,
}

-- 1 = base speed; faster cards finish sooner and walk quicker
function JobRules.getSpeedFactor(config: Config, spd: number): number
	if spd ~= spd then
		return 1
	end
	return math.clamp((spd / config.REFERENCE_SPD) ^ config.SPEED_EXPONENT, config.SPEED_MIN, config.SPEED_MAX)
end

function JobRules.getDuration(config: Config, baseSeconds: number, spd: number): number
	return baseSeconds / JobRules.getSpeedFactor(config, spd)
end

-- Chance of a mistake per trip or scan: high for weak cards, low for strong ones, linear between
function JobRules.getMistakeChance(config: Config, power: number): number
	local span = config.MISTAKE_POWER_HIGH - config.MISTAKE_POWER_LOW
	local t = math.clamp((power - config.MISTAKE_POWER_LOW) / span, 0, 1)
	return config.MISTAKE_MAX + (config.MISTAKE_MIN - config.MISTAKE_MAX) * t
end

function JobRules.getSlotCount(config: Config, level: number, hasPass: boolean): number
	if level < config.UNLOCK_LEVEL then
		return 0
	end
	return config.FREE_SLOTS + (if hasPass then config.PASS_SLOTS else 0)
end

return JobRules
