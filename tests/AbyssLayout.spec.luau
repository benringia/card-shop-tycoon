--!strict
-- The Crystal Abyss's layout (specs 2026-11-12-dungeon-world, 2026-11-12-abyss-regions): a winding way of islands over
-- the chasm, small stops between the steps, craters round the fight rooms, the regions, the castle, the lair, the fall
local AbyssLayout = require("../src/shared/Util/AbyssLayout")
local Dungeon = require("../src/shared/Config/Dungeon")
local expect = require("./lib/expect")

local ABYSS = Dungeon.ABYSS
local WALK_SPEED = 16 -- Roblox's default WalkSpeed

local function layout()
	local islands = AbyssLayout.islands(Dungeon)
	return islands, AbyssLayout.bridges(islands)
end

-- The distance from a point to a bridge's middle line (its segment)
local function fromBridge(bridge: AbyssLayout.Bridge, x: number, z: number): number
	local dx, dz = x - bridge.from.x, z - bridge.from.z
	local along = math.clamp(dx * math.cos(bridge.yaw) + dz * math.sin(bridge.yaw), 0, bridge.length)
	local spot = AbyssLayout.alongBridge(bridge, along)
	return math.sqrt((x - spot.x) ^ 2 + (z - spot.z) ^ 2)
end

return {
	["islands in walking order: the ledge, the steps with stops between, the castle"] = function()
		local islands = layout()
		expect.equal(islands[1].kind, "ledge", "the ledge first")
		expect.equal(islands[#islands].kind, "castle", "the castle last")
		local steps = 0
		for index, island in islands do
			if island.step then
				steps += 1
				expect.equal(island.step, steps, `step {steps} in order`)
				expect.equal(island.kind, Dungeon.STEPS[steps].kind, `step {steps}'s kind`)
				expect.equal(islands[index - 1].kind, "stop", `a stop before step {steps}`)
			end
			if index > 1 then
				expect.equal(island.entry.x > islands[index - 1].exit.x, true, `island {index} after {index - 1}`)
			end
		end
		expect.equal(steps, #Dungeon.STEPS, "every step")
		for step = 1, #Dungeon.STEPS do
			local found, at = AbyssLayout.stepIsland(islands, step)
			expect.equal(found ~= nil and found.step == step and islands[at :: number] == found, true, `stepIsland {step}`)
		end
	end,

	["a winding way: 12-22 s of walking between steps, swinging across the cave"] = function()
		local islands, bridges = layout()
		local marks = {}
		for index, island in islands do
			if island.step or island.kind == "ledge" or island.kind == "castle" then
				table.insert(marks, index)
			end
		end
		for k = 1, #marks - 1 do
			local studs = 0
			for index = marks[k], marks[k + 1] - 1 do
				studs += bridges[index].length
				if index > marks[k] then
					studs += islands[index].size * 2 -- across a stop
				end
			end
			local seconds = studs / WALK_SPEED
			expect.equal(seconds >= 12 and seconds <= 22, true, `walk {k}: {math.floor(seconds)} s`)
		end
		local widest = 0
		for _, island in islands do
			widest = math.max(widest, math.abs(island.z))
		end
		expect.equal(widest >= 40, true, "the way swings")
	end,

	["regions: each step's own, the stops on the way to it the same, the castle its own"] = function()
		local islands = layout()
		expect.equal(islands[1].region, Dungeon.REGION_OF_STEP[1], "the ledge")
		for index, island in islands do
			expect.equal(Dungeon.REGIONS[island.region] ~= nil, true, `island {index}'s region exists`)
			if island.step then
				expect.equal(island.region, Dungeon.REGION_OF_STEP[island.step], `step {island.step}`)
			elseif island.kind == "stop" then
				local nextStep = islands[index + 1]
				local k = index + 1
				while islands[k].kind == "stop" do
					k += 1
				end
				nextStep = islands[k]
				expect.equal(island.region, nextStep.region, `stop {index} takes the next step's`)
			end
		end
		expect.equal(islands[#islands].region, Dungeon.CASTLE_REGION, "the castle")
		-- Terrain colours are per material: no two regions share one, and none is the cave's own Rock
		local used = {}
		for name, region in Dungeon.REGIONS do
			for _, material in { region.top, region.rock } do
				expect.equal(used[material] == nil and material ~= "Rock", true, `{name}'s {material} its own`)
				used[material] = true
			end
		end
	end,

	["fight islands sit in craters: the rim taller than an eye and round the walls"] = function()
		local crater = ABYSS.CRATER
		for _, island in (layout()) do
			if island.kind == "fight" then
				expect.equal(island.round, true, "round")
				expect.equal(island.size, crater.outer, "the crater's edge")
			end
		end
		expect.equal(crater.outer > ABYSS.RUINS.radius + 4, true, "the rim outside the walls")
		expect.equal(crater.height >= 14, true, "taller than the camera's eye")
		expect.equal(math.asin(ABYSS.SEAL.pillarApart / 2 / crater.outer) < math.rad(crater.gap), true, "the way in wide enough")
	end,

	["puzzle pieces stand on their island"] = function()
		local limit = ABYSS.PUZZLE_HALF - 2
		for _, spot in Dungeon.PUZZLE.PLATES do
			expect.equal(math.abs(spot.x) <= limit and math.abs(spot.z) <= limit, true, "a plate")
		end
		local count = #Dungeon.PUZZLE.LOCK_LAYOUT
		for index = 1, count do
			local z = (index - (count + 1) / 2) * Dungeon.PUZZLE.LOCK_SPACING
			expect.equal(math.abs(z) <= limit, true, "a lock crystal")
		end
		for _, beams in Dungeon.BEAMS.LAYOUTS do
			local half = (math.max(beams.width, beams.height) + 1) / 2 * Dungeon.BEAMS.CELL
			expect.equal(half <= limit, true, "the beam grid")
		end
		for _, island in (layout()) do
			if island.kind == "beams" or island.kind == "plates" or island.kind == "lock" then
				expect.equal(island.round, false, "square")
				expect.equal(island.size, ABYSS.PUZZLE_HALF, "its half side")
			end
		end
	end,

	["the secret ledge sits on the plates island's +z side, nothing there"] = function()
		expect.equal(Dungeon.PUZZLE.ALCOVE.z <= ABYSS.PUZZLE_HALF + 2, true, "the cracked wall at the island's edge")
		local islands = layout()
		local plates = AbyssLayout.stepIsland(islands, 4) :: AbyssLayout.Island
		expect.equal(plates.kind, "plates", "step 4")
		local niche = { x = plates.x, z = plates.z + Dungeon.PUZZLE.ALCOVE.z + Dungeon.PUZZLE.ALCOVE.depth }
		for _, other in islands do
			if other ~= plates then
				expect.equal(AbyssLayout.onIsland(other, niche), false, "no other island in the niche")
			end
		end
	end,

	["islands never overlap"] = function()
		local islands = layout()
		for a = 1, #islands do
			for b = a + 1, #islands do
				local one, two = islands[a], islands[b]
				local apart = math.sqrt((one.x - two.x) ^ 2 + (one.z - two.z) ^ 2)
				expect.equal(apart > one.size + two.size, true, `islands {a} and {b}`)
			end
		end
	end,

	["bridges link neighbours and stay walkable"] = function()
		local islands, bridges = layout()
		expect.equal(#bridges, #islands - 1, "one between each pair")
		for index, bridge in bridges do
			expect.equal(bridge.length >= 12 and bridge.length <= 60, true, `bridge {index} length {math.floor(bridge.length)}`)
			local middle = AbyssLayout.alongBridge(bridge, bridge.length / 2)
			expect.equal(AbyssLayout.onStone(islands, {}, ABYSS.BRIDGE_WIDTH, middle), false, `bridge {index} over the chasm`)
			expect.equal(AbyssLayout.onStone(islands, bridges, ABYSS.BRIDGE_WIDTH, middle), true, `bridge {index} walkable`)
			expect.equal(AbyssLayout.onStone(islands, bridges, ABYSS.BRIDGE_WIDTH, AbyssLayout.alongBridge(bridge, 6)), true, `bridge {index} start`)
			expect.equal(AbyssLayout.onStone(islands, bridges, ABYSS.BRIDGE_WIDTH, AbyssLayout.alongBridge(bridge, bridge.length - 6)), true, `bridge {index} end`)
		end
		local bridge = bridges[2]
		local middle = AbyssLayout.alongBridge(bridge, bridge.length / 2)
		local aside = { x = middle.x - math.sin(bridge.yaw) * 10, z = middle.z + math.cos(bridge.yaw) * 10 }
		expect.equal(AbyssLayout.onStone(islands, bridges, ABYSS.BRIDGE_WIDTH, aside), false, "beside a bridge")
	end,

	["a bridge leaves a round island on the side facing where it goes, and lands the same"] = function()
		local islands, bridges = layout()
		for index, bridge in bridges do
			for _, pair in { { island = islands[index], at = bridge.from, sign = 1 }, { island = islands[index + 1], at = bridge.to, sign = -1 } } do
				local each = pair.island
				if each.round then
					local dx, dz = pair.at.x - each.x, pair.at.z - each.z
					expect.equal(math.abs(math.sqrt(dx * dx + dz * dz) - each.size) < 0.01, true, `bridge {index} on island {each.kind}'s edge`)
					local along = (dx * math.cos(bridge.yaw) + dz * math.sin(bridge.yaw)) * pair.sign
					expect.equal(along > each.size * 0.99, true, `bridge {index} leaves facing its way`)
				end
			end
		end
	end,

	["every corner of a bridge's slab ends over stone (nobody steps off where it meets an island)"] = function()
		local islands, bridges = layout()
		local half = ABYSS.BRIDGE_WIDTH / 2
		for index, bridge in bridges do
			-- the slab runs a stud past each end (DungeonBuilder.bridge): its end edges' corners
			for _, along in { -1, bridge.length + 1 } do
				for _, side in { -1, 1 } do
					local middle = AbyssLayout.alongBridge(bridge, along)
					local corner = { x = middle.x - math.sin(bridge.yaw) * half * side, z = middle.z + math.cos(bridge.yaw) * half * side }
					local island = if along < 0 then islands[index] else islands[index + 1]
					expect.equal(AbyssLayout.onIsland(island, corner), true, `bridge {index}'s corner over island {island.kind}`)
				end
			end
		end
	end,

	["no walking round a gate: only chasm past its ends (the lock's way on: the Hydra's door at the castle)"] = function()
		local islands, bridges = layout()
		for step = 1, #Dungeon.STEPS - 1 do
			local _, index = AbyssLayout.stepIsland(islands, step)
			local bridge = bridges[index :: number]
			local half = ABYSS.GATE_HALF
			local at = AbyssLayout.gateAlong(islands, bridge, half, false)
			expect.equal(at ~= nil, true, `step {step}'s gate fits its bridge`)
			local studs = at :: number
			local middle = AbyssLayout.alongBridge(bridge, studs)
			for _, past in { 0.5, 2, 4 } do
				for _, side in { -1, 1 } do
					local reach = side * (half + past)
					local spot = { x = middle.x - math.sin(bridge.yaw) * reach, z = middle.z + math.cos(bridge.yaw) * reach }
					expect.equal(AbyssLayout.onStone(islands, {}, ABYSS.BRIDGE_WIDTH, spot), false, `step {step}'s gate: chasm {past} past its end`)
				end
			end
			expect.equal(AbyssLayout.onStone(islands, bridges, ABYSS.BRIDGE_WIDTH, AbyssLayout.alongBridge(bridge, studs + 6)), true, `past step {step}'s gate`)
		end
	end,

	["spires stand beside the turns, clear of the way"] = function()
		local islands, bridges = layout()
		local spires = AbyssLayout.spires(islands, ABYSS)
		expect.equal(#spires >= #Dungeon.STEPS, true, "at least one a turn")
		for index, spire in spires do
			for _, island in islands do
				local apart = math.sqrt((spire.x - island.x) ^ 2 + (spire.z - island.z) ^ 2)
				expect.equal(apart > island.size + spire.radius + ABYSS.SPIRES.clear, true, `spire {index} clear of an island`)
			end
			for _, bridge in bridges do
				expect.equal(fromBridge(bridge, spire.x, spire.z) > spire.radius + ABYSS.BRIDGE_WIDTH / 2 + ABYSS.SPIRES.clear, true, `spire {index} clear of a bridge`)
			end
			expect.equal(math.abs(spire.z) + spire.radius < ABYSS.CAVE_HALF_WIDTH, true, `spire {index} inside the cave`)
		end
	end,

	["the castle at the end, the lair past the cave's east wall"] = function()
		local islands = layout()
		local castle = islands[#islands]
		expect.equal(castle.size, ABYSS.CASTLE.size, "its plateau")
		expect.equal(castle.z, ABYSS.ROUTE.castleZ, "its z")
		local east = AbyssLayout.eastWall(islands)
		local lair = ABYSS.LAIR
		expect.equal(Dungeon.CHAMBER.x - lair.radius - lair.wall > east + 20, true, "the lair's rock past the east wall")
		expect.equal(Dungeon.CHAMBER.z, 0, "on the middle line")
		expect.equal(lair.radius > 48 + 20, true, "the Hydra's ring and its gate inside the dome")
	end,

	-- The owner 2026-11-12: "this part of the entrance is empty. add large animal bones or adventurer bones"
	["the castle's forecourt: bones on the plateau, clear of the way to the gate"] = function()
		local look = ABYSS.CASTLE
		expect.equal(#look.bones >= 6, true, "enough to fill it")
		local big = 0
		for index, bone in look.bones do
			-- x from the gate (out front is negative), z from the castle's middle line
			expect.equal(bone.x < -3 and bone.x > -(look.size - look.front) + 3, true, `bone {index} on the forecourt`)
			expect.equal(math.abs(bone.z) < look.size - 4, true, `bone {index} on the plateau`)
			local small = bone.model == "Bones"
			local clear = if small then 8 else 14 -- the walkway from the bridge (and its braziers) stays open
			expect.equal(math.abs(bone.z) >= clear, true, `bone {index} clear of the walkway`)
			expect.equal(bone.scale > 0 and bone.scale <= 2, true, `bone {index} a sane size`)
			if not small then
				big += 1
			end
		end
		expect.equal(big >= 3, true, "a few big skeletons, not only small bones")
	end,

	["regionAt: the nearest island's region; the lair the castle's"] = function()
		local islands = layout()
		local room2 = AbyssLayout.stepIsland(islands, 3) :: AbyssLayout.Island
		expect.equal(AbyssLayout.regionAt(islands, { x = room2.x, z = room2.z }), "Volt", "room 2")
		expect.equal(AbyssLayout.regionAt(islands, { x = Dungeon.CHAMBER.x, z = 0 }), Dungeon.CASTLE_REGION, "the lair")
		expect.equal(AbyssLayout.regionAt(islands, { x = 0, z = 0 }), Dungeon.REGION_OF_STEP[1], "the ledge")
	end,

	["ruined walls round a fight room, open where the bridges come and go"] = function()
		local ruins = ABYSS.RUINS
		local angles = AbyssLayout.ruinAngles(ruins.count, ruins.gapOut, ruins.gapIn)
		expect.equal(#angles, ruins.count, "every piece")
		expect.equal(ruins.gapIn < ruins.gapOut, true, "the way in narrows to its seal")
		local sealHalf = math.deg(math.asin(ABYSS.SEAL.pillarApart / 2 / ruins.radius))
		expect.equal(sealHalf < ruins.gapIn, true, "the seal fits the way in")
		for index, angle in angles do
			local degrees = math.deg(angle) % 360
			local fromX = math.min(degrees, 360 - degrees)
			local fromMinusX = math.abs(degrees - 180)
			expect.equal(fromX >= ruins.gapOut and fromMinusX >= ruins.gapIn, true, `piece {index} clear of the ways in and out`)
			if index > 1 then
				expect.equal(angle > angles[index - 1], true, "in order round the ring")
			end
		end
	end,

	["the backdrop: far off the way, inside the cave, the same every time"] = function()
		local islands = layout()
		local west, east = islands[1].x - islands[1].size, AbyssLayout.eastWall(islands)
		local back = AbyssLayout.backdrop(ABYSS, west, east, 7)
		local again = AbyssLayout.backdrop(ABYSS, west, east, 7)
		local look = ABYSS.BACKDROP
		local widest = 0
		for _, island in islands do
			widest = math.max(widest, math.abs(island.z) + island.size)
		end
		expect.equal(look.band[1] > widest + 20, true, "the band past the way's widest swing")
		expect.equal(#back.crystals, look.crystals, "crystals")
		expect.equal(#back.islands, look.islands, "far islands")
		expect.equal(#back.falls, look.falls, "light falls")
		expect.equal(#back.reliefs, look.reliefs, "hydra carvings")
		expect.equal(back.islands[1].x, again.islands[1].x, "the same every time")
		for _, list in { back.crystals, back.islands, back.falls, back.reliefs } do
			for _, item in list do
				expect.equal(item.x >= west - 5 and item.x <= east + 5, true, "along the cave")
				expect.equal(math.abs(item.z) <= ABYSS.CAVE_HALF_WIDTH, true, "inside its walls")
				expect.equal(math.abs(item.z) >= look.band[1], true, "clear of the way")
			end
		end
		for a = 1, #back.islands do
			local one = back.islands[a]
			expect.equal(math.abs(one.z) + one.size <= ABYSS.CAVE_HALF_WIDTH - 10, true, "a far island off the wall")
			for b = a + 1, #back.islands do
				local two = back.islands[b]
				local apart = math.sqrt((one.x - two.x) ^ 2 + (one.y - two.y) ^ 2 + (one.z - two.z) ^ 2)
				expect.equal(apart > one.size + two.size, true, `far islands {a} and {b} apart`)
			end
		end
		for _, fall in back.falls do
			expect.equal(fall.top > fall.bottom and fall.bottom < ABYSS.KILL_Y, true, "a fall pours into the chasm")
		end
	end,

	["onIsland: on that island only, never its bridge"] = function()
		local islands, bridges = layout()
		local beams, at = AbyssLayout.stepIsland(islands, 2)
		local island = beams :: AbyssLayout.Island
		expect.equal(island.kind, "beams", "step 2's island")
		expect.equal(AbyssLayout.onIsland(island, { x = island.x, z = island.z }), true, "its middle")
		expect.equal(AbyssLayout.onIsland(island, { x = island.x + island.size - 1, z = island.z }), true, "by its edge")
		local into = bridges[(at :: number) - 1]
		expect.equal(AbyssLayout.onIsland(island, AbyssLayout.alongBridge(into, into.length / 2)), false, "the bridge in")
		local room = AbyssLayout.stepIsland(islands, 1) :: AbyssLayout.Island
		expect.equal(AbyssLayout.onIsland(island, { x = room.x, z = room.z }), false, "the room before")
	end,

	["everything inside the cave"] = function()
		for _, island in (layout()) do
			expect.equal(math.abs(island.z) + island.size < ABYSS.CAVE_HALF_WIDTH, true, "inside the walls")
		end
		expect.equal(ABYSS.KILL_Y < -ABYSS.UNDERSIDE - 5, true, "the kill height under every island")
		expect.equal(ABYSS.CEILING_Y > 60, true, "a high ceiling")
	end,

	["fallen"] = function()
		expect.equal(AbyssLayout.fallen(-61, -60), true, "below")
		expect.equal(AbyssLayout.fallen(-59, -60), false, "above")
	end,
}
