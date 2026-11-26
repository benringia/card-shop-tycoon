--!strict
-- The put-a-card-in windows (owner 2026-11-26: "Card condenser: can we redesign the window. remove the "ALL" tabs and
-- "Need Copies tap". The first tab is now "Condense" ... where the players put the card they want to condense. the
-- condenser then autofills the extra cards(weakest)", "Grading station is confusing too ... an "Upgrade" tab where the
-- player put the specific card they want to upgrade", "Bulkbin ... display a window"; the mockups of artifact
-- 72BD8xZJT75xL5ityfY621, Bulk Bin pick B): the Card Condenser's and the Grading Station's tabs, card slot, card
-- picker and recipe box, and the Bulk Bin window's tiles (client Util/StationPick, CondenserController,
-- GradingController, BulkBinController). Colours as RGB, sizes in pixels before a window's own scale. Plain data:
-- tests/StationLook checks the words read on them.
return {
	-- each station's colours: its chosen tab (fill, edge, words), the empty slot (fill, its + circle, its dashes)
	CONDENSER = {
		band = "Condenser", -- Config/CreamTheme headers: the Bag's pink
		tabOn = { 217, 194, 247 },
		tabEdge = { 180, 138, 230 },
		tabInk = { 59, 35, 80 },
		slot = { 246, 239, 253 },
		plus = { 217, 194, 247 },
		dash = { 180, 138, 230 },
	},
	GRADING = {
		band = "Grading", -- the sky
		tabOn = { 196, 228, 255 },
		tabEdge = { 90, 169, 255 },
		tabInk = { 18, 53, 92 },
		slot = { 238, 247, 255 },
		plus = { 196, 228, 255 },
		dash = { 90, 169, 255 },
	},
	BADGE = { fill = { 245, 184, 46 }, ink = { 74, 48, 0 } }, -- the Ready tab's count, a tile's Ready!
	FILLED = { fill = { 227, 246, 234 }, ink = { 30, 107, 61 } }, -- "Filled in for you: your 4 weakest extras"
	GHOST = { 201, 179, 230 }, -- the empty recipe's dashed spots and arrow
	BOX = { 230, 216, 245 }, -- the slot box's and the recipe box's edge
	RECIPE_FILL = { 246, 239, 253 }, -- the recipe box
	USE_ON = { fill = { 240, 230, 252 }, edge = { 180, 138, 230 } }, -- a Grading USE tile that's in
	COUNT = { fill = { 59, 35, 80 }, ink = { 255, 255, 255 } }, -- a Bulk Bin tile's "x6"
	KEPT = { badge = { 120, 104, 145 }, ink = { 255, 255, 255 }, dash = { 217, 204, 232 }, fade = 0.45 }, -- kept out

	TAB = { hit = 48, pad = 22, gap = 8, textSize = 18, badge = 22 }, -- the tabs: tall, padded, apart, the count's height
	BUTTON = 48, -- Change card, Not now, the picker's Back: finger-sized
	DASH = { length = 10, gap = 6, thick = 3 }, -- a dashed edge's strokes
	BODY_GAP = 14, -- between the tabs and the boxes, and between the two boxes
	EDGE = 16, -- the boxes' distance from the window's sides and bottom
	-- the slot box: its width, the empty slot's size and the card's in it (a computer's, a phone's)
	SLOT_BOX = { desktop = 270, phone = 150 },
	SLOT = { desktop = { 176, 246 }, phone = { 104, 146 } },
	-- the card picker's and the Ready tab's tiles (a computer's, a phone's), the art's share of a tile's height
	TILE = { desktop = { 138, 178 }, phone = { 108, 140 }, gap = 12, art = 0.58 },
	-- the Bulk Bin window's tiles
	BULK_TILE = { desktop = { 116, 140 }, phone = { 96, 118 }, gap = 10, art = 0.6 },
	RECIPE_SPOT_TALL = 80, -- a recipe spot's height at the most (the mockup's 56 x 78 copies)
}
