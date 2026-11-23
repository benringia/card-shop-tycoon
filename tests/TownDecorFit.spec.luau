--!strict
-- The hand-placed town decor (assets/town/TownDecor.rbxm) stays out of the shops (spec 2026-11-23-shop-rooms-design:
-- the shops grew to 50 x 60; tools/town/fit_town_decor takes out what stands in one)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local TownLayout = require("../src/shared/Util/TownLayout")
local DecorFit = require("../tools/town/decor_fit")
local town = require("../src/shared/Config/Town")
local expect = require("./lib/expect")

-- Config/Plots numbers (Lune can't load it): 6 plots, 3 a row, 50 x 60, 14 apart, the street 96 wide
local WORLD = { plotCount = 6, perRow = 3, plotWidth = 50, plotDepth = 60, gap = 14, streetWidth = 96 }

return {
	["no hand-placed decor below the roofline stands in a shop"] = function()
		local root = roblox.deserializeModel(fs.readFile("assets/town/TownDecor.rbxm"))[1]
		local hits = DecorFit.inTheWay(root, TownLayout.plotRects(WORLD :: any), town.WALL_THICKNESS, DecorFit.ROOFLINE)
		local names = {}
		for _, hit in hits do
			table.insert(names, `{hit.group}/{hit.piece}`)
		end
		expect.equal(#hits, 0, `pieces in a shop: {table.concat(names, ", ")}`)
	end,

	-- TownService moves any tree nearer a shop than Town.LAYOUT.TREE_CLEARANCE out of the way at runtime, and takes away
	-- one that can't clear (canopies poked through walls, owner 2026-11-19). Studio boxes a tree in its pivot's frame,
	-- which Lune can't read, so the check boxes each tree as a square as wide as its longest side: no hand-placed tree
	-- vanishes in the game (the Garden alley's first tree did, 2026-11-24)
	["no hand-placed tree is taken away at runtime"] = function()
		local root = roblox.deserializeModel(fs.readFile("assets/town/TownDecor.rbxm"))[1]
		local hits = DecorFit.treesStuck(root, TownLayout.plotRects(WORLD :: any), town.LAYOUT.TREE_CLEARANCE)
		local names = {}
		for _, hit in hits do
			table.insert(names, `{hit.group}/{hit.piece}`)
		end
		expect.equal(#hits, 0, `trees the game would take away: {table.concat(names, ", ")}`)
	end,
}
