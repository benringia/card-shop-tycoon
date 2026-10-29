--!strict
-- How hard each pull is celebrated in the pack opening (client only; UI project 3). Plain data so Lune tests can
-- load it; util/RevealRules turns it into a plan per card. Timings in seconds. See DESIGN.md section 5.7.
export type Tier = {
	tease: number, -- the face-down card glows in its rarity colour this long before it flips, 0 = flips at once
	shake: number, -- degrees the card wobbles while teasing
	dim: number, -- extra backdrop darkness while teasing (0 to 1)
	rays: boolean, -- light rays turn behind the card
	flash: boolean, -- white screen flash on the flip
	spotlight: boolean, -- the card pops bigger and taps are ignored a moment, so a double tap can't skip it
	burst: number, -- sparkle on the flip: glints round the card (one per 6)
	banner: string?, -- word that pops above the card
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
		Common = { tease = 0, shake = 0, dim = 0, rays = false, flash = false, spotlight = false, burst = 0, banner = nil,
			shards = 0, goldShards = false, cinematic = false, alive = false, glintRate = 0, moteRate = 0, tilt = 0 },
		Rare = { tease = 0.5, shake = 0, dim = 0, rays = false, flash = false, spotlight = false, burst = 10, banner = "RARE!",
			shards = 10, goldShards = false, cinematic = false, alive = true, glintRate = 4, moteRate = 8, tilt = 5 },
		["Very Rare"] = { tease = 0.8, shake = 3, dim = 0.15, rays = false, flash = false, spotlight = false, burst = 16, banner = "VERY RARE!",
			shards = 16, goldShards = false, cinematic = false, alive = true, glintRate = 5, moteRate = 10, tilt = 6 },
		Epic = { tease = 1.2, shake = 5, dim = 0.35, rays = true, flash = false, spotlight = true, burst = 24, banner = "EPIC!",
			shards = 24, goldShards = false, cinematic = true, alive = true, glintRate = 6, moteRate = 14, tilt = 7 },
		Legendary = { tease = 2, shake = 8, dim = 0.6, rays = true, flash = true, spotlight = true, burst = 36, banner = "LEGENDARY!",
			shards = 30, goldShards = true, cinematic = true, alive = true, glintRate = 7.5, moteRate = 18, tilt = 8 },
	} :: { [string]: Tier },

	-- Frontier cards only drop in the Frontier, but they get the biggest show wherever they're revealed
	FRONTIER = { tease = 2, shake = 8, dim = 0.6, rays = true, flash = true, spotlight = true, burst = 36, banner = "FRONTIER!",
		shards = 30, goldShards = true, cinematic = true, alive = true, glintRate = 7.5, moteRate = 18, tilt = 8 } :: Tier,

	-- Foil on top of any rarity: at least this much tease, extra sparks, and "FOIL" in front of the banner
	FOIL = { MIN_TEASE = 0.6, EXTRA_BURST = 12, PREFIX = "FOIL " },
}
