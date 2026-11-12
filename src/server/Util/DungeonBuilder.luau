--!strict
-- Builds the Dungeon from Config/Dungeon (DungeonService calls it once, in the Dungeon place): the Crystal Abyss (spec
-- 2026-11-12-dungeon-world), a giant cave in Terrain (ceiling, far walls, stalactites) over a bottomless chasm, and
-- the run as a winding way of islands over it (Util/AbyssLayout; round 3 part 2, spec 2026-11-12-abyss-regions): the
-- entrance ledge with the spawn, its braziers and the way back, small stop islands between the steps, rock spires beside
-- the turns, and one island per step of Dungeon.STEPS (spec 2026-11-11-dungeon-puzzles), each closed by a gate on its
-- bridge out: the fight rooms (in a crater, ringed by ruined walls, sealed at their Fight gate; room 3 with its pylons
-- and its pack's shield), the prism beam room (the gem, four mirrors on a grid, the door's prism), the plate room (the
-- plates and the secret niche behind a cracked wall, on its own small ledge) and the element lock room (five crystals).
-- Last the Hydra's castle: its broken walls and towers, the hydra gate sealed by the Hydra's round door (its five eyes
-- the lock's sockets), the portal into the lair past the cave's east wall (WildService.BuildBossArenas builds the
-- arena's ring at Dungeon.CHAMBER, inside the lair's dome). Islands are Terrain mesas in their region's rock (Config/
-- Dungeon REGIONS) with an invisible exact floor; crystals and ruins round their rims, a region accent over each step;
-- dim lights deep in the chasm, the far scenery, no sky. Pieces wear the props pack (tools/blender/build_dungeon_props.py,
-- ReplicatedStorage.PropModels) as a "Look" model under their part once it's imported, code-built stand-ins until then;
-- DungeonBuilder.tint / hide change a piece's look either way (the puzzles and fights call them).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local Town = require(Config:WaitForChild("Town"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))
local AbyssLayout = require(Shared:WaitForChild("Util"):WaitForChild("AbyssLayout"))
local PortalBuild = require((script.Parent :: Instance):WaitForChild("PortalBuild"))

export type Room = {
	center: Vector3,
	gate: BasePart,
	door: BasePart,
	barrier: { BasePart },
	inside: CFrame,
	approach: CFrame, -- on its bridge in, a few studs before the island, facing the ring (Studio's /room)
	packSpot: CFrame,
	pylons: { BasePart }, -- room 3 only (Pylon1..3)
	shield: BasePart?, -- room 3: the shield round its pack (shown while the pylons stand in its fight)
	seal: BasePart, -- the solid seal across its way in (DungeonBuilder.hide opens it once the room is cleared)
}
export type Beams = { gem: BasePart, mirrors: { BasePart }, prism: BasePart, door: BasePart, chestSpot: CFrame, layout: any, cellAt: (x: number, y: number) -> Vector3 }
export type Plates = { plates: { BasePart }, door: BasePart, wall: BasePart, alcove: CFrame, chestSpot: CFrame, secretSpot: CFrame }
export type Lock = { crystals: { [string]: BasePart }, sockets: { BasePart }, door: BasePart, chestSpot: CFrame }
export type DungeonLayout = {
	entrance: CFrame,
	spawn: SpawnLocation,
	rooms: { Room },
	doors: { BasePart }, -- the door after each step (Dungeon.STEPS order); the last one is the chamber door
	beams: Beams,
	plates: Plates,
	lock: Lock,
	chamberDoor: BasePart,
	returnSpot: CFrame,
	islands: { AbyssLayout.Island },
	bridges: { AbyssLayout.Bridge },
	afterDoor: { CFrame }, -- per door, a few studs past it on its way on (Studio's /puzzle)
	stepIslands: { AbyssLayout.Island }, -- each step's island (the puzzles wait for the group on theirs)
	lairPortal: BasePart, -- the castle's gate into the Hydra's lair (DungeonService's prompt, on once the door opens)
	hydraEyes: { BasePart }, -- the castle gate's dragon heads' eyes, left to right (dark until the lock is solved)
}

local DungeonBuilder = {}

local ABYSS = Dungeon.ABYSS
local RIM_PIECES = 14 -- crystals and pillars round a round island's rim (a square one: 4 a side)
local CLEAR_OF_BRIDGE = 12 -- rim pieces keep this far from where a bridge meets the island
local GATE_HEIGHT = 14 -- an island gate's barrier
local BRIDGE_SEGMENT = 12 -- a DungeonBridge prop's length
local BRIDGE_DECK = 1.4 -- a DungeonBridge prop's deck under its walking top (its pivot is its bottom)
local CHAIN_LENGTH = 60 -- a DungeonChain prop's length (hung from the ceiling)
local STALACTITES = 90 -- over the whole winding cave
-- Terrain's surface comes out this much above a fill's top (measured in Studio, 2026-11-12: a top filled to y 0 stood
-- at 2 and buried the plates and chests): fills meant to be level with a floor go this much lower
local TERRAIN_LIFT = 2
local EYE_ARC = ABYSS.DOOR_RADIUS * 0.55 -- the Hydra's door's eyes (the lock's sockets) on an arc this far out
local BRAZIER = Color3.fromRGB(255, 176, 96) -- the braziers' flame and light
local LIT_CRYSTAL_EVERY = 4 -- one crystal in this many carries a light (phones: few lights)
local PUZZLE = Dungeon.PUZZLE
local CHAMBER_RADIUS = BossRules.arenaRadius(Bosses.BOSSES[Dungeon.BOSS], Bosses) -- the Hydra's own (48)

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- An element's colour (Dungeon.ELEMENTS lines up with COLORS.CRYSTALS)
local function elementColor(element: string): Color3
	local index = table.find(Dungeon.ELEMENTS, element) or 1
	return rgb(Dungeon.COLORS.CRYSTALS[index])
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

-- A see-through, untouchable piece (glows, never blocks a prompt's ray or a player)
local function ghost(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local LOOK = "Look" -- a piece's props-pack model, parented to the piece's part

-- A props-pack model (ReplicatedStorage.PropModels, split from assets/props-import/DungeonProps.rbxm; 1 stud a Blender
-- unit, its pivot the bottom centre) with that pivot on `at`, `scale` times its size, its Glow parts Neon in `glow`.
-- Under `holder` as its Look (welded to it when `moves`, e.g. a turning mirror) or loose under `parent`. Nil until the
-- pack is imported: the caller keeps its stand-in.
local function prop(parent: Instance, name: string, at: CFrame, glow: Color3?, holder: BasePart?, moves: boolean?, scale: number?): Model?
	local folder = ReplicatedStorage:FindFirstChild("PropModels")
	local template = if folder then folder:FindFirstChild(name) else nil
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	if scale and scale ~= 1 then
		model:ScaleTo(scale)
	end
	model:PivotTo(at)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = not moves
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			if part.Name == "Glow" then
				for _, child in part:GetChildren() do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
				if part:IsA("MeshPart") then
					part.TextureID = ""
				end
				part.Material = Enum.Material.Neon
				part.Color = glow or Color3.new(1, 1, 1)
				part.CastShadow = false
			end
			if moves and holder then
				part.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = holder
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	if holder then
		model.Name = LOOK
		model.Parent = holder
	else
		model.Parent = parent
	end
	return model
end

-- What shows a piece's light: its Look's Glow parts, or the part itself when it has no Look
local function glowsOf(part: BasePart): { BasePart }
	local look = part:FindFirstChild(LOOK)
	if not look then
		return { part }
	end
	local list = {}
	for _, piece in look:GetDescendants() do
		if piece:IsA("BasePart") and piece.Name == "Glow" then
			table.insert(list, piece)
		end
	end
	return list
end

-- A piece's light recoloured and/or faded (a lit prism, a held plate, a broken pylon), prop or stand-in
function DungeonBuilder.tint(part: BasePart, color: Color3?, transparency: number?)
	for _, glow in glowsOf(part) do
		if color then
			glow.Color = color
		end
		if transparency then
			glow.Transparency = transparency
		end
	end
end

-- A piece gone (the broken secret wall): the part and everything it wears, see-through and walk-through
function DungeonBuilder.hide(part: BasePart)
	for _, piece in { part :: Instance, table.unpack(part:GetDescendants()) } do
		if piece:IsA("BasePart") then
			piece.Transparency = 1
			piece.CanCollide = false
			piece.CanQuery = false
		end
	end
end

-- A dragon head's eyes on the castle gate (PortalDungeon's Eye<index>): lit in the portal's colour for it, or dark
function DungeonBuilder.setEye(eye: BasePart, index: number, lit: boolean)
	local color = ((Town.PORTAL_LOOKS :: any).Dungeon.glow :: any)[`Eye{index}`] or Dungeon.HYDRA_EYES.dark
	if eye:IsA("MeshPart") then
		eye.TextureID = ""
	end
	eye.Material = if lit then Enum.Material.Neon else Enum.Material.Slate
	eye.Color = rgb(if lit then color else Dungeon.HYDRA_EYES.dark)
end

-- A light in a prop's first Glow part (a brazier's flame, a crystal cluster)
local function lightUp(model: Model, color: Color3, range: number, brightness: number)
	local glow = model:FindFirstChild("Glow", true)
	if glow then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = range
		light.Brightness = brightness
		light.Parent = glow
	end
end

-- A brazier's fire (owner 2026-11-12: "better torches, animated"): flames licking up off its bowl (its Glow) in its
-- colour, a few sparks, its light tagged DungeonTorch (DungeonRegionController flickers it gently); the welcome puts
-- the hall's out (its emitters off)
local function torchFire(model: Model, color: Color3, range: number)
	local glow = model:FindFirstChild("Glow", true)
	if not glow or not glow:IsA("BasePart") then
		return
	end
	local look = Dungeon.TORCH
	local flames = Instance.new("ParticleEmitter")
	flames.Name = "TorchFlames"
	flames.Texture = look.flameTexture
	flames.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.5)),
		ColorSequenceKeypoint.new(0.5, color),
		ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.6)),
	})
	flames.LightEmission = 1
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, look.size), NumberSequenceKeypoint.new(1, look.size * 0.2) })
	flames.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	flames.Lifetime = NumberRange.new(look.lifetime[1], look.lifetime[2])
	flames.Rate = look.rate
	flames.Speed = NumberRange.new(look.speed[1], look.speed[2])
	flames.SpreadAngle = Vector2.new(12, 12)
	flames.RotSpeed = NumberRange.new(-90, 90)
	flames.Rotation = NumberRange.new(0, 360)
	flames.EmissionDirection = Enum.NormalId.Top
	flames.Parent = glow
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "TorchSparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.2, 0)
	sparks.Lifetime = NumberRange.new(0.8, 1.4)
	sparks.Rate = look.sparks
	sparks.Speed = NumberRange.new(3, 6)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = glow
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 1.4
	light.Parent = glow
	CollectionService:AddTag(light, "DungeonTorch")
