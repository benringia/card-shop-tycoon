--!strict
-- Glass Showcase and Collector Case card layout (UI project 3 spec section 3): the cards stand upright over their
-- slots and spin (CaseSpinController). Plain data, so Lune tests load it (Config/Showcase holds Vector3s).
-- Studs, in the case part's space; the case is 6 x 4 x 2 (Config/Shelves).
return {
	UPRIGHT = {
		cardSize = { x = 0.84, y = 1.2 }, -- today's 1.05 x 1.5 card at 0.8, so spinning neighbours never touch
		columns = 3, -- cards per row
		spacing = 1.9, -- between card centres in a row
		rowDepth = 1.0, -- front row to back row (more than a card's width: they spin clear of each other)
		backRaise = 0.6, -- the back row stands this much higher, so it shows over the front one
		bedHeight = 0.3, -- the front cards' feet, as a share of the case height from its bottom
	},
}
