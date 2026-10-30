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
	local at = CFrame.new(op.x, op.y, op.z) * CFrame.Angles(0, math.rad(op.yaw or 0), 0) * CFrame.Angles(math.rad(op.pitch or 0), 0, 0)
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
	local ground = spot.y or 0
	model:PivotTo(CFrame.new(spot.x, ground, spot.z) * CFrame.Angles(0, math.rad(spot.yaw or 0), 0))
	local box, boxSize = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() - Vector3.new(0, box.Position.Y - boxSize.Y / 2 - ground, 0))
	model.Parent = parent
	return model
end

local function buildTrees(folder: Folder)
	for _, spot in Scenery.GIANT_TREES do
		placeModel(folder, spot, "GiantTree")
	end
	-- Pines whose leaves are frosted: the leaves' textured look swapped for plain snow in `tint`
	local function frostedPines(list: { any }, tint: { number })
		local color = Props.color(tint)
		for _, spot in list do
			local model = placeModel(folder, spot, "SnowPine")
			local leaves = if model then model:FindFirstChild("Leaves", true) else nil
			if leaves and leaves:IsA("MeshPart") then
				local look = leaves:FindFirstChildOfClass("SurfaceAppearance")
				if look then
					look:Destroy()
				end
				leaves.Color = color
				leaves.Material = Enum.Material.Snow
			end
		end
	end
	frostedPines(Scenery.SNOW_PINES, Scenery.SNOW_TINT)
	frostedPines(Scenery.DUSTED_PINES, Scenery.DUSTED_TINT)
end

