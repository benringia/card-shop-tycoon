--!strict
-- Shop workers get tired now and then (owner 2026-11-06; Config/Jobs TIRED, server JobService): after a stretch of
-- work (TIRED.every seconds, a random length in that range) a Restocker or Cashier is tired for TIRED.seconds, working
-- at TIRED.speed with more mistakes, never stopping; then it's rested and works a new stretch. A chance for the owner
-- to step in at the register (kid offers and haggles only come to the owner). Pure, Lune-tested.
local TiredRules = {}

-- (tick: how often the server steps the clock, seconds)
export type Config = { every: { number }, seconds: number, speed: number, mistakes: number, mistakeCap: number, tick: number }
-- workLeft: seconds of work before it tires; tiredLeft: seconds of tiredness left (0 while rested)
export type Clock = { workLeft: number, tiredLeft: number }

local function stretch(cfg: Config, roll: number): number
	return cfg.every[1] + (cfg.every[2] - cfg.every[1]) * math.clamp(roll, 0, 1)
end

-- A worker just put to work: rested, `roll` 0-1 picking how long until it tires
function TiredRules.start(cfg: Config, roll: number): Clock
	return { workLeft = stretch(cfg, roll), tiredLeft = 0 }
end

function TiredRules.isTired(clock: Clock): boolean
	return clock.tiredLeft > 0
end

-- `dt` seconds of work later: the new clock, and "tired" or "rested" when it just turned (`roll` picks the next
-- stretch when it's rested)
function TiredRules.step(clock: Clock, dt: number, cfg: Config, roll: number): (Clock, string?)
	if clock.tiredLeft > 0 then
		local left = clock.tiredLeft - dt
		if left <= 0 then
			return { workLeft = stretch(cfg, roll), tiredLeft = 0 }, "rested"
		end
		return { workLeft = clock.workLeft, tiredLeft = left }, nil
	end
	local work = clock.workLeft - dt
	if work <= 0 then
		return { workLeft = 0, tiredLeft = cfg.seconds }, "tired"
	end
	return { workLeft = work, tiredLeft = 0 }, nil
end

-- Its work speed multiplier
function TiredRules.speed(cfg: Config, tired: boolean): number
	return if tired then cfg.speed else 1
end

-- Its mistake chance, from its usual `chance`
function TiredRules.mistake(cfg: Config, chance: number, tired: boolean): number
	return if tired then math.min(chance * cfg.mistakes, cfg.mistakeCap) else chance
end

return TiredRules
