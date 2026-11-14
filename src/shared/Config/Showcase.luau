--!strict
-- Displaying single cards in Glass Showcases (NPC customers buy) and Collector Cases (players buy).
-- See DESIGN.md section 5.6.
return {
	-- Card prices: default is market value; +/- steps are a fraction of market value
	PRICE_STEP_RATIO = 0.1,
	MIN_PRICE_STEP = 0.01,
	MIN_PRICE = 0.01,
	MAX_MARKUP = 3, -- highest price as a multiple of market value

	CUSTOMER_CARD_CHANCE = 0.3, -- chance a customer also looks at the Glass Showcase

	ACTION_COOLDOWN = 0.15, -- display / remove / price changes per player
	BUY_COOLDOWN = 0.5, -- player-to-player purchases per buyer
	BUY_DISTANCE = 14, -- studs; buyer must be this close to the card
	BUY_PROMPT_DISTANCE = 8,
	BROWSE_CLOSE_DISTANCE = 24, -- the browse panel closes if the visitor walks this far from the case

	-- Deal tag shown to visitors: price ÷ market value
	GOOD_DEAL_MAX_RATIO = 1.0,
	FAIR_DEAL_MAX_RATIO = 1.2,

	-- Card slots laid out on the case's front face, left to right then top to bottom.
	-- The top strip of the face is kept clear for the case's label.
	SLOT_COLUMNS = 3,
	SLOT_SPACING = Vector2.new(1.9, 1.55), -- studs between slot centres
	SLOTS_OFFSET_Y = -0.35, -- shifts the card grid down a little on the case face
	CASED_CARD_INSET = 0.45, -- cases drawn with a prop: cards stand this far behind the case's front face
	CASED_CARD_RAISE = 0.25, -- and this much higher, on the cabinet's shelves
	CARD_SIZE = Vector3.new(1.05, 1.5, 0.08), -- the card's 0.7 shape; the client draws the card face on it
	-- Cases with upright cards (Shelves cardsUpright; layout in Config/CaseLayout): each client spins its cards
	-- (CaseSpinController) on a glowing pad and a light beam in the card's rarity colour. Studs and seconds.
	SPIN = {
		SECONDS = 6, -- one full turn
		BOB = 0.08, -- studs up and down
		BOB_SECONDS = 2.4,
		RANGE = 80, -- studs from the camera; further cases stand still
		PAD = Vector3.new(0.06, 0.7, 0.7), -- a glowing disc under each card (cylinder: height, diameter)
		PAD_TRANSPARENCY = 0.2,
		-- the museum vitrine (owner 2026-11-14, concept B): a metal ring round each pad, a soft beam to the case's lid
		-- with a bright core, a light spiralling up it (SWIRL, Util/CaseSwirl) and sparkles rising (SPARKLES)
		RING = Vector3.new(0.08, 0.86, 0.86),
		RING_COLOR = Color3.fromRGB(214, 218, 228),
		BEAM_HEIGHT = 2.4, -- the light beam rising from the pad
		BEAM_WIDTH = 0.9,
		BEAM_TRANSPARENCY = 0.25, -- at its foot; it fades out to the top
		BEAM_BRIGHTNESS = 2, -- over the bloom's threshold: the beams glow
		CORE_WIDTH = 0.3, -- the beam's bright middle
		CORE_TRANSPARENCY = 0.05,
		SWIRL = { seconds = 2.6, turns = 1.6, radius = 0.55, bottom = 0.1, top = 2.3, width = 0.07, lifetime = 1, bead = 0.08, brightness = 3 }, -- thin (owner 2026-11-14)
		SPARKLES = {
			image = "rbxassetid://117269166059195", -- Config/SwordFx TEXTURES.star: a four-point star
			rate = 10,
			lifetime = { 1.6, 2.4 },
			speed = { 0.5, 0.9 },
			spread = 28, -- degrees off straight up
			size = 0.28,
			brightness = 2,
		},
	},
}
