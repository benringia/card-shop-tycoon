--!strict
-- The Card Festival Square plaza (the user's pick C, 2026-10-30): a gazebo over the healing fountain, a fan of giant
-- cards, market stalls, cafe tables, string lights to lamp posts, potted trees. Placements in Config/Plaza, maths in
-- Util/PlazaLayout. The lanes to the shop doors and along the street stay clear; the spring stays reachable.
local plaza = require("../src/shared/Config/Plaza")
local town = require("../src/shared/Config/Town")
local combat = require("../src/shared/Config/Combat")
local PlazaLayout = require("../src/shared/Util/PlazaLayout")
local expect = require("./lib/expect")

local RIM = town.LAYOUT.PLAZA_RADIUS

-- Every bench as a footprint too (TownLayout places them round the spring)
local function allFootprints(): { PlazaLayout.Footprint }
	local list = PlazaLayout.footprints(plaza)
	for _, angle in town.LAYOUT.BENCH_ANGLES do
		local p = PlazaLayout.at(angle, town.LAYOUT.BENCH_RADIUS)
		table.insert(list, { kind = "bench", x = p.x, z = p.z, radius = plaza.BENCH_REACH })
	end
	return list
end

return {
	["everything stands inside the plaza"] = function()
		for _, f in allFootprints() do
			local r = math.sqrt(f.x * f.x + f.z * f.z)
			assert(r + f.radius <= RIM + 1e-9, `{f.kind} at {f.x}, {f.z} pokes past the plaza's edge`)
			assert(r - f.radius >= plaza.GAZEBO.platform.radius - 1e-9, `{f.kind} at {f.x}, {f.z} is on the gazebo`)
		end
	end,

	["the lanes to the shop doors and along the street stay clear"] = function()
		for _, f in allFootprints() do
			local nearX = math.abs(f.x) - f.radius < plaza.LANE_HALF
			local nearZ = math.abs(f.z) - f.radius < plaza.LANE_HALF
			assert(not nearX, `{f.kind} at {f.x}, {f.z} blocks a lane to a shop door`)
			assert(not nearZ, `{f.kind} at {f.x}, {f.z} blocks the street lane`)
		end
	end,

	["nothing stands on anything else"] = function()
		local list = allFootprints()
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				-- neighbouring giant cards overlap a little on purpose: a fan (the fan test checks each one shows)
				if a.kind == "giant card" and b.kind == "giant card" then
					continue
				end
				local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
				assert(d >= a.radius + b.radius, `{a.kind} at {a.x}, {a.z} overlaps {b.kind} at {b.x}, {b.z}`)
			end
		end
	end,

	["the dome clears the fountain's floating gem, and the spring stays reachable"] = function()
		expect.equal(plaza.FOUNTAIN_HEIGHT, town.SLOTS.HealingSpring.height, "the fountain is the size the gazebo is built for")
		local g = plaza.GAZEBO
		assert(g.platform.height + g.postHeight >= plaza.FOUNTAIN_HEIGHT + plaza.GEM_RISE, "the gem pokes into the dome")
		assert(g.radius - g.postSize / 2 > plaza.FOUNTAIN_RADIUS + 1, "the columns crowd the fountain")
		local gap = 2 * math.pi * g.radius / g.posts - g.postSize
		assert(gap >= 4, `only {gap} studs between columns`)
		assert(g.radius < combat.SPRING_RADIUS, "the healing area reaches past the columns")
	end,

	["the giant cards face where new players appear"] = function()
		expect.equal(#plaza.FAN.cards, 5, "five cards")
		local rarities = {}
		for _, card in plaza.FAN.cards do
			rarities[card.rarity] = true
		end
		for _, rarity in { "Common", "Rare", "Very Rare", "Epic", "Legendary" } do
			expect.equal(rarities[rarity], true, rarity)
		end
		expect.equal(plaza.FAN.cards[3].rarity, "Legendary", "the Legendary in the middle")
		-- New players appear in front of it, within 45 degrees of straight on
		local centre = PlazaLayout.at(plaza.FAN.angle, plaza.FAN.r)
		local fx, fz = plaza.FAN.face.x - centre.x, plaza.FAN.face.z - centre.z
		local sx, sz = plaza.SPAWN.x - centre.x, plaza.SPAWN.z - centre.z
		local cos = (fx * sx + fz * sz) / (math.sqrt(fx * fx + fz * fz) * math.sqrt(sx * sx + sz * sz))
		assert(cos >= math.cos(math.rad(45)), "the spawn isn't in front of the giant cards")
	end,

	["the five giant cards stand side by side, each showing, fanned from the middle"] = function()
		local cards = PlazaLayout.fanCards(plaza)
		expect.equal(#cards, 5, "five")
		for index = 2, #cards do
			local a, b = cards[index - 1], cards[index]
			local gap = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
			assert(gap >= (a.width + b.width) / 2 * 0.7, `cards {index - 1} and {index} hide each other`)
			assert(b.lean < a.lean, "each leans out a little more to the right")
		end
		expect.equal(cards[3].lean, 0, "the middle card stands straight")
		assert(cards[1].back > cards[3].back, "the outer cards stand behind the middle one")
	end,

	["string lights sag between the gazebo and each lamp"] = function()
		local a, b = { x = 0, y = 16, z = 0 }, { x = 12, y = 9, z = 0 }
		local bulbs = PlazaLayout.stringLight(a, b, 2, 1.5)
		assert(#bulbs >= 6, `only {#bulbs} bulbs`)
		local middle = bulbs[math.ceil(#bulbs / 2)]
		local straight = a.y + (b.y - a.y) * (middle.x - a.x) / (b.x - a.x)
		expect.near(straight - middle.y, 2, 0.35, "sags about 2 studs in the middle")
		assert(bulbs[1].x > a.x and bulbs[#bulbs].x < b.x, "bulbs hang between the ends")
		for index = 2, #bulbs do
			assert(bulbs[index].x > bulbs[index - 1].x, "in order along the string")
		end
	end,

	["eight lamps, three stalls, six tables, four potted trees"] = function()
		expect.equal(#plaza.LAMPS.angles, 8, "lamps")
		expect.equal(#plaza.STALLS, 3, "stalls")
		expect.equal(#plaza.TABLES.angles, 6, "tables")
		expect.equal(#plaza.TREES, 4, "potted trees")
	end,
}
