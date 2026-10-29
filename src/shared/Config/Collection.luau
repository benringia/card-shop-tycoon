--!strict
-- Binder / card collection. Cards earn money only by being sold from a showcase (Showcase.luau).
-- The binder screen: a 3D binder on a desk (Config/BinderDesk) with the 2D corner buttons, page keys and filters
-- panel over it.
-- See DESIGN.md section 10.6.
return {
	REQUEST_COOLDOWN = 2, -- seconds between "send me my collection" requests

	-- One set at a time, in this order (divider tabs on the binder's right edge)
	SETS = { "First Spark", "Frontier" },
	SET_COLORS = {
		["First Spark"] = Color3.fromRGB(235, 110, 40),
		Frontier = Color3.fromRGB(110, 70, 200),
	} :: { [string]: Color3 },
	SET_EMBLEMS = { ["First Spark"] = "✨", Frontier = "🌌" } :: { [string]: string },

	BOOK = {
		-- Where the binder goes on screen (its shape comes from the 3D binder, BinderDesk.aspect). On roomy screens
		-- it nearly fills the height (MARGIN above, MARGIN_BOTTOM below for the page counter tab); when that would
		-- run into the corner buttons (Cards / Bag / Rarity guide on the left, Filters / close / progress on the
		-- right) it fits between the top and bottom rows instead. Pixels.
		MARGIN = 6, -- from the very top of the screen (the book may rise into Roblox's top bar strip)
		MARGIN_BOTTOM = 50, -- room for the page counter under the book
		TOP_BAND = 64,
		BOTTOM_BAND = 52,
		CORNER_LEFT = 270, -- room the left corner buttons need
		CORNER_RIGHT = 300, -- and the right ones
		SIDE_LANE = 104, -- either side: a page arrow
		NARROW_BELOW = 900, -- screen width: narrower screens drop the arrows (swipe turns pages) for a bigger binder
		-- Narrow screens (phones): the corner buttons go compact (icons only) and stack in slim side lanes, so the
		-- book can take the full height: Cards and Bag down the left edge, Rarity guide bottom left, Filters under
		-- the close button
		NARROW_LEFT = 88,
		NARROW_RIGHT = 80,
		PROGRESS_FROM = 900, -- screen width in pixels: narrower screens skip the progress card (the cover shows it)
		SLIDE_SECONDS = 0.2, -- the camera moving the binder aside while the Filters panel opens
		-- A real binder: dark leather case with stitching, chrome rings on the spine, dark pages with plastic
		-- pocket sleeves; the cover is leather in the set's colour
		CASE = Color3.fromRGB(32, 34, 46),
		CASE_DARK = Color3.fromRGB(18, 19, 28),
		STITCH = Color3.fromRGB(205, 170, 105),
		PAGE_COLOR = Color3.fromRGB(38, 41, 54),
		EDGE = Color3.fromRGB(64, 69, 88),
		SLEEVE = Color3.fromRGB(52, 56, 72), -- a pocket
		SLEEVE_EDGE = Color3.fromRGB(88, 94, 116),
		SLEEVE_SHINE = 0.86, -- the plastic's glint across the card (1 = none)
		CHROME = { Color3.fromRGB(245, 247, 252), Color3.fromRGB(150, 156, 172) },
		INK = Color3.fromRGB(240, 242, 250), -- text on the dark pages
		SUBTEXT = Color3.fromRGB(170, 178, 205),
	},
	FILTERS_WIDTH = 340, -- pixels, the Filters panel on the right
}
