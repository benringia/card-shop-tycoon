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
		-- The book keeps an open binder's shape (width / height). On roomy screens it nearly fills the height
		-- (MARGIN above, MARGIN_BOTTOM below for the page counter tab); when that would run into the corner
		-- buttons (Cards / Bag / Rarity guide on the left, Filters / close / progress on the right) it fits
		-- between the top and bottom rows instead. Pixels.
		ASPECT = 1.36, -- a touch narrower than wide-open, so it stands taller
		MARGIN = 6, -- from the very top of the screen (the book may rise into Roblox's top bar strip)
		MARGIN_BOTTOM = 50, -- room for the page counter under the book
		TOP_BAND = 64,
		BOTTOM_BAND = 52,
		CORNER_LEFT = 270, -- room the left corner buttons need
		CORNER_RIGHT = 300, -- and the right ones
		SIDE_LANE = 152, -- either side: a set tab and a page arrow
		NARROW_BELOW = 900, -- screen width: narrower screens drop the arrows (swipe turns pages) for a bigger book
		NARROW_LANE = 72, -- and keep only room for the set tabs
		TAB_WIDTH = 64, -- set bookmark tabs sticking out of the book's left edge
		TAB_HEIGHT = 88,
		PROGRESS_FROM = 900, -- screen width in pixels: narrower screens skip the progress card (the cover shows it)
		SLIDE_SECONDS = 0.2, -- the book shrinking left while the Filters panel is open
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
		BACKDROP_TRANSPARENCY = 0.4, -- the world, dimmed, behind the book
		INK = Color3.fromRGB(240, 242, 250), -- text on the dark pages
		SUBTEXT = Color3.fromRGB(170, 178, 205),
		-- Page turn: the page rotates about the spine and lands on the other side showing the next cards
		FLIP_SECONDS = 0.35,
		FLIP_SHADE = 0.55, -- how dark a page gets edge-on (0 none, 1 black)
		FLIP_LIFT = 0.07, -- how much it swells as it lifts toward the viewer
		FLIP_SHADOW = 0.35, -- how far its shadow stretches past it, of a page's width
		SWIPE = true, -- phones: swipe across the book to turn pages
	},
	FILTERS_WIDTH = 340, -- pixels, the Filters panel on the right
}
