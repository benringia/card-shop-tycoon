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

-- Which cards hold a saved shop job (beastId -> job), from the saved jobs list. The Frontier place doesn't run
-- shop jobs but still locks these cards, so they can't join a party there.
function JobRules.getSavedLocks(config: { JOBS: { string } }, raw: unknown): { [string]: string }
	local locks: { [string]: string } = {}
	if typeof(raw) ~= "table" then
		return locks
	end
	for _, entry in raw :: { any } do
		if typeof(entry) == "table" and typeof(entry.beastId) == "string" and typeof(entry.job) == "string"
			and table.find(config.JOBS, entry.job) and not locks[entry.beastId] then
			locks[entry.beastId] = entry.job
		end
	end
	return locks
end

-- The job after `current` in the list (wrapping round): what Switch job turns a worker into
function JobRules.nextJob(jobs: { string }, current: string): string?
	local index = table.find(jobs, current)
	if not index then
		return nil
	end
	return jobs[index % #jobs + 1]
end

-- Kid words for a work speed factor, and their tone ("good", "ok", "bad")
function JobRules.speedWord(config: { SPEED_WORDS: { { min: number, word: string, tone: string } } }, factor: number): (string, string)
	for _, entry in config.SPEED_WORDS do
		if factor >= entry.min then
			return entry.word, entry.tone
		end
	end
	local last = config.SPEED_WORDS[#config.SPEED_WORDS]
	return last.word, last.tone
end

-- Kid words for a mistake chance, and their tone
function JobRules.mistakeWord(config: { MISTAKE_WORDS: { { max: number, word: string, tone: string } } }, chance: number): (string, string)
	for _, entry in config.MISTAKE_WORDS do
		if chance <= entry.max then
			return entry.word, entry.tone
		end
	end
	local last = config.MISTAKE_WORDS[#config.MISTAKE_WORDS]
	return last.word, last.tone
end

-- Whole minutes of work to the next level (nil at max level)
function JobRules.minutesToNext(xp: number, toNext: number, perMinute: number): number?
	if toNext <= 0 or perMinute <= 0 then
		return nil
	end
	return math.max(1, math.ceil((toNext - xp) / perMinute))
end

return JobRules
