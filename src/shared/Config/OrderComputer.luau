--!strict
-- The order computer (owner 2026-11-21: "redesign it to be fully immersive computer shopping layout", pick A): a
-- cotton candy tablet with a browser open on the store, product cards with a stepper, a cart beside them and a
-- taskbar with the town's clock (client OrderController, rules in Util/OrderRules). A monitor on a stand until
-- 2026-11-22 (owner: "remove the monitor stand to make it look like an ipad because its overlaping with the bottom
-- tile"): now a tablet with even bezels, fitted above the bottom tiles (OrderRules.fit). A phone gets the same store
-- on a thin screen: four cards in a row, the cart as a bar along the bottom. Sizes are px at scale 1; the whole
-- computer is scaled to fit the screen. Plain data (Lune-tested: tests/OrderRules).
return {
	WORDS = {
		-- The store's name (owner 2026-11-21 asked for "packenshit.co"; a swear word puts a Roblox game in the Restricted
		-- label, 17+ ID-verified only, so it's "packenship.co": a pack and ship pun)
		STORE = "packenship.co",
		URL_ORDER = "packenship.co/order",
		URL_DELIVERIES = "packenship.co/deliveries",
		NAV_ORDER = "Order stock",
		NAV_DELIVERIES = "My deliveries",
		CART = "Your cart",
		TOTAL = "Total",
		EMPTY_CART = "Tap Add to cart on a box to start your order.",
		COMING = "On the way",
		NO_DELIVERIES = "Nothing on the way. Order some stock!",
		PAD_HINT = "Boxes land on your delivery pad. Carry them to your shelves!",
		SENDING = "Sending...",
		ORDERED = "Ordered!",
	} :: { [string]: string },

	-- A product's shelves this full or less get the "Shelves low" tag
	LOW_SHARE = 0.25,
	-- How often the open store looks again at the shelves (the tag) and the clock, seconds
	REFRESH = 1,
	-- Order now waits this long for the server's answer before it can be pressed again, seconds
	SEND_WAIT = 2,
	-- How much of its room the computer fills each way: the room under Roblox's top bar, above the bottom tiles while
	-- they show (OrderRules.fit)
	FIT = 0.96,

	DESKTOP = {
		MONITOR = { 960, 600 }, -- the tablet, its edge under it included
		BEZEL = 20, -- px of bezel round the screen, even all round like a tablet's
		LIP = 8, -- px of the tablet's edge showing under it
		CORNER = 34, -- the tablet's rounded corners, px
		BROWSER_INSET = 10, -- the wallpaper showing round the browser
		TASKBAR = 40,
		TASKBAR_GAP = 8, -- under the taskbar
		TAB_ROW = 34,
		ADDRESS = 36,
		SITE_HEADER = 50,
		PAD = 12, -- inside the store's page
		GAP = 10, -- between cards
		CART_WIDTH = 256,
		PICTURE = 92, -- a card's picture panel, wide
		STEP = 36, -- a stepper button
		ADD_HEIGHT = 40,
		CHECKOUT_HEIGHT = 52,
		TEXT = { NAME = 18, META = 13, PILL = 12, PRICE = 24, COUNT = 19, SMALL = 13, LINE = 14, TOTAL = 24, BUTTON = 18, LOGO = 20, NAV = 13, URL = 13, CLOCK = 14 },
	},

	-- A phone's screen is short (280 px under Roblox's top bar on a Galaxy A06): a low screen so the computer is scaled
	-- down less, and the cards skip the sell line (the profit pill says it)
	PHONE = {
		MONITOR = { 760, 300 },
		BEZEL = 6,
		HEADER = 40,
		BAR = 56, -- the cart along the bottom
		PAD = 8,
		GAP = 8,
		PICTURE_HEIGHT = 44,
		STEP = 40, -- a stepper button
		ADD_HEIGHT = 44,
		CHECKOUT = { 156, 44 },
		NAV_HEIGHT = 30,
		TEXT = { NAME = 14, PILL = 12, PRICE = 18, COUNT = 17, LOGO = 17, NAV = 12, SUMMARY = 16, SMALL = 11, BUTTON = 18 },
	},

	-- Colours (RGB): the cotton candy tablet and the store's sky blue (the mockups' own)
	COLORS = {
		BEZEL_TOP = { 255, 250, 255 },
		BEZEL_BOTTOM = { 241, 228, 250 },
		BEZEL_LIP = { 216, 192, 234 },
		BEZEL_INK = { 180, 154, 200 }, -- the camera dot, the address bar's arrows
		SCREEN_EDGE = { 226, 207, 240 },
		WALL_TOP = { 185, 225, 255 }, -- the wallpaper: sky to lilac to pink
		WALL_MIDDLE = { 230, 216, 255 },
		WALL_BOTTOM = { 255, 217, 236 },
		BROWSER = { 255, 248, 253 },
		TAB_ROW = { 239, 227, 248 },
		URL = { 243, 230, 248 },
		URL_INK = { 123, 90, 142 },
		DOT_PINK = { 255, 127, 184 },
		DOT_BUTTER = { 255, 201, 63 },
		DOT_MINT = { 63, 214, 160 },
		SITE_TOP = { 130, 202, 255 },
		SITE_BOTTOM = { 79, 180, 255 },
		SITE_INK = { 28, 120, 200 }, -- the logo's shadow, the chosen tab's words
		PAGE_TOP = { 255, 248, 253 },
		PAGE_BOTTOM = { 246, 236, 255 },
		CARD = { 255, 255, 255 },
		CARD_EDGE = { 240, 222, 245 },
		CARD_LIP = { 230, 205, 238 },
		LOCKED_CARD = { 247, 240, 250 },
		LOCKED_EDGE = { 224, 203, 236 },
		LOCKED_PICTURE = { 236, 226, 242 },
		LOCK_INK = { 150, 80, 12 },
		STEPPER = { 243, 230, 248 },
		PROFIT = { 22, 112, 52 },
		TAG = { 255, 127, 184 },
		INK = { 91, 61, 110 },
		INK_SOFT = { 123, 90, 142 },
		DELIVERY = { 233, 246, 255 },
		DELIVERY_INK = { 28, 95, 153 },
		DELIVERY_SOFT = { 61, 106, 143 },
		BAR_TRACK = { 207, 230, 251 },
		BAR_FILL = { 79, 180, 255 },
		BAR_CART = { 160, 212, 255 }, -- the cart's share of the pad, after the boxes already there
		TASKBAR = { 255, 255, 255 },
		COIN = { 255, 201, 63 },
		COIN_INK = { 122, 79, 0 },
	} :: { [string]: { number } },
	-- A card's picture panel: the product's colour this far toward white
	PICTURE_TINT = 0.82,
}
