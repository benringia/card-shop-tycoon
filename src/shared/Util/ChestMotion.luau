--!strict
-- The boss chests' motion (the owner 2026-11-11: "make the chest/chest opening more immersive"; Config/BossChests BEATS,
-- used by BossChestController): the chests dropping in one after another, a waiting chest's rattle and the picked
-- chest's tension shake before it bursts. Pure, Lune-tested.
export type Drop = { stagger: number, seconds: number, height: number }
export type Rattle = { seconds: number }
export type Tension = { seconds: number, shakeFrom: number, shakeTo: number, speed: number }

local ChestMotion = {}

-- When chest `index` (1-3) lands, in seconds since the chests appeared
function ChestMotion.landsAt(index: number, drop: Drop): number
	return (index - 1) * drop.stagger + drop.seconds
end

-- How high above its place chest `index` is `elapsed` seconds after the chests appeared: waiting up high for its turn,
-- falling faster and faster, then down to stay
function ChestMotion.dropHeight(elapsed: number, index: number, drop: Drop): number
	local t = (elapsed - (index - 1) * drop.stagger) / drop.seconds
	if t <= 0 then
		return drop.height
	elseif t >= 1 then
		return 0
	end
	return drop.height * (1 - t * t)
end

-- A rattle started at `startAt`: how far its lid is cracked open at `now` (0 to 1 and back), 0 outside it
function ChestMotion.rattle(now: number, startAt: number, rattle: Rattle): number
	local t = (now - startAt) / rattle.seconds
	if t < 0 or t > 1 then
		return 0
	end
	return math.sin(math.pi * t)
end

-- The picked chest's shake `elapsed` seconds into its tension, in degrees: from shakeFrom to shakeTo and faster as it
-- builds; 0 once it has burst
function ChestMotion.tension(elapsed: number, tension: Tension): number
	if elapsed < 0 or elapsed > tension.seconds then
		return 0
	end
	local share = elapsed / tension.seconds
	local size = tension.shakeFrom + (tension.shakeTo - tension.shakeFrom) * share * share
	return size * math.sin(elapsed * tension.speed * (1 + share))
end

return ChestMotion
