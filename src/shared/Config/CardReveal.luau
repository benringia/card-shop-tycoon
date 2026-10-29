--!strict
-- How hard each pull is celebrated on the pack opening screen (client only). Plain data so Lune tests can
-- load it; util/RevealRules turns it into a plan per card. Timings in seconds. See DESIGN.md section 5.7.
export type Tier = {
	tease: number, -- the face-down card glows in its rarity colour this long before it flips, 0 = flips at once
	shake: number, -- degrees the card wobbles while teasing
	dim: number, -- extra backdrop darkness while teasing (0 to 1)
	rays: boolean, -- light rays turn behind the card
	flash: boolean, -- white screen flash on the flip
	spotlight: boolean, -- the card pops bigger and taps are ignored a moment, so a double tap can't skip it
	burst: number, -- sparks flying out on the flip
	confetti: number, -- confetti pieces raining down (the old 2D screen; the 3D opening uses shards)
	banner: string?, -- word that pops above the card
	-- The 3D opening (UI project 3, spec 4.4 / 4.5)
	shards: number, -- foil shards flying out on the flip (the Blender ShardHolo / ShardGold flipbooks)
	goldShards: boolean, -- gold shards (they rain down too) instead of holo
	cinematic: boolean, -- letterbox bars, the stage dims and the camera eases in during the tease
	alive: boolean, -- while shown the card floats and tilts, shimmers, and glints twinkle round it
	glintRate: number, -- glints a second round the shown card
	moteRate: number, -- motes a second rising past it
	tilt: number, -- degrees it tilts as it floats
}

return {
	BY_RARITY = {
		Common = { tease = 0, shake = 0, dim = 0, rays = false, flash = false, spotlight = false, burst = 0, confetti = 0, banner = nil,
			shards = 0, goldShards = false, cinematic = false, alive = false, glintRate = 0, moteRate = 0, tilt = 0 },
		Rare = { tease = 0.5, shake = 0, dim = 0, rays = false, flash = false, spotlight = false, burst = 10, confetti = 0, banner = "RARE!",
			shards = 10, goldShards = false, cinematic = false, alive = true, glintRate = 4, moteRate = 8, tilt = 5 },
		["Very Rare"] = { tease = 0.8, shake = 3, dim = 0.15, rays = false, flash = false, spotlight = false, burst = 16, confetti = 0, banner = "VERY RARE!",
			shards = 16, goldShards = false, cinematic = false, alive = true, glintRate = 5, moteRate = 10, tilt = 6 },
		Epic = { tease = 1.2, shake = 5, dim = 0.35, rays = true, flash = false, spotlight = true, burst = 24, confetti = 20, banner = "EPIC!",
			shards = 24, goldShards = false, cinematic = true, alive = true, glintRate = 6, moteRate = 14, tilt = 7 },
		Legendary = { tease = 2, shake = 8, dim = 0.6, rays = true, flash = true, spotlight = true, burst = 36, confetti = 50, banner = "LEGENDARY!",
			shards = 30, goldShards = true, cinematic = true, alive = true, glintRate = 7.5, moteRate = 18, tilt = 8 },
	} :: { [string]: Tier },

	-- Frontier cards only drop in the Frontier, but they get the biggest show wherever they're revealed
	FRONTIER = { tease = 2, shake = 8, dim = 0.6, rays = true, flash = true, spotlight = true, burst = 36, confetti = 50, banner = "FRONTIER!",
		shards = 30, goldShards = true, cinematic = true, alive = true, glintRate = 7.5, moteRate = 18, tilt = 8 } :: Tier,

	-- Foil on top of any rarity: at least this much tease, extra sparks, and "FOIL" in front of the banner
	FOIL = { MIN_TEASE = 0.6, EXTRA_BURST = 12, PREFIX = "FOIL " },

	TEASE_PULSE_SECONDS = 0.25, -- one glow breath while teasing
	SPOTLIGHT_POP = 1.08, -- a spotlight card's size after its flip, times its normal size
	BANNER_SECONDS = 0.35, -- the banner's pop-in
	BANNER_HOLD_SECONDS = 1.4, -- a banner by the card stays this long, then fades
	SPOTLIGHT_TAP_DELAY = 0.6, -- taps after a spotlight card's flip are ignored this long
	BURST_SECONDS = 0.7, -- how long sparks fly
	CONFETTI_SECONDS = 2.2, -- how long confetti falls
	RAY_COUNT = 12,
	RAY_TURN_SECONDS = 8, -- one full turn of the rays
}
