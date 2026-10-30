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

	["props stand clear of every trail and portal"] = function()
		local PortalTrails = require("../src/shared/Util/PortalTrails")
		local function segmentDistance(p, a, b)
			local dx, dz = b.x - a.x, b.z - a.z
			local t = math.clamp(((p.x - a.x) * dx + (p.z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
			return math.sqrt((p.x - (a.x + dx * t)) ^ 2 + (p.z - (a.z + dz * t)) ^ 2)
		end
		local clear = town.TRAIL.WIDTH / 2 + 2
		for _, list in { scenery.GIANT_TREES, scenery.SNOW_PINES, scenery.CACTI, scenery.TORCHES, scenery.CRYSTALS } do
			for _, prop in list do
				for _, area in town.PORTAL_AREAS do
					local trail = area.trail
					for index = 2, #trail do
						local d = segmentDistance(prop, trail[index - 1], trail[index])
						assert(d >= clear, `prop at {prop.x}, {prop.z} is {d} from the {area.key} trail`)
					end
					local portal = trail[#trail]
					local toPortal = math.sqrt((prop.x - portal.x) ^ 2 + (prop.z - portal.z) ^ 2)
					assert(toPortal >= 6, `prop at {prop.x}, {prop.z} crowds the {area.key} portal`)
				end
				local inIsland = math.abs(prop.x) < town.BOUNDS.HALF_X and math.abs(prop.z) < town.BOUNDS.HALF_Z
				assert(not inIsland, `prop at {prop.x}, {prop.z} lands among the hand-placed town decor`)
			end
		end
		expect.equal(PortalTrails.inside(town.WALK_EDGE, scenery.PLATFORM), true, "the Arena platform is walkable")
	end,

	["one flowing waterfall and effects within the caps"] = function()
		expect.equal(#scenery.FALLS.BEAMS <= 3, true, "falls beams")
		expect.equal(#scenery.FALLS.EMITTERS <= 2, true, "mist and splash")
		local perArea: { [string]: number } = {}
		for _, emitter in scenery.EMITTERS do
			perArea[emitter.area] = (perArea[emitter.area] or 0) + 1
		end
		for area, count in perArea do
			assert(count <= 4, `{area} has {count} effects`)
		end
		expect.equal(scenery.SMALL_DECOR_SIZE, 4, "small decor casts no shadow below this size")
	end,

	["every ambient sound has an id and stays quiet"] = function()
		expect.equal(#scenery.SOUNDS >= 4, true, "falls, wind, embers, birds")
		for _, sound in scenery.SOUNDS do
			assert(string.match(sound.id, "^rbxassetid://%d+$"), `{sound.name} id`)
			assert(sound.volume <= 0.6, `{sound.name} is loud`)
		end
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
