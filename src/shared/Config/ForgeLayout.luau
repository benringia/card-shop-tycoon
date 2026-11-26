--!strict
-- The Forge window's pane on phones (final review 2026-11-08: on a 667 x 375 phone what a weapon costs opened below
-- the fold). A picture recipe since 2026-11-20 (Util/Recipe): on a short screen its sentence, then the spots, the arrow
-- and a small card with its pill under it; a Forge weapon's element buttons come first, its sentence under the recipe;
-- the tab's line last. The weapon's name and grade are already on its list row. Pixel heights of each piece, checked
-- by tests/UiLayout through UiLayout.forgePhonePane and forgePhoneContent. Plain data.
return {
	HEADER = 60, -- UIKit.HEADER_HEIGHT: the window's title band
	INSET = 58, -- the most Roblox's top bar takes off the screen (the main ScreenGui keeps it)
	PANEL = 0.96, -- the window's height on phones, of the screen under the top bar
	LIST_GAP = 8, -- the list and the pane start this far under the title band
	ACTION = 52, -- the pinned button's height
	ACTION_ROOM = 28, -- the gaps above and under the button
	PAD = 6, -- the pane's padding, top and bottom
	GAP = 6, -- between the pane's rows
	CARD = { w = 44, h = 62 },
	SAY = 30, -- the sentence: two lines
	UNDER = 28, -- under the card: its pill
	-- the recipe's spots: their area's width (what the pane leaves beside the arrow and the card, between `min` and
	-- `max`; phones, all in one row: up to `phoneMax`) and a spot's height at the most
	SLOTS = { min = 130, max = 200, phoneMax = 230, tall = 88 },
	ELEMENT = 52, -- the element buttons' row (48 px buttons)
	-- The Mutate tab's current mutation (owner 2026-11-26: "make sure the mutation on this window is noticeable", the
	-- mockup's row): a row in the rarity colour under the recipe (`fill`: its colour this far to white; `ink`, `labelInk`:
	-- its words this far to black), `height` on a computer; on a phone a slim `phone` row comes first, over the recipe,
	-- so it stays above the fold. `chip`: a list row's mutation (the card's own glowing edge: WeaponLooks.CARD.mutation)
	MUTATION_ROW = {
		width = 420,
		height = 44,
		phone = 24,
		icon = 32,
		phoneIcon = 20,
		glyph = 22,
		label = 10,
		title = 15,
		phoneTitle = 12,
		pill = 11,
		fill = 0.86,
		ink = 0.38,
		labelInk = 0.45,
		none = { 201, 169, 220 }, -- no mutation yet: lilac
		chip = { height = 18, text = 11, icon = 14 },
	},
}
