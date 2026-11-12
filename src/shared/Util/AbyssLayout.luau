--!strict
-- The Crystal Abyss's layout (specs 2026-11-12-dungeon-world, 2026-11-12-abyss-regions): where every island, bridge,
-- door and spire stands, from Config/Dungeon. The way winds: the ledge, then for each step of Dungeon.STEPS small stop
-- islands (straight out of the last island, across the cave, straight in front of the next) and the step's island, and
-- last the Hydra's castle; the lair (the Hydra's arena) lies past the cave's east wall at Dungeon.CHAMBER. Each island
-- carries its region (Config/Dungeon REGIONS). Pure (no requires): DungeonBuilder builds from it, the client finds its
-- region with it, tests/AbyssLayout checks it.
local AbyssLayout = {}

export type Spot = { x: number, z: number }
export type Island = {
	kind: string, -- "ledge" | "stop" | "fight" | "beams" | "plates" | "lock" | "castle"
	step: number?, -- its place in Dungeon.STEPS
	x: number,
	z: number,
	round: boolean,
	size: number, -- a round island's radius, a square one's half side
	entry: Spot, -- on its -X edge
	exit: Spot, -- on its +X edge
	region: string, -- Config/Dungeon REGIONS
}
-- A bridge's yaw is its direction in the x-z plane: math.atan2(dz, dx), 0 along +X
export type Bridge = { from: Spot, to: Spot, length: number, yaw: number }
export type Spire = { x: number, z: number, radius: number }

local function island(kind: string, step: number?, x: number, z: number, round: boolean, size: number, region: string): Island
	return {
		kind = kind,
		step = step,
		x = x,
		z = z,
		round = round,
		size = size,
		entry = { x = x - size, z = z },
		exit = { x = x + size, z = z },
		region = region,
	}
end

-- Every island in walking order: the ledge, the stops and each step's island, the castle
function AbyssLayout.islands(dungeon: any): { Island }
	local abyss = dungeon.ABYSS
	local route = abyss.ROUTE
	local origin = dungeon.ORIGIN
	local list: { Island } = {}
	local back = abyss.LEDGE.back
	local ledgeHalf = (dungeon.HALL.length - back) / 2
	table.insert(list, island("ledge", nil, origin.x + back + ledgeHalf, origin.z, false, ledgeHalf, dungeon.REGION_OF_STEP[1]))
	local stopCount = 0
	-- the way from the last island to the next one's entry (`size` each side of its middle at z)
	local function wayTo(z: number, size: number, region: string): number
		local from = list[#list].exit
		local function stop(x: number, atZ: number)
			stopCount += 1
			local radius = if stopCount % 2 == 0 then route.stopSize[2] else route.stopSize[1]
			table.insert(list, island("stop", nil, x, atZ, true, radius, region))
		end
		local first = from.x + route.lead
		stop(first, from.z)
		for k = 1, route.middle do
			local t = k / (route.middle + 1)
			local swing = if k % 2 == 1 then route.swing else -route.swing
			stop(first + t * route.between, from.z + t * (z - from.z) + swing)
		end
		stop(first + route.between, z)
		return first + route.between + route.lead + size -- the next island's middle
	end
	for index, step in dungeon.STEPS do
		local fight = step.kind == "fight"
		local size = if fight then abyss.CRATER.outer else abyss.PUZZLE_HALF
		local region = dungeon.REGION_OF_STEP[index]
		local z = origin.z + (route.z[index] or 0)
		local x = wayTo(z, size, region)
		table.insert(list, island(step.kind, index, x, z, fight, size, region))
	end
	local castle = abyss.CASTLE
	local x = wayTo(route.castleZ, castle.size, dungeon.CASTLE_REGION)
	table.insert(list, island("castle", nil, x, route.castleZ, false, castle.size, dungeon.CASTLE_REGION))
	return list
end

-- A step's island and its place in the list (nil, nil when there's none)
function AbyssLayout.stepIsland(islands: { Island }, step: number): (Island?, number?)
	for index, each in islands do
		if each.step == step then
			return each, index
		end
	end
	return nil, nil
