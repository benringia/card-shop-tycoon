--!strict
-- Shop windows (spec docs/superpowers/specs/2026-11-14-shop-windows-design.md; owner: "I want an actual window player
-- can put on their walls"): real see-through windows cut into a shop's side and back walls (WindowService,
-- PlotService.SetWindows, Util/WindowLooks; rules in Util/WindowRules). Plain data so Lune tests load it.
-- Studs, dollars; `needs` an achievement as Config/Titles checks it (Util/TitleRules), `how` its words on a locked tile.
return {
	MAX = 6, -- windows a shop
	GRID = 2, -- a window's middle snaps to whole multiples of this along the wall
	CORNER = 1, -- studs of wall kept clear at each end of a wall
	GAP = 1, -- studs of wall kept between two windows
	-- the window's bottom stands this far over the floor: the decor band's top (Config/Decor SHELL BAND + TRIM) plus 1
	SILL = 4.7,
	SELL_REFUND = 0.5, -- of the price paid, as shelves
	-- inside lengths of the walls a window can go on (Config/Plots DEPTH for the sides, WIDTH for the back)
	WALLS = { left = 40, right = 40, back = 40 },
	SIDES = { "left", "right", "back" },
	ORDER = { "Square", "Wide", "Arched", "Porthole", "Stained" },
	STYLES = {
		Square = { name = "Square Window", width = 4, height = 4, price = 300, level = 3, points = 2 },
		Wide = { name = "Wide Window", width = 8, height = 4, price = 600, level = 6, points = 2 },
		Arched = { name = "Arched Window", width = 4, height = 7, price = 900, level = 9, points = 2 },
		Porthole = {
			name = "Porthole",
			width = 4,
			height = 4,
			price = 1200,
			level = 1,
			points = 2,
			needs = { kind = "bossClear", boss = "frostTyrant" },
			how = "Beat the Frost Tyrant",
		},
		Stained = {
			name = "Stained Glass Window",
			width = 4,
			height = 7,
			price = 2500,
			level = 1,
			points = 3,
			needs = { kind = "bossClear", boss = "prismHydra" },
			how = "Beat the Prism Hydra",
		},
	},
}
