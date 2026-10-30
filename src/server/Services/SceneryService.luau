--!strict
-- The scenery round the town and in the portal areas (Portal Worlds spec), from Config/Scenery: the terrain
-- (Util/TownTerrain), giant trees and snowy pines (scaled copies of the town's prop models), the canyon's cacti, platform
-- and torches, Forest Falls' water sheets, Frostpeak's ice crystals, snow, embers and the aurora, and ambient sounds.
-- Built once at server start. Main game only; the Frontier and the Dungeon keep their own.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Scenery = require(Config:WaitForChild("Scenery"))
local Town = require(Config:WaitForChild("Town"))
local SharedUtil = Shared:WaitForChild("Util")
local Place = require(SharedUtil:WaitForChild("Place"))
local Props = require(SharedUtil:WaitForChild("Props"))
local TownLayout = require(SharedUtil:WaitForChild("TownLayout"))
local TownTerrain = require(SharedUtil:WaitForChild("TownTerrain"))
local TownService = require(script.Parent:WaitForChild("TownService"))

local SceneryService = {}

local OPS_PER_YIELD = 20 -- fills between waits, so a big fill never stalls the server

local function material(name: string): Enum.Material
	return (Enum.Material :: any)[name]
end

local function fill(terrain: Terrain, op: TownTerrain.Op)
	local at = CFrame.new(op.x, op.y, op.z) * CFrame.Angles(0, math.rad(op.yaw or 0), 0)
	if op.shape == "Ball" then
		terrain:FillBall(Vector3.new(op.x, op.y, op.z), op.radius :: number, material(op.material))
	else
		local size = op.size :: { x: number, y: number, z: number }
		local vector = Vector3.new(size.x, size.y, size.z)
		if op.shape == "Wedge" then
			terrain:FillWedge(at, vector, material(op.material))
		else
			terrain:FillBlock(at, vector, material(op.material))
		end
	end
end

local function buildTerrain()
	local terrain = workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Grass, Props.color(Town.GRASS_COLOR))
	for name, rgb in Scenery.MATERIAL_COLORS do
		terrain:SetMaterialColor(material(name), Props.color(rgb))
	end
	local water = Scenery.WATER
	terrain.WaterColor = Props.color(water.COLOR)
	terrain.WaterTransparency = water.TRANSPARENCY
	terrain.WaterReflectance = water.REFLECTANCE
	terrain.WaterWaveSize = water.WAVE_SIZE
	terrain.WaterWaveSpeed = water.WAVE_SPEED
	for index, op in TownTerrain.ops(Scenery, Town, TownLayout.plotRects(TownService.GetWorld())) do
		fill(terrain, op)
		if index % OPS_PER_YIELD == 0 then
			task.wait()
		end
	end
end

local function anchorPart(parent: Instance, name: string, position: Vector3, size: Vector3?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size or Vector3.one
	part.Position = position
	part.Parent = parent
	return part
end

local function piece(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, surface: Enum.Material, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = surface
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A copy of one of the town's prop models (ReplicatedStorage.PropModels), scaled to `height` and stood on the ground
local function placeModel(parent: Instance, spot: any, label: string): Model?
	local models = ReplicatedStorage:FindFirstChild("PropModels")
	local source = models and models:FindFirstChild(spot.model)
	if not source or not source:IsA("Model") then
		warn(`[SceneryService] no prop model {spot.model}`)
		return nil
	end
	local model = source:Clone()
	model.Name = label
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * spot.height / size.Y)
	model:PivotTo(CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad(spot.yaw or 0), 0))
	local box, boxSize = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() - Vector3.new(0, box.Position.Y - boxSize.Y / 2, 0))
	model.Parent = parent
	return model
end

local function buildTrees(folder: Folder)
	for _, spot in Scenery.GIANT_TREES do
		placeModel(folder, spot, "GiantTree")
	end
	local snow = Props.color(Scenery.SNOW_TINT)
	for _, spot in Scenery.SNOW_PINES do
		local model = placeModel(folder, spot, "SnowPine")
		local leaves = if model then model:FindFirstChild("Leaves", true) else nil
		if leaves and leaves:IsA("MeshPart") then
			local look = leaves:FindFirstChildOfClass("SurfaceAppearance")
			if look then
				look:Destroy()
			end
			leaves.Color = snow
			leaves.Material = Enum.Material.Snow
		end
	end
end

