--!strict
-- The Forge window's pane on phones (final review 2026-11-08: on a 667 x 375 phone the Now/After boxes and the costs
-- opened below the fold). On a short screen the boxes (or a Forge weapon's element buttons) sit beside a small card,
-- the cost chips under them and the tab's line last; the weapon's name and grade are already on its list row. Pixel
-- heights of each piece (a label is its font size + 4), checked by tests/UiLayout through UiLayout.forgePhonePane and
-- forgePhoneContent. Plain data.
return {
	HEADER = 60, -- UIKit.HEADER_HEIGHT: the window's title band
	INSET = 58, -- the most Roblox's top bar takes off the screen (the main ScreenGui keeps it)
	PANEL = 0.96, -- the window's height on phones, of the screen under the top bar
	LIST_GAP = 8, -- the list and the pane start this far under the title band
	ACTION = 52, -- the pinned button's height
	ACTION_ROOM = 28, -- the gaps above and under the button
	PAD = 6, -- the pane's padding, top and bottom
	GAP = 8, -- between the pane's rows
	CARD = { w = 44, h = 62 },
	-- a Now / After box: padding (top and bottom), its title, value and lines (font + 4 each) and the gaps between
	BOX = { pad = 12, title = 15, big = 22, line = 16, gap = 2, lines = 1, side = 6 },
	CHIP = 34, -- one row of cost chips: a 24 px picture and 5 px either side
	ELEMENT = 52, -- the element buttons' row (48 px buttons)
}
