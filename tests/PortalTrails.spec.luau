--!strict
-- The portal areas (Portal Worlds spec): each portal stands at the end of a trail out of town, inside one walkable
-- outline that the town's invisible walls follow.
local town = require("../src/shared/Config/Town")
local wild = require("../src/shared/Config/Wild")
local places = require("../src/shared/Config/Places")
local pvp = require("../src/shared/Config/Pvp")
local combat = require("../src/shared/Config/Combat")
local TownLayout = require("../src/shared/Util/TownLayout")
local PortalTrails = require("../src/shared/Util/PortalTrails")
local expect = require("./lib/expect")

-- Plot numbers copied from Config/Plots (it holds Color3 and Vector3 values, so Lune can't load it)
local WORLD = {
	plotCount = 6,
	perRow = 3,
	plotWidth = 40,
	plotDepth = 40,
	gap = 24,
	streetWidth = 96,
	portals = {},
	spring = { x = wild.SPRING.x, z = wild.SPRING.z },
	springRadius = combat.SPRING_RADIUS,
}

return {
	["each trail ends at its portal"] = function()
		local spots = { wild.PLAZA_PORTAL, places.FRONTIER_PORTAL, pvp.ARENA_PORTAL }
		for index, area in town.PORTAL_AREAS do
			local last = area.trail[#area.trail]
			expect.equal(last.x, spots[index].x, `{area.key} x`)
			expect.equal(last.z, spots[index].z, `{area.key} z`)
		end
	end,

	["the walks are as long as the user chose"] = function()
		for _, area in town.PORTAL_AREAS do
			local range = if area.key == "Arena" then town.TRAIL.ARENA_LENGTH else town.TRAIL.EAST_LENGTH
			local length = PortalTrails.length(area.trail)
			assert(length >= range[1] and length <= range[2], `{area.key} trail is {length} studs`)
		end
	end,

	["the walkable edge is closed, simple and holds the town, every trail and every portal"] = function()
		expect.equal(PortalTrails.isSimple(town.WALK_EDGE), true, "no crossing edges")
		local points = {}
		for _, rect in TownLayout.plotRects(WORLD :: any) do
			for _, p in { { x = rect.minX, z = rect.minZ }, { x = rect.maxX, z = rect.minZ }, { x = rect.minX, z = rect.maxZ }, { x = rect.maxX, z = rect.maxZ } } do
				table.insert(points, p)
			end
		end
		for step = 0, 15 do
			local angle = step / 16 * 2 * math.pi
			table.insert(points, { x = town.LAYOUT.PLAZA_RADIUS * math.cos(angle), z = town.LAYOUT.PLAZA_RADIUS * math.sin(angle) })
		end
		for _, area in town.PORTAL_AREAS do
			for _, p in area.trail do
				table.insert(points, p)
			end
		end
		for _, p in points do
			expect.equal(PortalTrails.inside(town.WALK_EDGE, p), true, `{p.x}, {p.z} is walkable`)
		end
	end,

	["a crossing outline is caught"] = function()
		local bowtie = { { x = 0, z = 0 }, { x = 10, z = 10 }, { x = 10, z = 0 }, { x = 0, z = 10 } }
		expect.equal(PortalTrails.isSimple(bowtie), false, "bowtie")
		expect.equal(PortalTrails.inside(bowtie, { x = 50, z = 50 }), false, "far outside")
	end,

	["walls overlap at the corners"] = function()
		local edge = town.WALK_EDGE
		local walls = PortalTrails.walls(edge, 1)
		expect.equal(#walls, #edge, "one wall per side")
		for index, wall in walls do
			local a, b = edge[index], edge[index % #edge + 1]
			expect.near(wall.length, math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2) + 1, 1e-9, `wall {index} length`)
			expect.near(wall.centre.x, (a.x + b.x) / 2, 1e-9, `wall {index} centre x`)
			expect.near(wall.centre.z, (a.z + b.z) / 2, 1e-9, `wall {index} centre z`)
		end
	end,

	["portals face back along their trail"] = function()
		local facing = PortalTrails.facing({ { x = 0, z = 0 }, { x = 10, z = 0 } })
		expect.near(facing.x, -1, 1e-9, "faces the way players come from")
		expect.near(facing.z, 0, 1e-9, "level")
	end,

	["each portal service finds its area's facing by key"] = function()
		for _, area in town.PORTAL_AREAS do
			local facing = PortalTrails.areaFacing(town.PORTAL_AREAS, area.key)
			local expected = PortalTrails.facing(area.trail)
			expect.near(facing.x, expected.x, 1e-9, `{area.key} x`)
			expect.near(facing.z, expected.z, 1e-9, `{area.key} z`)
		end
		local unknown = PortalTrails.areaFacing(town.PORTAL_AREAS, "Nowhere")
		expect.equal(unknown.x * unknown.x + unknown.z * unknown.z, 1, "an unknown key still faces somewhere")
	end,

	["a portal can only be used from close by"] = function()
		expect.equal(PortalTrails.near({ x = 0, z = 0 }, { x = 10, z = 0 }, 16), true, "inside reach")
		expect.equal(PortalTrails.near({ x = 0, z = 0 }, { x = 100, z = 0 }, 16), false, "from the plaza")
	end,

	["trails leave the island where the hedge has its gaps"] = function()
		local exit = PortalTrails.exitPoint(town.PORTAL_AREAS[1].trail, town.BOUNDS.HALF_X)
		expect.near(exit.x, 130, 1e-9, "on the island edge")
		expect.near(exit.z, -26, 1e-9, "Wild trail exit")
		local west = PortalTrails.exitPoint(town.PORTAL_AREAS[3].trail, town.BOUNDS.HALF_X)
		expect.near(west.x, -130, 1e-9, "Arena trail leaves on the west edge")
	end,

	["signpost arms turn toward their target"] = function()
		-- TownLayout's convention: yaw 0 faces -Z, so facing +X is -90
		expect.near(PortalTrails.armYaw({ x = 0, z = 0 }, { x = 10, z = 0 }), -90, 1e-9, "east")
		expect.near(PortalTrails.armYaw({ x = 0, z = 0 }, { x = 0, z = -10 }), 0, 1e-9, "north (-Z)")
	end,

	["signposts stand in walkable ground and every arm names a known area"] = function()
		local keys = {}
		for _, area in town.PORTAL_AREAS do
			keys[area.key] = true
		end
		for _, sign in town.SIGNPOSTS do
			expect.equal(PortalTrails.inside(town.WALK_EDGE, sign), true, `signpost at {sign.x}, {sign.z}`)
			for _, arm in sign.arms do
				expect.equal(keys[arm], true, `arm {arm}`)
			end
		end
	end,
}
