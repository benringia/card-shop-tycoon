--!strict
-- The town's terrain (Portal Worlds spec): built at server start from Config/Scenery by Util/TownTerrain. The island's
-- terrain stays under the thin street, plaza and marking parts; grass only where open ground shows; walkable trails.
-- Roblox draws a terrain surface SURFACE_LIFT studs above the top of the fill (measured 2026-10-30: a fill topping out at
-- y -2 draws its ground at y 0.02), so the ground at y 0 is a fill topping out at y -2.
local town = require("../src/shared/Config/Town")
local scenery = require("../src/shared/Config/Scenery")
local TownLayout = require("../src/shared/Util/TownLayout")
local TownTerrain = require("../src/shared/Util/TownTerrain")
local expect = require("./lib/expect")

-- Plot numbers copied from Config/Plots (it holds Color3 and Vector3 values, so Lune can't load it)
local PLOTS = TownLayout.plotRects({
	plotCount = 6,
	perRow = 3,
	plotWidth = 40,
	plotDepth = 40,
	gap = 24,
	streetWidth = 96,
} :: any)
local OPS = TownTerrain.ops(scenery, town, PLOTS)

local GROUND = -TownTerrain.SURFACE_LIFT -- the fill top that draws the ground at y 0

return {
	["nothing in the island rises above the ground parts"] = function()
		for x = -128, 128, 4 do
			for z = -108, 108, 4 do
				local top = TownTerrain.topAt(OPS, x, z)
				assert(top == nil or top <= GROUND, `terrain at {x}, {z} tops out at {top}, drawn above the ground parts`)
			end
		end
	end,

	["no grass grows through the street or under the shops"] = function()
		for _, spot in { { x = 0, z = 0 }, { x = 90, z = 30 }, { x = -100, z = -40 }, { x = -64, z = -68 }, { x = 64, z = 68 } } do
			local material = TownTerrain.materialAt(OPS, spot.x, spot.z)
			assert(material ~= nil and material ~= "Grass", `{material} at {spot.x}, {spot.z}`)
		end
		expect.equal(TownTerrain.materialAt(OPS, -32, 100), "Grass", "open ground behind the shops is grass")
		expect.equal(TownTerrain.materialAt(OPS, 120, 60), "Grass", "open ground at the street's end is grass")
	end,

	["every trail is walkable ground at y 0"] = function()
		for _, area in town.PORTAL_AREAS do
			local trail = area.trail
			local points = {}
			for index, p in trail do
				table.insert(points, p)
				if index > 1 then
					table.insert(points, { x = (p.x + trail[index - 1].x) / 2, z = (p.z + trail[index - 1].z) / 2 })
				end
			end
			for _, p in points do
				local material = TownTerrain.materialAt(OPS, p.x, p.z)
				assert(material ~= nil and material ~= "Air" and material ~= "Water", `{area.key}: {material} at {p.x}, {p.z}`)
				expect.equal(TownTerrain.topAt(OPS, p.x, p.z), GROUND, `{area.key}: ground height at {p.x}, {p.z}`)
			end
		end
	end,

	["each trail is paved in its area's surface"] = function()
		for _, area in town.PORTAL_AREAS do
			local a, b = area.trail[#area.trail - 1], area.trail[#area.trail]
			expect.equal(TownTerrain.materialAt(OPS, (a.x + b.x) / 2, (a.z + b.z) / 2), area.surface, area.key)
		end
	end,

	["terrain stays inside the memory budget"] = function()
		local cells = TownTerrain.estimatedCells(OPS)
		assert(cells <= scenery.MAX_CELLS, `{cells} cells`)
	end,

	["the measured surface lift"] = function()
		expect.equal(TownTerrain.SURFACE_LIFT, 2, "fill top -2 draws the ground at 0")
	end,

	["a column under a ball or a turned block is measured right"] = function()
		local ops = {
			{ shape = "Ball", x = 0, y = 0, z = 0, radius = 10, material = "Rock" },
			{ shape = "Block", x = 100, y = -4, z = 0, yaw = 45, size = { x = 4, y = 8, z = 40 }, material = "Sand" },
		} :: { TownTerrain.Op }
		expect.near(TownTerrain.topAt(ops, 6, 0) :: number, 8, 1e-9, "ball top over an off-centre column")
		expect.equal(TownTerrain.topAt(ops, 0, 20), nil, "outside the ball")
		-- CFrame.Angles(0, 45 deg, 0) turns the block's long (Z) side toward +X +Z
		expect.equal(TownTerrain.materialAt(ops, 110, 10), "Sand", "along the turned block")
		expect.equal(TownTerrain.materialAt(ops, 110, -10), nil, "beside the turned block")
	end,
}
