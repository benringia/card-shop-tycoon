--!strict
-- The healing spring's fountain, the Elemental Bloom (plaza round 2, the user's pick B, 2026-10-30; Config/Plaza
-- FOUNTAIN): a lotus with five outer petals, one per card element, each with a glowing gem at its tip spraying an arc
-- of its colour into the pool in the flower's heart, and a golden card-shaped crystal floating over a cup. The model
-- is built in Blender (tools/blender/build_bloom_fountain.py) and kept in ReplicatedStorage.PropModels; until it's
-- there, a part-built stand-in (petals from Util/PlazaLayout). Either way the pool is named Water, the card Crystal
-- and the gems Gem_<Element>: this adds the water arcs, the gems' sparkles and the motes rising from the pool;
-- WildService the card's turning and bobbing; FountainFxController (each client, tag BloomFountain) the rune circle,
-- the column of light and the orbs.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Plaza = require(Shared:WaitForChild("Config"):WaitForChild("Plaza"))
local PlazaLayout = require(Shared:WaitForChild("Util"):WaitForChild("PlazaLayout"))
local ScenePieces = require(script.Parent:WaitForChild("ScenePieces"))

local BloomFountain = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X: stand them up
local GEM_TILT = CFrame.Angles(math.rad(45), 0, math.rad(35.26)) -- a cube stood on its corner reads as a gem

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function vec(origin: Vector3, p: PlazaLayout.Vec): Vector3
	return origin + Vector3.new(p.x, p.y, p.z)
end

