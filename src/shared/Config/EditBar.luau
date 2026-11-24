--!strict
-- The Edit bar (owner 2026-11-23, mockup C "Action bar"; Util/EditBarRules says what a thing offers, EditBarController
-- draws it): Edit on anything placed in your shop (shelves, cases, machines, trophies, decor, windows and posters)
-- lights the thing up and swaps the bottom-centre tiles for a bar: its name, a status chip and a hint line on the left,
-- its own candy tiles (the HUD's, Util/Hud.candyTile) and a close button. It is not a window: the world stays in view
-- and you can walk away, which closes it. Plain data.
return {
	HOLD_SECONDS = 0.8, -- Sell is held down this long (the tile fills from the bottom); let go early and nothing happens
	REACH = 18, -- studs: further than this from the thing, the bar closes
	CHECK_SECONDS = 0.25, -- how often it checks the distance and a machine's clock
	-- Each tile's baby colour (Config/BabyColors) by EditBarRules tile id; a resting or locked tile is `off`
	COLORS = {
		use = "mint",
		cards = "butter",
		unstock = "peach",
		move = "sky",
		sell = "pink",
		bag = "lilac",
		takeDown = "peach",
		off = "greyLilac",
	},
	-- Each tile's icon (Config/UIIcons); `use` by the machine's kind: its own picture (the Recycler: cards going in).
	-- Colour pictures only: the icon pops out over the tile's top edge onto the bar's light face, where a white glyph
	-- would vanish. `Move` is four arrows (owner 2026-11-23: "change the MOVE icon"; the map pin before)
	ICONS = {
		cards = "Cards",
		unstock = "Box",
		move = "Move",
		sell = "Coin",
		bag = "Bag",
		takeDown = "Remove",
		lock = "Lock",
		use = { Condenser = "Condenser", Grading = "GradingSeal", Forge = "Anvil", Recycler = "Copies", Storage = "Box" },
	},
	-- The status chip's colour by EditBarRules tone
	CHIP = { empty = "greyLilac", full = "sky", good = "mint", busy = "butter", ready = "butter", plain = "lilac" },
	-- px at full scale (the bar grows and shrinks with the HUD: Hud.scaleWith)
	INFO = { width = 200, phoneWidth = 136, name = 21, chip = 13, hint = 12 },
	-- the top leaves room for the icons over the tiles; the right for the round close button on the corner (it covered
	-- the last tile's icon at 24, seen in Studio 2026-11-23)
	PADDING = { left = 22, right = 50, top = 26, bottom = 12 },
	DIM = 0.5, -- a resting or locked tile's icon this see-through (the mockup's faded coin)
	GAP = 14, -- between the info and the tiles, and between tiles
	SUB = 12, -- the line under each tile
	LOCK = 30, -- the padlock on a locked tile's corner
	-- The thing in the world while its bar is up: a mint outline and a faint mint fill (the Shop window's band colour)
	HIGHLIGHT = { color = { 63, 214, 160 }, fill = 0.85, outline = 0 },
	HOLD_SHADE = 0.25, -- the Sell tile darkens this much as it fills
}
