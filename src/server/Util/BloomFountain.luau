--!strict
-- The healing spring's fountain, the Elemental Bloom (plaza round 2, the user's pick B, 2026-10-30; Config/Plaza
-- FOUNTAIN, petals from Util/PlazaLayout): a white stone lotus on a round step. Five outer petals, one per card
-- element, each with a glowing gem at its tip spraying an arc of its colour into the pool in the flower's heart; five
-- blush petals rise from the water; a golden card-shaped crystal floats over a stem. The pool is named Water and the
-- card Crystal, so WildService's spring effects (breathing water, sparkles, the card turning and bobbing) find them.
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

-- The fountain, its foot's middle at `at`, as a model named HealingSpring
function BloomFountain.build(at: Vector3, parent: Instance): Model
	local look = Plaza.FOUNTAIN
	local model = Instance.new("Model")
	model.Name = "HealingSpring"
	local stone, trim, gold = rgb(look.stone), rgb(look.trim), rgb(look.gold)
	ScenePieces.piece(model, "Step", Vector3.new(look.step.height, look.step.radius * 2, look.step.radius * 2), CFrame.new(at + Vector3.new(0, look.step.height / 2, 0)) * UPRIGHT, trim, Enum.Material.Limestone, Enum.PartType.Cylinder)
	ScenePieces.piece(model, "Bowl", Vector3.new(look.bowl.height, look.bowl.radius * 2, look.bowl.radius * 2), CFrame.new(at + Vector3.new(0, look.step.height + look.bowl.height / 2, 0)) * UPRIGHT, stone, Enum.Material.Plaster, Enum.PartType.Cylinder)
	local pool = detail(ScenePieces.piece(model, "Water", Vector3.new(0.2, look.pool.radius * 2, look.pool.radius * 2), CFrame.new(at + Vector3.new(0, look.pool.y - 0.1, 0)) * UPRIGHT, rgb(look.water), Enum.Material.Neon, Enum.PartType.Cylinder))
	pool.Transparency = 0.25
	local holder = ScenePieces.anchor(model, "Jets", at + Vector3.new(0, look.pool.y, 0))
	for _, spec in PlazaLayout.petals(look) do
		local color = rgb(spec.color)
		petal(model, at, spec, look.petal, stone:Lerp(color, look.tint))
		local tip = vec(at, spec.tip)
		detail(ScenePieces.piece(model, "PetalGem", Vector3.one * look.gem, CFrame.new(tip) * GEM_TILT, color, Enum.Material.Neon)).Transparency = 0.1
		jet(holder, tip, vec(at, spec.land), color)
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
	model.Parent = parent
	return model
end

return BloomFountain
