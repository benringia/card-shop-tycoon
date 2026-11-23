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
}