-- No collisions, no shadow: water, gems, the card
local function detail(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

-- A petal: an ellipsoid (a sphere mesh stretched to the part) from its foot to its tip, flat side facing out
local function petal(model: Model, origin: Vector3, spec: PlazaLayout.Petal, ring: any, color: Color3): Part
	local base, tip = vec(origin, spec.base), vec(origin, spec.tip)
	local along = (tip - base).Unit
	local a = math.rad(spec.angle)
	local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
	local part = ScenePieces.piece(model, "Petal", Vector3.new(ring.width, ring.length, ring.thickness), CFrame.fromMatrix(vec(origin, spec.centre), tangent, along), color, Enum.Material.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Every element's colour, for the particles that shift through them over their life
local function elementColors(): ColorSequence
	local elements = Plaza.FOUNTAIN.elements
	local keys = {}
	for index, element in elements do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#elements - 1), rgb(element.color)))
	end
	return ColorSequence.new(keys)
end

-- An arc of glowing water from a petal's gem down into the pool: a beam whose ends both point up, so it bows upward
local function jet(holder: BasePart, from: Vector3, to: Vector3, color: Color3)
	local look = Plaza.FOUNTAIN
	local function hook(point: Vector3): Attachment
		local attachment = Instance.new("Attachment")
		attachment.Parent = holder
		attachment.WorldCFrame = CFrame.fromMatrix(point, Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
		return attachment
	end
	local beam = Instance.new("Beam")
	beam.Attachment0 = hook(from)
	beam.Attachment1 = hook(to)
	beam.CurveSize0 = look.jet.rise
	beam.CurveSize1 = -look.jet.drop
	beam.Width0 = look.jet.width
	beam.Width1 = look.jet.width * 0.7
	beam.Segments = 12
	beam.FaceCamera = true
	beam.Texture = look.jet.texture
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 2
	beam.TextureSpeed = look.jet.speed
	beam.Color = ColorSequence.new(color, rgb(look.water))
	beam.Transparency = NumberSequence.new(0, 0.3)
	beam.LightEmission = 1
	beam.Parent = holder
end

-- The card crystal: glowing gold with a paler face inset on both sides
local function cardFaces(card: BasePart)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.Parent = card
		local inset = Instance.new("Frame")
		inset.AnchorPoint = Vector2.new(0.5, 0.5)
		inset.Position = UDim2.fromScale(0.5, 0.5)
		inset.Size = UDim2.fromScale(0.8, 0.85)
		inset.BackgroundColor3 = Color3.fromRGB(255, 244, 205)
		inset.BackgroundTransparency = 0.25
		inset.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.08, 0)
		corner.Parent = inset
		local diamond = Instance.new("Frame")
		diamond.AnchorPoint = Vector2.new(0.5, 0.5)
		diamond.Position = UDim2.fromScale(0.5, 0.5)
		diamond.Size = UDim2.fromScale(0.5, 0.5)
		diamond.SizeConstraint = Enum.SizeConstraint.RelativeXX
		diamond.Rotation = 45
		diamond.BackgroundColor3 = Color3.fromRGB(255, 196, 70)
		diamond.Parent = inset
	end
end

-- The part-built stand-in, its foot's middle at `at`
local function standIn(at: Vector3): Model
	local look = Plaza.FOUNTAIN
	local model = Instance.new("Model")
	local stone, trim, gold = rgb(look.stone), rgb(look.trim), rgb(look.gold)
	ScenePieces.piece(model, "Step", Vector3.new(look.step.height, look.step.radius * 2, look.step.radius * 2), CFrame.new(at + Vector3.new(0, look.step.height / 2, 0)) * UPRIGHT, trim, Enum.Material.Limestone, Enum.PartType.Cylinder)
	ScenePieces.piece(model, "Bowl", Vector3.new(look.bowl.height, look.bowl.radius * 2, look.bowl.radius * 2), CFrame.new(at + Vector3.new(0, look.step.height + look.bowl.height / 2, 0)) * UPRIGHT, stone, Enum.Material.Plaster, Enum.PartType.Cylinder)
	local pool = detail(ScenePieces.piece(model, "Water", Vector3.new(0.2, look.pool.radius * 2, look.pool.radius * 2), CFrame.new(at + Vector3.new(0, look.pool.y - 0.1, 0)) * UPRIGHT, rgb(look.water), Enum.Material.Neon, Enum.PartType.Cylinder))
	pool.Transparency = 0.25
	for _, spec in PlazaLayout.petals(look) do
		local color = rgb(spec.color)
		petal(model, at, spec, look.petal, stone:Lerp(color, look.tint))
		detail(ScenePieces.piece(model, "Gem_" .. spec.element, Vector3.one * look.gem, CFrame.new(vec(at, spec.tip)) * GEM_TILT, color, Enum.Material.Neon)).Transparency = 0.1
	end
	for _, spec in PlazaLayout.petalRing(look.inner, #look.elements, 180 / #look.elements) do
		detail(petal(model, at, spec, look.inner, rgb(look.blush)))
	end
	local stemHeight = look.stem.top - look.pool.y + 0.2
	ScenePieces.piece(model, "Stem", Vector3.new(stemHeight, look.stem.radius * 2, look.stem.radius * 2), CFrame.new(at + Vector3.new(0, look.pool.y - 0.2 + stemHeight / 2, 0)) * UPRIGHT, stone, Enum.Material.Plaster, Enum.PartType.Cylinder)
	detail(ScenePieces.piece(model, "Cup", Vector3.new(0.35, look.stem.cup * 2, look.stem.cup * 2), CFrame.new(at + Vector3.new(0, look.stem.top + 0.17, 0)) * UPRIGHT, gold, Enum.Material.Metal, Enum.PartType.Cylinder))
	local card = detail(ScenePieces.piece(model, "Crystal", Vector3.new(look.card.width, look.card.height, look.card.thickness), CFrame.new(at + Vector3.new(0, look.card.y, 0)), gold, Enum.Material.Neon))
	card.Transparency = 0.15
	cardFaces(card)
	return model
end

-- A part the game recolours: no texture or surface look left from the import, plain glowing colour
local function glowing(part: BasePart, color: Color3, transparency: number)
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	if part:IsA("MeshPart") then
		part.TextureID = ""
	end
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	detail(part)
end

-- The Blender model from PropModels, scaled so its base is FOUNTAIN_RADIUS round and stood on `at`; nil if missing
local function fromModel(at: Vector3): Model?
	local look = Plaza.FOUNTAIN
	local models = ReplicatedStorage:FindFirstChild("PropModels")
	local source = models and models:FindFirstChild(look.model)
	if not (source and source:IsA("Model")) then
		return nil
	end
	local model = source:Clone()
	local body = model:FindFirstChild("Body", true)
	if not (body and body:IsA("BasePart")) then
		warn(`[BloomFountain] {look.model} has no Body part, using the stand-in`)
		return nil
	end
	model:ScaleTo(model:GetScale() * Plaza.FOUNTAIN_RADIUS / (math.max(body.Size.X, body.Size.Z) / 2))
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(at.X - body.Position.X, at.Y - (box.Position.Y - size.Y / 2), at.Z - body.Position.Z))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanTouch = false
			part.CanCollide = part == body
			part.CanQuery = part == body
		end
	end
	local water = model:FindFirstChild("Water", true)
	if water and water:IsA("BasePart") then
		glowing(water, rgb(look.water), 0.25)
	end
	local card = model:FindFirstChild("Crystal", true)
	if card and card:IsA("BasePart") then
		glowing(card, rgb(look.gold), 0.15)
		cardFaces(card)
	end
	for _, element in look.elements do
		local gem = model:FindFirstChild("Gem_" .. element.name, true)
		if gem and gem:IsA("BasePart") then
			glowing(gem, rgb(element.color), 0.05)
		end
	end
	return model
end

-- The water arcs from each gem into the pool, the gems' sparkles and the motes rising from the pool
local function dress(model: Model)
	local look = Plaza.FOUNTAIN
	local water = model:FindFirstChild("Water", true) :: BasePart?
	if not water then
		return
	end
	local holder = ScenePieces.anchor(model, "Jets", water.Position)
	local poolRadius = math.max(water.Size.X, water.Size.Z) / 2
	for _, element in look.elements do
		local gem = model:FindFirstChild("Gem_" .. element.name, true) :: BasePart?
		if gem then
			local color = rgb(element.color)
			local out = Vector3.new(gem.Position.X - water.Position.X, 0, gem.Position.Z - water.Position.Z)
			local land = water.Position + (if out.Magnitude > 1e-3 then out.Unit else Vector3.zero) * poolRadius * look.jet.land / look.pool.radius
			jet(holder, gem.Position, land, color)
			local sparkles = Instance.new("ParticleEmitter")
			sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparkles.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
			sparkles.LightEmission = 1
			sparkles.Rate = look.gemSparkles.rate
			sparkles.Lifetime = NumberRange.new(look.gemSparkles.lifetime[1], look.gemSparkles.lifetime[2])
			sparkles.Speed = NumberRange.new(0.4, 1)
			sparkles.SpreadAngle = Vector2.new(180, 180)
			sparkles.Size = NumberSequence.new(look.gemSparkles.size, 0)
			sparkles.Parent = gem
		end
	end
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = elementColors()
	motes.LightEmission = 1
	motes.Rate = look.motes.rate
	motes.Lifetime = NumberRange.new(look.motes.lifetime[1], look.motes.lifetime[2])
	motes.Speed = NumberRange.new(look.motes.speed[1], look.motes.speed[2])
	motes.SpreadAngle = Vector2.new(look.motes.spread, look.motes.spread)
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, look.motes.size), NumberSequenceKeypoint.new(1, 0) })
	motes.RotSpeed = NumberRange.new(-90, 90)
	-- a flat disc emits up; the stand-in's water is a cylinder lying on its side, whose right face is up
	motes.EmissionDirection = if water.Size.Y < water.Size.X then Enum.NormalId.Top else Enum.NormalId.Right
	motes.Parent = water
end

-- The fountain, its foot's middle at `at`, as a model named HealingSpring tagged BloomFountain
function BloomFountain.build(at: Vector3, parent: Instance): Model
	local model = fromModel(at) or standIn(at)
	model.Name = "HealingSpring"
	-- Streams in whole, so FountainFxController never meets the tagged model before its Water and Crystal
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	dress(model)
	CollectionService:AddTag(model, "BloomFountain")
	model.Parent = parent
	return model
end

return BloomFountain
