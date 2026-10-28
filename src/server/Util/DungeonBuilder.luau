--!strict
-- Builds the Dungeon's cavern from Config/Dungeon (DungeonService calls it once, in the Dungeon place): a long dark floor
-- along +X walled on both sides, the entrance hall with the spawn, three rooms (a disc ringed by posts, a see-through
-- barrier that seals during its fight, a gate with the start prompt's part) each closed off from the next by a crossing
-- wall and its door, then the chamber door before the Prism Hydra's arena (WildService.BuildBossArenas builds that one
-- at Dungeon.CHAMBER). Prism crystals in the five element colours, coloured light shafts over the rooms, and the
-- place's Lighting dark and foggy.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))

export type Room = { center: Vector3, gate: BasePart, door: BasePart, barrier: { BasePart }, inside: CFrame, packSpot: CFrame }
export type DungeonLayout = { entrance: CFrame, spawn: SpawnLocation, rooms: { Room }, chamberDoor: BasePart, returnSpot: CFrame }

local DungeonBuilder = {}

local CRYSTALS_PER_SIDE = 14
local LIT_CRYSTAL_EVERY = 3 -- one crystal in this many carries a light (phones: few lights)

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Slate
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A door across the corridor: solid and glowing while closed (DungeonService opens it)
local function door(parent: Instance, name: string, x: number, origin: Vector3): Part
	local part = block(parent, name, Vector3.new(2, Dungeon.WALL_HEIGHT, Dungeon.CORRIDOR_WIDTH), CFrame.new(origin + Vector3.new(x, Dungeon.WALL_HEIGHT / 2, 0)), rgb(Dungeon.COLORS.DOOR), Enum.Material.ForceField)
	part.Transparency = 0.2
	return part
end

-- A crossing wall with a corridor-wide gap in the middle (its door fills the gap)
local function crossWall(parent: Instance, x: number, origin: Vector3, halfWidth: number)
	local side = halfWidth - Dungeon.CORRIDOR_WIDTH / 2
	for _, sign in { -1, 1 } do
		local z = sign * (Dungeon.CORRIDOR_WIDTH / 2 + side / 2)
		block(parent, "Wall", Vector3.new(4, Dungeon.WALL_HEIGHT, side), CFrame.new(origin + Vector3.new(x, Dungeon.WALL_HEIGHT / 2, z)), rgb(Dungeon.COLORS.WALL))
	end
end

local function crystal(parent: Instance, position: Vector3, color: Color3, random: Random, lit: boolean)
	local height = random:NextNumber(4, 11)
	local part = block(parent, "Crystal", Vector3.new(random:NextNumber(1.5, 3), height, random:NextNumber(1.5, 3)),
		CFrame.new(position + Vector3.new(0, height / 2 - 0.5, 0)) * CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(0, math.pi), random:NextNumber(-0.3, 0.3)),
		color, Enum.Material.Neon)
	part.Transparency = 0.15
	part.CanCollide = false
	if lit then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 16
		light.Brightness = 1.2
		light.Parent = part
	end
end

