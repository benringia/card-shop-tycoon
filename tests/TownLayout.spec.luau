--!strict
local town = require("../src/shared/Config/Town")
local wild = require("../src/shared/Config/Wild")
local places = require("../src/shared/Config/Places")
local pvp = require("../src/shared/Config/Pvp")
local combat = require("../src/shared/Config/Combat")
local TownLayout = require("../src/shared/Util/TownLayout")
local expect = require("./lib/expect")

-- Plot numbers copied from Config/Plots (it holds Color3 and Vector3 values, so Lune can't load it)
local WORLD: TownLayout.World = {
	plotCount = 6,
	perRow = 3,
	plotWidth = 40,
	plotDepth = 40,
	gap = 24,
	streetWidth = 60,
	portals = {
		{ x = wild.PLAZA_PORTAL.x, z = wild.PLAZA_PORTAL.z },
		{ x = places.FRONTIER_PORTAL.x, z = places.FRONTIER_PORTAL.z },
		{ x = pvp.ARENA_PORTAL.x, z = pvp.ARENA_PORTAL.z },
	},
	spring = { x = wild.SPRING.x, z = wild.SPRING.z },
	springRadius = combat.SPRING_RADIUS,
}

local HALF_STREET = WORLD.streetWidth / 2
local PLAZA_SLOTS = { Bench = true, Flower = true, PlazaDecor = true }

local function distance(a: { x: number, z: number }, b: { x: number, z: number }): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

local function count(placements: { TownLayout.Placement }, slot: string): number
	local total = 0
	for _, placement in placements do
		if placement.slot == slot then
			total += 1
		end
	end
	return total
end

return {
	["plot rects match the plot grid"] = function()
		local rects = TownLayout.plotRects(WORLD)
		expect.equal(#rects, 6, "rect count")
		expect.equal(rects[1].minX, -84, "rect 1 minX")
		expect.equal(rects[1].maxX, -44, "rect 1 maxX")
		expect.equal(rects[1].minZ, -70, "rect 1 minZ")
		expect.equal(rects[1].maxZ, -30, "rect 1 maxZ")
		expect.equal(rects[6].minX, 44, "rect 6 minX")
		expect.equal(rects[6].maxX, 84, "rect 6 maxX")
		expect.equal(rects[6].minZ, 30, "rect 6 minZ")
		expect.equal(rects[6].maxZ, 70, "rect 6 maxZ")
	end,

	["nothing inside a plot footprint"] = function()
		local margin = town.LAYOUT.PLOT_MARGIN
		for _, placement in TownLayout.build(WORLD, town) do
			for index, rect in TownLayout.plotRects(WORLD) do
				local inside = placement.x > rect.minX - margin
					and placement.x < rect.maxX + margin
					and placement.z > rect.minZ - margin
					and placement.z < rect.maxZ + margin
				assert(not inside, `{placement.slot} at {placement.x}, {placement.z} is inside plot {index}`)
			end
		end
	end,

	["only lamps, portals and the plaza in the street"] = function()
		for _, placement in TownLayout.build(WORLD, town) do
			if math.abs(placement.x) <= town.LAYOUT.STREET_HALF_LENGTH and math.abs(placement.z) < HALF_STREET then
				local where = `{placement.slot} at {placement.x}, {placement.z}`
				if placement.slot == "Lamp" then
					assert(HALF_STREET - math.abs(placement.z) <= 3, `{where} is not near a plot front`)
				elseif PLAZA_SLOTS[placement.slot] then
					assert(distance(placement, WORLD.spring) <= town.LAYOUT.PLAZA_RADIUS, `{where} is off the plaza`)
				else
					assert(placement.slot == "Portal", `{where} is in the street`)
				end
			end
		end
	end,

	["every plaza portal stands at a street end, apart from the others"] = function()
		for index, portal in WORLD.portals do
			assert(math.abs(portal.z) < HALF_STREET, `portal {index} at z {portal.z} is off the street`)
			assert(math.abs(portal.x) <= town.LAYOUT.STREET_HALF_LENGTH, `portal {index} is past the street end`)
			for other = index + 1, #WORLD.portals do
				assert(distance(portal, WORLD.portals[other]) >= 16, `portals {index} and {other} overlap`)
			end
		end
	end,

	["the whole town fits inside the bounds"] = function()
		local bounds = town.BOUNDS
		local function inside(x: number, z: number, margin: number): boolean
			return math.abs(x) + margin <= bounds.HALF_X and math.abs(z) + margin <= bounds.HALF_Z
		end
		for _, rect in TownLayout.plotRects(WORLD) do
			assert(inside(rect.minX, rect.minZ, 0) and inside(rect.maxX, rect.maxZ, 0), "a plot pokes out")
		end
		for _, placement in TownLayout.build(WORLD, town) do
			assert(inside(placement.x, placement.z, 2), `{placement.slot} at {placement.x}, {placement.z} is at or past the edge`)
		end
		for _, portal in WORLD.portals do
			assert(inside(portal.x, portal.z, 8), "a portal is too close to the edge")
		end
	end,

	["the plaza leaves open room for events"] = function()
		-- Between the plaza decor and the plot fronts there must be a clear ring for event NPCs and stalls
		local open = HALF_STREET - town.LAYOUT.PLAZA_RADIUS
		assert(open >= 6, `only {open} studs between the plaza and the shops`)
		assert(town.LAYOUT.PLAZA_RADIUS >= 20, "plaza radius")
	end,

	["a fence rings the whole island"] = function()
		local bounds, layout = town.BOUNDS, town.LAYOUT
		local edgeX, edgeZ = bounds.HALF_X - layout.EDGE_FENCE_INSET, bounds.HALF_Z - layout.EDGE_FENCE_INSET
		local sides = { north = {}, south = {}, east = {}, west = {} }
		for _, placement in TownLayout.build(WORLD, town) do
			if placement.slot == "Fence" then
				if math.abs(placement.z - edgeZ) < 0.01 then
					table.insert(sides.north, placement.x)
				elseif math.abs(placement.z + edgeZ) < 0.01 then
					table.insert(sides.south, placement.x)
				elseif math.abs(placement.x - edgeX) < 0.01 then
					table.insert(sides.east, placement.z)
				elseif math.abs(placement.x + edgeX) < 0.01 then
					table.insert(sides.west, placement.z)
				else
					error(`fence at {placement.x}, {placement.z} is not on the edge`)
				end
			end
		end
		for name, along in sides do
			local half = if name == "north" or name == "south" then edgeX else edgeZ
			table.sort(along)
			assert(#along > 0, `no fence on the {name} side`)
			assert(along[1] - layout.FENCE_SECTION / 2 <= -half + layout.FENCE_SECTION, `{name} side starts late`)
			assert(along[#along] + layout.FENCE_SECTION / 2 >= half - layout.FENCE_SECTION, `{name} side ends early`)
			for index = 2, #along do
				expect.near(along[index] - along[index - 1], layout.FENCE_SECTION, 0.01, `{name} spacing`)
			end
		end
	end,

	["code builds only lamps, benches, the island fence and portal frames"] = function()
		-- Trees, bushes, flowers, rocks, crates and the rest are hand-placed in Studio (assets/town, TownDecor)
		local allowed = { Lamp = true, Bench = true, Fence = true, Portal = true }
		for _, placement in TownLayout.build(WORLD, town) do
			assert(allowed[placement.slot], `{placement.slot} is still code-built`)
		end
	end,

	["portals stay clear"] = function()
		local placements = TownLayout.build(WORLD, town)
		expect.equal(count(placements, "Portal"), #WORLD.portals, "portal frames")
		for _, portal in WORLD.portals do
			for _, placement in placements do
				if placement.slot ~= "Portal" then
					assert(
						distance(placement, portal) > town.PORTAL_CLEARANCE,
						`{placement.slot} at {placement.x}, {placement.z} is too close to the portal at {portal.x}, {portal.z}`
					)
				end
			end
		end
	end,

	["spring area holds only benches and flowers"] = function()
		local placements = TownLayout.build(WORLD, town)
		expect.equal(count(placements, "Bench"), 4, "benches")
		for _, placement in placements do
			if distance(placement, WORLD.spring) <= WORLD.springRadius then
				assert(placement.slot == "Bench" or placement.slot == "Flower", `{placement.slot} is in the spring area`)
			end
		end
	end,

	["same output every time"] = function()
		local first = TownLayout.build(WORLD, town)
		local second = TownLayout.build(WORLD, town)
		expect.equal(#second, #first, "placement count")
		for index, placement in first do
			local other = second[index]
			expect.equal(other.slot, placement.slot, `slot {index}`)
			expect.equal(other.x, placement.x, `x {index}`)
			expect.equal(other.z, placement.z, `z {index}`)
			expect.equal(other.yaw, placement.yaw, `yaw {index}`)
			expect.equal(other.variant, placement.variant, `variant {index}`)
		end
	end,

	["every slot is known"] = function()
		for _, placement in TownLayout.build(WORLD, town) do
			assert(town.SLOTS[placement.slot], `unknown slot {placement.slot}`)
		end
	end,

	["variants count up per slot"] = function()
		local seen: { [string]: number } = {}
		for _, placement in TownLayout.build(WORLD, town) do
			seen[placement.slot] = (seen[placement.slot] or 0) + 1
			expect.equal(placement.variant, seen[placement.slot], `{placement.slot} variant`)
		end
	end,

	["a file belongs to the longest slot name it matches"] = function()
		assert(not TownLayout.isVariant("Counter", "CounterDecorA", town.SLOTS), "CounterDecorA is not a Counter")
		assert(TownLayout.isVariant("CounterDecor", "CounterDecorA", town.SLOTS), "CounterDecorA is a CounterDecor")
		assert(TownLayout.isVariant("Counter", "CounterA", town.SLOTS), "CounterA is a Counter")
		assert(TownLayout.isVariant("Tree", "TreeB", town.SLOTS), "TreeB is a Tree")
	end,

	["variant names"] = function()
		assert(TownLayout.isVariant("Tree", "Tree"), "Tree")
		assert(TownLayout.isVariant("Tree", "TreeA"), "TreeA")
		assert(TownLayout.isVariant("Tree", "Tree2"), "Tree2")
		assert(TownLayout.isVariant("Flower", "FlowerBlue"), "FlowerBlue")
		assert(not TownLayout.isVariant("Tree", "Treehouse"), "Treehouse")
		assert(not TownLayout.isVariant("Flower", "Flowers"), "Flowers")
		assert(not TownLayout.isVariant("Rock", "BigRock"), "BigRock")
	end,
}
