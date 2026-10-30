--!strict
-- The healing fountain's extra magic on this client (Config/Plaza FOUNTAIN.fx; Server/Util/BloomFountain tags the
-- fountain BloomFountain): a rune circle on the floor round it, turning slowly; a column of light rising from its
-- pool; one glowing orb per card element circling its card with a trail; the column and the pool's light shifting
-- through the element colours. Only while the camera is near and the extras are on (Util/Extras); built locally, so
-- nothing is sent to the server.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Plaza = require(Shared:WaitForChild("Config"):WaitForChild("Plaza"))
local Extras = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("Extras"))

type Fx = {
	folder: Folder,
	centre: Vector3,
	rune: BasePart,
	runeAt: Vector3,
	pillar: Beam,
	orbs: { BasePart },
	card: BasePart,
	light: PointLight?,
	shown: boolean,
}

local FountainFxController = {}

local active: { [Instance]: Fx } = {}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function holder(parent: Instance, name: string, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.CFrame = cframe
	part.Parent = parent
	return part
end

local function attach(part: BasePart, cframe: CFrame): Attachment
	local attachment = Instance.new("Attachment")
	attachment.CFrame = cframe
	attachment.Parent = part
	return attachment
end

-- The floor's height just inside the rune circle's edge (the gazebo's floor in the plaza, the ground elsewhere)
local function floorAt(spring: Instance, point: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { spring }
	-- From just above the fountain's foot: a ray from higher up would land on the gazebo's dome
	local hit = workspace:Raycast(point + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), params)
	return if hit then hit.Position.Y else point.Y
end

local function build(spring: Instance): Fx?
	local water = spring:WaitForChild("Water", 10) :: BasePart?
	local card = spring:WaitForChild("Crystal", 10) :: BasePart?
	if not (water and card) or active[spring] then
		return nil
	end
	local fx = Plaza.FOUNTAIN.fx
	local folder = Instance.new("Folder")
	folder.Name = "FountainFx"
	folder.Parent = workspace
	local centre = Vector3.new(water.Position.X, 0, water.Position.Z)
	local box, size = (spring :: Model):GetBoundingBox()
	local springBottom = box.Position.Y - size.Y / 2

	-- The rune circle: a flat beam lying on the floor, its width across (the attachments' up axis lies flat)
	local runeAt = Vector3.new(centre.X, floorAt(spring, centre + Vector3.new(fx.rune.radius - 0.6, springBottom, 0)) + fx.rune.lift, centre.Z)
	local rune = holder(folder, "RuneCircle", CFrame.new(runeAt))
	local radius = fx.rune.radius
	local flat = function(x: number): CFrame
		return CFrame.fromMatrix(Vector3.new(x, 0, 0), Vector3.xAxis, Vector3.zAxis)
	end
	local circle = Instance.new("Beam")
	circle.Attachment0 = attach(rune, flat(-radius))
	circle.Attachment1 = attach(rune, flat(radius))
	circle.FaceCamera = false
	circle.Width0 = radius * 2
	circle.Width1 = radius * 2
	circle.Segments = 1
	circle.Texture = fx.rune.texture
	circle.TextureMode = Enum.TextureMode.Stretch
	circle.TextureLength = 1
	circle.LightEmission = 1
	circle.LightInfluence = 0
	circle.Transparency = NumberSequence.new(fx.rune.transparency)
	circle.Parent = rune

	-- The column of light from the pool to just under the gazebo's dome
	local column = holder(folder, "LightColumn", CFrame.new(water.Position))
	local pillar = Instance.new("Beam")
	pillar.Attachment0 = attach(column, CFrame.new())
	pillar.Attachment1 = attach(column, CFrame.new(0, springBottom + fx.pillar.height - water.Position.Y, 0))
	pillar.FaceCamera = true
	pillar.Width0 = fx.pillar.width[1]
	pillar.Width1 = fx.pillar.width[2]
	pillar.Segments = 1
	pillar.Texture = Plaza.FOUNTAIN.jet.texture
	pillar.TextureMode = Enum.TextureMode.Wrap
	pillar.TextureLength = 3
	pillar.TextureSpeed = fx.pillar.speed
	pillar.LightEmission = 1
	pillar.LightInfluence = 0
	pillar.Transparency = NumberSequence.new(fx.pillar.transparency[1], fx.pillar.transparency[2])
	pillar.Parent = column

	-- One orb per element, each with a short trail
	local orbs = {}
	for _, element in Plaza.FOUNTAIN.elements do
		local color = rgb(element.color)
		local orb = holder(folder, "Orb", CFrame.new(card.Position))
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.one * fx.orbs.size
		orb.Material = Enum.Material.Neon
		orb.Color = color
		orb.Transparency = 0
		orb.CastShadow = false
		local trail = Instance.new("Trail")
		trail.Attachment0 = attach(orb, CFrame.new(0, fx.orbs.size * 0.4, 0))
		trail.Attachment1 = attach(orb, CFrame.new(0, -fx.orbs.size * 0.4, 0))
		trail.Lifetime = fx.orbs.trail
		trail.Color = ColorSequence.new(color)
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Parent = orb
		table.insert(orbs, orb)
	end

	return {
		folder = folder,
		centre = centre + Vector3.new(0, water.Position.Y, 0),
		rune = rune,
		runeAt = runeAt,
		pillar = pillar,
		orbs = orbs,
		card = card,
		light = water:FindFirstChildOfClass("PointLight"),
		shown = true,
	}
end

local function stepFx(fx: Fx, now: number)
	local look = Plaza.FOUNTAIN.fx
	local elements = Plaza.FOUNTAIN.elements
	fx.rune.CFrame = CFrame.new(fx.runeAt) * CFrame.Angles(0, math.rad(look.rune.spin * now), 0)
	local middle = fx.card.Position
	for index, orb in fx.orbs do
		local angle = math.rad(look.orbs.speed * now + (index - 1) * 360 / #fx.orbs)
		local bob = math.sin(now * 1.3 + index) * look.orbs.bob
		orb.CFrame = CFrame.new(middle + Vector3.new(math.cos(angle) * look.orbs.radius, look.orbs.rise + bob, math.sin(angle) * look.orbs.radius))
	end
	-- Ease from one element's colour to the next
	local t = now / look.cycle
	local from = math.floor(t) % #elements + 1
	local blend = t - math.floor(t)
	blend = blend * blend * (3 - 2 * blend)
	local color = rgb(elements[from].color):Lerp(rgb(elements[from % #elements + 1].color), blend)
	fx.pillar.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	if fx.light then
		fx.light.Color = color
	end
end

local function track(spring: Instance)
	task.spawn(function()
		local fx = build(spring)
		if fx then
			active[spring] = fx
		end
	end)
end

function FountainFxController.Start()
	for _, spring in CollectionService:GetTagged("BloomFountain") do
		track(spring)
	end
	CollectionService:GetInstanceAddedSignal("BloomFountain"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("BloomFountain"):Connect(function(spring)
		local fx = active[spring]
		if fx then
			fx.folder:Destroy()
			active[spring] = nil
		end
	end)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera.CFrame.Position
		local now = os.clock()
		local enabled = Extras.enabled()
		for _, fx in active do
			local show = enabled and (fx.centre - camera).Magnitude <= Plaza.FOUNTAIN.fx.range
			if show ~= fx.shown then
				fx.shown = show
				fx.folder.Parent = if show then workspace else nil
			end
			if show then
				stepFx(fx, now)
			end
		end
	end)
end

return FountainFxController