end

-- A crystal cluster with some variety (owner 2026-11-12: "a variety of shapes and noticeable sizes, some oversized,
-- some diagonal"): the props pack's clusters or single shards, mostly 0.5-1.3 times, now and then oversized, often
-- leaning, sometimes a second smaller one leaning the other way beside it. Returns the main one.
local CRYSTAL_SHAPES = { "DungeonCrystals", "DungeonCrystals", "ElementCrystal" }
local function crystalCluster(parent: Instance, at: CFrame, color: Color3, random: Random): Model?
	local look = Dungeon.CRYSTAL_VARIETY
	local shape = CRYSTAL_SHAPES[random:NextInteger(1, #CRYSTAL_SHAPES)]
	local scale = if random:NextNumber() < look.oversized then random:NextNumber(look.big[1], look.big[2]) else random:NextNumber(look.normal[1], look.normal[2])
	local lean = if random:NextNumber() < look.leanChance then math.rad(random:NextNumber(-look.lean, look.lean)) else 0
	local turn = CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	local main = prop(parent, shape, at * turn * CFrame.Angles(lean, 0, lean * 0.5), color, nil, nil, scale)
	if main and random:NextNumber() < look.pairChance then
		local beside = at * turn * CFrame.new(scale * 1.6, 0, 0) * CFrame.Angles(-lean - math.rad(15), 0, math.rad(20))
		prop(parent, "DungeonCrystals", beside, color, nil, nil, scale * 0.55)
	end
	return main
end

local RUIN_PIECES = { "DungeonWall", "CrackedWall", "DungeonWall", "DungeonPillarBroken" }

-- A fight room's ring of broken walls (round 2, concept_arena_walls.png): props pack walls and broken pillars round
-- its rim, open toward the bridges, each a little bigger or smaller, sunk and leaning; solid, so nobody walks off the
-- island through them. Low posts until the pack is in.
local function ruins(parent: Instance, center: Vector3, seed: number)
	local look = ABYSS.RUINS
	local random = Random.new(seed)
	for index, angle in AbyssLayout.ruinAngles(look.count, look.gapOut, look.gapIn) do
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local spot = center + direction * look.radius
		local scale = random:NextNumber(look.scale[1], look.scale[2])
		local name = RUIN_PIECES[(index + seed) % #RUIN_PIECES + 1]
		local lean = CFrame.Angles(math.rad(random:NextNumber(-look.tilt, look.tilt)), 0, math.rad(random:NextNumber(-look.tilt, look.tilt)))
		-- facing the ring's middle, its width along the rim
		local model = prop(parent, name, CFrame.lookAt(spot, center) * lean, rgb(ABYSS.GLOW.color), nil, nil, scale)
		if model then
			local _, size = model:GetBoundingBox()
			model:PivotTo(model:GetPivot() - Vector3.new(0, size.Y * random:NextNumber(look.sink[1], look.sink[2]), 0))
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and part.Name ~= "Glow" then
					part.CanCollide = true
				end
			end
		else
			block(parent, "Post", Vector3.new(1.4, 6, 1.4), CFrame.new(spot + Vector3.new(0, 3, 0)), rgb(Dungeon.COLORS.WALL):Lerp(Color3.new(1, 1, 1), 0.15))
		end
	end
end

-- The hydra seal standing across a gate (round 2): the props pack's DungeonSigil upright in `frame`'s opening (frame's
-- +X the way through), glowing, worn by `holder` so DungeonBuilder.hide takes it away with it. False until the pack is in.
local function seal(holder: BasePart, frame: CFrame, color: Color3): boolean
	local look = ABYSS.SEAL
	local template = ReplicatedStorage:FindFirstChild("PropModels") and ReplicatedStorage.PropModels:FindFirstChild("DungeonSigil")
	if not template or not template:IsA("Model") then
		return false
	end
	local _, size = template:GetBoundingBox()
	-- flat on the ground as made: stood up across the way (its face along +X), its middle at the seal's height
	local upright = frame * CFrame.new(0, look.height, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local model = prop(holder.Parent :: Instance, "DungeonSigil", upright, color, holder, false, look.size / math.max(size.X, size.Z))
	if not model then
		return false
	end
	-- the pivot is the sigil's bottom centre, flat: standing up it must be centred on the opening
	local box = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + ((frame * CFrame.new(0, look.height, 0)).Position - box.Position))
	lightUp(model, color, look.light, 1.5)
	CollectionService:AddTag(model, "DungeonCameraFade") -- see-through when the camera comes close (a fight's camera)
	return true
end

local function room(parent: Instance, index: number, center: Vector3): Room
	local radius = Dungeon.ROOM_RADIUS -- its floor is its island's (DungeonBuilder.build)
	ruins(parent, center, index * 31)
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
	local ruinsLook = ABYSS.RUINS
	-- the way in: the Fight gate in the walls' ring, sealed (solid) until the room is cleared
	local gateSpot = center - Vector3.new(ruinsLook.radius, 0, 0)
	local inWidth = 2 * ruinsLook.radius * math.sin(math.rad(ruinsLook.gapIn)) + 2
	local sealWall = block(parent, "RoomSeal", Vector3.new(2, ruinsLook.wallHeight, inWidth), CFrame.new(gateSpot + Vector3.new(0, ruinsLook.wallHeight / 2, 0)), rgb(Dungeon.COLORS.DOOR), Enum.Material.ForceField)
	sealWall.Transparency = 1
	sealWall.CanQuery = false -- the Fight prompt's ray passes
	-- the invisible wall behind the ruins, open only at the way out
	for degrees = 0, 359, ruinsLook.wallSegment do
		local fromX = math.min(degrees, 360 - degrees)
		if fromX >= ruinsLook.gapOut and math.abs(degrees - 180) >= ruinsLook.gapIn then
			local direction = Vector3.new(math.cos(math.rad(degrees)), 0, math.sin(math.rad(degrees)))
			local spot = center + direction * (ruinsLook.radius + 0.5) + Vector3.new(0, ruinsLook.wallHeight / 2, 0)
			local length = 2 * (ruinsLook.radius + 0.5) * math.sin(math.rad(ruinsLook.wallSegment / 2)) + 1
			local wall = block(parent, "RoomWall", Vector3.new(length, ruinsLook.wallHeight, 1), CFrame.lookAt(spot, spot + direction), Color3.new(0, 0, 0))
			wall.Transparency = 1
			wall.CanQuery = false
		end
	end
	local gate = block(parent, "RoomGate", Vector3.new(1, 9, 12), CFrame.new(gateSpot + Vector3.new(0, 4.5, 0)), rgb(Dungeon.COLORS.DOOR), Enum.Material.Neon)
	gate.CanCollide = false
	gate.Transparency = 0.6
	-- its look (round 2): two pillars and the hydra seal between them, where you press Fight (the part keeps the prompt)
	if seal(gate, CFrame.new(gateSpot), rgb(Dungeon.COLORS.DOOR)) then
		gate.Transparency = 1
		for _, side in { -1, 1 } do
			local pillar = prop(parent, "DungeonPillar", CFrame.lookAt(gateSpot + Vector3.new(0, 0, side * ABYSS.SEAL.pillarApart / 2), gateSpot + Vector3.new(0, 0, side * ABYSS.SEAL.pillarApart / 2) + Vector3.new(-1, 0, 0)), rgb(Dungeon.COLORS.DOOR), nil, nil, ABYSS.SEAL.pillarScale)
			if pillar then
				CollectionService:AddTag(pillar, "DungeonCameraFade")
			end
		end
	end
	local packSpot = center + Vector3.new(Dungeon.PACK_OFFSET, 0, 0)
	local made: Room = {
		center = center,
		gate = gate,
		door = gate, -- replaced by the door after this room (DungeonBuilder.build)
		barrier = barrier,
		inside = CFrame.lookAt(gateSpot + Vector3.new(Dungeon.ENTRY_STEP, 3, 0), packSpot + Vector3.new(0, 3, 0)),
		approach = CFrame.new(), -- set by DungeonBuilder.build (its bridge)
		packSpot = CFrame.lookAt(packSpot, gateSpot),
		pylons = {},
		shield = nil,
		seal = sealWall,
	}
	local pylons = Dungeon.ROOMS[index].pylons
	if pylons then
		-- Crystal pylons round the ring (one behind the pack, two toward the gate's sides) and the shield they feed
		for slot = 1, pylons.count do
			local angle = (slot - 1) / pylons.count * math.pi * 2
			local spot = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * PUZZLE.PYLON_RADIUS
			local pylon = block(parent, `Pylon{slot}`, Vector3.new(2.5, 10, 2.5), CFrame.new(spot + Vector3.new(0, 5, 0)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(150, 220, 255), Enum.Material.Neon)
			pylon.Transparency = 0.1
			pylon.CanCollide = false
			pylon:SetAttribute("Broken", false)
			if prop(parent, "CrystalPylon", CFrame.lookAt(spot, center), Color3.fromRGB(150, 220, 255), pylon) then
				pylon.Transparency = 1 -- the part stays: the swords' target and the tint's holder
			end
			table.insert(made.pylons, pylon)
		end
		local shield = block(parent, "PylonShield", Vector3.one * PUZZLE.SHIELD_RADIUS * 2, CFrame.new(packSpot + Vector3.new(0, 3, 0)), Color3.fromRGB(150, 220, 255), Enum.Material.ForceField)
		shield.Shape = Enum.PartType.Ball
		shield.Transparency = 1
		ghost(shield)
		shield:SetAttribute("Up", false)
		made.shield = shield
		-- A beam from each pylon's top into the shield, shown while that pylon feeds it (DungeonService)
		local into = Instance.new("Attachment")
		into.Name = "BeamEnd"
		into.Parent = shield
		for _, pylon in made.pylons do
			local from = Instance.new("Attachment")
			from.Name = "BeamStart"
			from.Position = Vector3.new(0, pylon.Size.Y / 2 - 1, 0)
			from.Parent = pylon
			local beam = Instance.new("Beam")
			beam.Name = "ShieldBeam"
			beam.Attachment0 = from
			beam.Attachment1 = into
			beam.Width0 = PUZZLE.BEAM_WIDTH
			beam.Width1 = PUZZLE.BEAM_WIDTH * 0.5
			beam.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255))
			beam.LightEmission = 1
			beam.FaceCamera = true
			beam.Segments = 1
			beam.Enabled = false
			beam.Parent = pylon
		end
	end
	return made
end

-- A mirror's panel turned to `facing` (Util/BeamRules): its face looks between the two sides it connects
function DungeonBuilder.facingCFrame(position: Vector3, facing: number): CFrame
	local function along(dir: number): Vector3
		local d = dir % 4
		return if d == 0 then Vector3.xAxis elseif d == 1 then Vector3.zAxis elseif d == 2 then -Vector3.xAxis else -Vector3.zAxis
	end
	return CFrame.lookAt(position, position + along(facing) + along(facing + 1))
end

-- The prism beam room: the layout's grid (+x along the cavern, +y across it) on the floor, the gem, the mirrors on
-- stands and the door's prism. Clients draw the beam between cells: the gem carries Cell11 (cell 1,1's centre at beam
-- height) and CellSize.
local function beamRoom(parent: Instance, center: Vector3, layout: any): Beams
	local cell = Dungeon.BEAMS.CELL
	local height = PUZZLE.BEAM_HEIGHT
	local function cellAt(x: number, y: number): Vector3
		return center + Vector3.new((x - (layout.width + 1) / 2) * cell, height, (y - (layout.height + 1) / 2) * cell)
	end
	local floorColor = rgb(Dungeon.COLORS.FLOOR):Lerp(Color3.new(1, 1, 1), 0.12)
	for x = 1, layout.width do
		for y = 1, layout.height do
			block(parent, "BeamTile", Vector3.new(cell - 0.8, 0.2, cell - 0.8), CFrame.new(cellAt(x, y) - Vector3.new(0, height - 0.1, 0)), floorColor)
		end
	end
	local gemSpot = cellAt(layout.gem.x, layout.gem.y)
	local gem = block(parent, "BeamGem", Vector3.one * 2.4, CFrame.new(gemSpot), Color3.fromRGB(255, 226, 122), Enum.Material.Neon)
	gem.Shape = Enum.PartType.Ball
	gem.CanCollide = false
	if prop(parent, "BeamGem", CFrame.new(gemSpot - Vector3.new(0, height, 0)), Color3.fromRGB(255, 226, 122), gem) then
		gem.Transparency = 1
	else
		block(parent, "GemStand", Vector3.new(3, height - 1, 3), CFrame.new(gemSpot - Vector3.new(0, (height + 1) / 2, 0)), rgb(Dungeon.COLORS.WALL))
	end
	gem:SetAttribute("Cell11", cellAt(1, 1))
	gem:SetAttribute("CellSize", cell)
	gem:SetAttribute("Path", "")
	gem:SetAttribute("Reached", false)
	local mirrors: { BasePart } = {}
	for index, spec in layout.mirrors do
		local spot = cellAt(spec.x, spec.y)
		local mirror = block(parent, `Mirror{index}`, Vector3.new(5, 5, 0.6), DungeonBuilder.facingCFrame(spot, spec.facing), Color3.fromRGB(127, 208, 255), Enum.Material.Glass)
		mirror.Transparency = 0.2
		-- the prop turns with the part (welded): the server turns the part a quarter per tap
		if prop(parent, "CrystalMirror", mirror.CFrame * CFrame.new(0, -height, 0), Color3.fromRGB(170, 225, 255), mirror, true) then
			mirror.Transparency = 1
		else
			block(parent, "MirrorStand", Vector3.new(2, height - 1, 2), CFrame.new(spot - Vector3.new(0, (height + 1) / 2, 0)), rgb(Dungeon.COLORS.WALL))
		end
		mirror:SetAttribute("Facing", spec.facing)
		table.insert(mirrors, mirror)
	end
	local prism = block(parent, "DoorPrism", Vector3.new(2.5, 6, 2.5), CFrame.new(cellAt(layout.prism.x, layout.prism.y)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(160, 110, 230), Enum.Material.Neon)
	prism.Transparency = 0.35
	prism.CanCollide = false
	prism:SetAttribute("Lit", false)
	local prismSpot = cellAt(layout.prism.x, layout.prism.y)
	local target = PUZZLE.TARGET
	if prop(parent, "DoorPrism", CFrame.new(prismSpot - Vector3.new(0, height, 0)), Color3.fromRGB(190, 140, 255), prism, false, target.scale) then
		prism.Transparency = 1
		DungeonBuilder.tint(prism, nil, 0.35) -- unlit until the beam reaches it
	end
	-- the target stands out (owner 2026-11-12): a column of light over it, a glow, rising sparkles and a label; all
	-- go out once the beam reaches it (DungeonPuzzleService)
	local color = rgb(target.color)
	local base = Instance.new("Attachment")
	base.Name = "TargetBase"
	base.Parent = prism
	local top = Instance.new("Attachment")
	top.Name = "TargetTop"
	top.Position = Vector3.new(0, target.column, 0)
	top.Parent = prism
	local column = Instance.new("Beam")
	column.Name = "TargetColumn"
	column.Attachment0 = base
	column.Attachment1 = top
	column.Color = ColorSequence.new(color)
	column.LightEmission = 1
	column.FaceCamera = true
	column.Width0 = target.width
	column.Width1 = target.width * 0.4
	column.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	column.Parent = prism
	local glow = Instance.new("PointLight")
	glow.Name = "TargetGlow"
	glow.Color = color
	glow.Range = target.light
	glow.Brightness = 2
	glow.Parent = prism
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "TargetSparkles"
	sparkles.Color = ColorSequence.new(color)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.6, 0)
	sparkles.Lifetime = NumberRange.new(1.5, 2.5)
	sparkles.Rate = 8
	sparkles.Speed = NumberRange.new(3, 6)
	sparkles.SpreadAngle = Vector2.new(15, 15)
	sparkles.Parent = base
	local label = Instance.new("BillboardGui")
	label.Name = "TargetLabel"
	label.Size = UDim2.fromOffset(200, 50)
	label.StudsOffset = Vector3.new(0, target.labelHeight, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = target.labelDistance
	label.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.TextStrokeColor3 = Color3.fromRGB(40, 20, 70)
	text.Text = target.text
	text.Parent = label
	label.Parent = prism
	return { gem = gem, mirrors = mirrors, prism = prism, door = prism, chestSpot = CFrame.new(), layout = layout, cellAt = cellAt }
end

-- The plate room: its plates (the third dims for runs under Dungeon.PLATES.GROUP_FROM) and the secret niche on the +z
-- side behind a cracked wall
local function plateRoom(parent: Instance, center: Vector3): Plates
	local plates: { BasePart } = {}
	for index, spot in PUZZLE.PLATES do
		local plate = block(parent, `Plate{index}`, Vector3.new(Dungeon.PLATES.SIZE, 0.6, Dungeon.PLATES.SIZE), CFrame.new(center + Vector3.new(spot.x, 0.3, spot.z)), Color3.fromRGB(96, 110, 90))
		plate:SetAttribute("Held", false)
		plate:SetAttribute("Needed", true)
		if prop(parent, "StonePlate", CFrame.new(center + Vector3.new(spot.x, 0, spot.z)), Color3.fromRGB(150, 160, 190), plate) then
			plate.Transparency = 1 -- stays solid underfoot: the plates' check reads its box
		end
		table.insert(plates, plate)
	end
	local alcove = PUZZLE.ALCOVE
	local wallHeight = 14
	local frontZ = alcove.z
	local backZ = alcove.z + alcove.depth
	local wallColor = rgb(Dungeon.COLORS.WALL)
	block(parent, "AlcoveBack", Vector3.new(alcove.width + 4, wallHeight, 2), CFrame.new(center + Vector3.new(0, wallHeight / 2, backZ)), wallColor)
	for _, sign in { -1, 1 } do
		block(parent, "AlcoveSide", Vector3.new(2, wallHeight, alcove.depth), CFrame.new(center + Vector3.new(sign * (alcove.width / 2 + 1), wallHeight / 2, (frontZ + backZ) / 2)), wallColor)
	end
	block(parent, "AlcoveRoof", Vector3.new(alcove.width + 4, 2, alcove.depth + 2), CFrame.new(center + Vector3.new(0, wallHeight + 1, (frontZ + backZ) / 2)), wallColor)
	local wall = block(parent, "SecretWall", Vector3.new(alcove.width, wallHeight, 2), CFrame.new(center + Vector3.new(0, wallHeight / 2, frontZ)), wallColor:Lerp(Color3.new(1, 1, 1), 0.06))
	wall:SetAttribute("Taps", 0)
	wall:SetAttribute("Open", false)
	-- Faint glowing cracks on its face (its Look's Glow: brighter with each tap, gone with the wall)
	if prop(parent, "CrackedWall", CFrame.new(center + Vector3.new(0, 0, frontZ)), Color3.fromRGB(255, 220, 140), wall) then
		wall.Transparency = 1 -- the invisible part stays the wall you bump into
	else
		local cracks = Instance.new("Model")
		cracks.Name = LOOK
		for _, crack in { { -2, 3, 20 }, { 1.5, 6, -35 }, { 3, 2, 60 } } do
			local line = block(cracks, "Glow", Vector3.new(0.25, 4, 0.2), CFrame.new(center + Vector3.new(crack[1], crack[2], frontZ - 1.05)) * CFrame.Angles(0, 0, math.rad(crack[3])), Color3.fromRGB(255, 220, 140), Enum.Material.Neon)
			ghost(line)
		end
		cracks.Parent = wall
	end
	DungeonBuilder.tint(wall, nil, 0.3)
	local inside = center + Vector3.new(0, 0, (frontZ + backZ) / 2 + 1)
	return {
		plates = plates,
		door = wall, -- replaced by the room's door (DungeonBuilder.build)
		wall = wall,
		alcove = CFrame.lookAt(inside, inside - Vector3.zAxis),
		chestSpot = CFrame.new(),
		secretSpot = CFrame.lookAt(inside + Vector3.new(0, 0, 1), inside - Vector3.zAxis * 5),
	}
end

-- The element lock room: its crystals across the room (Dungeon.PUZZLE.LOCK_LAYOUT), the sockets over its door filled
-- in the Hydra's order
local function lockRoom(parent: Instance, center: Vector3): Lock
	local crystals: { [string]: BasePart } = {}
	local count = #PUZZLE.LOCK_LAYOUT
	for index, element in PUZZLE.LOCK_LAYOUT do
		local z = (index - (count + 1) / 2) * PUZZLE.LOCK_SPACING
		local spot = center + Vector3.new(-6, 0, z)
		local piece = block(parent, `LockCrystal_{element}`, Vector3.new(2.2, 6, 2.2), CFrame.new(spot + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, math.rad(45), 0), elementColor(element), Enum.Material.Neon)
		piece.Transparency = 0.15
		piece.CanCollide = false
		piece:SetAttribute("Element", element)
		if prop(parent, "ElementCrystal", CFrame.lookAt(spot, spot - Vector3.xAxis), elementColor(element), piece) then
			piece.Transparency = 1
		else
			block(parent, "CrystalStand", Vector3.new(3, 1.5, 3), CFrame.new(spot + Vector3.new(0, 0.75, 0)), rgb(Dungeon.COLORS.WALL))
		end
		crystals[element] = piece
	end
	return { crystals = crystals, sockets = {}, door = crystals[PUZZLE.LOCK_LAYOUT[1]], chestSpot = CFrame.new() }
end

-- The lock's sockets: the Hydra's door's five eyes on an arc over its middle, on the face toward the lock, one per
-- phase in the Hydra's order (left to right as you face it), dim until lit; under the door, so they go when it opens
local function sockets(hydra: BasePart): { BasePart }
	local list: { BasePart } = {}
	local phases = Bosses.BOSSES[Dungeon.BOSS].phases
	for index, phase in phases do
		local angle = math.rad(-60 + (index - 1) * 120 / math.max(1, #phases - 1))
		local offset = CFrame.new(-1.4, math.cos(angle) * EYE_ARC - 2, math.sin(angle) * EYE_ARC)
		local socket = block(hydra, `LockSocket{index}`, Vector3.new(0.6, 2.6, 2.6), hydra.CFrame * offset, elementColor(phase.element), Enum.Material.Neon)
		socket.Shape = Enum.PartType.Cylinder
		socket.Transparency = 0.7
		ghost(socket)
		socket:SetAttribute("Element", phase.element)
		socket:SetAttribute("Lit", false)
		table.insert(list, socket)
	end
	return list
end

-- A layout spot (x, z) at height y
local function flat(spot: AbyssLayout.Spot, y: number?): Vector3
	return Vector3.new(spot.x, y or 0, spot.z)
end

-- A CFrame at `at` whose +X points along `yaw` (AbyssLayout: math.atan2(dz, dx)): the code's parts
local function turned(at: Vector3, yaw: number): CFrame
	return CFrame.new(at) * CFrame.Angles(0, -yaw, 0)
end

-- A prop's CFrame at `at` facing along `yaw`: its width (Blender X) across the way, its front (Blender -Y) back toward
-- where you come from
local function facingAlong(at: Vector3, yaw: number): CFrame
	return CFrame.lookAt(at, at + Vector3.new(math.cos(yaw), 0, math.sin(yaw)))
end

-- A prop's carved front (Blender's -Y comes in as its LookVector) turned towards whoever walks along yaw
local function facingBack(at: Vector3, yaw: number): CFrame
	return facingAlong(at, yaw + math.pi)
end

-- An island gate across the start of its bridge out: the closed barrier (DungeonService opens it with
-- DungeonBuilder.hide) in a ruined arch (the props pack's DungeonIslandGate, stone pillars until it's in)
local function door(parent: Instance, name: string, at: Vector3, yaw: number): Part
	local width = ABYSS.GATE_HALF * 2 -- across the bridge and its landing
	local frame = turned(at, yaw)
	local part = block(parent, name, Vector3.new(2, GATE_HEIGHT, width), frame + Vector3.new(0, GATE_HEIGHT / 2, 0), rgb(Dungeon.COLORS.DOOR), Enum.Material.ForceField)
	part.Transparency = 0.2
	seal(part, frame, rgb(Dungeon.COLORS.DOOR)) -- plainly shut until it opens (round 2)
	-- invisible wings past its ends over the chasm (owner 2026-11-12: "players can just jump to the side"): no jumping
	-- round it; worn by the barrier, so they go when it opens
	for _, side in { -1, 1 } do
		local wing = block(part, "GateWing", Vector3.new(2, GATE_HEIGHT + ABYSS.GATE_WING.above, ABYSS.GATE_WING.reach), frame * CFrame.new(0, (GATE_HEIGHT + ABYSS.GATE_WING.above) / 2, side * (width / 2 + ABYSS.GATE_WING.reach / 2)), Color3.new(0, 0, 0))
		wing.Transparency = 1
		wing.CanQuery = false
	end
	-- a stone landing across the bridge under it: its posts stand on stone, not over the edge (owner 2026-11-12)
	local column = ABYSS.COLUMN
	local landing = block(parent, "GateLanding", Vector3.new(column.landing, 1.5, ABYSS.GATE_HALF * 2), frame - Vector3.new(0, 0.75, 0), rgb(Dungeon.COLORS.FLOOR), Enum.Material.Slate)
	landing.Name = "GateLanding"
	-- rock columns under its posts, down into the chasm: it stands on something
	for _, side in { -1, 1 } do
		local foot = (frame * CFrame.new(0, 0, side * column.apart / 2)).Position
		workspace.Terrain:FillCylinder(CFrame.new(foot - Vector3.new(0, column.depth / 4 + 1, 0)), column.depth / 2, column.radius, Enum.Material.Basalt)
		workspace.Terrain:FillCylinder(CFrame.new(foot - Vector3.new(0, column.depth * 3 / 4 + 1, 0)), column.depth / 2, column.radius * 0.6, Enum.Material.Basalt)
	end
	if not prop(parent, "DungeonIslandGate", facingBack(at, yaw), rgb(Dungeon.COLORS.DOOR)) then
		for _, side in { -1, 1 } do
			block(parent, "GatePillar", Vector3.new(3, GATE_HEIGHT + 2, 3), frame * CFrame.new(0, (GATE_HEIGHT + 2) / 2, side * (width / 2 + 1.5)), rgb(Dungeon.COLORS.WALL))
		end
		block(parent, "GateLintel", Vector3.new(3, 2.5, width + 6), frame * CFrame.new(0, GATE_HEIGHT + 3.25, 0), rgb(Dungeon.COLORS.WALL))
	end
	return part
end

-- The Hydra's round door at the chamber island's edge: solid until the lock is solved (DungeonService opens it), the
-- props pack's DungeonHydraDoor as its Look (a stone disc until it's in)
local function hydraDoor(parent: Instance, at: Vector3, yaw: number, name: string?): Part
	local radius = ABYSS.DOOR_RADIUS
	local frame = turned(at, yaw)
	-- a Cylinder's axis is its X: along the way through
	local part = block(parent, name or "ChamberDoor", Vector3.new(2, radius * 2, radius * 2), frame + Vector3.new(0, radius, 0), rgb(Dungeon.COLORS.WALL):Lerp(rgb(Dungeon.COLORS.DOOR), 0.25))
	part.Shape = Enum.PartType.Cylinder
	if prop(parent, "DungeonHydraDoor", facingBack(at, yaw), rgb(Dungeon.COLORS.DOOR), part) then
		part.Transparency = 1
	end
	return part
end

-- A region's look (Config/Dungeon REGIONS) and its Terrain materials
local function regionOf(name: string): any
	return (Dungeon.REGIONS :: any)[name] or (Dungeon.REGIONS :: any)[Dungeon.CASTLE_REGION]
end

local function materialOf(name: string): Enum.Material
	return (Enum.Material :: any)[name]
end

-- One of a region's crystal colours
local function regionCrystal(name: string, index: number): Color3
	local colors = regionOf(name).crystals
	return rgb(colors[(index - 1) % #colors + 1])
end

-- An island's rock hanging into the chasm (Terrain, under its top): three layers of its region's rock, each narrower
local function underside(at: Vector3, size: number, round: boolean, region: string)
	local terrain = workspace.Terrain
	local rock = materialOf(regionOf(region).rock)
	local depth = ABYSS.UNDERSIDE / 3
	local top = -4 - TERRAIN_LIFT -- under the mesa's top layer
	for layer = 0, 2 do
		local width = size * (1 - layer * 0.3)
		local middle = Vector3.new(at.X, top - depth * layer - depth / 2, at.Z)
		if layer == 0 and not round then
			terrain:FillBlock(CFrame.new(middle), Vector3.new(width * 2, depth, width * 2), rock)
		else
			terrain:FillCylinder(CFrame.new(middle), depth, width, rock)
		end
	end
end

-- An island: a Terrain mesa in its region's rock (its top flat at y 0, a rocky lip round its edge away from where its
-- bridges meet it: `ways`) and, for the exact floor the puzzles' pieces and players stand on, an invisible part over it
local function island(parent: Instance, each: AbyssLayout.Island, ways: { Vector3 })
	local terrain = workspace.Terrain
	local at = Vector3.new(each.x, 0, each.z)
	local region = regionOf(each.region)
	local top = materialOf(region.top)
	local floor: Part
	if each.round then
		-- a Terrain cylinder's top snaps to the 4-stud grid (2 or -2, never 0: measured in Studio): it sits under the
		-- floor, and the floor part shows in the region's own material and colour
		terrain:FillCylinder(CFrame.new(at - Vector3.new(0, 6, 0)), 4, each.size, top)
		-- Cylinders run along X: lay the disc flat
		floor = block(parent, "IslandFloor", Vector3.new(2, each.size * 2, each.size * 2), CFrame.new(at - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(region.topColor), top)
		floor.Shape = Enum.PartType.Cylinder
	else
		terrain:FillBlock(CFrame.new(at - Vector3.new(0, 2 + TERRAIN_LIFT, 0)), Vector3.new(each.size * 2, 4, each.size * 2), top)
		floor = block(parent, "IslandFloor", Vector3.new(each.size * 2, 2, each.size * 2), CFrame.new(at - Vector3.new(0, 1, 0)), rgb(region.topColor))
		floor.Transparency = 1 -- the Terrain's own top shows (a block's lands at 0)
	end
	underside(at, each.size, each.round, each.region)
	if each.kind == "fight" or each.kind == "castle" then
		return -- the crater's rim, the castle's walls
	end
	-- the lip: rocks along the edge, clear of where bridges meet it (and the plates island's secret niche)
	local rock = materialOf(region.rock)
	local random = Random.new(math.floor(each.x * 7 + each.z))
	local count = math.max(6, math.floor(each.size * 0.9))
	for index = 1, count do
		local angle = (index - 0.5) / count * math.pi * 2
		local edge = if each.round then each.size - 1 else each.size / math.max(math.abs(math.cos(angle)), math.abs(math.sin(angle))) - 1
		local spot = at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * edge
		local nearWay = false
		for _, way in ways do
			nearWay = nearWay or (spot - way).Magnitude < CLEAR_OF_BRIDGE + 2
		end
		local niche = each.kind == "plates" and spot.Z > each.z and math.abs(spot.X - each.x) < PUZZLE.ALCOVE.width
		if not nearWay and not niche then
			terrain:FillBall(spot - Vector3.new(0, 1.5 + TERRAIN_LIFT, 0), random:NextNumber(2.2, 3.4), rock)
		end
	end
end

-- A fight room's crater (round 3 part 2): a rock rim round its ring, taller than a camera's eye, open at its ways in and
-- out; broken lumps along its top
local function crater(each: AbyssLayout.Island)
	local terrain = workspace.Terrain
	local look = ABYSS.CRATER
	local rock = materialOf(regionOf(each.region).rock)
	local center = Vector3.new(each.x, 0, each.z)
	local inner = ABYSS.RUINS.radius + 2
	local middle = (inner + look.outer) / 2
	local thick = look.outer - inner
	local random = Random.new(math.floor(each.x))
	for degrees = 0, 359, 6 do
		local fromX = math.min(degrees, 360 - degrees)
		if fromX >= look.gap and math.abs(degrees - 180) >= look.gap then
			local direction = Vector3.new(math.cos(math.rad(degrees)), 0, math.sin(math.rad(degrees)))
			local spot = center + direction * middle
			local tall = look.height * random:NextNumber(0.85, 1.15)
			local width = 2 * middle * math.sin(math.rad(3)) + 2
			-- from under the floor (-4) to its full height
			terrain:FillBlock(CFrame.lookAt(spot + Vector3.new(0, tall / 2 - 2, 0), spot + Vector3.new(0, tall / 2 - 2, 0) + direction), Vector3.new(width, tall + 4, thick), rock)
			if random:NextNumber() < 0.5 then
				terrain:FillBall(spot + Vector3.new(0, tall - 1, 0), random:NextNumber(2.5, 4.5), rock)
			end
		end
	end
end

-- The rock spires beside the way's turns (AbyssLayout.spires): floor of the chasm to the ceiling, a wider foot
local function spires(islands: { AbyssLayout.Island })
	local terrain = workspace.Terrain
	local bottom = ABYSS.KILL_Y - 150
	local height = ABYSS.CEILING_Y + 10 - bottom
	for _, spire in AbyssLayout.spires(islands, ABYSS) do
		local at = Vector3.new(spire.x, 0, spire.z)
		terrain:FillCylinder(CFrame.new(at + Vector3.new(0, bottom + height / 2, 0)), height, spire.radius, Enum.Material.Rock)
		terrain:FillBall(at + Vector3.new(0, ABYSS.CEILING_Y - 10, 0), spire.radius * 1.5, Enum.Material.Rock)
		terrain:FillBall(at + Vector3.new(0, -30, 0), spire.radius * 1.4, Enum.Material.Rock)
	end
end

-- The cave round it all, in Terrain: the ceiling, the far walls, both ends, stalactites; every region's colours
local function cave(islands: { AbyssLayout.Island })
	local terrain = workspace.Terrain
	terrain:Clear()
	terrain:SetMaterialColor(Enum.Material.Rock, rgb(Dungeon.COLORS.WALL))
	for _, region in Dungeon.REGIONS :: any do
		terrain:SetMaterialColor(materialOf(region.top), rgb(region.topColor))
		terrain:SetMaterialColor(materialOf(region.rock), rgb(region.rockColor))
	end
	local first = islands[1]
	local west = first.x - first.size - 4 -- right behind the ledge: the way back is in this wall
	local east = AbyssLayout.eastWall(islands)
	local half = ABYSS.CAVE_HALF_WIDTH
	local bottom = ABYSS.KILL_Y - 200
	local height = ABYSS.CEILING_Y + 20 - bottom
	local middle = (west + east) / 2
	local length = east - west + 40
	terrain:FillBlock(CFrame.new(middle, ABYSS.CEILING_Y + 10, 0), Vector3.new(length, 20, half * 2 + 40), Enum.Material.Rock)
	for _, sign in { -1, 1 } do
		terrain:FillBlock(CFrame.new(middle, bottom + height / 2, sign * (half + 10)), Vector3.new(length, height, 20), Enum.Material.Rock)
	end
	terrain:FillBlock(CFrame.new(west - 10, bottom + height / 2, 0), Vector3.new(20, height, half * 2 + 40), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(east + 10, bottom + height / 2, 0), Vector3.new(20, height, half * 2 + 40), Enum.Material.Rock)
	local random = Random.new(9090)
	for _ = 1, STALACTITES do
		local x, z = random:NextNumber(west, east), random:NextNumber(-half + 20, half - 20)
		local size = random:NextNumber(5, 12)
		terrain:FillBall(Vector3.new(x, ABYSS.CEILING_Y - size * 0.4, z), size, Enum.Material.Rock)
		terrain:FillBall(Vector3.new(x, ABYSS.CEILING_Y - size * 1.3, z), size * 0.5, Enum.Material.Rock)
	end
end

-- The Hydra's castle on the last plateau (round 3 part 2, concept_castle.png): its broken front wall with the hydra
-- gate (the PortalDungeon model, dressed with its violet swirl; the Hydra's door seals it), walls and towers of broken
-- stone behind, crystals growing through, violet braziers along the forecourt. Returns the door and the lair portal (an
-- invisible slab in the gate: DungeonService puts its prompt on it, on once the door opens).
local function castle(parent: Instance, each: AbyssLayout.Island): (Part, Part, { BasePart })
	local terrain = workspace.Terrain
	local look = ABYSS.CASTLE
	local region = regionOf(each.region)
	local stone = materialOf(region.rock)
	local random = Random.new(1977)
	local cx, cz = each.x, each.z
	local frontX = cx - look.front
	local far = each.size - look.wall / 2 - 1
	local gate = Vector3.new(frontX, 0, cz)
	-- a broken wall from a to b (x, z): 8-stud pieces of varying height, some knocked low
	local function wall(ax: number, az: number, bx: number, bz: number)
		local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local pieces = math.max(1, math.floor(length / 8))
		for index = 1, pieces do
			local t = (index - 0.5) / pieces
			local x, z = ax + (bx - ax) * t, az + (bz - az) * t
			local tall = random:NextNumber(look.wallHeight[1], look.wallHeight[2])
			if random:NextNumber() < look.breach.chance then
				tall *= look.breach.height -- a breach, still too tall to jump
			end
			local spot = Vector3.new(x, tall / 2 - 2, z)
			local along = Vector3.new(bx - ax, 0, bz - az).Unit
			terrain:FillBlock(CFrame.lookAt(spot, spot + along), Vector3.new(look.wall, tall + 4, length / pieces + 1), stone)
		end
	end
	local opening = look.gateWidth * look.gateScale / 2 -- the gate model's half width: no wall there
	-- the Blender castle (tools/blender/build_castle.py; owner 2026-11-12: "use Blender to draw a proper castle"), its
	-- front on the gate, solid through invisible blocks along its walls and round its towers; Terrain walls until it's in
	local model = look.model
	local castleModel = prop(parent, "DungeonCastle", facingBack(gate, 0) * CFrame.new(model.pivot.x, model.pivot.y, model.pivot.z), regionCrystal(each.region, 1))
	if castleModel then
		-- its stone's colour under its texture: what shows while the texture can't load (a fresh upload Roblox
		-- hasn't processed yet: "No asset content representation found"), violet stone instead of black
		local frame = castleModel:FindFirstChild("Frame", true)
		if frame and frame:IsA("BasePart") then
			frame.Color = rgb(regionOf(each.region).rockColor)
			frame.Material = Enum.Material.Slate
		end
		local function solid(name: string, size: Vector3, at: CFrame)
			local part = block(parent, name, size, at, Color3.new(0, 0, 0))
			part.Transparency = 1
			part.CanQuery = false
		end
		local tall = model.wallTall + 6
		for _, side in { -1, 1 } do
			local inner, outer = model.gap + 3, model.wide
			solid("CastleWall", Vector3.new(model.wall, tall, outer - inner), CFrame.new(frontX, tall / 2, cz + side * (inner + outer) / 2))
			solid("CastleWall", Vector3.new(model.deep, tall, model.wall), CFrame.new(frontX + model.deep / 2, tall / 2, cz + side * model.wide))
		end
		solid("CastleWall", Vector3.new(model.wall, tall, model.wide * 2), CFrame.new(frontX + model.deep, tall / 2, cz))
		for _, tower in model.towers do
			local towerAt = Vector3.new(frontX + tower.y, 20, cz + tower.x)
			local part = block(parent, "CastleTower", Vector3.new(40, tower.radius * 2.4, tower.radius * 2.4), CFrame.new(towerAt) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(0, 0, 0))
			part.Shape = Enum.PartType.Cylinder
			part.Transparency = 1
			part.CanQuery = false
		end
	else
		wall(frontX, cz - far, frontX, cz - opening)
		wall(frontX, cz + opening, frontX, cz + far)
		wall(frontX, cz - far, cx + far, cz - far)
		wall(frontX, cz + far, cx + far, cz + far)
		wall(cx + far, cz - far, cx + far, cz + far)
		-- the towers at its corners, broken tops
		for _, corner in { Vector3.new(frontX, 0, cz - far), Vector3.new(frontX, 0, cz + far), Vector3.new(cx + far, 0, cz - far), Vector3.new(cx + far, 0, cz + far) } do
			local tall = random:NextNumber(look.towers[1], look.towers[2])
			terrain:FillCylinder(CFrame.new(corner + Vector3.new(0, tall / 2 - 2, 0)), tall + 4, look.towerRadius, stone)
			terrain:FillBall(corner + Vector3.new(random:NextNumber(-2, 2), tall, random:NextNumber(-2, 2)), look.towerRadius * 0.8, stone)
		end
		-- the keep in the middle, half fallen
		terrain:FillBlock(CFrame.new(cx + 10, 14, cz) * CFrame.Angles(0, 0, math.rad(4)), Vector3.new(24, 32, 30), stone)
	end
	-- crystals growing through
	for index = 1, 6 do
		local spot = Vector3.new(cx + random:NextNumber(-8, far - 6), 0, cz + random:NextNumber(-far + 6, far - 6))
		local color = regionCrystal(each.region, index)
		local cluster = prop(parent, "DungeonCrystals", CFrame.new(spot) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0), color, nil, nil, random:NextNumber(2, 3.2))
		if cluster and index <= 2 then
			lightUp(cluster, color, 40, 1.5)
		end
	end
	-- violet braziers lining the forecourt
	local flame = regionCrystal(each.region, 1)
	for _, offset in { Vector3.new(-12, 0, -10), Vector3.new(-12, 0, 10), Vector3.new(-24, 0, -10), Vector3.new(-24, 0, 10) } do
		local spot = gate + offset
		local brazier = prop(parent, "DungeonBrazier", CFrame.lookAt(spot, Vector3.new(spot.X, 0, cz)), flame)
		if brazier then
			torchFire(brazier, flame, 20)
		end
	end
	-- the forecourt's dead: a dragon's skeleton, a giant's skull and ribs, an adventurer's sword, bones
	for _, bone in look.bones do
		local spot = gate + Vector3.new(bone.x, -(bone.sink or 0), bone.z)
		local turn = CFrame.Angles(0, math.rad(bone.yaw), 0) * CFrame.Angles(0, 0, math.rad(bone.tilt or 0))
		prop(parent, bone.model, CFrame.new(spot) * turn, regionCrystal(each.region, 1), nil, nil, bone.scale)
	end
	-- the hydra gate: the Frontier's Dungeon portal model, facing the way in, its swirl; the Hydra's door in front
	local arch = prop(parent, "PortalDungeon", facingBack(gate, 0), nil, nil, nil, look.gateScale)
	local eyes: { BasePart } = {}
	if arch then
		arch.Name = "HydraGate"
		PortalBuild.dress(arch, (Town.PORTAL_LOOKS :: any).Dungeon)
		-- its dragon heads' eyes stay dark until the Hydra's lock is solved (DungeonService lights them)
		local eye = arch:FindFirstChild("Eye1")
		while eye and eye:IsA("BasePart") do
			table.insert(eyes, eye)
			DungeonBuilder.setEye(eye, #eyes, false)
			eye = arch:FindFirstChild(`Eye{#eyes + 1}`)
		end
	end
	local door = hydraDoor(parent, gate - Vector3.new(2, 0, 0), 0)
	-- solid across the whole opening until the door opens (then walking into the swirl takes you in: DungeonService)
	local portal = block(parent, "LairPortal", Vector3.new(2, look.portal.height, opening * 2), CFrame.new(gate + Vector3.new(0.5, look.portal.height / 2, 0)), rgb(Dungeon.COLORS.DOOR))
	portal.Transparency = 1
	return door, portal, eyes
end

-- The Hydra's lair past the cave's east wall (round 3 part 2): a dome of rock round Dungeon.CHAMBER with a flat floor
-- (the arena's ring is WildService's), crystals round its wall, the Hydra's carving huge behind the arena
local function lair(parent: Instance)
	local terrain = workspace.Terrain
	local look = ABYSS.LAIR
	local center = Vector3.new(Dungeon.CHAMBER.x, 0, Dungeon.CHAMBER.z)
	local outer = look.radius + look.wall
	terrain:FillBlock(CFrame.new(center + Vector3.new(0, look.radius / 2 - 20, 0)), Vector3.new(outer * 2, look.radius + look.wall + 40, outer * 2), Enum.Material.Rock)
	terrain:FillBall(center, look.radius, Enum.Material.Air)
	terrain:FillBlock(CFrame.new(center - Vector3.new(0, 20 + TERRAIN_LIFT, 0)), Vector3.new(look.radius * 2 + 8, 40, look.radius * 2 + 8), Enum.Material.Rock)
	local random = Random.new(2200)
	local count = 12
	for index = 1, count do
		local angle = (index - 0.5) / count * math.pi * 2
		local spot = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (look.radius - 12)
		local color = regionCrystal(Dungeon.CASTLE_REGION, index)
		local cluster = crystalCluster(parent, CFrame.lookAt(spot, center) * CFrame.Angles(math.rad(-20), 0, 0), color, random)
		if cluster and index % 3 == 0 then
			lightUp(cluster, color, 60, 2)
		end
	end
	-- the arena's gate (WildService's prompts on an invisible part there): two pillars and the hydra seal, like the rooms
	local arena = Dungeon.LAIR_ARENA
	local gateSpot = center - Vector3.new(CHAMBER_RADIUS - 2, 0, 0)
	local sealHolder = block(parent, "LairSeal", Vector3.new(1, 9, 12), CFrame.new(gateSpot + Vector3.new(0, 4.5, 0)), rgb(Dungeon.COLORS.DOOR))
	sealHolder.Transparency = 1
	ghost(sealHolder)
	seal(sealHolder, CFrame.new(gateSpot), rgb(Dungeon.COLORS.DOOR))
	for _, side in { -1, 1 } do
		local at = gateSpot + Vector3.new(0, 0, side * ABYSS.SEAL.pillarApart / 2)
		local pillar = prop(parent, "DungeonPillar", CFrame.lookAt(at, at - Vector3.xAxis), rgb(Dungeon.COLORS.DOOR), nil, nil, ABYSS.SEAL.pillarScale)
		if pillar then
			CollectionService:AddTag(pillar, "DungeonCameraFade")
		end
	end
	-- the way in: the portal you came through on the dome's wall, a stone causeway to the gate, braziers along it
	local wallX = center.X - look.radius + 14
	local portalAt = Vector3.new(wallX, 0, center.Z)
	local arch = prop(parent, "PortalDungeon", facingAlong(portalAt, 0), nil, nil, nil, arena.portalScale)
	if arch then
		arch.Name = "LairWayIn"
		PortalBuild.dress(arch, (Town.PORTAL_LOOKS :: any).Dungeon)
	end
	local runFrom, runTo = wallX + 4, gateSpot.X - 2
	local causeway = block(parent, "Causeway", Vector3.new(runTo - runFrom, 1, arena.causewayWidth), CFrame.new((runFrom + runTo) / 2, 0.02, center.Z), rgb(arena.path), Enum.Material.Cobblestone)
	causeway.CanCollide = false
	for k = 1, arena.braziers do
		local x = runFrom + (k - 0.5) / arena.braziers * (runTo - runFrom)
		for _, side in { -1, 1 } do
			local at = Vector3.new(x, 0, center.Z + side * (arena.causewayWidth / 2 + 2))
			local brazier = prop(parent, "DungeonBrazier", CFrame.lookAt(at, Vector3.new(x, 0, center.Z)), regionCrystal(Dungeon.CASTLE_REGION, 1))
			if brazier then
				torchFire(brazier, regionCrystal(Dungeon.CASTLE_REGION, 1), 18)
			end
		end
	end
	local back = center + Vector3.new(look.carving.reach, 0, 0) -- where the dome is tall enough for it
	local carving = prop(parent, "DungeonHydraDoor", facingAlong(back, math.pi), rgb(Dungeon.COLORS.DOOR), nil, nil, look.carving.scale)
	if carving then
		lightUp(carving, rgb(Dungeon.COLORS.DOOR), 80, 1.5)
	end
end

-- A region's accent over an island (round 3 part 2): Tide's mist, Ember's rising embers, Shade's slow motes, Volt's
-- flickering light (CollectionService DungeonFlicker: DungeonRegionController flickers it)
local function accent(parent: Instance, each: AbyssLayout.Island)
	local region = regionOf(each.region)
	local holder = block(parent, "RegionAccent", Vector3.new(each.size * 1.6, 1, each.size * 1.6), CFrame.new(each.x, 2, each.z), Color3.new(1, 1, 1))
	holder.Transparency = 1
	ghost(holder)
	local color = regionCrystal(each.region, 1)
	if region.accent == "flicker" then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 40
		light.Brightness = 1.5
		light.Parent = holder
		CollectionService:AddTag(light, "DungeonFlicker")
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.LightEmission = if region.accent == "mist" then 0 else 1
	emitter.Color = ColorSequence.new(color)
	if region.accent == "mist" then
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Size = NumberSequence.new(8, 14)
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 1) })
		emitter.Lifetime = NumberRange.new(6, 9)
		emitter.Rate = 2
		emitter.Speed = NumberRange.new(0.5, 1.5)
	else
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Size = NumberSequence.new(0.35, 0)
		emitter.Lifetime = NumberRange.new(3, 5)
		emitter.Rate = if region.accent == "embers" then 10 else 5
		emitter.Speed = NumberRange.new(1, if region.accent == "embers" then 4 else 1.5)
		emitter.Acceleration = Vector3.new(0, if region.accent == "embers" then 2 else 0.4, 0)
	end
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = holder
end

-- A bridge: the stone you walk on (always a part) dressed with DungeonBridge segments, or broken railing posts
local function bridge(parent: Instance, each: AbyssLayout.Bridge, random: Random)
	local from, to = flat(each.from), flat(each.to)
	local frame = CFrame.lookAt((from + to) / 2, to)
	local color = rgb(Dungeon.COLORS.FLOOR)
	local slab = block(parent, "Bridge", Vector3.new(ABYSS.BRIDGE_WIDTH, 1.5, each.length + 2), frame - Vector3.new(0, 0.75, 0), color)
	local segments = math.max(1, math.ceil(each.length / BRIDGE_SEGMENT))
	local dressed = false
	for index = 1, segments do
		local middle = math.min((index - 0.5) * BRIDGE_SEGMENT, each.length - BRIDGE_SEGMENT / 2)
		local spot = flat(AbyssLayout.alongBridge(each, math.max(middle, each.length / 2 * (if segments == 1 then 1 else 0))), -BRIDGE_DECK)
		if prop(parent, "DungeonBridge", CFrame.lookAt(spot, spot + (to - from).Unit)) then
			dressed = true
		end
	end
	if dressed then
		slab.Transparency = 1
		return
	end
	-- stand-in railings: low posts along both edges, some missing, some broken short
	for along = 1, each.length - 1, 2.5 do
		for _, side in { -1, 1 } do
			if random:NextNumber() < 0.7 then
				local tall = ABYSS.RAIL_HEIGHT * random:NextNumber(0.4, 1)
				block(parent, "Railing", Vector3.new(0.8, tall, 0.8), frame * CFrame.new(side * (ABYSS.BRIDGE_WIDTH / 2 - 0.4), tall / 2, each.length / 2 - along), rgb(Dungeon.COLORS.WALL))
			end
		end
	end
end

-- Spots round an island's rim (clear of where its bridges meet it), facing its middle
local function rimSpots(each: AbyssLayout.Island, ways: { Vector3 }): { CFrame }
	local center = Vector3.new(each.x, 0, each.z)
	local list: { Vector3 } = {}
	if each.round then
		local pieces = if each.kind == "stop" then 4 else RIM_PIECES
		for index = 1, pieces do
			local angle = (index - 0.5) / pieces * math.pi * 2
			table.insert(list, center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (each.size - 1.5))
		end
	else
		local inset = each.size - 2.5
		for step = 1, 4 do
			local along = -inset + (step - 0.5) / 4 * inset * 2
			for _, offset in { Vector3.new(along, 0, -inset), Vector3.new(along, 0, inset), Vector3.new(-inset, 0, along), Vector3.new(inset, 0, along) } do
				table.insert(list, center + offset)
			end
		end
	end
	local spots: { CFrame } = {}
	for _, spot in list do
		local clear = true
		for _, way in ways do
			clear = clear and (spot - way).Magnitude > CLEAR_OF_BRIDGE
		end
		if clear then
			table.insert(spots, CFrame.lookAt(spot, Vector3.new(each.x, 0, each.z)))
		end
	end
	return spots
end

-- The ruins and crystals round every island's rim, chains from the ceiling, the hydra sigil in the fight rings, the
-- puzzle islands' braziers, a few slabs on the ledge (props once the pack is in; neon crystals stand in)
-- Something on every small stop (owner 2026-11-12: "these small islands need something instead of being empty"),
-- off the way across it, one of a few recipes in turn: a fallen relic (the Hydra's seal lying cracked), a brazier pair,
-- a broken pillar ring, a slab with a big crystal
local function stopDecor(parent: Instance, each: AbyssLayout.Island, index: number, ways: { Vector3 }, random: Random)
	local center = Vector3.new(each.x, 0, each.z)
	-- the side away from the way across: perpendicular to its two ends
	local across = if #ways >= 2 then (ways[2] - ways[1]) else Vector3.xAxis
	across = Vector3.new(across.X, 0, across.Z)
	across = if across.Magnitude > 0.01 then across.Unit else Vector3.xAxis
	local side = Vector3.new(-across.Z, 0, across.X) * (if index % 2 == 0 then 1 else -1)
	local spot = center + side * (each.size * 0.5)
	local color = regionCrystal(each.region, index)
	local recipe = index % 4
	if recipe == 0 then
		-- a fallen relic: the Hydra's seal lying cracked and tilted, a crystal through it
		prop(parent, "DungeonHydraDoor", CFrame.new(spot) * CFrame.Angles(math.rad(-80), random:NextNumber(0, math.pi * 2), 0), rgb(Dungeon.COLORS.DOOR), nil, nil, 0.35)
		crystalCluster(parent, CFrame.new(spot + side * 2), color, random)
	elseif recipe == 1 then
		for _, offset in { -3.5, 3.5 } do
			local at = spot + across * offset
			local brazier = prop(parent, "DungeonBrazier", CFrame.lookAt(at, center), BRAZIER)
			if brazier then
				torchFire(brazier, BRAZIER, 16)
			end
		end
	elseif recipe == 2 then
		for k = 1, 3 do
			local angle = (k / 3) * math.pi * 2 + random:NextNumber(-0.3, 0.3)
			local at = spot + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 3
			prop(parent, if k == 2 then "DungeonPillar" else "DungeonPillarBroken", CFrame.lookAt(at, spot) * CFrame.Angles(math.rad(random:NextNumber(-8, 8)), 0, 0), color, nil, nil, 0.6)
		end
		crystalCluster(parent, CFrame.new(spot), color, random)
	else
		prop(parent, "DungeonSlab", CFrame.new(spot) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0), color)
		local cluster = crystalCluster(parent, CFrame.new(spot + Vector3.new(0, 0.6, 0)), color, random)
		if cluster then
			lightUp(cluster, color, 18, 1)
		end
	end
end

local function dress(parent: Instance, islands: { AbyssLayout.Island }, ways: { { Vector3 } })
	local ruins = Instance.new("Folder")
	ruins.Name = "Ruins"
	ruins.Parent = parent
	local colors = Dungeon.COLORS.CRYSTALS
	local random = Random.new(4242)
	local count = 0
	for index, each in islands do
		if each.kind == "castle" then
			continue -- the castle dresses itself
		end
		local center = Vector3.new(each.x, 0, each.z)
		local spots = rimSpots(each, ways[index])
		if each.kind == "fight" then
			-- crystals crowning the crater's rim instead
			spots = {}
			local middle = (ABYSS.RUINS.radius + 2 + ABYSS.CRATER.outer) / 2
			for index = 1, 10 do
				local angle = (index - 0.5) / 10 * math.pi * 2
				local spot = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * middle + Vector3.new(0, ABYSS.CRATER.height - 1, 0)
				if math.abs(math.cos(angle)) < math.cos(math.rad(ABYSS.CRATER.gap + 4)) then
					table.insert(spots, CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z)))
				end
			end
		end
		for _, spot in spots do
			count += 1
			local color = regionCrystal(each.region, count)
			if count % 3 == 0 then
				if each.kind ~= "fight" then
					prop(ruins, if count % 2 == 0 then "DungeonPillarBroken" else "DungeonPillar", spot, color)
					continue
				end
			end
			local lit = count % LIT_CRYSTAL_EVERY == 0
			local cluster = crystalCluster(ruins, spot, color, random)
			if cluster then
				if lit then
					lightUp(cluster, color, 16, 1.2)
				end
			else
				crystal(ruins, spot.Position, color, random, lit)
			end
		end
		if each.kind == "fight" then
			prop(ruins, "DungeonSigil", CFrame.new(center + Vector3.new(0, 0.05, 0)), rgb(Dungeon.COLORS.DOOR))
			prop(ruins, "DungeonChain", CFrame.new(center + Vector3.new(each.size * 0.6, ABYSS.CEILING_Y - CHAIN_LENGTH, -each.size * 0.4)))
		elseif each.kind ~= "ledge" and each.kind ~= "stop" then
			for _, side in { -1, 1 } do
				local spot = center + Vector3.new(each.size - 4, 0, side * (each.size - 6))
				local brazier = prop(ruins, "DungeonBrazier", CFrame.lookAt(spot, center), BRAZIER)
				if brazier then
					torchFire(brazier, BRAZIER, 22)
				end
			end
		elseif each.kind == "ledge" then
			for _ = 1, 3 do
				local spot = center + Vector3.new(random:NextNumber(-each.size + 6, each.size - 8), 0, random:NextNumber(-each.size + 6, each.size - 6))
				prop(ruins, "DungeonSlab", CFrame.new(spot) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0), rgb(colors[random:NextInteger(1, #colors)]))
			end
		end
		if each.kind == "stop" then
			stopDecor(ruins, each, index, ways[index], random)
		end
		if each.step or each.kind == "castle" then
			accent(ruins, each)
		end
	end
end

-- The chasm's glow: dim violet lights far down along the run (never a glowing floor)
local function chasmGlow(parent: Instance, islands: { AbyssLayout.Island })
	local look = ABYSS.GLOW
	for _, each in islands do
		if each.step or each.kind == "castle" then
			local color = rgb(look.color):Lerp(regionCrystal(each.region, 1), 0.5)
			local holder = block(parent, "ChasmGlow", Vector3.one, CFrame.new(each.x, look.y, each.z), color)
			holder.Transparency = 1
			ghost(holder)
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = look.range
			light.Brightness = look.brightness
			light.Parent = holder
		end
	end
end

-- A fall of light from the ceiling into the chasm: two camera-facing beams, a bright core and a wide faint glow
local function lightFall(parent: Instance, fall: AbyssLayout.Fall, color: Color3)
	local top = block(parent, "LightFall", Vector3.one, CFrame.new(fall.x, fall.top, fall.z), color)
	top.Transparency = 1
	ghost(top)
	local from = Instance.new("Attachment")
	from.Parent = top
	local to = Instance.new("Attachment")
	to.WorldPosition = Vector3.new(fall.x, fall.bottom, fall.z)
	to.Parent = top
	for _, layer in { { width = fall.width, transparency = 0.35 }, { width = fall.width * 2.6, transparency = 0.8 } } do
		local beam = Instance.new("Beam")
		beam.Attachment0 = from
		beam.Attachment1 = to
		beam.Color = ColorSequence.new(color)
		beam.LightEmission = 1
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Width0 = layer.width
		beam.Width1 = layer.width * 0.6
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, layer.transparency),
			NumberSequenceKeypoint.new(0.7, (1 + layer.transparency) / 2),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Parent = top
	end
end

-- The far scenery (round 2, concept_backdrop.png; AbyssLayout.backdrop): giant crystals on the side walls, far islands
-- of rock with crystals, falls of light into the chasm, the Hydra's carving huge on the walls, and the cave's violet haze
local function backdrop(parent: Instance, islands: { AbyssLayout.Island })
	local look = ABYSS.BACKDROP
	local first = islands[1]
	local far = AbyssLayout.backdrop(ABYSS, first.x - first.size - 4, AbyssLayout.eastWall(islands), 2026)
	local function regionAt(x: number): string
		return AbyssLayout.regionAt(islands, { x = x, z = 0 })
	end
	local folder = Instance.new("Folder")
	folder.Name = "Backdrop"
	folder.Parent = parent
	local lit = 0
	for _, crystal in far.crystals do
		local color = regionCrystal(regionAt(crystal.x), crystal.tone)
		local spot = Vector3.new(crystal.x, crystal.y, crystal.z)
		-- growing out of the wall, leaning toward the cave's middle
		local model = prop(folder, "DungeonCrystals", CFrame.lookAt(spot, Vector3.new(crystal.x, crystal.y, 0)) * CFrame.Angles(math.rad(-50), 0, 0), color, nil, nil, crystal.size)
		if model and lit < look.lights and crystal.size > (look.crystalScale[1] + look.crystalScale[2]) / 2 then
			lit += 1
			lightUp(model, color, 50, 2)
		end
	end
	for _, rock in far.islands do
		local center = Vector3.new(rock.x, rock.y, rock.z)
		local region = regionOf(regionAt(rock.x))
		workspace.Terrain:FillCylinder(CFrame.new(center), 3, rock.size, materialOf(region.top))
		workspace.Terrain:FillBall(center - Vector3.new(0, rock.size * 0.55, 0), rock.size * 0.8, materialOf(region.rock))
		workspace.Terrain:FillBall(center - Vector3.new(0, rock.size * 1.2, 0), rock.size * 0.4, materialOf(region.rock))
		prop(folder, "DungeonCrystals", CFrame.new(center + Vector3.new(0, 1.5, 0)), regionCrystal(regionAt(rock.x), rock.tone), nil, nil, rock.size / 6)
	end
	for _, fall in far.falls do
		lightFall(folder, fall, rgb(regionOf(regionAt(fall.x)).fall))
	end
	for _, relief in far.reliefs do
		local model = prop(folder, "DungeonHydraDoor", facingAlong(Vector3.new(relief.x, relief.y, relief.z), relief.yaw), rgb(ABYSS.GLOW.color), nil, nil, look.reliefScale)
		if model then
			lightUp(model, rgb(ABYSS.GLOW.color), 70, 1.5)
		end
	end
	-- the haze: the dark reads as violet depth, not black
	local haze = look.haze
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		;(atmosphere :: Atmosphere).Parent = Lighting
	end
	local air = atmosphere :: Atmosphere
	air.Density = Dungeon.LIGHTING.atmosphereDensity
	air.Offset = haze.offset
	air.Color = rgb(haze.color)
	air.Decay = rgb(haze.decay)
	air.Glare = haze.glare
	air.Haze = haze.haze
end

-- The Abyss under `parent` with beam layout `beamLayout` (Dungeon.BEAMS.LAYOUTS); its rooms, puzzles and doors for
-- DungeonService and DungeonPuzzleService
function DungeonBuilder.build(parent: Instance, beamLayout: number): DungeonLayout
	local origin = Vector3.new(Dungeon.ORIGIN.x, Dungeon.ORIGIN.y, Dungeon.ORIGIN.z)
	local chamber = Vector3.new(Dungeon.CHAMBER.x, Dungeon.CHAMBER.y, Dungeon.CHAMBER.z)
	local islands = AbyssLayout.islands(Dungeon)
	local bridges = AbyssLayout.bridges(islands)
	local random = Random.new(4243)

	cave(islands)
	-- where bridges meet each island (its lip and rim crystals keep clear of them)
	local ways: { { Vector3 } } = {}
	for index in islands do
		ways[index] = {}
	end
	for index, each in bridges do
		table.insert(ways[index], flat(each.from))
		table.insert(ways[index + 1], flat(each.to))
	end
	local hydra: Part, lairPortal: Part
	local hydraEyes: { BasePart } = {}
	for index, each in islands do
		island(parent, each, ways[index])
		if each.kind == "fight" then
			crater(each)
		elseif each.kind == "castle" then
			hydra, lairPortal, hydraEyes = castle(parent, each)
		end
	end
	for _, each in bridges do
		bridge(parent, each, random)
	end
	spires(islands)
	lair(parent)

	-- The entrance ledge: the spawn, facing into the cave
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
	-- The way back: an arch in the cave wall behind the ledge (the welcome's slab seals it)
	local back = origin + Vector3.new(ABYSS.LEDGE.back - 1, 0, 0)
	if not prop(parent, "DungeonArch", CFrame.lookAt(back, back + Vector3.xAxis), rgb(Dungeon.COLORS.DOOR)) then
		for _, side in { -1, 1 } do
			block(parent, "BackPillar", Vector3.new(3, 18, 3), CFrame.new(back + Vector3.new(0, 9, side * 11.5)), rgb(Dungeon.COLORS.WALL))
		end
		block(parent, "BackLintel", Vector3.new(3, 3, 26), CFrame.new(back + Vector3.new(0, 19.5, 0)), rgb(Dungeon.COLORS.WALL))
	end

	-- The ledge's braziers: the Hydra's welcome puts them out one by one (DungeonIntroController finds HallBrazier<n>)
	local hall = Instance.new("Folder")
	hall.Name = "HallLights"
	hall.Parent = parent
	for index, spot in Dungeon.HALL_BRAZIERS do
		local at = origin + Vector3.new(spot.x, 0, spot.z)
		local facing = CFrame.lookAt(at, Vector3.new(at.X, at.Y, origin.Z))
		local brazier = prop(hall, "DungeonBrazier", facing, BRAZIER)
		if brazier then
			torchFire(brazier, BRAZIER, 22)
		else
			-- stand-in: a stone stand with a flame (its Glow) and the light
			brazier = Instance.new("Model")
			block(brazier :: Model, "Stand", Vector3.new(2, 4, 2), CFrame.new(at + Vector3.new(0, 2, 0)), rgb(Dungeon.COLORS.WALL))
			local flame = block(brazier :: Model, "Glow", Vector3.new(1.2, 1.6, 1.2), CFrame.new(at + Vector3.new(0, 4.8, 0)), BRAZIER, Enum.Material.Neon)
			ghost(flame)
			local light = Instance.new("PointLight")
			light.Color = BRAZIER
			light.Range = 22
			light.Brightness = 1.4
			light.Parent = flame
			;(brazier :: Model).Parent = hall
		end
		(brazier :: Model).Name = `HallBrazier{index}`
	end

	-- One island per step; a gate across each bridge out (the lock's: the Hydra's door at the castle)
	local stepIslands: { AbyssLayout.Island } = {}
	local rooms: { Room } = {}
	local doors: { BasePart } = {}
	local afterDoor: { CFrame } = {}
	local beams: Beams? = nil
	local plates: Plates? = nil
	local lock: Lock? = nil
	for index, step in Dungeon.STEPS do
		local found, at = AbyssLayout.stepIsland(islands, index)
		local here = found :: AbyssLayout.Island
		stepIslands[index] = here
		local center = Vector3.new(here.x, 0, here.z)
		local out = bridges[at :: number] -- this island's bridge on
		local after: BasePart
		if index == #Dungeon.STEPS then
			-- the lock opens the Hydra's door at the castle: in front of it is where its skip sets you
			after = hydra
			local spot = hydra.Position - Vector3.new(10, hydra.Position.Y - 3, 0)
			afterDoor[index] = CFrame.lookAt(spot, spot + Vector3.xAxis)
		else
			-- on the bridge where only chasm lies past its ends (nobody walks round it over the island's edge)
			local along = AbyssLayout.gateAlong(islands, out, ABYSS.GATE_HALF, false) or 0
			local at = flat(AbyssLayout.alongBridge(out, along))
			local name = if step.kind == "fight" then `Door {step.room}` else `PuzzleDoor_{step.kind}`
			after = door(parent, name, at, out.yaw)
			local past = flat(AbyssLayout.alongBridge(out, along + 6), 3)
			afterDoor[index] = CFrame.lookAt(past, flat(out.to, 3))
		end
		table.insert(doors, after)
		-- A chest's spot by the island's way out, off to one side
		local exit = flat(here.exit)
		local chestSpot = CFrame.lookAt(exit + Vector3.new(-8, 0, -16), exit + Vector3.new(-20, 0, -16))
		if step.kind == "fight" then
			local made = room(parent, step.room :: number, center)
			made.door = after
			local into = bridges[(at :: number) - 1]
			made.approach = CFrame.lookAt(flat(AbyssLayout.alongBridge(into, into.length - 6), 3), center + Vector3.new(0, 3, 0))
			rooms[step.room :: number] = made
		elseif step.kind == "beams" then
			local layout = Dungeon.BEAMS.LAYOUTS[beamLayout] or Dungeon.BEAMS.LAYOUTS[1]
			local made = beamRoom(parent, center, layout)
			made.door = after
			made.chestSpot = chestSpot
			beams = made
		elseif step.kind == "plates" then
			local made = plateRoom(parent, center)
			made.door = after
			made.chestSpot = chestSpot
			-- the secret niche's own small ledge, off the island's +z side
			local alcove = PUZZLE.ALCOVE
			local ledgeAt = center + Vector3.new(0, 0, here.size + (alcove.z + alcove.depth - here.size) / 2 + 1)
			local ledgeSize = Vector3.new(alcove.width + 8, 2, alcove.z + alcove.depth - here.size + 4)
			block(parent, "SecretLedge", ledgeSize, CFrame.new(ledgeAt - Vector3.new(0, 1, 0)), rgb(Dungeon.COLORS.FLOOR))
			underside(ledgeAt, ledgeSize.X / 2, true, here.region)
			plates = made
		elseif step.kind == "lock" then
			local made = lockRoom(parent, center)
			made.chestSpot = chestSpot
			-- the order where you strike (the reviewer, 2026-11-12: the castle's door is 250 studs off): the Hydra's seal
			-- on this island, off the way through, facing the crystals, its eyes the sockets (the castle's door wears the
			-- same eyes: the lock's cinematic lights them there)
			local look = ABYSS.LOCK_SEAL
			local sealAt = center + Vector3.new(look.x, 0, look.z)
			local seal = hydraDoor(parent, sealAt, math.atan2(look.z, look.x), "LockSeal")
			ghost(seal) -- off the walkway; never in the way
			made.door = seal
			made.sockets = sockets(seal)
			lock = made
		end
	end
	dress(parent, islands, ways)
	chasmGlow(parent, islands)
	backdrop(parent, islands)

	local look = Dungeon.LIGHTING
	Lighting.Ambient = rgb(look.ambient)
	Lighting.OutdoorAmbient = rgb(look.outdoorAmbient)
	Lighting.Brightness = look.brightness
	Lighting.ClockTime = look.clockTime
	Lighting.FogColor = rgb(look.fogColor)
	Lighting.FogEnd = look.fogEnd
	-- (the Atmosphere, which overrides the fog, is the backdrop's haze)
	-- Underground: no stars, no sun or moon (the cave's ceiling hides the sky anyway)
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		;(sky :: Sky).Parent = Lighting
	end
	;(sky :: Sky).StarCount = 0
	;(sky :: Sky).CelestialBodiesShown = false

	return {
		entrance = entrance,
		spawn = spawn,
		rooms = rooms,
		doors = doors,
		beams = beams :: Beams,
		plates = plates :: Plates,
		lock = lock :: Lock,
		chamberDoor = doors[#doors],
		returnSpot = CFrame.lookAt(chamber + Vector3.new(0, 0, -(CHAMBER_RADIUS - 8)), chamber),
		islands = islands,
		bridges = bridges,
		afterDoor = afterDoor,
		stepIslands = stepIslands,
		lairPortal = lairPortal,
		hydraEyes = hydraEyes,
	}
end

return DungeonBuilder