-- A saguaro: a rounded trunk, two arms that bend up at the elbow, darker ribs and a pink flower on top
local function buildCactus(folder: Folder, spot: any)
	local look = Scenery.CACTUS
	local body, dark = Props.color(look.BODY), Props.color(look.DARK)
	local model = Instance.new("Model")
	model.Name = "Cactus"
	local h = spot.height
	local base = CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad((spot.x * 37) % 360), 0)
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X: stand them up
	local trunk = 1.7
	piece(model, "Trunk", Vector3.new(h, trunk, trunk), base * CFrame.new(0, h / 2, 0) * upright, body, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	piece(model, "Top", Vector3.new(trunk, trunk, trunk), base * CFrame.new(0, h, 0), body, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		piece(model, "Rib", Vector3.new(h * 0.92, 0.25, 0.25), base * CFrame.new(side * trunk * 0.42, h / 2, 0) * upright, dark, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	for index, side in { 1, -1 } do
		local armY = h * (if index == 1 then 0.5 else 0.36)
		local rise = h * (if index == 1 then 0.32 else 0.24)
		local out = 1.6
		local arm = 1.05
		piece(model, "Arm", Vector3.new(out, arm, arm), base * CFrame.new(side * (trunk / 2 + out / 2 - 0.2), armY, 0), body, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		piece(model, "Elbow", Vector3.new(arm, arm, arm), base * CFrame.new(side * (trunk / 2 + out - 0.2), armY, 0), body, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		piece(model, "Arm", Vector3.new(rise, arm, arm), base * CFrame.new(side * (trunk / 2 + out - 0.2), armY + rise / 2, 0) * upright, body, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		piece(model, "ArmTop", Vector3.new(arm, arm, arm), base * CFrame.new(side * (trunk / 2 + out - 0.2), armY + rise, 0), body, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	piece(model, "Flower", Vector3.new(0.7, 0.7, 0.7), base * CFrame.new(0, h + trunk / 2, 0), Props.color(look.FLOWER), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	model.Parent = folder
end

-- Lava: a glowing river at the south wall's foot and a pool behind the portal, each lighting its rock
local function buildLava(folder: Folder)
	local lava = Scenery.LAVA
	local color, hot = Props.color(lava.COLOR), Props.color(lava.HOT)
	local river = lava.RIVER
	local from = Vector3.new(river.from.x, 0.15, river.from.z)
	local to = Vector3.new(river.to.x, 0.15, river.to.z)
	local surface = piece(folder, "LavaRiver", Vector3.new(river.width, 0.3, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), color, Enum.Material.Neon)
	surface.CanCollide = false
	surface.CastShadow = false
	local pool = lava.POOL
	local disc = piece(folder, "LavaPool", Vector3.new(0.3, pool.radius * 2, pool.radius * 2), CFrame.new(pool.x, 0.15, pool.z) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon, Enum.PartType.Cylinder)
	disc.CanCollide = false
	disc.CastShadow = false
	local core = piece(folder, "LavaPoolCore", Vector3.new(0.32, pool.radius, pool.radius), CFrame.new(pool.x, 0.16, pool.z) * CFrame.Angles(0, 0, math.rad(90)), hot, Enum.Material.Neon, Enum.PartType.Cylinder)
	core.CanCollide = false
	core.CastShadow = false
	for _, at in { Vector3.new(pool.x, 3, pool.z), (from + to) / 2 + Vector3.new(0, 3, 0) } do
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = lava.GLOW.BRIGHTNESS
		light.Range = lava.GLOW.RANGE
		light.Shadows = false
		light.Parent = anchorPart(folder, "LavaGlow", at)
	end
end

local function buildCanyon(folder: Folder)
	for _, spot in Scenery.CACTI do
		buildCactus(folder, spot)
	end
	buildLava(folder)
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

local function buildSnowman(folder: Folder)
	local spot = Scenery.SNOWMAN
	local model = Instance.new("Model")
	model.Name = "Snowman"
	local base = CFrame.new(spot.x, spot.y, spot.z) * CFrame.Angles(0, math.rad(spot.yaw), 0)
	local white = Color3.fromRGB(245, 250, 255)
	for _, ball in { { 3.2, 1.4 }, { 2.4, 3.9 }, { 1.7, 5.8 } } do
		piece(model, "Snow", Vector3.new(ball[1], ball[1], ball[1]), base * CFrame.new(0, ball[2], 0), white, Enum.Material.Snow, Enum.PartType.Ball)
	end
	piece(model, "Nose", Vector3.new(0.3, 0.3, 0.9), base * CFrame.new(0, 5.8, -1), Color3.fromRGB(255, 140, 40), Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		piece(model, "Eye", Vector3.new(0.25, 0.25, 0.25), base * CFrame.new(side * 0.35, 6.1, -0.8), Color3.fromRGB(30, 30, 36), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		piece(model, "Arm", Vector3.new(0.2, 0.2, 2), base * CFrame.new(side * 1.8, 4.2, 0) * CFrame.Angles(0, math.rad(90), math.rad(side * 25)), Color3.fromRGB(110, 76, 50), Enum.Material.Wood)
	end
	piece(model, "Scarf", Vector3.new(0.6, 2.4, 2.4), base * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 60, 70), Enum.Material.Fabric, Enum.PartType.Cylinder)
	model.Parent = folder
end

local function buildFrost(folder: Folder)
	local ice = Props.color(Scenery.CRYSTAL_COLOR)
	for _, spot in Scenery.ICICLES do
		local icicle = piece(folder, "Icicle", Vector3.new(0.7, spot.length, 0.7), CFrame.new(spot.x, spot.y - spot.length / 2, spot.z) * CFrame.Angles(0, math.rad(45), 0), ice, Enum.Material.Ice)
		icicle.CanCollide = false
		icicle.Transparency = 0.1
	end
	buildSnowman(folder)
	for _, spot in Scenery.CRYSTALS do
		local crystal = piece(folder, "IceCrystal", Vector3.new(spot.height * 0.45, spot.height, spot.height * 0.45), CFrame.new(spot.x, (spot.y or 0) + spot.height * 0.4, spot.z) * CFrame.Angles(math.rad(12), math.rad(spot.yaw), math.rad(8)), ice, Enum.Material.Ice)
		crystal.Transparency = 0.15
	end
end

local function buildSmallLife(folder: Folder)
	for _, spot in Scenery.AREA_PROPS do
		placeModel(folder, spot, spot.model)
	end
	local garden = workspace:FindFirstChild("PlazaGarden")
	local source = garden and (garden:FindFirstChild("GlowMushrooms") or garden:FindFirstChild("GlowMushroom"))
	if source then
		for _, spot in Scenery.MUSHROOMS do
			local copy = source:Clone()
			for _, light in copy:GetDescendants() do
				if light:IsA("Light") then
					light:Destroy()
				end
			end
			copy:PivotTo(CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad((spot.x * 53) % 360), 0))
			local box, size = copy:GetBoundingBox()
			copy:PivotTo(copy:GetPivot() - Vector3.new(0, box.Position.Y - size.Y / 2, 0))
			copy.Parent = folder
		end
	end
end

-- The look of each kind of area effect (Config/Scenery EMITTERS)
local EFFECT_LOOKS: { [string]: (ParticleEmitter) -> () } = {
	snow = function(emitter)
		emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
		emitter.Lifetime = NumberRange.new(8, 12)
		emitter.Speed = NumberRange.new(1, 2)
		emitter.Acceleration = Vector3.new(0.4, -2.5, 0)
		emitter.Size = NumberSequence.new(0.35)
		emitter.EmissionDirection = Enum.NormalId.Bottom
	end,
	glints = function(emitter)
		emitter.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
		emitter.Lifetime = NumberRange.new(0.6, 1.2)
		emitter.Speed = NumberRange.new(0, 0)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 0) })
	end,
	embers = function(emitter)
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 140, 50), Color3.fromRGB(255, 70, 30))
		emitter.Lifetime = NumberRange.new(3, 5)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.Acceleration = Vector3.new(0, 1.5, 0)
		emitter.Size = NumberSequence.new(0.3, 0)
		emitter.EmissionDirection = Enum.NormalId.Top
	end,
	bubbles = function(emitter)
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 90, 20))
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.Acceleration = Vector3.new(0, -2, 0)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.6, 0.9), NumberSequenceKeypoint.new(1, 0) })
		emitter.EmissionDirection = Enum.NormalId.Top
	end,
	flow = function(emitter)
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 110, 30))
		emitter.Lifetime = NumberRange.new(4, 6)
		emitter.Speed = NumberRange.new(2, 3)
		emitter.Size = NumberSequence.new(0.5, 0.2)
		emitter.EmissionDirection = Enum.NormalId.Left -- downstream, toward the pool
		emitter.SpreadAngle = Vector2.new(5, 5)
	end,
	fireflies = function(emitter)
		emitter.Color = ColorSequence.new(Color3.fromRGB(210, 255, 120))
		emitter.Lifetime = NumberRange.new(4, 7)
		emitter.Speed = NumberRange.new(0.3, 1)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(0.7, 0.35), NumberSequenceKeypoint.new(1, 0) })
	end,
	leaves = function(emitter)
		emitter.Color = ColorSequence.new(Color3.fromRGB(150, 200, 90), Color3.fromRGB(230, 200, 80))
		emitter.LightEmission = 0
		emitter.Lifetime = NumberRange.new(8, 12)
		emitter.Speed = NumberRange.new(1, 2)
		emitter.Acceleration = Vector3.new(0.6, -1.6, 0.3)
		emitter.RotSpeed = NumberRange.new(-90, 90)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.Size = NumberSequence.new(0.45)
		emitter.EmissionDirection = Enum.NormalId.Bottom
	end,
}

