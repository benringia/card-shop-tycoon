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
	-- A heavy pack before the tear (owner 2026-11-17, "do all": the pack trembles; EA FC's walkout flare): one holding a
	-- `rarity` or better shivers in bursts (`degrees`, `seconds` long, every `every` s) and glows gold, and the hint
	-- says `hint`; a pack whose best is a Very Rare does it `fakeOut` of the time, so it stays a guess
	PACK_TELL = { rarity = "Epic", fakeOut = 0.25, degrees = 4, seconds = 0.35, every = 1.3, glow = { 255, 200, 60 },
		hint = "This one feels heavy... Swipe across the top!" },
	-- The creature comes alive on the stage (owner 2026-11-17, "do all"; client Util/OpeningCreature): an Epic, a Legendary,
	-- a Frontier card or a card you never had (RevealRules.comesAlive) bursts out of its card `height` studs tall, rising
	-- `rise` and coming `toward` the camera in `popSeconds`, turned `facing` degrees (a three-quarter view), roars (a
	-- `roar` size pulse) and turns `turn` degrees either way for `holdSeconds`, then dives back in over `backSeconds`.
	-- A tap moves on at any time
	-- Open 10's best pulls (owner 2026-11-17: "highlight any veryrare and above cards on the after opening 10cards"; look A
	-- of artifact XyGHP2ku71fRaYeuEkGZ6D; BulkOpenController, RevealRules.standsOut): a card `from` or better lights up as
	-- it turns (a halo `halo` times its size, breathing between the `glow` transparencies, its rim `rim` px turning once
	-- every `spinSeconds`, a shine every
	-- `shineEvery` s, its rarity's tag), and once all are turned the rest dims (black at `dim` over them)
	BEST = { from = "Very Rare", halo = 2.3, glow = { 0.05, 0.4 }, rim = 3, spinSeconds = 2.4, shineEvery = 2.6, dim = 0.55 },
	CREATURE = { height = 1.3, rise = 0.2, toward = 0.8, popSeconds = 0.45, roar = 1.12, turn = 18, facing = 25, holdSeconds = 1.6, backSeconds = 0.35 },
}
