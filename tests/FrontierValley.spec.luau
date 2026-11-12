--!strict
-- The Frontier valley (spec docs/superpowers/specs/2026-11-10-frontier-valley-design.md): the Wild valley's engine on
-- the Frontier's own config. Camp → Frostwood → a climb to Stormpeak → a drop into the Rift, a dead giant between them,
-- the Dungeon gate at the trail's end.
local frontierValley = require("../src/shared/Config/FrontierValley")
local wildValley = require("../src/shared/Config/WildValley")
local frontier = require("../src/shared/Config/Frontier")
local bosses = require("../src/shared/Config/Bosses")
local WildValley = require("../src/shared/Util/WildValley")
local BossRules = require("../src/shared/Util/BossRules")
local TownTerrain = require("../src/shared/Util/TownTerrain")
local expect = require("./lib/expect")
local fs = require("@lune/fs")

local valley = frontierValley :: any
local OPS = WildValley.terrainOps(valley, TownTerrain.trailSegment)

-- Keys the valley engine (Util/WildValley, WildService, SceneryService, BossService, the sky, the music) reads from
-- any valley; the Wild's own pieces (stream, bridge, cave, volcano, vents...) are left out
local SHARED_KEYS = {
	"MAX_CELLS", "SURFACE_LIFT", "TRAIL_WIDTH", "MARKER_SPACING", "MAX_STEP", "PORTAL_CLEAR", "BOARD_CLEAR", "POPULATION",
	"SPOT_SPACING", "SPOT_MARGIN", "SPOT_PROP_CLEAR", "ARRIVAL_CLEAR", "BIOMES", "TRAIL", "TRAIL_MATERIAL", "BIOME_FLOOR",
	"BIOME_CLIFF", "PASS", "PASS_BANKS", "HILLS", "EDGE_WALL", "EDGE", "TERRAIN_READY_ATTRIBUTE", "TERRAIN_WAIT",
	"RETURN_SIGN", "BOARD_FACE_BACK", "ARROWS", "MARKER", "TERRAIN", "SKYLINES", "CARVES", "BOSS_PORTAL", "ARENA_FIELD",
	"ARENA_CLEARING", "ARENA_COPIES_FOR_TERRAIN", "ARENA_HOLD", "ARENA_EDGE_INSET", "ARENA_EDGE_SIDES", "ARENA_LIFT",
	"ARENA_LOOKS", "ARENA_DRESSING", "ARENA_FENCE", "ARENA_HOME", "PROP_LISTS", "DRESSED_LISTS", "GLOW", "COLLIDERS",
	"PROPS", "SETTLE", "FEET", "BACKDROP", "MOUNTAINS", "HOME",
}

