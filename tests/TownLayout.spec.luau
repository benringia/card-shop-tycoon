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
	gap = 8,
	streetWidth = 30,
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
		expect.equal(rects[1].minX, -68, "rect 1 minX")
		expect.equal(rects[1].maxX, -28, "rect 1 maxX")
		expect.equal(rects[1].minZ, -55, "rect 1 minZ")
		expect.equal(rects[1].maxZ, -15, "rect 1 maxZ")
		expect.equal(rects[6].minX, 28, "rect 6 minX")
		expect.equal(rects[6].maxX, 68, "rect 6 maxX")
		expect.equal(rects[6].minZ, 15, "rect 6 minZ")
		expect.equal(rects[6].maxZ, 55, "rect 6 maxZ")
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
