--!strict
-- The combat HUD's HP bar motion (Config/CombatHud HP_BAR, HIT_FLASH, PORTRAIT): where the fill and the ghost of lost
-- HP are drawn at a moment, how hard the screen's edges flash red for a hit and pulse at low HP, and the portrait's
-- shake. Pure (callers pass Config/CombatHud in, times are os.clock seconds), so tests/ can run it in Lune.
local HpBarRules = {}

-- The last change: its share, where the moving part started from, when, and whether it was a heal
export type Bar = { target: number, from: number, changedAt: number, healing: boolean }

local function share01(value: number): number
	return math.clamp(value, 0, 1)
end

local function progress(now: number, start: number, seconds: number): number
	return if seconds <= 0 then 1 else math.clamp((now - start) / seconds, 0, 1)
end

function HpBarRules.new(share: number): Bar
	local start = share01(share)
	return { target = start, from = start, changedAt = -math.huge, healing = false }
end

-- The fill and the ghost's shares at `now`, the white flash (1 at a hit, fading to 0) and whether the ghost is a
-- heal's pale lead
function HpBarRules.sample(bar: Bar, now: number, cfg: any): (number, number, number, boolean)
	local hp = cfg.HP_BAR
	if bar.healing then
		local t = progress(now, bar.changedAt, hp.HEAL_RISE)
		local eased = 1 - (1 - t) ^ 2
		return bar.from + (bar.target - bar.from) * eased, bar.target, 0, true
	end
	local t = progress(now, bar.changedAt + hp.GHOST_HOLD, hp.GHOST_DRAIN)
	local ghost = bar.from + (bar.target - bar.from) * t ^ 2
	local flash = 1 - progress(now, bar.changedAt, hp.FLASH)
	return bar.target, ghost, flash, false
end

-- A new share: a drop leaves a ghost from what's shown now, a rise moves the lead there and the fill follows
function HpBarRules.set(bar: Bar, share: number, now: number, cfg: any)
	local target = share01(share)
	if target == bar.target then
		return
	end
	local fill, ghost = HpBarRules.sample(bar, now, cfg)
	bar.healing = target > bar.target
	bar.from = if bar.healing then fill else math.max(fill, ghost)
	bar.target = target
	bar.changedAt = now
end

function HpBarRules.settled(bar: Bar, now: number, cfg: any): boolean
	local hp = cfg.HP_BAR
	local seconds = if bar.healing then hp.HEAL_RISE else math.max(hp.GHOST_HOLD + hp.GHOST_DRAIN, hp.FLASH)
	return now - bar.changedAt >= seconds
end

-- How opaque the red edges start for a hit of `damage` out of `maxHp`
function HpBarRules.flashPeak(damage: number, maxHp: number, cfg: any): number
	local flash = cfg.HIT_FLASH
	if maxHp <= 0 then
		return flash.MIN
	end
	return math.min(1, flash.MIN + flash.PER_SHARE * math.max(0, damage) / maxHp)
end

-- The red edges' opacity at `now`: the last hit's flash fading out, or the low-HP pulse if that's stronger
function HpBarRules.edgeAlpha(now: number, hitAt: number, peak: number, share: number, beaten: boolean, cfg: any): number
	local flash = cfg.HIT_FLASH
	local fade = 1 - progress(now, hitAt, flash.SECONDS)
	local hit = peak * fade ^ 2
	local pulse = 0
	if not beaten and share < flash.LOW_SHARE then
		local wave = (1 - math.cos(2 * math.pi * now / flash.PULSE_SECONDS)) / 2
		pulse = flash.PULSE_MIN + (flash.PULSE_MAX - flash.PULSE_MIN) * wave
	end
	return math.max(hit, pulse)
end

-- The portrait's offset in pixels at `now` after a hit at `hitAt`: through SHAKE's offsets, still at both ends
function HpBarRules.shake(now: number, hitAt: number, cfg: any): (number, number)
	local shake = cfg.PORTRAIT.SHAKE
	local t = progress(now, hitAt, shake.seconds)
	if t <= 0 or t >= 1 then
		return 0, 0
	end
	local keys = { { 0, 0 } }
	for _, offset in shake.offsets do
		table.insert(keys, offset)
	end
	table.insert(keys, { 0, 0 })
	local position = t * (#keys - 1)
	local index = math.floor(position)
	local a, b = keys[index + 1], keys[math.min(index + 2, #keys)]
	local f = position - index
	return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f
end

return HpBarRules
