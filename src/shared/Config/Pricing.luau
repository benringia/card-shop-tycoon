--!strict
-- Player-set sell prices and how customers react to them. See DESIGN.md section 4.4.
return {
	PRICE_STEP = 0.25, -- each +/- tap in the pricing UI
	MIN_PRICE = 0.25,
	MAX_MARKUP = 3, -- highest allowed price as a multiple of market price
	DEFAULT_MARKUP = 1, -- new products start at market price

	SET_COOLDOWN = 0.2, -- seconds between price updates per player
	CLIENT_SEND_DELAY = 0.4, -- client waits this long after the last tap before sending

	-- Price ÷ market price → chance a customer buys. Checked in order; above the last band nobody buys.
	BUY_BANDS = {
		{ maxRatio = 1.0, chance = 0.95, label = "Almost always buy" },
		{ maxRatio = 1.2, chance = 0.5, label = "Sometimes buy" },
		{ maxRatio = 1.5, chance = 0.15, label = "Rarely buy" },
	},
	NEVER_LABEL = "Won't buy, and get annoyed",
	NEVER_TAG = "Won't buy", -- the same, short enough for the Prices window's tag
	-- The Prices window's slim rows (owner 2026-11-03, round 3 pick A): px. A row ROW_HEIGHT tall; on the right one
	-- stepper pill STEPPER wide with round - and + buttons ROUND across inside HIT-sized tap areas, the price between
	ROWS = { ROW_HEIGHT = 64, STEPPER = 148, STEPPER_HEIGHT = 40, ROUND = 30, HIT = 48, PRICE_TEXT = 16, NAME_TEXT = 15, META_TEXT = 12, TAG_HEIGHT = 18 },
}
