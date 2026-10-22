--!strict
-- How hard each pull is celebrated on the pack opening screen (client only). Plain data so Lune tests can
-- load it; util/RevealRules turns it into a plan per card. Timings in seconds. See DESIGN.md section 5.7.
export type Tier = {
	tease: number, -- the face-down card glows in its rarity colour this long before it flips, 0 = flips at once
	shake: number, -- degrees the card wobbles while teasing
	dim: number, -- extra backdrop darkness while teasing (0 to 1)
	rays: boolean, -- light rays turn behind the card
	flash: boolean, -- white screen flash on the flip
	spotlight: boolean, -- the card is shown big in the middle until tapped
	burst: number, -- sparks flying out on the flip
	confetti: number, -- confetti pieces raining down
	banner: string?, -- word that pops above the card
}

return {
	BY_RARITY = {
		Common = { tease = 0, shake = 0, dim = 0, rays = false, flash = false, spotlight = false, burst = 0, confetti = 0, banner = nil },
		Rare = { tease = 0.5, shake = 0, dim = 0, rays = false, flash = false, spotlight = false, burst = 10, confetti = 0, banner = "RARE!" },
		["Very Rare"] = { tease = 0.8, shake = 3, dim = 0.15, rays = false, flash = false, spotlight = false, burst = 16, confetti = 0, banner = "VERY RARE!" },
		Epic = { tease = 1.2, shake = 5, dim = 0.35, rays = true, flash = false, spotlight = true, burst = 24, confetti = 20, banner = "EPIC!" },
		Legendary = { tease = 2, shake = 8, dim = 0.6, rays = true, flash = true, spotlight = true, burst = 36, confetti = 50, banner = "LEGENDARY!" },
	} :: { [string]: Tier },

	-- Frontier cards only drop in the Frontier, but they get the biggest show wherever they're revealed
	FRONTIER = { tease = 2, shake = 8, dim = 0.6, rays = true, flash = true, spotlight = true, burst = 36, confetti = 50, banner = "FRONTIER!" } :: Tier,

	-- Foil on top of any rarity: at least this much tease, extra sparks, and "FOIL" in front of the banner
	FOIL = { MIN_TEASE = 0.6, EXTRA_BURST = 12, PREFIX = "FOIL " },

	TEASE_PULSE_SECONDS = 0.25, -- one glow breath while teasing
	SPOTLIGHT_SCALE = 2.4, -- the spotlight card, times the card row's card size
	SPOTLIGHT_MAX_HEIGHT = 0.7, -- of the screen, so the banner and "Tap to continue" still fit
	BANNER_SECONDS = 0.35, -- the banner's pop-in
	BANNER_HOLD_SECONDS = 1.4, -- a banner by the card stays this long, then fades
	SPOTLIGHT_TAP_DELAY = 0.6, -- taps on the spotlight are ignored this long, so a double tap can't skip it
	BURST_SECONDS = 0.7, -- how long sparks fly
	CONFETTI_SECONDS = 2.2, -- how long confetti falls
	RAY_COUNT = 12,
	RAY_TURN_SECONDS = 8, -- one full turn of the rays
}