local function buildEffects(folder: Folder)
	for _, spec in Scenery.EMITTERS do
		if spec.kind == "aurora" then
			local aurora = Scenery.AURORA
			for index, curtain in aurora.CURTAINS do
				local anchor = anchorPart(folder, "Aurora", Vector3.new(curtain.from.x, curtain.from.y, curtain.from.z))
				-- Upright attachments hang the beam's width vertically; turned a quarter about Y, their X axis (the way
				-- CurveSize bends the beam) points across the curtain, so it waves
				local function hook(at: { x: number, y: number, z: number }): Attachment
					local attachment = Instance.new("Attachment")
					attachment.Parent = anchor
					attachment.WorldCFrame = CFrame.new(at.x, at.y, at.z) * CFrame.Angles(0, math.rad(90), 0)
					return attachment
				end
				local beam = Instance.new("Beam")
				beam.Attachment0 = hook(curtain.from)
				beam.Attachment1 = hook(curtain.to)
				beam.FaceCamera = false
				beam.Width0 = curtain.width
				beam.Width1 = curtain.width * 0.85
				beam.CurveSize0 = curtain.curve[1]
				beam.CurveSize1 = curtain.curve[2]
				beam.Segments = 24
				beam.Texture = aurora.TEXTURE
				beam.TextureMode = Enum.TextureMode.Wrap
				beam.TextureLength = aurora.TEXTURE_LENGTH
				beam.TextureSpeed = aurora.SPEED * (if index % 2 == 0 then -1 else 1)
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.ZOffset = index * 0.5
				beam.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.15, aurora.TRANSPARENCY),
					NumberSequenceKeypoint.new(0.85, aurora.TRANSPARENCY),
					NumberSequenceKeypoint.new(1, 1),
				})
				beam.Parent = anchor
			end
		else
			local box = anchorPart(folder, "AreaEffect", Vector3.new(spec.x, spec.y, spec.z), Vector3.new(spec.size.x, 1, spec.size.z))
			local emitter = Instance.new("ParticleEmitter")
			emitter.Shape = Enum.ParticleEmitterShape.Box
			emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			emitter.Rate = spec.rate
			emitter.LightEmission = 1
			local look = EFFECT_LOOKS[spec.kind]
			if look then
				look(emitter)
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
	buildSmallLife(folder)
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