local function buildCanyon(folder: Folder)
	local green = Color3.fromRGB(96, 158, 82)
	for _, spot in Scenery.CACTI do
		local base = CFrame.new(spot.x, 0, spot.z)
		local h = spot.height
		piece(folder, "Cactus", Vector3.new(h, 1.4, 1.4), base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), green, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		piece(folder, "Cactus", Vector3.new(h * 0.35, 0.9, 0.9), base * CFrame.new(0.9, h * 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), green, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		piece(folder, "Cactus", Vector3.new(h * 0.3, 0.9, 0.9), base * CFrame.new(-0.9, h * 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)), green, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	local platform = Scenery.PLATFORM
	piece(folder, "Platform", Vector3.new(platform.height, platform.radius * 2, platform.radius * 2), CFrame.new(platform.x, platform.height / 2, platform.z) * CFrame.Angles(0, 0, math.rad(90)), Props.color(platform.color), Enum.Material.Slate, Enum.PartType.Cylinder)
	local fire = Scenery.TORCH_FIRE
	for _, spot in Scenery.TORCHES do
		local base = CFrame.new(spot.x, 0, spot.z)
		piece(folder, "TorchPillar", Vector3.new(1.6, spot.height, 1.6), base * CFrame.new(0, spot.height / 2, 0), Props.color(platform.color), Enum.Material.Slate)
		local bowl = piece(folder, "TorchBowl", Vector3.new(0.6, 2.2, 2.2), base * CFrame.new(0, spot.height + 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 50, 45), Enum.Material.Metal, Enum.PartType.Cylinder)
		local flame = Instance.new("ParticleEmitter")
		flame.Texture = "rbxasset://textures/particles/fire_main.dds"
		flame.Color = ColorSequence.new(Props.color(fire.COLOR))
		flame.LightEmission = 1
		flame.Rate = fire.RATE
		flame.Lifetime = NumberRange.new(0.5, 0.9)
		flame.Speed = NumberRange.new(2, 4)
		flame.SpreadAngle = Vector2.new(15, 15)
		flame.Size = NumberSequence.new(1.4, 0.2)
		flame.Transparency = NumberSequence.new(0.2, 1)
		flame.EmissionDirection = Enum.NormalId.Top
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0.4, 0, 0) -- the bowl lies on its side: its +X points up
		top.Parent = bowl
		flame.Parent = top
	end
end

local function buildFalls(folder: Folder)
	local falls = Scenery.FALLS
	local anchor = anchorPart(folder, "Falls", Vector3.new(falls.TOP.x, falls.BOTTOM.y, falls.TOP.z))
	-- Parent first: an attachment's WorldPosition only means world space once it has a part
	local top = Instance.new("Attachment")
	top.Parent = anchor
	top.WorldPosition = Vector3.new(falls.TOP.x, falls.TOP.y, falls.TOP.z)
	local bottom = Instance.new("Attachment")
	bottom.Parent = anchor
	bottom.WorldPosition = Vector3.new(falls.BOTTOM.x, falls.BOTTOM.y, falls.BOTTOM.z)
	for _, spec in falls.BEAMS do
		local beam = Instance.new("Beam")
		beam.Attachment0 = top
		beam.Attachment1 = bottom
		beam.Width0 = spec.width0
		beam.Width1 = spec.width1
		beam.Texture = falls.TEXTURE
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = falls.TEXTURE_LENGTH
		beam.TextureSpeed = spec.speed
		beam.Color = ColorSequence.new(Props.color(falls.COLOR))
		beam.LightEmission = 1 -- additive: the texture's black reads as see-through
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new(spec.transparency)
		beam.FaceCamera = true
		beam.Segments = 8
		beam.Parent = anchor
	end
	for _, spec in falls.EMITTERS do
		local at = anchorPart(folder, "FallsEffect", Vector3.new(spec.x, spec.y, spec.z))
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = spec.rate
		if spec.kind == "mist" then
			emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
			emitter.Lifetime = NumberRange.new(2, 3)
			emitter.Speed = NumberRange.new(2, 5)
			emitter.SpreadAngle = Vector2.new(70, 70)
			emitter.Size = NumberSequence.new(5, 11)
			emitter.Transparency = NumberSequence.new(0.7, 1)
		else
			emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			emitter.Lifetime = NumberRange.new(0.6, 1)
			emitter.Speed = NumberRange.new(8, 12)
			emitter.SpreadAngle = Vector2.new(40, 40)
			emitter.Acceleration = Vector3.new(0, -30, 0)
			emitter.Size = NumberSequence.new(0.4, 0.1)
			emitter.Color = ColorSequence.new(Props.color(falls.COLOR))
		end
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Parent = at
	end
end

