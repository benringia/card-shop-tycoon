--!strict
-- The windows' look. Was cream & candy (spec 2026-11-03-cream-windows-design); now cotton candy (owner 2026-11-03, look
-- A; spec 2026-11-03-cotton-candy-ui-design): milky pink-lavender bodies with thick white outlines and a soft lilac
-- glow, white rows with a soft lilac base line, plum text, header bands in the baby colour of each window's HUD button
-- (Config/BabyColors). The code still calls this theme "cream". UIStyle turns these into Color3s; UIKit builds the
-- windows with them (the binder and the fight screens keep the dark tokens). Plain data: tests/ContrastRules.
return {
	bodyTop = { 255, 248, 253 },
	bodyBottom = { 246, 236, 255 },
	row = { 255, 255, 255 }, -- rows, slots, stat cards
	rowEdge = { 240, 222, 245 }, -- their soft lilac edge and base line
	rowBase = { 230, 205, 238 }, -- a deeper line along their bottom
	slotEmpty = { 244, 230, 250 },
	ink = { 91, 61, 110 }, -- body text and numbers: plum
	inkSoft = { 123, 90, 142 }, -- secondary text (still 4.5:1 on the body)
	hint = { 150, 80, 12 }, -- hints and small headings: a dark amber that reads on white and lilac
	-- Meaning colours deep enough to read on cream (the dark windows' bright ones don't)
	good = { 22, 112, 52 }, -- fast, ready, better
	bad = { 176, 40, 40 }, -- resting, mistakes, not enough
	power = { 160, 74, 8 }, -- Power numbers; also "pricey" and "rarely buy" (the price bands: good, fair, power, bad)
	fair = { 112, 96, 0 }, -- "fair" and "sometimes buy": a dark mustard, its own hue between the green and the orange
	track = { 243, 230, 248 }, -- bar tracks
	outline = { 255, 255, 255 },
	outlineThickness = 4, -- the window's outline (px)
	buttonOutline = 3, -- buttons', pills' and chips' outlines (px)
	corner = 22,
	shadow = { offset = 6, transparency = 0.8 },
	-- Header bands, top to bottom: the baby colour (Config/BabyColors) of the window's HUD button, from halfway to its
	-- light shade down to the full colour (Bag pink, Cards sky, Bosses and Party lilac, Shop mint, Prices peach, Jobs
	-- sky, the rest sky)
	headers = {
		Bag = { top = { 255, 163, 205 }, bottom = { 255, 127, 184 } },
		Cards = { top = { 130, 202, 255 }, bottom = { 79, 180, 255 } },
		Bosses = { top = { 191, 160, 255 }, bottom = { 162, 116, 255 } },
		Party = { top = { 191, 160, 255 }, bottom = { 162, 116, 255 } },
		Shop = { top = { 116, 228, 187 }, bottom = { 63, 214, 160 } },
		Prices = { top = { 255, 178, 146 }, bottom = { 255, 148, 104 } },
		Jobs = { top = { 130, 202, 255 }, bottom = { 79, 180, 255 } },
		Default = { top = { 130, 202, 255 }, bottom = { 79, 180, 255 } },
	},
}