end

-- The cave's east wall: past the castle
function AbyssLayout.eastWall(islands: { Island }): number
	local last = islands[#islands]
	return last.x + last.size + 60
end

-- Where a bridge meets an island: a square one at its exit (or entry), a round one on its edge facing `toward`
local function edgeToward(each: Island, toward: Spot, fallback: Spot): Spot
	if not each.round then
		return fallback
	end
	local dx, dz = toward.x - each.x, toward.z - each.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-6 then
		return fallback
	end
	return { x = each.x + dx / length * each.size, z = each.z + dz / length * each.size }
end

-- The bridges: from each island to the next, leaving a round island on the side facing where it goes (owner
-- 2026-11-12: a diagonal bridge off a stop's +X edge hung over its rim)
function AbyssLayout.bridges(islands: { Island }): { Bridge }
	local list: { Bridge } = {}
	for index = 1, #islands - 1 do
		local a, b = islands[index], islands[index + 1]
		local aimA: Spot = if a.round then { x = a.x, z = a.z } else a.exit
		local aimB: Spot = if b.round then { x = b.x, z = b.z } else b.entry
		local from = edgeToward(a, aimB, a.exit)
		local to = edgeToward(b, aimA, b.entry)
		local dx, dz = to.x - from.x, to.z - from.z
		table.insert(list, { from = from, to = to, length = math.sqrt(dx * dx + dz * dz), yaw = math.atan2(dz, dx) })
	end
	return list
end

-- A point `studs` along a bridge from its start
function AbyssLayout.alongBridge(bridge: Bridge, studs: number): Spot
	return { x = bridge.from.x + math.cos(bridge.yaw) * studs, z = bridge.from.z + math.sin(bridge.yaw) * studs }
end

-- Whether a point (x, z) stands on this island (not its bridges): a puzzle waits until the whole group is on it
function AbyssLayout.onIsland(island: Island, point: Spot): boolean
	local dx, dz = point.x - island.x, point.z - island.z
	if island.round then
		return dx * dx + dz * dz <= island.size * island.size
	end
	return math.abs(dx) <= island.size and math.abs(dz) <= island.size
end

-- Whether a point (x, z) has stone under it: an island or a bridge `width` wide
function AbyssLayout.onStone(islands: { Island }, bridges: { Bridge }, width: number, point: Spot): boolean
	for _, each in islands do
		local dx, dz = point.x - each.x, point.z - each.z
		if each.round and dx * dx + dz * dz <= each.size * each.size then
			return true
		elseif not each.round and math.abs(dx) <= each.size and math.abs(dz) <= each.size then
			return true
		end
	end
	for _, bridge in bridges do
		local dx, dz = point.x - bridge.from.x, point.z - bridge.from.z
		local along = dx * math.cos(bridge.yaw) + dz * math.sin(bridge.yaw)
		local across = -dx * math.sin(bridge.yaw) + dz * math.cos(bridge.yaw)
		if along >= 0 and along <= bridge.length and math.abs(across) <= width / 2 then
			return true
		end
	end
	return false
end

-- How far along a bridge a gate `half` studs each side of its middle stands so that only chasm lies past its ends
-- (nobody walks round it over an island's edge): the first such spot from the bridge's start, or from its end with
-- fromEnd (the Hydra's door, as close to the chamber as fits). Nil when none on this bridge does.
local GATE_STEP = 0.5
local GATE_CLEAR = { 0.5, 2, 4 } -- studs past each end that must be chasm
function AbyssLayout.gateAlong(islands: { Island }, bridge: Bridge, half: number, fromEnd: boolean): number?
	local across = { x = -math.sin(bridge.yaw), z = math.cos(bridge.yaw) }
	local function clear(studs: number): boolean
		local middle = AbyssLayout.alongBridge(bridge, studs)
		for _, past in GATE_CLEAR do
			for _, side in { -1, 1 } do
				local reach = side * (half + past)
				if AbyssLayout.onStone(islands, {}, 0, { x = middle.x + across.x * reach, z = middle.z + across.z * reach }) then
					return false
				end
			end
		end
		return true
	end
	local steps = math.floor(bridge.length / GATE_STEP)
	for index = 0, steps do
		local studs = if fromEnd then bridge.length - index * GATE_STEP else index * GATE_STEP
		if clear(studs) then
			return studs
		end
	end
	return nil
end

-- A fight room's broken walls: `count` angles (radians, 0 along +X) spread evenly round the ring, none within `gapOut`
-- degrees of +X (the way out) or `gapIn` of -X (the way in, narrowed to its seal)
function AbyssLayout.ruinAngles(count: number, gapOut: number, gapIn: number): { number }
	local angles: { number } = {}
	local perSide = math.ceil(count / 2)
	local span = 180 - gapOut - gapIn
	for index = 1, count do
		local upper = index <= perSide -- the +z half (from the way out to the way in), then the -z half
		local slot = if upper then index else index - perSide
		local inSide = if upper then perSide else count - perSide
		local start = if upper then gapOut else 180 + gapIn
		table.insert(angles, math.rad(start + (slot - 0.5) / inSide * span))
	end
	return angles
end

export type Far = { x: number, y: number, z: number, size: number, tone: number }
export type Fall = { x: number, z: number, top: number, bottom: number, width: number }
export type Relief = { x: number, y: number, z: number, yaw: number }
export type Backdrop = { crystals: { Far }, islands: { Far }, falls: { Fall }, reliefs: { Relief } }

-- A small seeded generator (pure: no Roblox Random here), numbers in [0, 1)
local function generator(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
end

local function between(roll: () -> number, range: { number }): number
	return range[1] + roll() * (range[2] - range[1])
end

-- The far scenery between the cave's ends `west` and `east` (abyss = Config/Dungeon ABYSS): giant crystals on the
-- side walls, far islands, falls of light from the ceiling into the chasm, hydra carvings on the side walls and the
-- end wall behind the chamber. Everything at least BACKDROP.band[1] from the path's line (z 0); the same for a seed.
function AbyssLayout.backdrop(abyss: any, west: number, east: number, seed: number): Backdrop
	local look = abyss.BACKDROP
	local half = abyss.CAVE_HALF_WIDTH
	local roll = generator(seed)
	local length = east - west
	local made: Backdrop = { crystals = {}, islands = {}, falls = {}, reliefs = {} }
	for index = 1, look.crystals do
		local side = if index % 2 == 0 then 1 else -1
		local x = west + (index - 0.5) / look.crystals * length
		table.insert(made.crystals, {
			x = x,
			y = between(roll, { abyss.KILL_Y + 20, abyss.CEILING_Y - 30 }),
			z = side * (half - between(roll, { 0, 3 })), -- in the wall's face, not off it
			size = between(roll, look.crystalScale),
			tone = 1 + math.floor(roll() * #look.colors),
		})
	end
	local tries = 0
	while #made.islands < look.islands and tries < 400 do
		tries += 1
		local size = between(roll, look.islandSize)
		local side = if roll() < 0.5 then -1 else 1
		local candidate = {
			x = between(roll, { west + size, east - size }),
			y = between(roll, look.islandY),
			z = side * between(roll, { look.band[1] + size, half - 10 - size }),
			size = size,
			tone = 1 + math.floor(roll() * #look.colors),
		}
		local clear = true
		for _, other in made.islands do
			local apart = math.sqrt((candidate.x - other.x) ^ 2 + (candidate.y - other.y) ^ 2 + (candidate.z - other.z) ^ 2)
			if apart <= candidate.size + other.size + 4 then
				clear = false
				break
			end
		end
		if clear then
			table.insert(made.islands, candidate)
		end
	end
	for index = 1, look.falls do
		local side = if index % 2 == 0 then 1 else -1
		table.insert(made.falls, {
			x = west + (index - 0.5) / look.falls * length + between(roll, { -15, 15 }),
			z = side * between(roll, look.band),
			top = abyss.CEILING_Y,
			bottom = abyss.KILL_Y - 60,
			width = between(roll, look.fallWidth),
		})
	end
	-- the carvings: one on each side wall, the last on the end wall behind the chamber
	for index = 1, look.reliefs do
		if index == look.reliefs then
			table.insert(made.reliefs, { x = east - 2, y = 10, z = look.band[1] * (if index % 2 == 0 then 1 else -1), yaw = math.pi })
		else
			local side = if index % 2 == 0 then 1 else -1
			table.insert(made.reliefs, { x = west + index / look.reliefs * length, y = 15, z = side * (half - 3), yaw = if side > 0 then -math.pi / 2 else math.pi / 2 })
		end
	end
	return made
end

-- How far a point lies from a bridge's middle line
local function fromBridge(bridge: Bridge, x: number, z: number): number
	local dx, dz = x - bridge.from.x, z - bridge.from.z
	local along = math.clamp(dx * math.cos(bridge.yaw) + dz * math.sin(bridge.yaw), 0, bridge.length)
	local spot = AbyssLayout.alongBridge(bridge, along)
	return math.sqrt((x - spot.x) ^ 2 + (z - spot.z) ^ 2)
end

-- The rock spires (Terrain, floor to ceiling) beside the way's turns, two between each pair of steps: at the inner
-- corners of the way's swing, pushed out until clear of every island and bridge by SPIRES.clear
function AbyssLayout.spires(islands: { Island }, abyss: any): { Spire }
	local look = abyss.SPIRES
	local bridges = AbyssLayout.bridges(islands)
	local function clear(x: number, z: number, radius: number): boolean
		for _, each in islands do
			if math.sqrt((x - each.x) ^ 2 + (z - each.z) ^ 2) <= each.size + radius + look.clear + 1 then
				return false
			end
		end
		for _, bridge in bridges do
			if fromBridge(bridge, x, z) <= radius + abyss.BRIDGE_WIDTH / 2 + look.clear + 1 then
				return false
			end
		end
		return math.abs(z) + radius < abyss.CAVE_HALF_WIDTH - 10
	end
	local marks: { Island } = {}
	for _, each in islands do
		if each.kind ~= "stop" then
			table.insert(marks, each)
		end
	end
	local list: { Spire } = {}
	for k = 1, #marks - 1 do
		local a, b = marks[k], marks[k + 1]
		local midX = (a.exit.x + b.entry.x) / 2
		for side, atZ in { a.z, b.z } do
			local radius = if (k + side) % 2 == 0 then look.radius[1] else look.radius[2]
			-- outward: away from the other island's side of the swing (or across, when level)
			local outward = if a.z == b.z then (if side == 1 then 1 else -1) else (if side == 1 then math.sign(a.z - b.z) else math.sign(b.z - a.z))
			local z = atZ
			for _ = 1, 40 do
				if clear(midX, z, radius) then
					table.insert(list, { x = midX, z = z, radius = radius })
					break
				end
				z += outward * 4
			end
		end
	end
	return list
end

-- The region at a point: its nearest island's (past the castle, the lair: the castle's)
function AbyssLayout.regionAt(islands: { Island }, point: Spot): string
	local best, region = math.huge, islands[1].region
	for _, each in islands do
		local apart = math.sqrt((point.x - each.x) ^ 2 + (point.z - each.z) ^ 2) - each.size
		if apart < best then
			best, region = apart, each.region
		end
	end
	return region
end

-- Whether a character this low has fallen into the chasm
function AbyssLayout.fallen(y: number, killY: number): boolean
	return y < killY
end

return AbyssLayout
