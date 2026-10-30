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

	["no grass grows near a shop, so none pokes through its floor"] = function()
		local margin = scenery.PLOT_GROUND_MARGIN
		assert(margin >= 4, "terrain blends about a cell past its fill: keep grass at least 4 studs from the walls")
		for _, rect in PLOTS do
			for _, spot in {
				{ x = rect.minX - 2, z = (rect.minZ + rect.maxZ) / 2 },
				{ x = rect.maxX + 2, z = (rect.minZ + rect.maxZ) / 2 },
				{ x = (rect.minX + rect.maxX) / 2, z = if rect.minZ > 0 then rect.maxZ + 2 else rect.minZ - 2 },
				{ x = rect.minX + 1, z = rect.minZ + 1 },
				{ x = rect.maxX - 1, z = rect.maxZ - 1 },
			} do
				local material = TownTerrain.materialAt(OPS, spot.x, spot.z)
				assert(material ~= "Grass", `grass at {spot.x}, {spot.z}, beside a shop`)
			end
		end
	end,

	["every trail is walkable ground at its height"] = function()
		for _, area in town.PORTAL_AREAS do
			local trail = area.trail
			local points = {}
			for index, p in trail do
				table.insert(points, { x = p.x, z = p.z, y = p.y or 0 })
				if index > 1 then
					local q = trail[index - 1]
					table.insert(points, { x = (p.x + q.x) / 2, z = (p.z + q.z) / 2, y = ((p.y or 0) + (q.y or 0)) / 2 })
				end
			end
			for _, p in points do
				local material = TownTerrain.materialAt(OPS, p.x, p.z)
				assert(material ~= nil and material ~= "Air" and material ~= "Water", `{area.key}: {material} at {p.x}, {p.z}`)
				local top = TownTerrain.topAt(OPS, p.x, p.z) :: number
				assert(math.abs(top + TownTerrain.SURFACE_LIFT - p.y) < 0.6, `{area.key}: ground at {p.x}, {p.z} draws at {top + TownTerrain.SURFACE_LIFT}, not {p.y}`)
			end
		end
	end,

	["Frostpeak stands on a snowy rise above the grass"] = function()
		local frontier = town.PORTAL_AREAS[2]
		local portal = frontier.trail[#frontier.trail]
		assert((portal.y or 0) >= 8, "the Frontier portal stands up on the snow")
		expect.equal(TownTerrain.materialAt(OPS, 200, 140), "Snow", "the clearing is snow")
		expect.equal(TownTerrain.materialAt(OPS, 170, 66), "Grass", "grass below the rise")
		for _, spot in { { x = 200, z = 140 }, { x = 225, z = 115 }, { x = 160, z = 150 } } do
			local drawn = (TownTerrain.topAt(OPS, spot.x, spot.z) :: number) + TownTerrain.SURFACE_LIFT
			assert(math.abs(drawn - (portal.y or 0)) < 0.6, `the clearing at {spot.x}, {spot.z} draws at {drawn}, not up on the rise`)
		end
		local below = (TownTerrain.topAt(OPS, 170, 66) :: number) + TownTerrain.SURFACE_LIFT
		assert(math.abs(below) < 0.6, "the grass below the rise is at street level")
	end,

	["each trail is paved in its area's surface"] = function()
		for _, area in town.PORTAL_AREAS do
			local a, b = area.trail[#area.trail - 1], area.trail[#area.trail]
			expect.equal(TownTerrain.materialAt(OPS, (a.x + b.x) / 2, (a.z + b.z) / 2), area.surface, area.key)
		end
	end,

	["the canyon is a caldera"] = function()
		-- Ember Canyon in the portal's colours (caldera spec 2026-10-31): dark basalt walls, a dark cracked floor, a
		-- basalt trail; nothing left of the desert
		expect.equal(TownTerrain.materialAt(OPS, -185, 32), "Basalt", "the north wall")
		expect.equal(TownTerrain.materialAt(OPS, -185, -36), "Basalt", "the south wall")
		expect.equal(TownTerrain.materialAt(OPS, -246, 0), "Basalt", "the end wall")
		expect.equal(TownTerrain.materialAt(OPS, -170, 14), "CrackedLava", "the floor beside the trail")
		expect.equal(TownTerrain.materialAt(OPS, -170, 0), "Basalt", "the trail")
		for _, list in { scenery.GROUND, scenery.FLOORS, scenery.TERRAIN } do
			for _, op in list do
				assert(op.material ~= "Sand" and op.material ~= "Sandstone" and op.material ~= "Limestone", `desert {op.material} at {op.x}, {op.z}`)
			end
		end
	end,

	["only canyon materials change colour"] = function()
		-- terrain colours are per material across the whole map: the caldera may recolour only what no other area uses
		local kept = {
			Rock = { 98, 120, 92 },
			Slate = { 118, 128, 144 },
			Snow = { 240, 246, 255 },
			Glacier = { 170, 215, 245 },
			Ground = { 120, 96, 70 },
		}
		for name, rgb in kept do
			local now = scenery.MATERIAL_COLORS[name]
			assert(now and now[1] == rgb[1] and now[2] == rgb[2] and now[3] == rgb[3], `{name} changed colour`)
		end
		for _, list in { scenery.GROUND, scenery.FLOORS, scenery.TERRAIN } do
			for _, op in list do
				if op.material == "Basalt" or op.material == "CrackedLava" then
					assert(op.x < -130, `{op.material} outside the canyon at {op.x}, {op.z}`)
				end
			end
		end
	end,

	["the volcano stands behind the canyon"] = function()
		-- concept A's quiet volcano (caldera spec): far behind the end wall, rising over it, never crowding the portal
		local volcano = scenery.VOLCANO
		local portal = town.PORTAL_AREAS[3].trail[#town.PORTAL_AREAS[3].trail]
		assert(volcano.x < -280, `the volcano at x {volcano.x} is not behind the end wall`)
		assert(math.sqrt((volcano.x - portal.x) ^ 2 + (volcano.z - portal.z) ^ 2) > 60, "the volcano crowds the portal")
		assert(volcano.height >= 100, "the volcano rises over the cliffs")
		local smoke = 0
		for _, emitter in scenery.EMITTERS do
			if emitter.area == "EmberCanyon" and emitter.kind == "plume" then
				smoke += 1
			end
		end
		-- a beam, not particles: the client stops simulating particle emitters far from the camera, and the volcano is
		-- 190+ studs from anywhere a player stands
		expect.equal(smoke, 1, "the crater's smoke plume")
		local plume = scenery.PLUME
		assert(plume and plume.rise >= 60, "the plume rises well over the crater")
		assert(plume.width[2] > plume.width[1], "the plume widens as it rises")
		assert(#scenery.CHARRED_TREES >= 6 and #scenery.SHARDS >= 4, "charred trees and obsidian shards dot the caldera")
	end,

	["the caldera's trees and shards block players"] = function()
		-- they stand inside the walkable floor (the cacti they replaced collided): each kind gets an invisible collider
		-- round its trunk or base, sized as a share of the spot's height
		for _, list in { scenery.CHARRED_TREES, scenery.SHARDS } do
			for _, spot in list do
				local collider = scenery.CALDERA_COLLIDERS[spot.model]
				assert(collider, `{spot.model} has no collider`)
				assert(collider.radius * spot.height >= 0.4, `{spot.model}'s collider is too thin`)
				assert(collider.height * spot.height >= 1.5, `{spot.model}'s collider is too low to stop a player`)
			end
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
		for _, list in { scenery.GIANT_TREES, scenery.SNOW_PINES, scenery.DUSTED_PINES, scenery.TORCHES, scenery.CRYSTALS, scenery.AREA_PROPS, scenery.MUSHROOMS, scenery.CHARRED_TREES, scenery.SHARDS, { scenery.LAVA.POOL } } do
			for _, prop in list do
				for _, area in town.PORTAL_AREAS do
					local trail = area.trail
					for index = 2, #trail do
						local d = segmentDistance(prop, trail[index - 1], trail[index])
						assert(d >= clear, `prop at {prop.x}, {prop.z} is {d} from the {area.key} trail`)
					end
					local portal = trail[#trail]
					local toPortal = math.sqrt((prop.x - portal.x) ^ 2 + (prop.z - portal.z) ^ 2)
					assert(toPortal >= town.PORTAL_SCENERY_CLEAR, `prop at {prop.x}, {prop.z} crowds the {area.key} portal`)
				end
				local inIsland = math.abs(prop.x) < town.BOUNDS.HALF_X and math.abs(prop.z) < town.BOUNDS.HALF_Z
				assert(not inIsland, `prop at {prop.x}, {prop.z} lands among the hand-placed town decor`)
			end
		end
		-- Nobody wades into the lava: the river and the pool lie past the walkable floor
		local river = scenery.LAVA.RIVER
		for _, p in { river.from, river.to, { x = (river.from.x + river.to.x) / 2, z = river.from.z } } do
			for _, side in { -1, 1 } do
				local edge = { x = p.x, z = p.z + side * river.width / 2 }
				expect.equal(PortalTrails.inside(town.WALK_EDGE, edge), false, `lava at {edge.x}, {edge.z} is walkable`)
			end
		end
		expect.equal(PortalTrails.inside(town.WALK_EDGE, scenery.LAVA.POOL), false, "the lava pool is walkable")
	end,

	["one flowing waterfall and effects within the caps"] = function()
		expect.equal(#scenery.FALLS.STREAMS <= 4, true, "falls streams")
		expect.equal(#scenery.FALLS.EMITTERS <= 4, true, "mist, splash, foam and lip spray")
		local perArea: { [string]: number } = {}
		for _, emitter in scenery.EMITTERS do
			perArea[emitter.area] = (perArea[emitter.area] or 0) + 1
		end
		for area, count in perArea do
			assert(count <= 4, `{area} has {count} effects`)
		end
		expect.equal(scenery.SMALL_DECOR_SIZE, 4, "small decor casts no shadow below this size")
	end,

	["the frozen falls stay a modest number of parts, with a walkable frozen pond at their foot"] = function()
		local PortalTrails = require("../src/shared/Util/PortalTrails")
		local frozen = scenery.FROZEN_FALLS
		-- each column has a rounded tip; the pond itself is one more part
		assert(frozen.COLUMNS * 2 + frozen.MOUND + frozen.FRINGE + frozen.POND.RIM + frozen.POND.CRACKS + 1 <= 60, "too many parts")
		expect.equal(PortalTrails.inside(town.WALK_EDGE, frozen.POND), true, "players can walk onto the pond")
		local portal = town.PORTAL_AREAS[2].trail[#town.PORTAL_AREAS[2].trail]
		local gap = math.sqrt((frozen.POND.x - portal.x) ^ 2 + (frozen.POND.z - portal.z) ^ 2)
		assert(gap > frozen.POND.radius + 6, "the pond crowds the Frontier portal")
		expect.equal(scenery.SNOWMAN, nil, "the snowman is gone (user feedback)")
		for _, op in scenery.TERRAIN do
			assert(op.material ~= "Glacier", "the frozen falls are built from ice parts now, not a terrain slab")
		end
	end,

	["every ambient sound has an id and stays quiet"] = function()
		expect.equal(#scenery.SOUNDS >= 4, true, "falls, wind, embers, birds")
		for _, sound in scenery.SOUNDS do
			assert(string.match(sound.id, "^rbxassetid://%d+$"), `{sound.name} id`)
			assert(sound.volume <= 0.6, `{sound.name} is loud`)
		end
	end,

	["props stand on the drawn ground, up hills too"] = function()
		expect.near(TownTerrain.groundAt(OPS, 150, -125) :: number, 0, 0.6, "flat forest floor")
		local hill = TownTerrain.groundAt(OPS, 208, 0) :: number
		assert(hill > 8, `the hill between the trails is only {hill} high`)
		expect.near(TownTerrain.groundAt(OPS, 200, 140) :: number, scenery.FROST_HEIGHT, 0.6, "up on Frostpeak's rise")
	end,

	["the grass between the east trails and the edge of the snowy rise aren't bare"] = function()
		local function countNear(cx: number, cz: number, radius: number): number
			local total = 0
			for _, list in { scenery.GIANT_TREES, scenery.SNOW_PINES, scenery.DUSTED_PINES, scenery.AREA_PROPS } do
				for _, prop in list do
					if math.sqrt((prop.x - cx) ^ 2 + (prop.z - cz) ^ 2) <= radius then
						total += 1
					end
				end
			end
			return total
		end
		assert(countNear(190, 5, 55) >= 10, "the grass between Forest Falls and Frostpeak is bare")
		assert(countNear(165, 115, 30) >= 5, "the snowy rise's edge by the Frontier portal is bare")
	end,

	["no pool leaves a hole to fall through"] = function()
		for _, op in OPS do
			if op.material == "Water" and op.size then
				local bottom = op.y - op.size.y / 2
				for _, dx in { -0.4, 0, 0.4 } do
					for _, dz in { -0.4, 0, 0.4 } do
						local x, z = op.x + dx * op.size.x, op.z + dz * op.size.z
						local below = nil
						for _, other in OPS do
							if other.material ~= "Water" and other.material ~= "Air" and other.shape == "Block" and other.size then
								local half = other.size.y / 2
								local inX = math.abs(x - other.x) <= other.size.x / 2 and math.abs(z - other.z) <= other.size.z / 2
								if inX and other.y - half <= bottom - 1 and other.y + half >= bottom then
									below = other.material
								end
							end
						end
						assert(below, `nothing solid under the water at {x}, {z} (bottom {bottom})`)
					end
				end
			end
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