local function distanceToSegment(p: any, a: any, b: any): number
	local dx, dz = b.x - a.x, b.z - a.z
	local t = math.clamp(((p.x - a.x) * dx + (p.z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((p.x - (a.x + dx * t)) ^ 2 + (p.z - (a.z + dz * t)) ^ 2)
end

local function trailDistance(p: any): number
	local best = math.huge
	for index = 2, #valley.TRAIL do
		best = math.min(best, distanceToSegment(p, valley.TRAIL[index - 1], valley.TRAIL[index]))
	end
	return best
end

local function arrivalMiddle(): any
	local a = valley.ARRIVAL_CLEAR
	return { x = (a.minX + a.maxX) / 2, z = (a.minZ + a.maxZ) / 2 }
end

local function inArrival(p: any): boolean
	local a = valley.ARRIVAL_CLEAR
	return p.x >= a.minX and p.x <= a.maxX and p.z >= a.minZ and p.z <= a.maxZ
end

return {
	["every key the valley engine reads is here"] = function()
		for _, key in SHARED_KEYS do
			assert(valley[key] ~= nil, `FrontierValley.{key} is missing`)
		end
		for _, key in SHARED_KEYS do
			assert((wildValley :: any)[key] ~= nil, `WildValley.{key} is missing (the engine reads it from both)`)
		end
	end,

	["three biomes at 0, 30 and -12, each at least 200 studs across"] = function()
		expect.equal(#valley.BIOMES, 3)
		for index, ground in { 0, 30, -12 } do
			local biome = valley.BIOMES[index]
			expect.equal(biome.ground, ground, `biome {index}'s ground`)
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, p in biome.outline do
				minX, maxX, minZ, maxZ = math.min(minX, p.x), math.max(maxX, p.x), math.min(minZ, p.z), math.max(maxZ, p.z)
			end
			assert(math.max(maxX - minX, maxZ - minZ) >= 200, `biome {index} is only {maxX - minX} by {maxZ - minZ}`)
			for _, p in biome.outline do
				local ground = TownTerrain.groundAt(OPS, (p.x + biome.centre.x) / 2, (p.z + biome.centre.z) / 2)
				expect.near(ground :: number, biome.ground, 1.5, `biome {index}'s floor halfway to {p.x}, {p.z}`)
			end
		end
	end,

	["the trail runs camp → Frostwood → Stormpeak → the Rift, never back"] = function()
		expect.equal(inArrival(valley.TRAIL[1]), true, "the trail starts in the camp")
		local last = 1
		for _, p in valley.TRAIL do
			local zone = WildValley.zoneAt(valley, p)
			if zone then
				assert(zone >= last, `the trail goes back from zone {last} to {zone} at {p.x}, {p.z}`)
				last = zone
			end
		end
		expect.equal(last, 3, "the trail ends in the Rift")
	end,

	["the trail climbs gently, with no step, and stays inside the edge"] = function()
		local trail = WildValley.trail(valley)
		for index = 2, #trail do
			local a, b = trail[index - 1], trail[index]
			local length = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
			local last = TownTerrain.groundAt(OPS, a.x, a.z) :: number
			for step = 1, math.floor(length / 2) do
				local t = step * 2 / length
				local x, z = a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t
				local ground = TownTerrain.groundAt(OPS, x, z) :: number
				assert(math.abs(ground - last) <= 2 * math.tan(math.rad(25)), `a step at {x}, {z}: {last} to {ground}`)
				assert(WildValley.inside(valley.EDGE, { x = x, z = z }), `the trail leaves the edge at {x}, {z}`)
				last = ground
			end
		end
	end,

	["the Rift can't be seen from the camp"] = function()
		local from = valley.TRAIL[1]
		local to = valley.BIOMES[3].centre
		local blocked = false
		for step = 1, 99 do
			local t = step / 100
			local x, z = from.x + (to.x - from.x) * t, from.z + (to.z - from.z) * t
			local sight = (from.y + 5) + ((valley.BIOMES[3].ground + 5) - (from.y + 5)) * t
			local top = TownTerrain.topAt(OPS, x, z)
			blocked = blocked or (top ~= nil and top > sight + 20)
		end
		assert(blocked, "a straight look from the camp reaches the Rift")
	end,

	["the Dungeon gate stands at the trail's end, in the Rift"] = function()
		local gate = valley.DUNGEON_GATE
		local last = valley.TRAIL[#valley.TRAIL]
		assert(math.sqrt((gate.x - last.x) ^ 2 + (gate.z - last.z) ^ 2) <= 40, "the gate is more than 40 studs from the trail's end")
		expect.equal(WildValley.zoneAt(valley, gate), 3, "the gate is in the Rift")
		expect.equal(frontier.DUNGEON_PORTAL.x, gate.x, "Config/Frontier's Dungeon portal is the gate")
		expect.equal(frontier.DUNGEON_PORTAL.z, gate.z, "Config/Frontier's Dungeon portal is the gate")
		for index, biome in valley.BIOMES do
			assert(trailDistance(gate) <= trailDistance(biome.portal) + 40 or index < 3, "the gate is off the trail")
		end
	end,

	["the camp holds the arrival, the spring and the way home, and no spawn spots"] = function()
		local entrance = { x = frontier.ORIGIN.x + frontier.ENTRANCE_OFFSET.x, z = frontier.ORIGIN.z + frontier.ENTRANCE_OFFSET.z }
		expect.equal(inArrival(entrance), true, "the arrival point")
		expect.equal(inArrival(frontier.SPRING), true, "the spring")
		expect.equal(inArrival(valley.RETURN_SIGN), true, "the way home's board")
		for index in valley.BIOMES do
			for _, spot in WildValley.zoneSpots(valley, index) do
				expect.equal(inArrival(spot), false, `a spawn spot in the camp at {spot.x}, {spot.z}`)
			end
		end
	end,

	["every biome has its full set of spawn spots"] = function()
		for index in valley.BIOMES do
			expect.equal(#WildValley.zoneSpots(valley, index), valley.POPULATION.MAX, `biome {index}'s spawn spots`)
		end
	end,

	["scenery stays clear of the trail, portals, boards and camp, in its own biome"] = function()
		for _, spot in WildValley.scenery(valley) do
			local clear, why = WildValley.clearOf(spot, valley)
			assert(clear, `{spot.model} at {spot.x}, {spot.z}: {why}`)
			assert(WildValley.inside(valley.EDGE, spot), `{spot.model} at {spot.x}, {spot.z} is outside the edge`)
		end
	end,

	["the edge closes round the biomes, the trail and the camp"] = function()
		for index, biome in valley.BIOMES do
			for _, p in biome.outline do
				local dx, dz = biome.centre.x - p.x, biome.centre.z - p.z
				local length = math.sqrt(dx * dx + dz * dz)
				local inset = { x = p.x + dx / length * 3, z = p.z + dz / length * 3 }
				expect.equal(WildValley.inside(valley.EDGE, inset), true, `biome {index}'s corner {p.x}, {p.z}`)
			end
		end
		expect.equal(WildValley.inside(valley.EDGE, arrivalMiddle()), true, "the camp")
	end,

	["the invisible walls rise well above every biome's ground"] = function()
		assert(valley.EDGE_WALL.bottom <= -12 - 5, "the walls reach under the Rift's floor")
		assert(valley.EDGE_WALL.top >= 30 + 30, "the walls stand well above Stormpeak")
	end,

	["the valley's terrain fits its budget"] = function()
		expect.equal(valley.SURFACE_LIFT, TownTerrain.SURFACE_LIFT, "the ramps use the terrain's surface lift")
		-- the main place runs its town and the Wild valley at 245k cells (Config/Scenery MAX_CELLS, measured at 60 fps);
		-- the Frontier place has no town
		assert(valley.MAX_CELLS <= 150000, "the budget stays well under the main place's")
		local cells = TownTerrain.estimatedCells(OPS)
		assert(cells <= valley.MAX_CELLS, `{cells} cells (budget {valley.MAX_CELLS})`)
	end,

	["arena copies stand apart, far from the valley"] = function()
		expect.equal(valley.ARENA_COPIES_FOR_TERRAIN, bosses.ARENA_COPIES)
		local centres = {}
		for zone in valley.BIOMES do
			for copy = 1, bosses.ARENA_COPIES do
				table.insert(centres, WildValley.arenaCopyCenter(valley, zone, copy))
			end
		end
		for i, a in centres do
			for j, b in centres do
				if i < j then
					assert(math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) >= 400, `arena copies {i} and {j} are close`)
				end
			end
			for _, p in valley.EDGE do
				assert(math.sqrt((a.x - p.x) ^ 2 + (a.z - p.z) ^ 2) >= 600, `arena copy {i} is near the valley`)
			end
		end
	end,

	["each boss portal stands beside its biome's trail, inside the edge, in its biome"] = function()
		for index, biome in valley.BIOMES do
			local distance = trailDistance(biome.portal)
			assert(distance >= valley.TRAIL_WIDTH and distance <= 45, `biome {index}'s portal is {distance} from the trail`)
			expect.equal(WildValley.zoneAt(valley, biome.portal), index, `biome {index}'s portal`)
			for _, hill in valley.HILLS do
				assert(math.sqrt((hill.x - biome.portal.x) ^ 2 + (hill.z - biome.portal.z) ^ 2) > hill.radius + 4, `biome {index}'s portal on a hill`)
			end
		end
	end,

	["backdrop and mountains stand outside the walkable edge"] = function()
		for _, list in { valley.BACKDROP, valley.MOUNTAINS } do
			for _, spot in list do
				expect.equal(WildValley.inside(valley.EDGE, spot), false, `{spot.model} at {spot.x}, {spot.z}`)
			end
		end
	end,

	["the Frontier draws monsters 30% bigger than the Wild"] = function()
		expect.equal(frontier.MONSTER_HEIGHT, 3.9)
	end,

	-- Plan Task 3: the Titans' Graveyard props (tools/blender/build_frontier_props.py, split by tools/props/split_pack)
	["every model the Frontier names is a saved prop"] = function()
		local named = {}
		local function add(spot: any)
			if spot.model then
				named[spot.model] = true
			end
		end
		for _, spot in WildValley.scenery(valley) do
			add(spot)
		end
		for _, spot in WildValley.passProps(valley) do
			add(spot)
		end
		for _, list in { valley.BACKDROP, valley.MOUNTAINS, valley.LANDMARKS } do
			for _, spot in list do
				add(spot)
			end
		end
		for _, dressing in valley.ARENA_DRESSING do
			for _, row in dressing.walls do
				for _, model in row.models do
					named[model] = true
				end
			end
			for _, group in dressing.inner do
				for _, model in group.models do
					named[model] = true
				end
			end
		end
		named[valley.HOME.model] = true
		named[valley.BOSS_PORTAL.model] = true
		for model in named do
			assert(fs.isFile(`assets/props/{model}.rbxm`), `assets/props/{model}.rbxm is missing`)
		end
	end,

	["landmarks stand inside the edge, the ribcage's feet off the trail it arches over"] = function()
		for _, spot in valley.LANDMARKS do
			expect.equal(WildValley.inside(valley.EDGE, spot), true, `{spot.model} at {spot.x}, {spot.z}`)
		end
		local ribcage
		for _, spot in valley.LANDMARKS do
			if spot.model == "Ribcage" then
				ribcage = spot
			end
		end
		assert(ribcage, "the ribcage over Frostwood's trail")
		assert(trailDistance(ribcage) <= 4, "the ribcage stands over the trail")
		local yaw = math.rad(ribcage.yaw)
		for _, share in valley.COLLIDERS.Ribcage.spread do
			-- a piece's own X turned by its yaw (CFrame.Angles about Y)
			local foot = { x = ribcage.x + math.cos(yaw) * share * ribcage.height, z = ribcage.z - math.sin(yaw) * share * ribcage.height }
			assert(trailDistance(foot) >= valley.TRAIL_WIDTH / 2 + 2, `a rib's foot at {foot.x}, {foot.z} is on the trail`)
		end
	end,

	["floating rocks hang well above the Rift's floor"] = function()
		for _, spot in valley.LANDMARKS do
			if spot.model == "FloatingRock" then
				assert(spot.y >= valley.BIOMES[3].ground + 12, `a floating rock at {spot.x}, {spot.z} hangs low`)
				expect.equal(WildValley.zoneAt(valley, spot), 3, "floating rocks are in the Rift")
			end
		end
	end,

	-- The owner 2026-11-10: "rift too empty. maybe add different size of floating rocks. or crystals": many of each, from
	-- small to big
	["the Rift has floating rocks and crystals of many sizes"] = function()
		local function spread(list: { any }, model: string?): (number, number, number)
			local count, low, high = 0, math.huge, 0
			for _, spot in list do
				if (model == nil or spot.model == model) and WildValley.zoneAt(valley, spot) == 3 then
					count += 1
					low = math.min(low, spot.height)
					high = math.max(high, spot.height)
				end
			end
			return count, low, high
		end
		local function oversized(list: { any }, model: string?, from: number): number
			local count = 0
			for _, spot in list do
				if (model == nil or spot.model == model) and spot.height >= from then
					count += 1
				end
			end
			return count
		end
		-- then "add oversized crystals, these crystals are too small. also oversized floating rocks"
		local rocks, smallRock, bigRock = spread(valley.LANDMARKS, "FloatingRock")
		assert(rocks >= 12, `only {rocks} floating rocks`)
		assert(smallRock <= 4 and bigRock >= 50, `rocks from {smallRock} to {bigRock} studs`)
		assert(oversized(valley.LANDMARKS, "FloatingRock", 30) >= 4, "oversized floating rocks")
		local crystals, smallCrystal, bigCrystal = spread(valley.CRYSTALS)
		assert(crystals >= 14, `only {crystals} crystal clusters`)
		assert(smallCrystal <= 6 and bigCrystal >= 50, `crystals from {smallCrystal} to {bigCrystal} studs`)
		assert(oversized(valley.CRYSTALS, nil, 30) >= 6, "oversized crystals")
		local stalagmites = spread(valley.SPIRES, "Stalagmite")
		assert(stalagmites >= 4, "dark stalagmites in the crater")
		assert(valley.COLLIDERS.Stalagmite, "a stalagmite stops players")
	end,

	-- A big crystal's whole foot stays off the trail and the boss portal, and monsters spawn clear of it
	["the crystals keep their feet off the trail and the portals"] = function()
		local all = table.clone(valley.CRYSTALS)
		for _, spot in valley.STORM_CRYSTALS do
			table.insert(all, spot)
		end
		for _, spot in all do
			local foot = spot.height * 0.25
			assert(trailDistance(spot) >= foot + valley.TRAIL_WIDTH / 2 + 2, `a crystal at {spot.x}, {spot.z} reaches the trail`)
			local portal = valley.BIOMES[WildValley.zoneAt(valley, spot) or 3].portal
			local d = math.sqrt((portal.x - spot.x) ^ 2 + (portal.z - spot.z) ^ 2)
			assert(d >= valley.PORTAL_CLEAR + foot, `a crystal at {spot.x}, {spot.z} crowds the boss portal`)
			if spot.height >= 20 then
				assert((spot.clear or 0) >= foot, `a big crystal at {spot.x}, {spot.z} keeps no spawns off`)
			end
		end
	end,

	-- The Frontier's crystals are pointed (Util/WildValley.crystalShards; SceneryService builds each as a diamond prism
	-- with a pyramid tip): a tall one in the middle and three smaller ones leaning out round it
	["a crystal cluster is a tall pointed crystal with three leaning out"] = function()
		expect.equal(valley.CRYSTAL_LOOK.pointed, true, "the Frontier's crystals are pointed")
		local shards = WildValley.crystalShards({ x = 0, z = 0, height = 40, yaw = 0 }, valley.CRYSTAL_LOOK.point)
		expect.equal(#shards, 4)
		local main = shards[1]
		expect.equal(main.out, 0)
		expect.equal(main.tilt, 0)
		local whole = main.height + main.width * valley.CRYSTAL_LOOK.point
		assert(math.abs(whole - 40) <= 2, `the main crystal stands {whole} studs, not the spot's 40`)
		for index = 2, 4 do
			local side = shards[index]
			assert(side.height < main.height and side.width < main.width, "the side crystals are smaller")
			assert(side.tilt >= 15 and side.tilt <= 35, "the side crystals lean out")
			assert(side.out > 0, "the side crystals stand round the main one")
		end
	end,

	-- The owner 2026-11-10 on Stormpeak: "add some storm related elements in various sizes, so that it wouldnt look
	-- empty/plain"
	["Stormpeak has storm crystals, spires, stones and dead trees of many sizes"] = function()
		local function heights(list: { any }, model: string?): { number }
			local found = {}
			for _, spot in list do
				if (model == nil or spot.model == model) and WildValley.zoneAt(valley, spot) == 2 then
					table.insert(found, spot.height)
				end
			end
			table.sort(found)
			return found
		end
		expect.equal(valley.STORM_CRYSTAL_LOOK.pointed, true, "storm crystals are pointed like the Rift's")
		local crystals = heights(valley.STORM_CRYSTALS)
		assert(#crystals >= 8 and crystals[1] <= 6 and crystals[#crystals] >= 40, "storm crystals from small to oversized")
		local big = 0
		for _, h in crystals do
			big += if h >= 30 then 1 else 0
		end
		assert(big >= 3, "oversized storm crystals")
		local spires = heights(valley.SPIRES, "RockSpire")
		assert(spires[#spires] >= 50, "a giant rock spire")
		local stones = heights(valley.SPIRES, "StormStone")
		assert(stones[1] <= 5 and stones[#stones] >= 20, "storm stones from small to huge")
		local trees = heights(valley.PROPS, "CharredTree")
		assert(trees[#trees] >= 20, "a giant lightning-struck tree")
	end,

	-- "maybe add some puddles, some ponds with bones or something a swamp": swamps (a mud patch in the terrain round
	-- a dark pool) on flat ground off the trail, each with bones by or in it; puddles scattered over Stormpeak
	["Stormpeak has bone swamps and puddles on flat ground off the trail"] = function()
		local function flatAround(spot: any, radius: number): boolean
			local centre = TownTerrain.groundAt(OPS, spot.x, spot.z)
			if not centre then
				return false
			end
			for step = 0, 7 do
				local angle = step * math.pi / 4
				local here = TownTerrain.groundAt(OPS, spot.x + math.cos(angle) * radius, spot.z + math.sin(angle) * radius)
				if not here or math.abs(here - centre) > 0.6 then
					return false
				end
			end
			return true
		end
		assert(#valley.SWAMPS >= 2, "two swamps")
		for _, swamp in valley.SWAMPS do
			expect.equal(WildValley.zoneAt(valley, swamp), 2, "swamps are on Stormpeak")
			assert(flatAround(swamp, swamp.radius), `the swamp at {swamp.x}, {swamp.z} isn't on flat ground`)
			assert(trailDistance(swamp) >= swamp.radius + valley.TRAIL_WIDTH / 2 + 4, `the swamp at {swamp.x}, {swamp.z} reaches the trail`)
			local bones = 0
			for _, list in { valley.BONES, valley.LANDMARKS } do
				for _, spot in list do
					local d = math.sqrt((spot.x - swamp.x) ^ 2 + (spot.z - swamp.z) ^ 2)
					if (spot.model == "Bones" or spot.model == "HornedSkull") and d <= swamp.radius + 6 then
						bones += 1
					end
				end
			end
			assert(bones >= 1, `the swamp at {swamp.x}, {swamp.z} has no bones`)
		end
		local mud = WildValley.swampOps(valley)
		assert(#mud >= #valley.SWAMPS, "each swamp's mud is in the terrain")
		for _, op in mud do
			expect.equal(op.material, "Mud")
		end
		expect.equal(#WildValley.swampOps(wildValley :: any), 0, "the Wild has none")
		assert(valley.MATERIAL_COLORS.Mud, "the mud has its colour")
		assert(#valley.PUDDLES >= 10, "puddles")
		for _, puddle in valley.PUDDLES do
			expect.equal(WildValley.zoneAt(valley, puddle), 2, "puddles are on Stormpeak")
			assert(puddle.radius >= 2 and puddle.radius <= 7, "puddle-sized")
			assert(flatAround(puddle, puddle.radius + 1), `the puddle at {puddle.x}, {puddle.z} isn't on flat ground`)
			assert(trailDistance(puddle) >= puddle.radius + valley.TRAIL_WIDTH / 2, `the puddle at {puddle.x}, {puddle.z} is on the trail`)
		end
	end,

	-- Plan Task 5: the Frontier bosses' arenas, mirroring the Wild's rules
	["each Frontier arena copy is walled in round its clearing, its ring and its way home inside"] = function()
		local clearing = valley.ARENA_CLEARING
		for zone = 1, 3 do
			local half = clearing.size[zone] / 2
			assert(valley.ARENA_HOLD >= half * math.sqrt(2), `zone {zone}: a player in a clearing's corner still holds the copy`)
			for copy = 1, bosses.ARENA_COPIES do
				local c = WildValley.arenaCopyCenter(valley, zone, copy)
				local edge = WildValley.arenaEdge(valley, zone, copy)
				expect.equal(WildValley.inside(edge, c), true, `copy {zone}/{copy}'s middle`)
				expect.equal(WildValley.inside(edge, { x = c.x - valley.ARENA_HOME.distance, z = c.z }), true, `copy {zone}/{copy}'s way home`)
				for _, p in edge do
					assert(math.abs(p.x - c.x) <= half and math.abs(p.z - c.z) <= half, "the wall stands on the clearing")
				end
			end
		end
	end,

	["each Frontier arena is walled all round, its pieces clear of the fight and the way home, with its own sound"] = function()
		local function bossOf(zone: number): any
			for _, boss in bosses.BOSSES do
				if (boss :: any).place == "Frontier" and boss.zone == zone then
					return boss
				end
			end
			error(`no Frontier boss in zone {zone}`)
		end
		local function lcg(seed: number): () -> number
			local state = seed
			return function(): number
				state = (state * 1103515245 + 12345) % 2147483648
				return state / 2147483648
			end
		end
		for zone = 1, 3 do
			local dressing = valley.ARENA_DRESSING[zone]
			local ringRadius = bossOf(zone).ringRadius or bosses.RING_RADIUS
			for _, row in dressing.walls do
				assert(2 * math.pi * row.radius / row.count <= 14, `zone {zone}: a gap in its walls`)
				assert(row.radius + 4 <= valley.ARENA_CLEARING.size[zone] / 2, `zone {zone}: a wall off its ground`)
				-- the Frontier's bosses are big: walls stand well back from the fight (the owner found the Wild's 56 tight)
				assert(row.radius >= 72, `zone {zone}: walls {row.radius} studs out`)
			end
			for _, piece in WildValley.arenaDressing(valley, ringRadius, zone, lcg(zone)) do
				if not piece.wall then
					local distance = math.sqrt(piece.x ^ 2 + piece.z ^ 2)
					assert(distance > ringRadius + 4 and distance > valley.ARENA_FENCE + 2, `zone {zone}: a piece in the fight`)
					assert(not (piece.x < -valley.ARENA_FENCE and math.abs(piece.z) < 8), `zone {zone}: a piece on the path home`)
					assert(math.sqrt((piece.x + valley.ARENA_HOME.distance) ^ 2 + piece.z ^ 2) >= 8, `zone {zone}: a piece by the way home`)
				end
			end
			assert(string.match(dressing.sound.id, "^rbxassetid://%d+$"), `zone {zone} has no ambient sound`)
			assert(dressing.sound.range < valley.ARENA_FIELD.spacing / 2, `zone {zone}'s sound reaches the next copy`)
		end
		assert(valley.ARENA_DRESSING[1].backdrop and valley.ARENA_DRESSING[1].backdrop.model == "IceThrone", "the Frost Tyrant's throne")
	end,

	-- The owner 2026-11-10: "make the arena wider and make the boss larger": the Frontier's big bosses fight in a wider
	-- ring (their own arenaRadius) than the Wild's
	["the Frontier arenas' fence agrees with their bosses and their way home is the crystal ring inside the walls"] = function()
		for _, boss in bosses.BOSSES do
			if boss.place == "Frontier" then
				expect.equal(valley.ARENA_FENCE, BossRules.arenaRadius(boss, bosses), `{boss.name}'s fence`)
			end
		end
		assert(valley.ARENA_FENCE >= 48, "wider than the Wild's 36")
		local home = valley.ARENA_HOME
		for zone = 1, 3 do
			expect.equal(home[zone].model, "PortalFrontier", `zone {zone}'s way home`)
			local innerWall = math.huge
			for _, row in valley.ARENA_DRESSING[zone].walls do
				innerWall = math.min(innerWall, row.radius)
			end
			assert(home.distance >= valley.ARENA_FENCE + 6 and home.distance <= innerWall - 4, `zone {zone}: the way home is outside its walls`)
		end
	end,

	-- The owner's first look (2026-11-10): the sign stood in the spring, the cliffs were flat walls, the Dungeon gate had
	-- no portal model, Stormpeak was plain
	["the camp's board stands clear of the spring"] = function()
		local spring, sign = frontier.SPRING, valley.RETURN_SIGN
		assert(math.sqrt((spring.x - sign.x) ^ 2 + (spring.z - sign.z) ^ 2) >= 14, "the board is in the spring")
	end,

	["outcrops break up every cliff face, off the trail and its passes"] = function()
		local faces = WildValley.faceOps(valley)
		assert(#faces >= 150, `only {#faces} outcrops`)
		for _, op in faces do
			expect.equal(op.shape, "Ball")
			assert(trailDistance(op) >= op.radius + valley.TRAIL_WIDTH / 2 + 4, `an outcrop at {op.x}, {op.z} sits on the trail`)
			for index, biome in valley.BIOMES do
				local d = math.sqrt((biome.portal.x - op.x) ^ 2 + (biome.portal.z - op.z) ^ 2)
				assert(d >= op.radius + 10, `an outcrop at {op.x}, {op.z} crowds biome {index}'s portal`)
			end
		end
		-- the Wild has none (its terrain is unchanged)
		expect.equal(#WildValley.faceOps(wildValley :: any), 0)
	end,

	["the Dungeon gate is a real portal model"] = function()
		local gate = valley.DUNGEON_GATE
		-- its own model, or (until that's saved) its fallback's: never a bare ring
		local shown = if gate.model and fs.isFile(`assets/props/{gate.model}.rbxm`) then gate.model
			elseif gate.fallback and fs.isFile(`assets/props/{gate.fallback.model}.rbxm`) then gate.fallback.model
			else nil
		assert(shown ~= nil, "the gate's portal model")
		assert(gate.look and gate.height and gate.height >= 16, "the gate's look and size")
	end,

	["it rains lightly on Stormpeak, under quieter thunder"] = function()
		local fx = valley.FX
		expect.equal(fx.rain.zone, 2, "rain on Stormpeak")
		-- the owner then: "I havent seen rain in this region make it rain a little": drops in the air at once round you
		-- (rate x fall time over the box), per 100 square studs: seen, but light
		local fall = fx.rain.height / ((fx.rain.speed[1] + fx.rain.speed[2]) / 2)
		local density = fx.rain.rate * fall / (fx.rain.size * fx.rain.size / 100)
		assert(density >= 1.5 and density <= 6, `{density} drops per 100 square studs`)
		assert(fx.rain.drop >= 0.25, "drops big enough to see")
		assert(fx.lightning.volume <= 0.3, "thunder turned down")
	end,

	-- The owner 2026-11-10 ("fix floating trees"): a backdrop piece past the rims stood over no terrain at all, its
	-- crown showing over the rim with nothing under it. Every one now stands on the drawn rim: terrain under its foot
	-- all round, the foot near level
	["every backdrop piece stands on drawn terrain"] = function()
		for _, spot in valley.BACKDROP do
			local centre = TownTerrain.groundAt(OPS, spot.x, spot.z)
			assert(centre, `{spot.model} at {spot.x}, {spot.z} stands over no terrain`)
			local foot = spot.height * 0.15
			for step = 0, 7 do
				local angle = step * math.pi / 4
				local here = TownTerrain.groundAt(OPS, spot.x + math.cos(angle) * foot, spot.z + math.sin(angle) * foot)
				assert(here, `{spot.model} at {spot.x}, {spot.z}: no terrain under its foot`)
				assert(math.abs(here - centre) <= 6, `{spot.model} at {spot.x}, {spot.z}: its foot hangs over a drop`)
			end
		end
	end,

	["the Frontier's terrain flag is its own"] = function()
		assert(valley.TERRAIN_READY_ATTRIBUTE ~= wildValley.TERRAIN_READY_ATTRIBUTE, "the two valleys share a terrain flag")
	end,
}
