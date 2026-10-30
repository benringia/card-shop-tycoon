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

-- The swirl in the Opening's middle: three image layers per face on a still, see-through panel facing down the trail
-- (the model's front): a glowing core (it fills the gaps between the swirl's arms), the swirl, and a smaller inner swirl.
-- The client turns the swirls in their own plane and breathes the core (PortalFxController, PortalLooks.animate): a
-- beam turned with its part twisted out of the opening and looked like several disks tumbling.
local function layer(gui: SurfaceGui, name: string, image: string, size: number, z: number, transparency: number, colors: { Color3 })
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(size, size)
	label.BackgroundTransparency = 1
	label.Image = image
	label.ImageTransparency = transparency
	label.ZIndex = z
	label.Parent = gui
	local tint = Instance.new("UIGradient")
	tint.Color = if #colors == 1 then ColorSequence.new(colors[1]) else ColorSequence.new(colors[1], colors[2])
	tint.Parent = label
end

local function swirlFace(holder: BasePart, face: Enum.NormalId, look: any)
	local fx = Town.PORTAL_FX
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SwirlGui"
	gui.Face = face
	gui.MaxDistance = fx.VORTEX_DISTANCE
	gui.LightInfluence = 0
	gui.Brightness = fx.VORTEX_BRIGHTNESS
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = fx.VORTEX_PIXELS
	gui.Parent = holder
	local colors = { rgb(look.vortex.colors[1]), rgb(look.vortex.colors[2]) }
	layer(gui, "Glow", fx.GLOW_TEXTURE, 0.85, 1, fx.PULSE.glow[1], { rgb(look.vortex.core) })
	layer(gui, "Swirl", fx.VORTEX_TEXTURE, 1, 2, look.vortex.transparency, colors)
	layer(gui, "Inner", fx.VORTEX_TEXTURE, fx.INNER.scale, 3, fx.INNER.transparency, { colors[2], colors[1] })
end

local function vortex(model: Model, look: any, opening: BasePart): BasePart
	local size = PortalLooks.vortexSize(opening.Size.X, opening.Size.Y, Town)
	local holder = Instance.new("Part")
	holder.Name = "Vortex"
	holder.Size = Vector3.new(size, size, 0.05)
	holder.Anchored = true
	hide(holder)
	holder.CFrame = CFrame.lookAt(opening.Position, opening.Position + model:GetPivot().LookVector)
	holder.Parent = model
	swirlFace(holder, Enum.NormalId.Front, look)
	swirlFace(holder, Enum.NormalId.Back, look)
	local light = Instance.new("PointLight")
	light.Color = rgb(look.light.color)
	light.Brightness = look.light.brightness
	light.Range = look.light.range
	light.Parent = holder
	return holder
end

-- Sinks a placed portal model (Props stood its lowest point on the ground) until its ground part stands at its
-- Blender height: the roots, shards and drift built below the Blender ground go back under it
local function settle(model: Model, look: any)
	local ground = model:FindFirstChild(look.ground.part)
	if not (ground and ground:IsA("BasePart")) then
		return
	end
	local box, size = model:GetBoundingBox()
	local shift = PortalLooks.groundShift(ground.Position.Y - ground.Size.Y / 2, box.Position.Y - size.Y / 2, look.ground.bottom, model:GetScale())
	model:PivotTo(model:GetPivot() + Vector3.new(0, shift, 0))
end

-- Dresses a placed portal model with its look (Config/Town PORTAL_LOOKS)
function PortalBuild.dress(model: Model, look: any)
	settle(model, look)
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
