--!strict
-- The HUD mascot's timing (spec 2026-11-03-hud-creature-pals-design; numbers in Config/HudMascot, drawn by
-- Util/HudMascotView): when it blinks, how it ducks behind the cash pill and comes back up, its tap bounce, and where
-- it sits. Pure, Lune-tested.
local HudMascotRules = {}

-- Seconds until the next blink, `roll` 0-1 picking within cfg.blink.every
function HudMascotRules.nextBlink(roll: number, cfg: any): number
	local every = cfg.blink.every
	return every[1] + (every[2] - every[1]) * math.clamp(roll, 0, 1)
end

-- How far down it is (0 up, 1 hidden) `t` seconds into a duck: down eased out over cfg.duck.down, held, then up
-- eased in over cfg.duck.up
function HudMascotRules.duckShare(t: number, cfg: any): number
	local duck = cfg.duck
	if t <= 0 then
		return 0
	end
	if t < duck.down then
		local p = t / duck.down
		return 1 - (1 - p) * (1 - p)
	end
	if t <= duck.down + duck.hold then
		return 1
	end
	local p = (t - duck.down - duck.hold) / duck.up
	if p >= 1 then
		return 0
	end
	return 1 - p * p
end

-- The time to restart a duck from so it carries on down from `share` (a summon while it's still coming back up)
function HudMascotRules.restartAt(share: number, cfg: any): number
	local s = math.clamp(share, 0, 1)
	return (1 - math.sqrt(1 - s)) * cfg.duck.down
end

-- Its size `t` seconds into a tap bounce: swells by cfg.tap.scale halfway and settles
function HudMascotRules.bounce(t: number, cfg: any): number
	local tap = cfg.tap
	if t <= 0 or t >= tap.seconds then
		return 1
	end
	return 1 + tap.scale * math.sin(math.pi * t / tap.seconds)
end

-- How far a duck moves the sticker down (its `height` in pixels): past its own height by its breathing and bounce
-- swells, so no ear tip shows at the bottom of a duck
function HudMascotRules.duckTravel(height: number, cfg: any): number
	return height * (1 + cfg.breath.scale + cfg.tap.scale)
end

-- Its pieces' left edges (px) from its seat's left edge: the sticker, its tail, its tap area
function HudMascotRules.layout(cfg: any): { sticker: number, tail: number, tap: number }
	local width = cfg.size.peek[1]
	local sticker = cfg.perch.x
	return {
		sticker = sticker,
		tail = sticker + cfg.tail.at[1],
		tap = sticker + width / 2 - cfg.tapArea.w / 2,
	}
end

return HudMascotRules
