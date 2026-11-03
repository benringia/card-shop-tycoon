--!strict
-- The HUD tiles in the cotton candy look (owner 2026-11-03, tile pick 1 "squircle, the icon pops out"; spec
-- 2026-11-03-cotton-candy-ui-design): one rounded square per tile in a baby colour (Config/BabyColors), the icon big
-- and over the top edge, a squishy hover. Plain data (Lune-tested: tests/SquishRules); Config/HudLayout reads its sizes.
return {
	TILE = {
		size = 84, -- px, square
		gap = 20, -- between tiles in a row (and the Manage tray); the owner found 10 too close together
		corner = 0.3, -- corner radius, a share of the tile's width
		outline = 4, -- white outline (px)
		keySize = 24, -- the key letter's white circle (px)
		keyInset = 7, -- its centre sits this far in from the bottom-right corner (px)
		icon = 0.74, -- the icon's size, a share of the tile's width
		iconRise = 0.26, -- how far it sticks out over the top edge, a share of the tile's width
		label = 0.26, -- the label's height, a share of the tile's height
		iconShadow = { drop = 3, transparency = 0.72 }, -- a dark copy of the icon under it (px down, see-through)
		glow = { drop = 5, transparency = 0.4 }, -- the soft glow in the tile's colour under it
		openShade = 0.18, -- the Manage tile deepens this much while its tray is open
	},
	-- Each tile's baby colour; the Manage tray's tiles by their order, round and round
	COLORS = { Manage = "butter", Cards = "sky", Bag = "pink", Bosses = "lilac", Admin = "greyLilac", Rip = "peach", Drop = "peach" },
	FAN = { "mint", "peach", "sky", "lilac" },
	-- The hover, mouse only: each step tweens the tile's body to x wide, y tall (shares of its size, from its bottom
	-- centre) and lift px up, in order; a gentle squash, a small stretch as it hops, a little rebound, the settle (the
	-- owner asked for a subtler bounce). Leaving springs it back to rest in `release` s. A press squashes it (on touch
	-- too) and springs back the same way.
	SQUISH = {
		steps = {
			{ seconds = 0.09, x = 1.04, y = 0.95, lift = 0 },
			{ seconds = 0.12, x = 0.98, y = 1.05, lift = 5 },
			{ seconds = 0.11, x = 1.02, y = 0.99, lift = 3 },
			{ seconds = 0.11, x = 1.03, y = 1.03, lift = 4 },
		},
		release = 0.24,
		press = { seconds = 0.06, x = 1.05, y = 0.9 },
	},
}
