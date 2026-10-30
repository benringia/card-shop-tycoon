--!strict
-- The town portals grown from their worlds (spec 2026-10-30-town-portals-design): dresses a placed portal model (Props
-- slots PortalWild, PortalFrontier, PortalArena; Blender builds, docs/props.md) from the parts Config/Town
-- PORTAL_LOOKS names: the Opening and the Fx_ markers hidden, glow parts made glowing colour, a vortex beam filling
-- the Opening on a part named Vortex (PortalFxController spins it near the camera), the look's light, and its beams and
-- emitters (Util/PortalLooks.effectsFor: an effect whose parts are missing is left out). The model streams in whole and
-- is tagged TownPortal. Also builds the emitters of today's frame (TownService), which stands in until a model is saved.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local PortalLooks = require(Shared:WaitForChild("Util"):WaitForChild("PortalLooks"))

local PortalBuild = {}

local TAG = "TownPortal"

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function colorSequence(colors: { { number } }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(rgb(colors[1]))
	end
	local keys = {}
	for index, color in colors do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), rgb(color)))
	end
	return ColorSequence.new(keys)
end

-- A part the game only uses as a spot: invisible and out of the way
local function hide(part: BasePart)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- A part drawn as plain glowing colour: no texture or surface look left from the import
local function glowing(part: BasePart, color: Color3)
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
	part.CastShadow = false
end

-- A particle emitter from a PORTAL_EFFECTS / PORTAL_LOOKS spec, emitting from the whole of its part
function PortalBuild.emitter(spec: any, colors: { { number } }, parent: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = spec.texture
	emitter.Rate = spec.rate
	emitter.Lifetime = NumberRange.new(spec.lifetime[1], spec.lifetime[2])
	emitter.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
	emitter.Size = NumberSequence.new(spec.size[1], spec.size[2])
	emitter.Transparency = if spec.transparency then NumberSequence.new(spec.transparency[1], spec.transparency[2]) else NumberSequence.new(0, 1)
	emitter.Color = colorSequence(spec.colors or colors)
	emitter.Acceleration = Vector3.new(0, spec.rise, 0)
	emitter.RotSpeed = NumberRange.new(-spec.spin, spec.spin)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.LightEmission = 1
	emitter.Parent = parent
	return emitter
end

-- An attachment at a world position, its up axis world up (a camera-facing beam's ends)
local function hook(holder: BasePart, position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	attachment.WorldCFrame = CFrame.new(position)
	return attachment
end

-- A scrolling beam from one part to another (water trickling, lava dripping), held by its start (a still marker:
-- never the Vortex, which spins)
local function beam(spec: any, from: BasePart, to: BasePart)
	local stream = Instance.new("Beam")
	stream.Attachment0 = hook(from, from.Position)
	stream.Attachment1 = hook(from, to.Position)
	stream.FaceCamera = true
	stream.Width0 = spec.width
	stream.Width1 = spec.width * 0.8
	stream.Segments = 8
	stream.Texture = spec.texture
	stream.TextureMode = Enum.TextureMode.Wrap
	stream.TextureLength = 2
	stream.TextureSpeed = spec.speed
	stream.Color = ColorSequence.new(rgb(spec.color))
	stream.Transparency = NumberSequence.new(0, 0.2)
	stream.LightEmission = 1
	stream.Parent = from
end

-- The swirl filling the Opening: a flat beam across it on a part facing down the trail (the model's front), so the
-- client turns the part about its look axis to spin it
local function vortex(model: Model, look: any, opening: BasePart): BasePart
	local fx = Town.PORTAL_FX
	local holder = Instance.new("Part")
	holder.Name = "Vortex"
	holder.Size = Vector3.one * 0.2
	holder.Anchored = true
	hide(holder)
	holder.CFrame = CFrame.lookAt(opening.Position, opening.Position + model:GetPivot().LookVector)
	holder.Parent = model
	-- default orientation: the attachments' up axis is the part's Y, so the beam's width runs up the opening
	local left = Instance.new("Attachment")
	left.Position = Vector3.new(-opening.Size.X / 2, 0, 0)
	left.Parent = holder
	local right = Instance.new("Attachment")
	right.Position = Vector3.new(opening.Size.X / 2, 0, 0)
	right.Parent = holder
	local swirl = Instance.new("Beam")
	swirl.Attachment0 = left
	swirl.Attachment1 = right
	swirl.FaceCamera = false
	swirl.Width0 = opening.Size.Y
	swirl.Width1 = opening.Size.Y
	swirl.Segments = 1
	swirl.Texture = fx.VORTEX_TEXTURE
	swirl.TextureMode = Enum.TextureMode.Stretch
	swirl.TextureLength = 1
	swirl.LightEmission = fx.VORTEX_LIGHT
	swirl.LightInfluence = 0
	swirl.Color = ColorSequence.new(rgb(look.vortex.colors[1]), rgb(look.vortex.colors[2]))
	swirl.Transparency = NumberSequence.new(look.vortex.transparency)
	swirl.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = rgb(look.light.color)
	light.Brightness = look.light.brightness
	light.Range = look.light.range
	light.Parent = holder
	return holder
end

-- Dresses a placed portal model with its look (Config/Town PORTAL_LOOKS)
function PortalBuild.dress(model: Model, look: any)
	local missing = {}
	for _, name in PortalLooks.parts(look) do
		if not model:FindFirstChild(name) then
			table.insert(missing, name)
		end
	end
	if #missing > 0 then
		warn(`[PortalBuild] {model.Name} has no {table.concat(missing, ", ")}: what needs them is left out`)
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and (part.Name == "Opening" or string.sub(part.Name, 1, 3) == "Fx_") then
			hide(part)
		end
	end
	for name, color in look.glow do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			glowing(part, rgb(color))
		end
	end
	local opening = model:FindFirstChild("Opening")
	if opening and opening:IsA("BasePart") then
		vortex(model, look, opening)
	end
	for _, spec in PortalLooks.effectsFor(look, function(name: string): boolean
		return model:FindFirstChild(name) ~= nil
	end) do
		if spec.kind == "beam" then
			beam(spec, model:FindFirstChild(spec.from) :: BasePart, model:FindFirstChild(spec.to) :: BasePart)
		else
			PortalBuild.emitter(spec, look.vortex.colors, model:FindFirstChild(spec.at) :: BasePart)
		end
	end
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(model, TAG)
end

return PortalBuild
