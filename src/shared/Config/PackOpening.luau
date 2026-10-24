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
		TOP = Color3.fromRGB(236, 238, 255),
		BOTTOM = Color3.fromRGB(178, 186, 236), -- a richer lavender blue at the foot
		GLOW_TRANSPARENCY = 0.35, -- the soft white glow in the middle
		DIM = 0.55, -- how dark the stage gets at a tease's full dim (CardReveal dim = 1)
	},
	-- The premium backdrop (Util/PackStage): slow light rays behind the pack in its colour, bokeh sparkles drifting
	-- up, a glowing pedestal under the pack and a soft vignette. Sizes of the screen's height; speeds in pixels a second.
	AMBIENT = {
		RAY_COUNT = 16,
		RAY_RADIUS = 0.95,
		RAY_WIDTH = 0.16,
		RAY_TRANSPARENCY = 0.55, -- at the centre; they fade out to nothing
		RAY_TURN_SECONDS = 60,
		TINT_SOFTEN = 0.55, -- how much the pack's colour is mixed with white for the rays and pedestal
		BOKEH_COUNT = 24,
		BOKEH_SIZE = { 4, 16 }, -- pixels
		BOKEH_SPEED = { 14, 40 },
		BOKEH_TRANSPARENCY = { 0.45, 0.85 },
		PEDESTAL_WIDTH = 0.75,
		PEDESTAL_HEIGHT = 0.16,
		PEDESTAL_GAP = 0.01, -- under the pack's foot
		PEDESTAL_TRANSPARENCY = 0.25,
		PEDESTAL_PULSE_SECONDS = 1.8,
		VIGNETTE_COLOR = Color3.fromRGB(70, 70, 140),
		VIGNETTE_SIZE = 0.28,
		VIGNETTE_TRANSPARENCY = 0.7, -- at the very edge
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
		SWAY = 2.5, -- degrees it rocks either way while it floats
		SWAY_SECONDS = 2.2,
		SHINE_SECONDS = 0.9, -- a foil shine sweeping across it
		SHINE_EVERY = 1.8, -- seconds between sweeps
		ENTER_SECONDS = 0.5, -- popping in when the screen opens
	},
	-- A deck box (Config/Packs kind "Deck"): boxier than a pack, a deeper lid, a darker side face for depth
	DECK = { ASPECT = 0.8, LID = 0.17, SIDE = 0.07 },
	CARD_Y = 0.53, -- the card being revealed: centre height
	CARD_HEIGHT = 0.56,
	BANNER = { SCALE = 0.2, MIN = 36, MAX = 64 }, -- the RARE! banner's height: of the card's height, in pixels
	SUMMARY_Y = 0.5, -- the results row: centre height (below the pills, with room for the NEW ribbons)
	SUMMARY_HEIGHT = 0.42, -- each card in the results row

	-- Border thickness by rarity, so better pulls feel heavier
	STROKE_THICKNESS = { Common = 2, Rare = 3, ["Very Rare"] = 3.5, Epic = 4, Legendary = 6 },

	TEAR_SOUND_ID = "",
	FLIP_SOUND_ID = "",
	HIT_SOUND_IDS = { Rare = "", ["Very Rare"] = "", Epic = "", Legendary = "" },
}