local function buildFrost(folder: Folder)
	local ice = Props.color(Scenery.CRYSTAL_COLOR)
	for _, spot in Scenery.CRYSTALS do
		local crystal = piece(folder, "IceCrystal", Vector3.new(spot.height * 0.45, spot.height, spot.height * 0.45), CFrame.new(spot.x, spot.height * 0.4, spot.z) * CFrame.Angles(math.rad(12), math.rad(spot.yaw), math.rad(8)), ice, Enum.Material.Ice)
		crystal.Transparency = 0.15
	end
end

local function buildEffects(folder: Folder)
	for _, spec in Scenery.EMITTERS do
		if spec.kind == "aurora" then
			local anchor = anchorPart(folder, "Aurora", Vector3.new(spec.x, spec.y, spec.z))
			local a = Instance.new("Attachment")
			a.Parent = anchor
			a.WorldPosition = Vector3.new(spec.x, spec.y, spec.z)
			local b = Instance.new("Attachment")
			b.Parent = anchor
			b.WorldPosition = Vector3.new(spec.toX, spec.toY, spec.toZ)
			local beam = Instance.new("Beam")
			beam.Attachment0 = a
			beam.Attachment1 = b
			beam.Width0 = spec.width
			beam.Width1 = spec.width * 0.7
			beam.CurveSize0 = 30
			beam.CurveSize1 = -25
			beam.Segments = 16
			beam.LightEmission = 1
			beam.LightInfluence = 0
			-- The falls' streaks, slow and long: ribbons flowing along the band instead of one flat sheet
			beam.Texture = Scenery.FALLS.TEXTURE
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = 40
			beam.TextureSpeed = 0.3
			beam.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 255, 170)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 120, 255)),
			})
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.25, 0.55),
				NumberSequenceKeypoint.new(0.75, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			})
			beam.Parent = anchor
		else
			local box = anchorPart(folder, "AreaEffect", Vector3.new(spec.x, spec.y, spec.z), Vector3.new(spec.size.x, 1, spec.size.z))
			local emitter = Instance.new("ParticleEmitter")
			emitter.Shape = Enum.ParticleEmitterShape.Box
			emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			emitter.Rate = spec.rate
			emitter.LightEmission = 1
			if spec.kind == "snow" then
				emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
				emitter.Lifetime = NumberRange.new(8, 12)
				emitter.Speed = NumberRange.new(1, 2)
				emitter.Acceleration = Vector3.new(0.4, -2.5, 0)
				emitter.Size = NumberSequence.new(0.35)
				emitter.EmissionDirection = Enum.NormalId.Bottom
			else
				emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				emitter.Color = ColorSequence.new(Color3.fromRGB(255, 140, 50), Color3.fromRGB(255, 70, 30))
				emitter.Lifetime = NumberRange.new(3, 5)
				emitter.Speed = NumberRange.new(1, 3)
				emitter.Acceleration = Vector3.new(0, 1.5, 0)
				emitter.Size = NumberSequence.new(0.3, 0)
				emitter.EmissionDirection = Enum.NormalId.Top
			end
			emitter.Parent = box
		end
	end
end

local function buildSounds(folder: Folder)
	for _, spec in Scenery.SOUNDS do
		local at = anchorPart(folder, spec.name .. "Sound", Vector3.new(spec.x, spec.y, spec.z))
		local sound = Instance.new("Sound")
		sound.SoundId = spec.id
		sound.Volume = spec.volume
		sound.Looped = true
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = spec.range * 0.2
		sound.RollOffMaxDistance = spec.range
		sound.Parent = at
		sound:Play()
	end
end

-- Small hand-placed decor (flowers, clover, mushrooms, small rocks) casts no shadow: it saves shadow work and no one
-- misses those shadows
local function quietSmallShadows()
	for _, name in { "TownDecor", "PlazaGarden" } do
		local root = workspace:FindFirstChild(name)
		if root then
			for _, part in root:GetDescendants() do
				if part:IsA("BasePart") and math.max(part.Size.X, part.Size.Y, part.Size.Z) < Scenery.SMALL_DECOR_SIZE then
					part.CastShadow = false
				end
			end
		end
	end
end

local function buildDressing()
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	buildTrees(folder)
	buildCanyon(folder)
	buildFalls(folder)
	buildFrost(folder)
	buildEffects(folder)
	buildSounds(folder)
	folder.Parent = workspace
	quietSmallShadows()
end

function SceneryService.Start()
	if Place.isFrontier() or Place.isDungeon() then
		return
	end
	task.spawn(buildTerrain)
	buildDressing()
end

return SceneryService
