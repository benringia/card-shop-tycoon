--!strict
-- The binder's Filters window (owner 2026-11-03, round 3 "tidy column"): px. Plain data (Lune-tested: tests/UiLayout
-- filtersFrame); Config/Collection serves it as FILTERS. Its body sits `inset` in from the window's edges with `edge`
-- more room inside (outlines and glows never cut off), `gap` between pieces; the search box, header and footer heights;
-- heading text; the five rarity tags wrap into `rarityRows` rows at the window's width. The window is as tall as its
-- content (UiLayout.filtersBody): from `top` (below the binder's close and magnifier) where it ends `bottom` px or
-- more above the screen's bottom (clear of the set progress card); else from `shortTop`, covering those buttons (its
-- own close in their corner), and at most to `shortBottom` above the bottom, the body scrolling on a landscape phone.
return {
	inset = 10,
	edge = 6,
	gap = 8,
	search = 40,
	header = 60, -- UIKit.HEADER_HEIGHT
	footer = 40,
	heading = 12,
	headingRow = 18, -- a heading's row: its text sits on the row's bottom
	top = 140,
	bottom = 100,
	shortTop = 8,
	shortBottom = 8,
	rarityRows = 2,
	zIndex = 8, -- among the binder screen's pieces: over its close (7) and magnifier
}
