--!strict
-- Watches frame times and says whether the town's extras (tree sway, animals, butterflies) should run (Portal Worlds
-- spec): off after a stretch of slow frames, back on only after a longer fast stretch, so a slow phone sheds them and
-- a short hitch doesn't flicker them. The first WARMUP_SECONDS (the join's loading) never count, so a loading client
-- doesn't shed them and then wait out a fast stretch. Pure, Lune-tested; numbers in Config/Ambient WATCHDOG.
export type Config = {
	WARMUP_SECONDS: number,
	SLOW_FRAME: number,
	SLOW_SECONDS: number,
	FAST_FRAME: number,
	FAST_SECONDS: number,
	SMOOTH_SECONDS: number,
	MAX_FRAME: number,
}

local FrameWatchdog = {}
FrameWatchdog.__index = FrameWatchdog

export type Watchdog = typeof(setmetatable(
	{} :: { cfg: Config, on: boolean, average: number?, slowFor: number, fastFor: number, warmFor: number },
	FrameWatchdog
))

function FrameWatchdog.new(cfg: Config): Watchdog
	return setmetatable({ cfg = cfg, on = true, average = nil :: number?, slowFor = 0, fastFor = 0, warmFor = 0 }, FrameWatchdog)
end

local EPSILON = 1e-6 -- so a stretch of exactly SLOW_SECONDS counts despite rounding

function FrameWatchdog.push(self: Watchdog, dt: number)
	local cfg = self.cfg
	if self.warmFor < cfg.WARMUP_SECONDS - EPSILON then
		self.warmFor += math.max(dt, 0)
		return
	end
	if dt > cfg.MAX_FRAME or dt <= 0 then
		return
	end
	local average = self.average
	if average then
		average += (dt - average) * math.min(1, dt / cfg.SMOOTH_SECONDS)
	else
		average = dt
	end
	self.average = average
	if self.on then
		self.slowFor = if (average :: number) > cfg.SLOW_FRAME then self.slowFor + dt else 0
		if self.slowFor >= cfg.SLOW_SECONDS - EPSILON then
			self.on = false
			self.slowFor = 0
			self.fastFor = 0
		end
	else
		self.fastFor = if (average :: number) < cfg.FAST_FRAME then self.fastFor + dt else 0
		if self.fastFor >= cfg.FAST_SECONDS - EPSILON then
			self.on = true
			self.fastFor = 0
		end
	end
end

return FrameWatchdog
