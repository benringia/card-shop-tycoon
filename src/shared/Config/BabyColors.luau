--!strict
-- The cotton candy look's baby colours (owner 2026-11-03, look A; spec 2026-11-03-cotton-candy-ui-design): six bright
-- pastels that pop, each with a light shade (gradient tops, glows) and a deep shade (the outline round white labels,
-- a portrait rim's underside). Plain data (Lune-tested: tests/SoftColors); UIStyle.BABY turns them into Color3s.
return {
	COLORS = {
		pink = { fill = { 255, 127, 184 }, light = { 255, 196, 223 }, deep = { 212, 60, 130 } }, -- bubblegum
		mint = { fill = { 63, 214, 160 }, light = { 169, 242, 213 }, deep = { 24, 140, 100 } },
		sky = { fill = { 79, 180, 255 }, light = { 180, 224, 255 }, deep = { 28, 120, 200 } },
		lilac = { fill = { 162, 116, 255 }, light = { 220, 203, 255 }, deep = { 118, 70, 217 } },
		butter = { fill = { 255, 201, 63 }, light = { 255, 231, 163 }, deep = { 176, 118, 0 } },
		peach = { fill = { 255, 148, 104 }, light = { 255, 208, 187 }, deep = { 205, 84, 46 } },
		greyLilac = { fill = { 185, 169, 207 }, light = { 222, 213, 234 }, deep = { 112, 94, 138 } }, -- disabled, Admin
		white = { fill = { 255, 255, 255 }, light = { 255, 255, 255 }, deep = { 217, 200, 230 } }, -- neutral buttons
	},
	INK = { 91, 61, 110 }, -- plum: text on light buttons
	LIGHT_LUMA = 0.75, -- fills brighter than this (butter, white) take plum text; the rest white with a deep outline
	-- The kit's named colours (UIKit.Colors) and the baby colour each becomes in the soft look
	ROLES = {
		Accent = "butter", -- the main action
		Secondary = "sky", -- other choices
		Danger = "pink", -- remove or leave
		Success = "mint", -- summoned, confirm
		Locked = "greyLilac", -- can't be used now
		-- Neutral buttons (Colors.Row, Colors.Panel, and the window's own white row and pale slot colours passed as a
		-- button's fill) are sky like the mockup's, never white (owner 2026-11-03: no white glossy buttons)
		Row = "sky",
		Panel = "sky",
		Neutral = "sky",
	},
	-- Each element's colour on a party portrait's rim
	ELEMENTS = { Ember = "peach", Tide = "sky", Bloom = "mint", Volt = "butter", Shade = "lilac" },
	-- The soft glow (tools/ui-art/make_soft_glow.py, assets/ui/soft/Glow.png): a blurred rounded square with the square
	-- cut out, SIZE px; the square sits MARGIN px in with a CORNER px radius. UIKit.glow 9-slices it at MARGIN + CORNER
	-- and scales the slices so the hole's corner matches the thing it glows round.
	GLOW = { image = "rbxassetid://110423921326900", size = 128, margin = 32, corner = 24 },
	-- A soft button (UIKit.button in a themed window or the binder), like the mockup's (owner 2026-11-03: exactly like
	-- it, no gloss, no grey hover): its white outline and corner (px), a glow you can see dropped under it (px, see-through
	-- share), a soft outline round white text (px, see-through share), and how much it grows under a mouse (a row in a
	-- window grows a little less)
	SOFT_BUTTON = {
		outline = 3,
		corner = 16,
		glowDrop = 6,
		glowTransparency = 0.2,
		textOutline = { thickness = 1, transparency = 0.4 },
		hoverScale = 1.04,
		rowHoverScale = 1.015,
	},
	-- A segmented switch (UIKit.segmented: the binder's Filters, round 3): the pill drawn `height` px tall inside a
	-- `hit` px tap row, inner padding, text size; and a dot tag (UIKit.dotTag: the rarity picks): drawn `height` px tall
	-- inside a `hit` px tap area, its dot's size, text size. Taps stay finger-sized (48 px) on phones.
	SEGMENTED = { height = 40, hit = 48, padding = 4, textSize = 14 },
	DOT_TAG = { height = 32, hit = 48, dot = 14, textSize = 13 },
	-- The soft glow under a window instead of the dark shadow: its colour (a COLORS name), drop (px), see-through share
	WINDOW_GLOW = { color = "lilac", drop = 10, transparency = 0.35 },
}
