--!strict
-- The binder's set covers (spec 2026-11-04-round4-design section 1; owner's picks 2026-11-04): a painting of the set's
-- place with no creature on it, so new players discover them in packs, and the set's name as a chunky candy logo (a
-- three-colour fill top to bottom, a thick white outline, a drop in `drop`). The paintings are Figma-generated, kept in
-- assets/ui/covers/ (680 wide) and uploaded. Plain data (Lune-tested: tests/BinderCovers.spec).
export type Cover = {
	art: string,
	lines: { string }, -- the logo, one label per line
	fill: { { number } }, -- RGB, top to bottom
	drop: { number }, -- RGB, the shadow copy under the logo
}

return {
	SETS = {
		-- A radiant golden spark in a dawn sky, the five element orbs circling it, over a flowery hilltop
		["First Spark"] = {
			art = "rbxassetid://95161168581849",
			lines = { "FIRST", "SPARK" },
			fill = { { 255, 224, 102 }, { 255, 154, 60 }, { 255, 95, 126 } },
			drop = { 194, 65, 12 },
		},
		-- A frosty ridge with glowing crystals under a purple rift and aurora
		Frontier = {
			art = "rbxassetid://103841348500551",
			lines = { "FRONTIER" },
			fill = { { 231, 246, 255 }, { 159, 214, 255 }, { 180, 139, 255 } },
			drop = { 59, 42, 138 },
		},
	} :: { [string]: Cover },
}
