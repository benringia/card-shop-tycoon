--!strict
-- Pack opening presentation (client only). Timings in seconds, sizes in fractions of the screen's height.
-- See DESIGN.md section 5.7. Sound IDs are empty until you pick some: paste e.g. "rbxassetid://123" to enable.
return {
	TEAR_SECONDS = 0.45, -- the top flying off and the pack sliding away
	AUTO_TEAR_SECONDS = 0.35, -- the tear line running across by itself after a tap
	FLIP_SECONDS = 0.18, -- each half of the flip
	FLASH_SECONDS = 0.6, -- the white flash on big pulls (CardReveal flash = true)
	FOIL_SHIMMER_SECONDS = 1.6, -- one sweep of the foil shimmer
	RISE_SECONDS = 0.45, -- the cards rising out of the pack
	OUT_SECONDS = 0.25, -- a revealed card sliding off to the left
	SUMMARY_STAGGER = 0.06, -- between each card popping into the summary row

	-- The light stage behind everything
	STAGE = {
		TOP = Color3.fromRGB(232, 238, 250),
		BOTTOM = Color3.fromRGB(196, 210, 236),
		GLOW_TRANSPARENCY = 0.35, -- the soft white glow in the middle
		DIM = 0.55, -- how dark the stage gets at a tease's full dim (CardReveal dim = 1)
	},
	-- Pixels: the top row (hint pill, Odds) sits below Roblox's top bar (36 on phones); the bottom pill this far up
	TOP = 44,
	EDGE = 12,
	PILL_HEIGHT = 46,
	PACK = {
		Y = 0.6, -- centre height
		HEIGHT = 0.6,
		ASPECT = 0.65, -- width / height
		CAP = 0.1, -- the strip above the tear line, of the pack's height
		TEETH = 16, -- crimp teeth across the pack
		BOB_PIXELS = 8, -- the pack floats up and down this much
		BOB_SECONDS = 1.6,
		TEAR_DONE = 0.8, -- dragged across this much of the pack's width = torn open
		TAP_PIXELS = 12, -- a press that moves less than this is a tap (the pack tears by itself)
	},
	CARD_Y = 0.53, -- the card being revealed: centre height
	CARD_HEIGHT = 0.56,
	BANNER = { SCALE = 0.2, MIN = 36, MAX = 64 }, -- the RARE! banner's height: of the card's height, in pixels
	SUMMARY_Y = 0.46, -- the summary row: centre height (clear of the Odds button on phones)
	SUMMARY_HEIGHT = 0.44, -- each card in the summary row

	-- Border thickness by rarity, so better pulls feel heavier
	STROKE_THICKNESS = { Common = 2, Rare = 3, ["Very Rare"] = 3.5, Epic = 4, Legendary = 6 },

	TEAR_SOUND_ID = "",
	FLIP_SOUND_ID = "",
	HIT_SOUND_IDS = { Rare = "", ["Very Rare"] = "", Epic = "", Legendary = "" },
}
