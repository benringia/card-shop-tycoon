--!strict
-- The HUD layout (client only): candy icon tiles on the left (Manage, with its tray) and bottom centre (Cards,
-- Bag, Bosses, and contextual tiles like Rip a pack). Cash, shards and level sit in the bottom-right corner (UIController). Pixels. See DESIGN.md (UI) and Util/Hud.
return {
	TILE_SIZE = Vector2.new(84, 84),
	SIDE_X = 12, -- left edge of the side column
	BOTTOM_MARGIN = 16, -- the bottom row sits this far above the screen's bottom
	GAP = 10,
	TRAY = { PADDING = 8, TRANSPARENCY = 0.35 }, -- the bar the Manage tiles slide out in
	KEY_CHIP = Color3.fromRGB(14, 16, 24),
	-- The creature pals look (spec 2026-11-03-hud-creature-pals-design): each tile in its own soft gradient with a thick
	-- white outline and a soft shadow; some get little ears or horns poking out of the top. Unknown ids look like Manage.
	CANDY = {
		Cards = { top = Color3.fromRGB(127, 184, 255), bottom = Color3.fromRGB(74, 127, 224), topper = "ears" },
		Bag = { top = Color3.fromRGB(255, 158, 122), bottom = Color3.fromRGB(240, 96, 60), topper = "ears" },
		Bosses = { top = Color3.fromRGB(199, 155, 255), bottom = Color3.fromRGB(138, 85, 224), topper = "horns" },
		Manage = { top = Color3.fromRGB(255, 211, 107), bottom = Color3.fromRGB(242, 165, 43) },
		Admin = { top = Color3.fromRGB(176, 184, 198), bottom = Color3.fromRGB(122, 130, 148) },
		Rip = { top = Color3.fromRGB(255, 176, 96), bottom = Color3.fromRGB(245, 140, 40) },
		Drop = { top = Color3.fromRGB(255, 176, 96), bottom = Color3.fromRGB(245, 140, 40) },
	},
	-- The Manage tray's tiles, by their order, round and round: soft mint, sky, pink, lilac
	CANDY_FAN = {
		{ top = Color3.fromRGB(140, 228, 176), bottom = Color3.fromRGB(62, 182, 120) },
		{ top = Color3.fromRGB(128, 214, 240), bottom = Color3.fromRGB(56, 160, 210) },
		{ top = Color3.fromRGB(255, 166, 200), bottom = Color3.fromRGB(232, 96, 150) },
		{ top = Color3.fromRGB(196, 170, 255), bottom = Color3.fromRGB(140, 104, 226) },
	},
	CANDY_OPEN_SHADE = 0.18, -- the Manage tile darkens this much while its tray is open
	OUTLINE = 4, -- the tiles' white outline (px at full scale)
	SHADOW = { offset = 5, transparency = 0.75 },
	CORNER = 0.27, -- corner radius, a share of the tile's width
	EAR = 0.26, -- ear size, a share of the tile's width
	HORN = 0.24,
	KEY_SIZE = 24,
	-- Bouncy hover on the tiles (owner 2026-11-03, pick 1 of 3): lift in px, grow, the shadow's offset while lifted, ear
	-- and horn tilt in degrees, seconds (eased with a soft overshoot)
	HOVER = { lift = 6, scale = 1.07, shadow = 9, ear = 14, seconds = 0.35 },
	-- The status corner in the same look: a green cash pill with a gold coin, a white level pill with a gold star and
	-- paw prints that fill with XP (Util/XpPaws), a white buff chip
	CASH = { top = Color3.fromRGB(142, 224, 154), bottom = Color3.fromRGB(63, 179, 90) },
	PILL_EDGE = Color3.fromRGB(236, 224, 208), -- the white pills' soft edge
	PAWS = 5,
	PAW_SIZE = 18,
	XP_TEXT = 12, -- the XP numbers under the paws (px)
	XP_TEXT_COLOR = Color3.fromRGB(107, 74, 42),
	PAW_ON = Color3.fromRGB(255, 154, 58), -- a filled paw's tint (the icon is white with a dark outline)
	PAW_OFF = Color3.fromRGB(205, 196, 186), -- an empty paw's tint
	PAW_OFF_TRANSPARENCY = 0.55,
	STATUS_ICON = 54, -- the coin and the star, bigger than their pills
	-- The whole HUD shrinks with the screen's height on small screens (landscape phones): 1 at REFERENCE_HEIGHT
	-- and up, never below MIN (tiles stay over 48 px to tap)
	SCALE = { REFERENCE_HEIGHT = 560, MIN = 0.7 },
}
