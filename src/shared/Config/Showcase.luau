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
	SLOTS_OFFSET_Y = -0.35, -- shifts the card grid down, below the label
	CASED_CARD_INSET = 0.45, -- cases drawn with a prop: cards stand this far behind the case's front face
	CASED_CARD_RAISE = 0.25, -- and this much higher, on the cabinet's shelves
	CARD_SIZE = Vector3.new(1.5, 1.4, 0.1),
	-- Glass counters (Shelves cardsFlat, drawn with a prop): smaller cards lying on the bed, leaning up toward
	-- the front so customers can read them. BED = height of the bed as a fraction of the case height.
	FLAT = { SCALE = 0.62, BED = 0.74, TILT = 20, SPACING = Vector2.new(1.9, 0.95) },
	LABEL_HEIGHT = 0.2, -- fraction of the case face used for its label
}
