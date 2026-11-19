--!strict
-- Shop windows (spec docs/superpowers/specs/2026-11-14-shop-windows-design.md; owner: "I want an actual window player
-- can put on their walls"): real see-through windows cut into a shop's side and back walls (WindowService,
-- PlotService.SetWindows, Util/WindowLooks; rules in Util/WindowRules). Plain data so Lune tests load it.
-- Studs, dollars; `needs` an achievement as Config/Titles checks it (Util/TitleRules), `how` its words on a locked tile.
return {
	MAX = 6, -- windows a shop
	-- Posters (owner 2026-11-19: "posters should be a decor. not automatically placed to the glass. players can also
	-- put it on walls inside the shop"): styles with a `poster` picture. Placed like a window from the Decor tab, on a
	-- side or back wall inside or on the front's outer glass panes; they cut no hole, are free, add no decor points
	-- (free points would be a free rating) and have their own cap. Funny scenes from Figma's image generator with no
	-- text (assets/ui/posters/art), their jokes put on by tools/ui-art/make_posters.py; uploaded as images.
	MAX_POSTERS = 8,
	-- the shop front (Town.SHOP DOOR_WIDTH and PANES, the plot's width with its walls): a poster takes one of the two
	-- outer panes each side of the door (WindowRules.frontSpots); the inner pane is where a door leaf rests when open
	FRONT = { doorWidth = 12, outerWidth = 42, panes = 3 },
	-- a poster hangs `inset` studs off a wall's inside face (past the look's liner), or `glass` outside the front
	-- glass's middle (WindowRules.depth)
	POSTER = { inset = 0.14, glass = 0.22 },
	GRID = 2, -- a window's middle snaps to whole multiples of this along the wall
	CORNER = 1, -- studs of wall kept clear at each end of a wall
	GAP = 1, -- studs of wall kept between two windows
	-- the window's bottom stands this far over the floor: the decor band's top (Config/Decor SHELL BAND + TRIM) plus 1
	SILL = 4.7,
	SELL_REFUND = 0.5, -- of the price paid, as shelves
	-- inside lengths of the walls a window can go on (Config/Plots DEPTH for the sides, WIDTH for the back)
	WALLS = { left = 40, right = 40, back = 40 },
	SIDES = { "left", "right", "back" },
	ORDER = { "Square", "Wide", "Arched", "Porthole", "Stained", "PosterOneMore", "PosterWallet", "PosterBeware", "PosterWanted", "PosterEmployee" },
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
		-- a kid buried in pack wrappers: "I said that 40 packs ago"
		PosterOneMore = { name = "Just One More", width = 4, height = 6, price = 0, level = 1, points = 0, poster = "rbxassetid://130617427345771" },
		-- a crying empty wallet: "Last seen near the packs"
		PosterWallet = { name = "Missing: Wallet", width = 4, height = 6, price = 0, level = 1, points = 0, poster = "rbxassetid://79938640905944" },
		-- Pish in a spiked collar: "He will lick you"
		PosterBeware = { name = "Beware of Dog", width = 4, height = 6, price = 0, level = 1, points = 0, poster = "rbxassetid://88089754453070" },
		-- Chikin with a golden card in his mouth: "For eating a Legendary"
		PosterWanted = { name = "Wanted", width = 4, height = 6, price = 0, level = 1, points = 0, poster = "rbxassetid://132979931860531" },
		-- Turts asleep on the register: "Asleep since Monday"
		PosterEmployee = { name = "Top Employee", width = 4, height = 6, price = 0, level = 1, points = 0, poster = "rbxassetid://95573475223904" },
	},
}
