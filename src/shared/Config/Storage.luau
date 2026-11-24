--!strict
-- Storage racks (spec docs/superpowers/specs/2026-11-24-storage-racks-design.md; owner 2026-11-24: "storage system where
-- box can be put to storage racks. also pets can also carry boxes to the storage racks"; picks: rack look A, the stock
-- clipboard C). The rack itself is Config/Shelves StorageRack (kind "Storage"); its boxes are plain data on the placed
-- rack (PlacementService), drawn as the delivery boxes (server Util/BoxLook). Rules: Util/StorageRules. Plain data, so
-- Lune tests load it.
return {
	-- Where a box stands, in the rack part's own space: the rack faces its part's -Z, so +X is on your left as you face
	-- it. Spot n is on deck ceil(n / 3) (deck tops in studs over the floor), across at x[(n - 1) % 3 + 1]
	SPOTS = { x = { 3, 0, -3 }, decks = { 0.45, 2.7, 4.95 }, boxHeight = 1.5 },
	-- A restocker refills a selling shelf from a rack when it is this full or less (owner's "numbers OK", 2026-11-24)
	LOW_SHARE = 0.5,
	-- A box hopping from your arms to its spot or back (everyone within `range` studs of it sees it: StorageController;
	-- inside ShopDetail.STOCK_SHOW, so a hop never shows a box the far-shop stock LOD keeps hidden)
	HOP = { seconds = 0.3, height = 2.2, range = 60 },
	-- The stock clipboard's line name for each kind of box (tests/StorageRules: every product has one)
	NAMES = {
		FirstSparkPack = "Booster Packs",
		CardSleeves = "Card Sleeves",
		DeckBox = "Deck Boxes",
		FirstSparkBox = "Booster Boxes",
		FrontierPack = "Frontier Packs",
		BulkCards = "Bulk Cards",
	} :: { [string]: string },
	-- What is inside a box, one and many ("62 packs", "1 booster box")
	UNITS = {
		FirstSparkPack = { "pack", "packs" },
		CardSleeves = { "packet", "packets" },
		DeckBox = { "deck box", "deck boxes" },
		FirstSparkBox = { "booster box", "booster boxes" },
		FrontierPack = { "pack", "packs" },
		BulkCards = { "handful", "handfuls" },
	} :: { [string]: { string } },
	WORDS = {
		store = "Store",
		open = "Open",
		rackCount = "Storage Rack · %s",
		empty = "empty",
		oneBox = "1 box",
		boxes = "%d boxes",
		full = "Rack full · %d / %d",
		title = "STORAGE RACK",
		spots = "%d of %d spots",
		countedBy = " · counted by %s",
		nothing = "Nothing stored yet.",
		footer = "Carry a box here to add it to the sheet.",
		take = "TAKE",
		fullRack = "This rack is full. Take a box off, or place another rack.",
		handsFull = "Your hands are full.",
		padFull = "Your delivery pad is full. Put a pad box on a shelf or a rack first.",
		cap = "Your shop has room for %d storage racks. Sell one to make space.",
		sellLocked = "Take the boxes off this rack first.",
		refunded = "Some stored boxes had no room, so you got %s back.",
		storing = "Storing a %s",
		restocking = "Restocking from storage",
		idleFull = "Idle: shelves and storage full",
	},
	-- Look A (the mockup the owner picked): navy steel posts, orange beams, plywood decks, a yellow STORAGE sign
	-- (Util/StorageRackLook). Studs; colours as RGB
	RACK = {
		post = { 44, 56, 92 },
		foot = { 30, 36, 58 },
		beam = { 247, 132, 38 },
		deck = { 222, 188, 140 },
		sign = { 255, 208, 60 },
		signInk = { 30, 36, 58 },
		signText = "STORAGE",
		postWidth = 0.3,
		beamHeight = 0.3,
		beamDepth = 0.14,
		deckThick = 0.08,
		inset = 0.15, -- the posts' centres from the rack's ends and faces
	},
	-- The stock clipboard (mockup C, StorageController): drawn at its layout's `size` and scaled to fit the window. A
	-- computer's is mockup C (one column); a phone's (a short screen, UIKit.isShort) lies on its side with two columns of
	-- taller lines, so a line, its whole width the TAKE button, stays a 48 px tap. Pixels; colours as RGB
	CLIPBOARD = {
		desk = { size = { 460, 504 }, columns = 1, lineHeight = 43, linesTop = 85, titleY = 24, subY = 54 },
		phone = { size = { 640, 330 }, columns = 2, lineHeight = 64, linesTop = 70, titleY = 12, subY = 42 },
		fit = 0.9, -- its share of the room under Roblox's top bar and above the bottom tiles (OrderRules.fit)
		board = { top = { 201, 139, 85 }, bottom = { 168, 105, 58 }, drop = { 125, 74, 36 }, corner = 24, dropY = 6 },
		clip = { width = 150, height = 46, y = -12, top = { 242, 244, 248 }, bottom = { 169, 177, 189 }, hole = { 108, 116, 128 } },
		paper = { color = { 255, 253, 246 }, left = 18, top = 22, right = 18, bottom = 18, corner = 10 },
		inner = { left = 58, top = 34, right = 16, bottom = 12 }, -- the writing on the paper, inside its margin
		rules = { color = { 223, 233, 246 }, thickness = 2 }, -- a ruled line at every line's foot, up the whole paper
		margin = { color = { 235, 110, 120 }, x = 46, width = 2 },
		ink = { 47, 53, 80 },
		inkSoft = { 107, 114, 144 },
		titleSize = 24,
		subSize = 12,
		nameSize = 15,
		smallSize = 12,
		sticker = { size = 36, image = 30, tilt = -4, tape = { 255, 225, 150 } },
		stamp = { color = { 212, 60, 130 }, fill = { 255, 127, 184 }, fillTransparency = 0.88, tilt = -4, stroke = 3, textSize = 15, width = 68, height = 28 },
		close = { size = 40, color = { 255, 127, 184 }, drop = { 212, 60, 130 } },
	},
}
