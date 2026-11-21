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
local leaderboard = require("../src/shared/Config/Leaderboard")
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
		if critter.area == "plaza" and not critter.orbit and not critter.y then
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
		assert(f.size.height + f.card.bob <= plaza.FOUNTAIN_HEIGHT, "the model's card floats higher than the fountain's height")
		local cardTop = f.card.y + f.card.height / 2 + f.card.bob
		assert(cardTop <= plaza.FOUNTAIN_HEIGHT, "the stand-in's card floats higher than the fountain's height")
		assert(f.fx.pillar.height <= g.platform.height + g.postHeight, "the column of light goes through the dome")
		assert(f.fx.orbs.radius + f.fx.orbs.size < plaza.FOUNTAIN_RADIUS, "the orbs fly out past the fountain")
		assert(g.platform.height + g.postHeight >= plaza.FOUNTAIN_HEIGHT + 2, "the fountain reaches into the dome")
		assert(g.radius - g.postSize / 2 > plaza.FOUNTAIN_RADIUS + 1, "the columns crowd the fountain")
		local gap = 2 * math.pi * g.radius / g.posts - g.postSize
		assert(gap >= 4, `only {gap} studs between columns`)
		assert(g.radius < combat.SPRING_RADIUS, "the healing area reaches past the columns")
	end,

	-- Owner 2026-11-13: the plaza leaderboard as giant cards (pick A), "replace the cards on the plaza with it"; owner
	-- 2026-11-22, pick A of three ("lets go A"): both rankings up at once, each on its own pair of cards (all time and
	-- this server), where the two cards showed them in turn
	["the giant cards are the leaderboard's lists: each ranking's all time and this server, facing where new players appear"] = function()
		expect.equal(#plaza.FAN.cards, 2 * #leaderboard.BOARDS, "a pair of cards for each ranking")
		local seen = {}
		for _, card in plaza.FAN.cards do
			local key = `{card.board}/{card.list}`
			assert(not seen[key], `{key} stands twice`)
			seen[key] = true
			expect.equal(card.rarity, if card.list == "allTime" then "Legendary" else "Rare", `{key}'s rim`)
		end
		for _, board in leaderboard.BOARDS do
			for _, list in { "allTime", "server" } do
				assert(seen[`{board.stat}/{list}`], `{board.stat} has no {list} card`)
			end
		end
		-- New players appear in front of it, within 45 degrees of straight on
		local centre = PlazaLayout.at(plaza.FAN.angle, plaza.FAN.r)
		local fx, fz = plaza.FAN.face.x - centre.x, plaza.FAN.face.z - centre.z
		local sx, sz = plaza.SPAWN.x - centre.x, plaza.SPAWN.z - centre.z
		local cos = (fx * sx + fz * sz) / (math.sqrt(fx * fx + fz * fz) * math.sqrt(sx * sx + sz * sz))
		assert(cos >= math.cos(math.rad(45)), "the spawn isn't in front of the giant cards")
	end,

	["the list cards stand side by side, neither hiding the other: boss kills' pair on the left, this server first in each, a wider gap between the pairs"] = function()
		local cards = PlazaLayout.fanCards(plaza)
		local specs = plaza.FAN.cards
		expect.equal(#cards, #specs)
		local function apart(a: PlazaLayout.FanCard, b: PlazaLayout.FanCard): number
			return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
		end
		for index = 1, #cards - 1 do
			local a, b = cards[index], cards[index + 1]
			assert(apart(a, b) >= (a.width + b.width) / 2 + 0.3, `cards {index} and {index + 1} overlap`)
		end
		for index = 1, #cards do
			expect.near(cards[index].lean, -cards[#cards + 1 - index].lean, 1e-9, "leaning out alike")
			assert(cards[index].height <= 7.5, "smaller than the old board")
		end
		-- Facing the cards (looking back along their facing), your left is the cards' own right side
		local centre = PlazaLayout.at(plaza.FAN.angle, plaza.FAN.r)
		local fx, fz = plaza.FAN.face.x - centre.x, plaza.FAN.face.z - centre.z
		local rx, rz = -fz, fx
		local function leftness(index: number): number
			return (cards[index].x - centre.x) * rx + (cards[index].z - centre.z) * rz
		end
		local function find(board: string, list: string): number
			for index, spec in specs do
				if spec.board == board and spec.list == list then
					return index
				end
			end
			error(`no {board} {list} card`)
		end
		local packs, bosses = leaderboard.BOARDS[1].stat, leaderboard.BOARDS[2].stat
		for _, board in { packs, bosses } do
			local allTime, server = find(board, "allTime"), find(board, "server")
			assert(math.abs(allTime - server) == 1, `{board}'s cards stand together`)
			assert(leftness(server) > leftness(allTime), `{board}: this server stands on the right`)
		end
		assert(leftness(find(bosses, "allTime")) > leftness(find(packs, "server")), "packs opened stand left of boss kills")
		local within = apart(cards[find(packs, "allTime")], cards[find(packs, "server")])
		local between = apart(cards[find(packs, "server")], cards[find(bosses, "allTime")])
		assert(between > within + 0.5, "no wider gap between the two rankings' pairs")
	end,

	-- Seen 2026-11-22 from the spawn: the plaza's signpost (Town.SIGNPOSTS[1], the user's pick A) hides part of the card
	-- at the row's end nearest it, and no spot in the corner clears it; that end holds the list with the least on it
	-- (owner: "go 1", the row mirrored from the mockup)
	["the card at the signpost's end of the row is this server's boss kills"] = function()
		local sign = town.SIGNPOSTS[1]
		local nearest, best = 0, math.huge
		for index, card in PlazaLayout.fanCards(plaza) do
			local d = math.sqrt((card.x - sign.x) ^ 2 + (card.z - sign.z) ^ 2)
			if d < best then
				nearest, best = index, d
			end
		end
		local spec = plaza.FAN.cards[nearest]
		expect.equal(spec.board, "bossKills", "the ranking nearest the signpost")
		expect.equal(spec.list, "server", "the list nearest the signpost")
	end,

	-- The mockup's gold plaques: one on the plinth's front under each pair, naming its ranking (Config/Leaderboard)
	["a plaque under each pair names its ranking, inside the plinth"] = function()
		local cards = PlazaLayout.fanCards(plaza)
		local plaques = PlazaLayout.fanPlaques(plaza)
		expect.equal(#plaques, #leaderboard.BOARDS, "one for each ranking")
		local half = PlazaLayout.fanWidth(plaza) / 2
		for _, plaque in plaques do
			local sum, count, low, high = 0, 0, math.huge, -math.huge
			for index, spec in plaza.FAN.cards do
				if spec.board == plaque.board then
					sum += cards[index].along
					count += 1
					low = math.min(low, cards[index].along - cards[index].width / 2)
					high = math.max(high, cards[index].along + cards[index].width / 2)
				end
			end
			expect.equal(count, 2, `{plaque.board}: under a pair`)
			expect.near(plaque.along, sum / count, 1e-9, `{plaque.board}: in the middle of its pair`)
			assert(plaza.FAN.plaque.width <= high - low, `{plaque.board}: wider than its pair`)
			assert(math.abs(plaque.along) + plaza.FAN.plaque.width / 2 <= half, `{plaque.board}: off the plinth's end`)
		end
		assert(plaza.FAN.plaque.height < plaza.FAN.base.height, "taller than the plinth")
	end,

	-- The leaderboard is read up close: no cafe table (and its sitter) in front of a list card
	["no table stands in front of the leaderboard's cards"] = function()
		local centre = PlazaLayout.at(plaza.FAN.angle, plaza.FAN.r)
		local fx, fz = plaza.FAN.face.x - centre.x, plaza.FAN.face.z - centre.z
		local length = math.sqrt(fx * fx + fz * fz)
		fx, fz = fx / length, fz / length
		for _, card in PlazaLayout.fanCards(plaza) do
			for index, angle in plaza.TABLES.angles do
				local t = PlazaLayout.at(angle, plaza.TABLES.r)
				local ahead = (t.x - card.x) * fx + (t.z - card.z) * fz
				local aside = math.abs((t.x - card.x) * -fz + (t.z - card.z) * fx)
				assert(not (ahead > 0 and ahead < 8 and aside < card.width / 2 + plaza.TABLE.reach), `table {index} hides a list card`)
			end
		end
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

	["chairs ring each table facing it, and two tables have someone sitting"] = function()
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
		expect.equal(#t.sitters, 2, "two townsfolk (the third sat where the Support corner is)")
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

	["the puppy's laps run on the gazebo's floor, between the columns and the edge"] = function()
		local g = plaza.GAZEBO
		local laps = 0
		for _, critter in ambient.CRITTERS do
			if critter.area == "plaza" and critter.orbit then
				laps += 1
				local half = critter.height / 4
				expect.equal(critter.y, g.platform.height, "on the floor")
				assert(critter.orbit - half >= g.radius + g.postSize * 0.75, "runs into the columns")
				assert(critter.orbit + half <= g.platform.radius, "runs off the edge")
			end
		end
		expect.equal(laps, 1, "one animal running laps")
	end,

	-- its bench went with the others (owner 2026-11-20: benches blocked the way round the gazebo): it took a dog's bed
	["the cat sleeps on one of the dogs' beds"] = function()
		local sleepers = 0
		for _, critter in ambient.CRITTERS do
			if critter.area == "plaza" and critter.sleeps then
				sleepers += 1
				local onBed = false
				for _, bed in PlazaLayout.dogBeds(plaza) do
					if math.sqrt((bed.x - critter.home.x) ^ 2 + (bed.z - critter.home.z) ^ 2) <= plaza.SUPPORT.beds.radius * 0.4 then
						onBed = true
					end
				end
				assert(onBed, `the {critter.model} isn't on a dog bed`)
				assert(critter.y > plaza.SUPPORT.beds.height and critter.y < 1, "lying on the pillow, not in it")
			end
		end
		expect.equal(sleepers, 1, "one sleeper")
	end,

	["eight lamps, two stalls, four tables, four potted trees"] = function()
		expect.equal(#plaza.LAMPS.angles, 8, "lamps")
		expect.equal(#plaza.STALLS, 2, "stalls (the pink one made room for the Support corner)")
		expect.equal(#plaza.TABLES.angles, 4, "tables (one in front of the leaderboard went, one for the Support corner)")
		expect.equal(#plaza.TREES, 4, "potted trees")
	end,
	["the plaza's signpost stands in a planter beside the spawn, clear of the lamps and trees"] = function()
		local sign = town.SIGNPOSTS[1]
		expect.equal(#sign.arms, 3, "the plaza's signpost names all three portals")
		local planters = plaza.PLANTERS
		local r = math.sqrt(sign.x ^ 2 + sign.z ^ 2)
		assert(math.abs(r - planters.r) <= planters.width / 2, `{r} studs out, the planters are at {planters.r}`)
		local angle = math.deg(math.atan2(sign.z, sign.x)) % 360
		local inArc = false
		for _, arc in planters.arcs do
			inArc = inArc or (angle >= arc[1] and angle <= arc[2])
		end
		assert(inArc, `{angle} degrees is between the planters`)
		for _, lampAngle in plaza.LAMPS.angles do
			local lamp = PlazaLayout.at(lampAngle, plaza.LAMPS.r)
			local gap = math.sqrt((lamp.x - sign.x) ^ 2 + (lamp.z - sign.z) ^ 2)
			assert(gap >= 2, `{gap} studs from the lamp at {lampAngle}`)
		end
		for _, tree in plaza.TREES do
			local spot = PlazaLayout.at(tree.angle, tree.r)
			local gap = math.sqrt((spot.x - sign.x) ^ 2 + (spot.z - sign.z) ^ 2)
			assert(gap >= 3, `{gap} studs from a potted tree`)
		end
		local spawn = plaza.SPAWN
		local gap = math.sqrt((spawn.x - sign.x) ^ 2 + (spawn.z - sign.z) ^ 2)
		assert(gap <= 12, `{gap} studs from the spawn`)
	end,
	-- owner 2026-11-20: "a is a dog bed/house with a jar. replace these 3 elements with them ... remove one group in any
	-- side. and replace them with the support dev": the pink cart, its table and its bench went; the dogs' house, their
	-- beds and the tip jar stand there
	["the Support corner: a dog house, the dogs' beds and the tip jar where the pink cart's group stood"] = function()
		local support = plaza.SUPPORT
		local kinds = {}
		for _, f in PlazaLayout.footprints(plaza) do
			kinds[f.kind] = (kinds[f.kind] or 0) + 1
		end
		expect.equal(kinds["dog house"], 1)
		expect.equal(kinds["dog beds"], 1)
		expect.equal(kinds["tip jar"], 1)
		-- owner 2026-11-20: "players will be coming from the sides not from the front(there is a fountain). move the jar
		-- and sign out of the way": beside the house, not in front of it
		assert(math.abs(support.jar.r - support.house.r) <= 2, "the jar stands beside the house, as far out as it")
		assert(math.abs(support.jar.angle - support.house.angle) >= 12, "beside it, not in front")
		for _, stall in plaza.STALLS do
			assert(math.abs(stall.angle - support.house.angle) > 60, "no cart in the corner's quarter")
		end
		for _, angle in plaza.TABLES.angles do
			assert(angle < 270 or math.abs(angle - support.house.angle) > 60, "no table in the corner's quarter")
		end
		expect.equal(#town.LAYOUT.BENCH_ANGLES, 0, "no benches in the ring (they blocked the way round the gazebo)")
	end,

	["the tip jar's prompt: its own name for the client, E, reaching past the jar's stand"] = function()
		local prompt = plaza.SUPPORT.prompt
		expect.equal(prompt.name, "SupportJar")
		assert(prompt.action ~= "" and prompt.object ~= "", "says what it is")
		assert(prompt.distance >= plaza.SUPPORT.jar.reach + 4 and prompt.distance <= 12, "reached standing by it, not from across the plaza")
	end,

	-- owner 2026-11-20: "also remove benches like this that blocks the way" (a bench in the ring between the gazebo and
	-- the leaderboard), and the jar "out of the way"
	["the way round the gazebo is open: nothing stands in the ring"] = function()
		local edge = plaza.GAZEBO.platform.radius
		for _, f in allFootprints() do
			local inner = math.sqrt(f.x * f.x + f.z * f.z) - f.radius
			assert(inner >= edge + 3.5, `{f.kind} at {f.x}, {f.z} stands in the way round the gazebo ({inner - edge} studs from its edge)`)
		end
	end,

	["the sign over the jar reads from both ways round: a board on a post, taller than a player"] = function()
		local sign = plaza.SUPPORT.jar.sign
		assert(sign.text ~= "", "it says something")
		assert(sign.post >= 5, "the board hangs over the jar")
		assert(sign.bottom > plaza.SUPPORT.jar.stand + plaza.SUPPORT.jar.height, "clear of the jar's lid")
	end,

	-- owner 2026-11-20: "add the dog house as a stop for both dogs. currently they are phashing through the dog house"
	["the dogs' home: each a spot in front of its own bed, and the house is something they walk round"] = function()
		local homes = PlazaLayout.dogHomes(plaza)
		local beds = PlazaLayout.dogBeds(plaza)
		expect.equal(#homes, 2)
		expect.equal(#beds, 2)
		local solid = PlazaLayout.dogObstacles(plaza, 0.8)
		local kinds = {}
		for _, o in solid do
			kinds[o.kind] = true
		end
		for _, kind in { "dog house", "tip jar", "stall", "table", "giant card" } do
			assert(kinds[kind], `they'd walk through the {kind}`)
		end
		assert(kinds["dog bed"], "the cat sleeps on a bed: they walk round the beds too")
		assert(not kinds.planter, "the planters are at the edge")
		for index, home in homes do
			local d = math.sqrt((home.x - beds[index].x) ^ 2 + (home.z - beds[index].z) ^ 2)
			assert(d > plaza.SUPPORT.beds.radius and d < plaza.SUPPORT.beds.radius + 2, `home {index} is right in front of bed {index}`)
			assert(math.sqrt(home.x ^ 2 + home.z ^ 2) < math.sqrt(beds[index].x ^ 2 + beds[index].z ^ 2), "on the gazebo's side of it")
			for _, o in solid do
				assert(math.sqrt((home.x - o.x) ^ 2 + (home.z - o.z) ^ 2) > o.radius, `home {index} is inside the {o.kind}`)
			end
		end
		local chikin = require("../src/shared/Config/Chikin")
		local pish = require("../src/shared/Config/Pish")
		local own = 0
		for _, stop in chikin.TOWN.stops do
			if stop.home then
				own += 1
				expect.near(stop.x, homes[2].x, 0.05, "Chikin's home stop is in front of the second bed")
				expect.near(stop.z, homes[2].z, 0.05)
			end
		end
		expect.equal(own, 1, "one home stop for Chikin")
		assert(pish.TOWN.homeChance > 0 and pish.TOWN.homeChance <= 0.3, "Pish comes home now and then")
	end,
	-- seen 2026-11-20: Pish walked across the second bed, through the sleeping cat
	["from anywhere round the plaza to their homes and back, the dogs never cut through the house, the jar or a bed"] = function()
		local PishPath = require("../src/shared/Util/PishPath")
		local circles = { { kind = "fountain", x = 0, z = 0, radius = plaza.FOUNTAIN_RADIUS + 2 } }
		for _, o in PlazaLayout.dogObstacles(plaza, 0.8) do
			table.insert(circles, o)
		end
		local function gap(a: any, b: any, c: any): number
			local dx, dz = b.x - a.x, b.z - a.z
			local lengthSq = dx * dx + dz * dz
			local t = if lengthSq > 0 then math.clamp(((c.x - a.x) * dx + (c.z - a.z) * dz) / lengthSq, 0, 1) else 0
			return math.sqrt((a.x + dx * t - c.x) ^ 2 + (a.z + dz * t - c.z) ^ 2)
		end
		local starts = {}
		for angle = 0, 345, 15 do
			table.insert(starts, PlazaLayout.at(angle, 16))
			table.insert(starts, PlazaLayout.at(angle, 40))
		end
		for _, home in PlazaLayout.dogHomes(plaza) do
			for _, start in starts do
				for _, way in { { start, home }, { home, start } } do
					local last = way[1]
					for _, point in PishPath.routeRound(way[1], way[2], circles :: any) do
						for _, o in circles do
							if o.kind == "dog house" or o.kind == "tip jar" or o.kind == "dog bed" then
								-- its real size (the routing circle is 0.8 wider), but for a leg that starts or ends inside it
								local inside = math.sqrt((last.x - o.x) ^ 2 + (last.z - o.z) ^ 2) < o.radius or math.sqrt((point.x - o.x) ^ 2 + (point.z - o.z) ^ 2) < o.radius
								assert(inside or gap(last, point, o) >= o.radius - 0.8 - 1e-6, `a walk from {way[1].x}, {way[1].z} to {way[2].x}, {way[2].z} cuts through the {o.kind}`)
							end
						end
						last = point
					end
				end
			end
		end
	end,
}