local function shaft(parent: Instance, position: Vector3, color: Color3)
	local beam = block(parent, "LightShaft", Vector3.new(Dungeon.WALL_HEIGHT * 2, 6, 6), CFrame.new(position + Vector3.new(0, Dungeon.WALL_HEIGHT, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon)
	beam.Shape = Enum.PartType.Cylinder
	beam.Transparency = 0.9
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CastShadow = false
end

local function room(parent: Instance, index: number, center: Vector3): Room
	local radius = Dungeon.ROOM_RADIUS
	-- Cylinders run along X: lay the disc flat
	local floor = block(parent, `Room {index}`, Vector3.new(2, radius * 2, radius * 2), CFrame.new(center - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(Dungeon.COLORS.FLOOR):Lerp(Color3.new(1, 1, 1), 0.08))
	floor.Shape = Enum.PartType.Cylinder
	for step = 0, 19 do
		local angle = step / 20 * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		if math.abs(direction.X) < 0.97 then -- open toward both corridors (-X in, +X out)
			block(parent, "Post", Vector3.new(1.4, 6, 1.4), CFrame.new(center + direction * (radius - 0.7) + Vector3.new(0, 3, 0)), rgb(Dungeon.COLORS.WALL):Lerp(Color3.new(1, 1, 1), 0.15))
		end
	end
	local barrier: { BasePart } = {}
	for _, angle in BossRules.ringSegments(radius + 0.5, Bosses.BARRIER_SEGMENT) do
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local spot = center + direction * (radius + 0.5) + Vector3.new(0, Bosses.BARRIER_HEIGHT / 2, 0)
		local wall = block(parent, "Barrier", Vector3.new(Bosses.BARRIER_SEGMENT + 0.5, Bosses.BARRIER_HEIGHT, 1), CFrame.lookAt(spot, spot + direction), Color3.fromRGB(170, 120, 255), Enum.Material.ForceField)
		wall.Transparency = 1
		wall.CanCollide = false
		wall.CanQuery = false
		table.insert(barrier, wall)
	end
	local gateSpot = center - Vector3.new(radius - 2, 0, 0)
	local gate = block(parent, "RoomGate", Vector3.new(1, 9, 12), CFrame.new(gateSpot + Vector3.new(0, 4.5, 0)), rgb(Dungeon.COLORS.DOOR), Enum.Material.Neon)
	gate.CanCollide = false
	gate.Transparency = 0.6
	local packSpot = center + Vector3.new(8, 0, 0)
	return {
		center = center,
		gate = gate,
		door = gate, -- replaced by the door after this room (DungeonBuilder.build)
		barrier = barrier,
		inside = CFrame.lookAt(gateSpot + Vector3.new(Bosses.INSIDE_STEP, 3, 0), packSpot + Vector3.new(0, 3, 0)),
		packSpot = CFrame.lookAt(packSpot, gateSpot),
	}
end

-- The cavern under `parent`; its rooms and doors for DungeonService
function DungeonBuilder.build(parent: Instance): DungeonLayout
	local origin = Vector3.new(Dungeon.ORIGIN.x, Dungeon.ORIGIN.y, Dungeon.ORIGIN.z)
	local chamber = Vector3.new(Dungeon.CHAMBER.x, Dungeon.CHAMBER.y, Dungeon.CHAMBER.z)
	local radius, gap = Dungeon.ROOM_RADIUS, Dungeon.ROOM_GAP
	local halfWidth = math.max(radius, Bosses.ARENA_RADIUS) + 14
	local finish = chamber.X - origin.X + Bosses.ARENA_RADIUS + 16
	local wallColor = rgb(Dungeon.COLORS.WALL)

	-- The floor just under the rooms' and the arena's discs (their tops sit at y = 0)
	block(parent, "Floor", Vector3.new(finish + 20, 2, halfWidth * 2), CFrame.new(origin + Vector3.new(finish / 2 - 10, -1.05, 0)), rgb(Dungeon.COLORS.FLOOR))
	for _, sign in { -1, 1 } do
		block(parent, "Wall", Vector3.new(finish + 20, Dungeon.WALL_HEIGHT, 4), CFrame.new(origin + Vector3.new(finish / 2 - 10, Dungeon.WALL_HEIGHT / 2, sign * (halfWidth + 2))), wallColor)
	end
	block(parent, "Wall", Vector3.new(4, Dungeon.WALL_HEIGHT, halfWidth * 2 + 8), CFrame.new(origin + Vector3.new(-12, Dungeon.WALL_HEIGHT / 2, 0)), wallColor)
	block(parent, "Wall", Vector3.new(4, Dungeon.WALL_HEIGHT, halfWidth * 2 + 8), CFrame.new(origin + Vector3.new(finish + 12, Dungeon.WALL_HEIGHT / 2, 0)), wallColor)

	-- The entrance hall: the spawn, facing into the cavern
	local entrance = CFrame.lookAt(origin + Vector3.new(6, 3, 0), origin + Vector3.new(30, 3, 0))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "DungeonSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + Vector3.new(6, 0.5, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = parent

	-- The rooms, each closed off from the next by a crossing wall and its door; the last door opens onto the chamber
	local rooms: { Room } = {}
	local x = Dungeon.HALL.length + gap + radius
	for index = 1, #Dungeon.ROOMS do
		local center = origin + Vector3.new(x, 0, 0)
		local made = room(parent, index, center)
		local doorX = x + radius + gap / 2
		crossWall(parent, doorX, origin, halfWidth)
		made.door = door(parent, if index == #Dungeon.ROOMS then "ChamberDoor" else `Door {index}`, doorX, origin)
		-- At the back of the ring, behind the pack: never over the fight
		shaft(parent, center + Vector3.new(radius - 4, 0, 0), rgb(Dungeon.COLORS.CRYSTALS[(index - 1) % #Dungeon.COLORS.CRYSTALS + 1]))
		table.insert(rooms, made)
		x += radius * 2 + gap
	end
	shaft(parent, chamber + Vector3.new(Bosses.ARENA_RADIUS - 6, 0, 0), Color3.fromRGB(235, 245, 255))

	-- Prism crystals along both walls
	local random = Random.new(4242)
	local count = 0
	for _, sign in { -1, 1 } do
		for step = 1, CRYSTALS_PER_SIDE do
			count += 1
			local along = (step - 0.5) / CRYSTALS_PER_SIDE * finish
			local color = rgb(Dungeon.COLORS.CRYSTALS[count % #Dungeon.COLORS.CRYSTALS + 1])
			crystal(parent, origin + Vector3.new(along, 0, sign * (halfWidth - random:NextNumber(1.5, 4))), color, random, count % LIT_CRYSTAL_EVERY == 0)
		end
	end

	local look = Dungeon.LIGHTING
	Lighting.Ambient = rgb(look.ambient)
	Lighting.OutdoorAmbient = rgb(look.outdoorAmbient)
	Lighting.Brightness = look.brightness
	Lighting.ClockTime = look.clockTime
	Lighting.FogColor = rgb(look.fogColor)
	Lighting.FogEnd = look.fogEnd
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		-- Fog settings are ignored while an Atmosphere exists: tint it instead
		atmosphere.Color = rgb(look.fogColor)
		atmosphere.Decay = rgb(look.fogColor)
		atmosphere.Density = look.atmosphereDensity
	end

	return {
		entrance = entrance,
		spawn = spawn,
		rooms = rooms,
		chamberDoor = rooms[#rooms].door,
		returnSpot = CFrame.lookAt(chamber + Vector3.new(0, 0, -(Bosses.ARENA_RADIUS - 8)), chamber),
	}
end

return DungeonBuilder
