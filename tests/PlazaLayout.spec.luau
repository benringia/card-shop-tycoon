--!strict
-- The Card Festival Square plaza (the user's pick C, 2026-10-30): a gazebo over the healing fountain (the Elemental
-- Bloom lotus, round 2's pick B), a fan of giant cards, market stalls, cafe tables with townsfolk sitting at some,
-- string lights to lamp posts, four planters of bushes and flowers along the edge holding the lamps and trees.
-- Placements in Config/Plaza, maths in Util/PlazaLayout. The lanes to the shop doors and along the street stay clear;
-- the spring stays reachable.
local plaza = require("../src/shared/Config/Plaza")
local town = require("../src/shared/Config/Town")
local combat = require("../src/shared/Config/Combat")
local ambient = require("../src/shared/Config/Ambient")
local PlazaLayout = require("../src/shared/Util/PlazaLayout")
local expect = require("./lib/expect")

local RIM = town.LAYOUT.PLAZA_RADIUS

-- Every bench and the plaza's resting animals as footprints too (TownLayout places the benches round the spring)
local function allFootprints(): { PlazaLayout.Footprint }
	local list = PlazaLayout.footprints(plaza)
	for _, angle in town.LAYOUT.BENCH_ANGLES do
		local p = PlazaLayout.at(angle, town.LAYOUT.BENCH_RADIUS)
		table.insert(list, { kind = "bench", x = p.x, z = p.z, radius = plaza.BENCH_REACH })
	end
	for _, critter in ambient.CRITTERS do
		if critter.area == "plaza" and not critter.orbit then
			table.insert(list, { kind = "resting " .. critter.model, x = critter.home.x, z = critter.home.z, radius = critter.height / 2 })
		end
	end
	return list
end

-- Lamps and potted trees stand in the edge planters on purpose; planter pieces touch each other
local function standsIn(a: PlazaLayout.Footprint, b: PlazaLayout.Footprint): boolean
	local function pair(x: string, y: string): boolean
		return (a.kind == x and b.kind == y) or (a.kind == y and b.kind == x)
	end
	return pair("planter", "lamp") or pair("planter", "potted tree") or pair("planter", "planter")
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
				if (a.kind == "giant card" and b.kind == "giant card") or standsIn(a, b) then
					continue
				end
				local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
				assert(d >= a.radius + b.radius, `{a.kind} at {a.x}, {a.z} overlaps {b.kind} at {b.x}, {b.z}`)
			end
		end
	end,

	["the dome clears the fountain's floating card, and the spring stays reachable"] = function()
		local g, f = plaza.GAZEBO, plaza.FOUNTAIN
		local cardTop = f.card.y + f.card.height / 2 + f.card.bob
		assert(cardTop <= plaza.FOUNTAIN_HEIGHT, "the card floats higher than the fountain's height")
		assert(g.platform.height + g.postHeight >= plaza.FOUNTAIN_HEIGHT + 2, "the fountain reaches into the dome")
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

	["the lotus has five petals, one per card element, evenly round"] = function()
		local petals = PlazaLayout.petals(plaza.FOUNTAIN)
		expect.equal(#petals, 5, "five petals")
		local seen = {}
		for index, petal in petals do
			seen[petal.element] = true
			expect.near(petal.angle, (index - 1) * 72, 1e-9, `petal {index}'s angle`)
		end
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			expect.equal(seen[element], true, element)
		end
	end,

	["each petal leans out, its gem stays over the basin, and its water arcs into the pool"] = function()
		local f = plaza.FOUNTAIN
		for _, petal in PlazaLayout.petals(f) do
			local baseR = math.sqrt(petal.base.x ^ 2 + petal.base.z ^ 2)
			local tipR = math.sqrt(petal.tip.x ^ 2 + petal.tip.z ^ 2)
			assert(tipR > baseR, `{petal.element} doesn't lean out`)
			assert(petal.tip.y > petal.base.y, `{petal.element} droops`)
			assert(tipR + f.gem / 2 <= plaza.FOUNTAIN_RADIUS + 1e-9, `{petal.element}'s gem hangs past the basin`)
			local angle = math.deg(math.atan2(petal.tip.z, petal.tip.x)) % 360
			expect.near(angle, petal.angle % 360, 1e-6, `{petal.element} points along its angle`)
			local landR = math.sqrt(petal.land.x ^ 2 + petal.land.z ^ 2)
			assert(landR < f.pool.radius, `{petal.element}'s water lands outside the pool`)
			expect.near(petal.land.y, f.pool.y, 1e-9, "lands on the water")
		end
	end,

	["chairs ring each table facing it, and three tables have someone sitting"] = function()
		local t = plaza.TABLE
		for index, angle in plaza.TABLES.angles do
			local chairs = PlazaLayout.chairs(plaza, index)
			expect.equal(#chairs, t.chairs, `table {index}'s chairs`)
			local middle = PlazaLayout.at(angle, plaza.TABLES.r)
			for _, chair in chairs do
				local d = math.sqrt((chair.x - middle.x) ^ 2 + (chair.z - middle.z) ^ 2)
				expect.near(d, t.chairRadius, 1e-9, "chair distance")
				assert(d + t.chairSize / 2 <= t.reach + 1e-9, "a chair sticks out past the table's footprint")
				-- facing: a unit vector pointing at the table's middle
				expect.near(chair.faceX * (middle.x - chair.x) + chair.faceZ * (middle.z - chair.z), d, 1e-9, "faces the table")
			end
		end
		expect.equal(#t.sitters, 3, "three townsfolk")
		for _, sitter in t.sitters do
			assert(plaza.TABLES.angles[sitter.table], `no table {sitter.table}`)
			assert(sitter.chair >= 1 and sitter.chair <= t.chairs, `no chair {sitter.chair}`)
		end
	end,

	["planters along the edge in every quarter, between the lanes, holding the lamps and trees"] = function()
		local p = plaza.PLANTERS
		local quarters = {}
		for _, arc in p.arcs do
			assert(arc[1] < arc[2], "an arc runs backwards")
			quarters[math.floor(arc[1] / 90)] = true
			expect.equal(math.floor(arc[1] / 90), math.floor(arc[2] / 90), "a planter crosses a lane")
		end
		for quarter = 0, 3 do
			expect.equal(quarters[quarter], true, `quarter {quarter}`)
		end
		assert(p.r + p.width / 2 <= RIM + 1e-9, "the planters poke past the plaza's edge")
		local function inPlanter(angle: number, r: number): boolean
			for _, arc in p.arcs do
				local a = angle % 360
				if a >= arc[1] and a <= arc[2] and math.abs(r - p.r) <= p.width / 2 then
					return true
				end
			end
			return false
		end
		for _, angle in plaza.LAMPS.angles do
			assert(inPlanter(angle, plaza.LAMPS.r), `the lamp at {angle} isn't in a planter`)
		end
		for _, tree in plaza.TREES do
			assert(inPlanter(tree.angle, tree.r), `the tree at {tree.angle} isn't in a planter`)
		end
	end,

	["bushes and flowers fill the planters, clear of the lamps and trees, kept light"] = function()
		local plants = PlazaLayout.planterPlants(plaza)
		local bushes, flowers = 0, 0
		for _, plant in plants do
			if plant.kind == "bush" then
				bushes += 1
			else
				expect.equal(plant.kind, "flower", "kind")
				flowers += 1
			end
			for _, angle in plaza.LAMPS.angles do
				local lamp = PlazaLayout.at(angle, plaza.LAMPS.r)
				assert(math.sqrt((plant.x - lamp.x) ^ 2 + (plant.z - lamp.z) ^ 2) >= plaza.PLANTERS.clear, "a plant on a lamp")
			end
			for _, tree in plaza.TREES do
				local spot = PlazaLayout.at(tree.angle, tree.r)
				assert(math.sqrt((plant.x - spot.x) ^ 2 + (plant.z - spot.z) ^ 2) >= plaza.PLANTERS.clear, "a plant on a tree")
			end
		end
		assert(bushes >= 8, `only {bushes} bushes`)
		assert(flowers >= 12, `only {flowers} flowers`)
		assert(#plants <= 60, `{#plants} plants is too many`)
	end,

	["eight lamps, three stalls, six tables, four potted trees"] = function()
		expect.equal(#plaza.LAMPS.angles, 8, "lamps")
		expect.equal(#plaza.STALLS, 3, "stalls")
		expect.equal(#plaza.TABLES.angles, 6, "tables")
		expect.equal(#plaza.TREES, 4, "potted trees")
	end,
}
