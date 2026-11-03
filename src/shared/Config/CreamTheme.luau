--!strict
-- The windows' cream & candy look (spec 2026-11-03-cream-windows-design, the owner's pick A): cream bodies with thick
-- white outlines and soft shadows, white rows with soft cream edges, brown text, header bands in the colour of each
-- window's HUD button (Config/HudLayout CANDY). UIStyle turns these into Color3s; UIKit builds cream windows with them
-- (the binder and the fight screens keep the dark tokens). Plain data: tests/ContrastRules checks the text reads.
return {
	bodyTop = { 255, 248, 238 },
	bodyBottom = { 246, 227, 201 },
	row = { 255, 255, 255 }, -- rows, slots, stat cards
	rowEdge = { 240, 220, 194 }, -- their soft edge
	rowBase = { 233, 207, 174 }, -- the darker line along their bottom
	slotEmpty = { 245, 230, 209 },
	ink = { 107, 74, 42 }, -- body text and numbers
	inkSoft = { 124, 90, 58 }, -- secondary text (still 4.5:1 on the body)
	hint = { 150, 80, 12 }, -- hints and small headings: a dark amber that reads on white and cream
	track = { 242, 227, 207 }, -- bar tracks
	outline = { 255, 255, 255 },
	outlineThickness = 4, -- the window's outline (px)
	buttonOutline = 3, -- buttons', pills' and chips' outlines (px)
	corner = 22,
	shadow = { offset = 6, transparency = 0.8 },
	-- Header bands, top to bottom, matching the HUD buttons
	headers = {
		Bag = { top = { 255, 158, 122 }, bottom = { 240, 96, 60 } },
		Cards = { top = { 127, 184, 255 }, bottom = { 74, 127, 224 } },
		Bosses = { top = { 199, 155, 255 }, bottom = { 138, 85, 224 } },
		Party = { top = { 196, 170, 255 }, bottom = { 140, 104, 226 } },
		Shop = { top = { 140, 228, 176 }, bottom = { 62, 182, 120 } },
		Prices = { top = { 128, 214, 240 }, bottom = { 56, 160, 210 } },
		Jobs = { top = { 255, 166, 200 }, bottom = { 232, 96, 150 } },
		Default = { top = { 128, 214, 240 }, bottom = { 56, 160, 210 } },
	},
}
