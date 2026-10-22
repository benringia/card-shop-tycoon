--!strict
-- Binder / card collection. Cards earn money only by being sold from a showcase (Showcase.luau).
-- The binder screen: a full-screen book (cover page per set, set tabs, page keys, filters panel).
-- See DESIGN.md section 10.6.
return {
	REQUEST_COOLDOWN = 2, -- seconds between "send me my collection" requests

	-- One binder per set, in this order (set tabs on the book's left edge)
	SETS = { "First Spark", "Frontier" },
	SET_COLORS = {
		["First Spark"] = Color3.fromRGB(235, 110, 40),
		Frontier = Color3.fromRGB(110, 70, 200),
	} :: { [string]: Color3 },
	SET_EMBLEMS = { ["First Spark"] = "✨", Frontier = "🌌" } :: { [string]: string },

	BOOK = {
		WIDTH = 0.8, -- of the screen, then kept to ASPECT (width / height)
		HEIGHT = 0.8,
		ASPECT = 1.5,
		CENTRE_Y = 0.47,
		FILTER_SCALE = 0.72, -- the book while the Filters panel is open
		FILTER_X = 0.36, -- and its centre
		SLIDE_SECONDS = 0.2,
		COLOR = Color3.fromRGB(24, 28, 48),
		PAGE_COLOR = Color3.fromRGB(40, 44, 66),
		STITCH = Color3.fromRGB(205, 165, 80),
	},
	FILTERS_WIDTH = 340, -- pixels, the Filters panel on the right
}
