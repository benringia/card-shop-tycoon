--!strict
-- The main town around the plots (main town spec): grass, the asphalt street and paved sidewalks, the plaza pad round the
-- healing spring, every decoration from TownLayout (swappable props, docs/props.md), portal frames and the
-- lighting. Main game only. Everything here is decoration: no gameplay reads it.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Combat = require(Config:WaitForChild("Combat"))
local Places = require(Config:WaitForChild("Places"))
local PlotConfig = require(Config:WaitForChild("Plots"))
local Pvp = require(Config:WaitForChild("Pvp"))
local Town = require(Config:WaitForChild("Town"))
local Wild = require(Config:WaitForChild("Wild"))
local SharedUtil = Shared:WaitForChild("Util")
local Place = require(SharedUtil:WaitForChild("Place"))
local TownLayout = require(SharedUtil:WaitForChild("TownLayout"))

local Props = require(SharedUtil:WaitForChild("Props"))

local TownService = {}

local GROUND_THICKNESS = 0.2 -- street and plaza sink half into the baseplate: no z-fighting on top
local SIDEWALK_HEIGHT = 0.4 -- a low kerb above the street
local MARKING_THICKNESS = 0.04 -- each marking or plaza layer sits this much above the one under it

-- The plaza portals: floating names, their ring part's name (built by WildService, FrontierService and
-- ArenaService) and their look (Town.PORTAL_EFFECTS)
local PORTAL_LABELS = {
	{ spot = Wild.PLAZA_PORTAL, text = "🌿 The Wild", detail = "Lv 1-15 monsters", ring = "The Wild", effect = "Wild" },
	{ spot = Places.FRONTIER_PORTAL, text = "❄️ The Frontier", detail = "Lv 15+ · rare cards", ring = "The Frontier", effect = "Frontier" },
	{ spot = Pvp.ARENA_PORTAL, text = "⚔️ PvP Arena", detail = "Watch battles", ring = "Arena", effect = "Arena" },
}
local PORTAL_MATCH_DISTANCE = 1 -- a Portal prop at this spot belongs to that portal

local function point(spot: { x: number, z: number }): TownLayout.Point
	return { x = spot.x, z = spot.z }
end

local function getWorld(): TownLayout.World
	return {
		plotCount = PlotConfig.COUNT,
		perRow = PlotConfig.PER_ROW,
		plotWidth = PlotConfig.WIDTH,
		plotDepth = PlotConfig.DEPTH,
		gap = PlotConfig.GAP,
		streetWidth = PlotConfig.STREET_WIDTH,
		portals = { point(Wild.PLAZA_PORTAL), point(Places.FRONTIER_PORTAL), point(Pvp.ARENA_PORTAL) },
		spring = point(Wild.SPRING),
		springRadius = Combat.SPRING_RADIUS,
	}
end

local function ground(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: { number }, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = Props.color(color)
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- The town is all there is: the Baseplate shrinks to the bounds and invisible walls keep players on it
local function buildBounds(folder: Folder)
	local bounds = Town.BOUNDS
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		local top = baseplate.Position.Y + baseplate.Size.Y / 2
		baseplate.Size = Vector3.new(bounds.HALF_X * 2, baseplate.Size.Y, bounds.HALF_Z * 2)
		baseplate.Position = Vector3.new(0, top - baseplate.Size.Y / 2, 0)
		baseplate.Color = Props.color(Town.GRASS_COLOR)
		baseplate.Material = Enum.Material.Grass
		baseplate.Transparency = 0
		local texture = baseplate:FindFirstChildOfClass("Texture")
		if texture then
			texture:Destroy() -- the default grid
		end
	end
	local walls = {
		{ size = Vector3.new(bounds.HALF_X * 2 + 2, bounds.WALL_HEIGHT, 1), x = 0, z = bounds.HALF_Z + 0.5 },
		{ size = Vector3.new(bounds.HALF_X * 2 + 2, bounds.WALL_HEIGHT, 1), x = 0, z = -bounds.HALF_Z - 0.5 },
		{ size = Vector3.new(1, bounds.WALL_HEIGHT, bounds.HALF_Z * 2 + 2), x = bounds.HALF_X + 0.5, z = 0 },
		{ size = Vector3.new(1, bounds.WALL_HEIGHT, bounds.HALF_Z * 2 + 2), x = -bounds.HALF_X - 0.5, z = 0 },
	}
	for _, spec in walls do
		local wall = Instance.new("Part")
		wall.Name = "TownEdge"
		wall.Anchored = true
		wall.Transparency = 1
		wall.CanQuery = false -- the camera can still look past it
		wall.CanTouch = false
		wall.Size = spec.size
		wall.Position = Vector3.new(spec.x, bounds.WALL_HEIGHT / 2, spec.z)
		wall.Parent = folder
	end
end

-- A thin marking lying on a surface whose top is at `top`: no collisions, no shadow
local function marking(parent: Instance, name: string, size: Vector3, x: number, top: number, z: number, color: { number }, material: Enum.Material): Part
	local part = ground(parent, name, Vector3.new(size.X, MARKING_THICKNESS, size.Z), CFrame.new(x, top + MARKING_THICKNESS / 2, z), color, material)
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

-- A flat disc centred on the spring with its top at `top` (cylinders run along X: lay it flat)
local function disc(parent: Instance, name: string, radius: number, top: number, color: { number }, material: Enum.Material): Part
	local spring = Wild.SPRING
	local part = ground(parent, name, Vector3.new(GROUND_THICKNESS, radius * 2, radius * 2), CFrame.new(spring.x, top - GROUND_THICKNESS / 2, spring.z) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	part.Shape = Enum.PartType.Cylinder
	part.CanCollide = false
	return part
end

-- Square paving slabs: a seam across the sidewalk every tile, and one down its middle
local function buildSidewalkSeams(folder: Instance, z: number, top: number)
	local floor = Town.FLOOR
	local layout = Town.LAYOUT
	local length = layout.STREET_HALF_LENGTH * 2
	marking(folder, "Seam", Vector3.new(length, 0, floor.SEAM_WIDTH), 0, top, z, floor.SEAM_COLOR, Enum.Material.Concrete)
	for x = -layout.STREET_HALF_LENGTH + floor.SIDEWALK_TILE, layout.STREET_HALF_LENGTH - floor.SIDEWALK_TILE, floor.SIDEWALK_TILE do
		marking(folder, "Seam", Vector3.new(floor.SEAM_WIDTH, 0, layout.SIDEWALK), x, top, z, floor.SEAM_COLOR, Enum.Material.Concrete)
	end
end

-- The plaza's glowing rings: a neon disc with a stone disc just inside it on top, so only a thin ring shows
local function buildPlazaRings(folder: Instance, top: number)
	local floor = Town.FLOOR
	local radii = { Town.LAYOUT.PLAZA_RADIUS - floor.RING_RIM_INSET, Combat.SPRING_RADIUS }
	for _, radius in radii do
		top += MARKING_THICKNESS
		local glow = disc(folder, "PlazaRing", radius + floor.RING_WIDTH, top, floor.RING_COLOR, Enum.Material.Neon)
		glow.Transparency = floor.GLOW_TRANSPARENCY
		glow.CastShadow = false
		top += MARKING_THICKNESS
		disc(folder, "Plaza", radius, top, Town.PLAZA_COLOR, Enum.Material.Limestone)
	end
end

local function buildGround(folder: Folder)
	buildBounds(folder)

	local layout = Town.LAYOUT
	local floor = Town.FLOOR
	local world = getWorld()
	ground(folder, "Street", Vector3.new(layout.STREET_HALF_LENGTH * 2, GROUND_THICKNESS, PlotConfig.STREET_WIDTH), CFrame.new(), Town.STREET_COLOR, Enum.Material.Asphalt)
	local streetTop = GROUND_THICKNESS / 2

	-- Pale concrete sidewalks along each shop row's front, a little above the street, paved in square slabs
	local walk = layout.SIDEWALK
	for _, side in { -1, 1 } do
		local z = side * (PlotConfig.STREET_WIDTH / 2 - walk / 2)
		local sidewalk = ground(folder, "Sidewalk", Vector3.new(layout.STREET_HALF_LENGTH * 2, SIDEWALK_HEIGHT, walk), CFrame.new(0, (SIDEWALK_HEIGHT - GROUND_THICKNESS) / 2, z), Town.SIDEWALK_COLOR, Enum.Material.Concrete)
		sidewalk.CanCollide = false
		buildSidewalkSeams(folder, z, sidewalk.Position.Y + SIDEWALK_HEIGHT / 2)
	end

	for _, stripe in TownLayout.crosswalks(world, Town) do
		marking(folder, "Crosswalk", Vector3.new(stripe.maxX - stripe.minX, 0, stripe.maxZ - stripe.minZ), (stripe.minX + stripe.maxX) / 2, streetTop, (stripe.minZ + stripe.maxZ) / 2, floor.CROSSWALK.COLOR, Enum.Material.SmoothPlastic)
	end

	-- Pale limestone plaza with glowing rings; glowing lines in each portal's colour lead from it to the portals
	local plazaTop = streetTop + MARKING_THICKNESS
	disc(folder, "Plaza", layout.PLAZA_RADIUS, plazaTop, Town.PLAZA_COLOR, Enum.Material.Limestone)
	buildPlazaRings(folder, plazaTop)

	for index, path in TownLayout.portalPaths(world, Town) do
		local look = Town.PORTAL_EFFECTS[PORTAL_LABELS[index].effect]
		local length = math.abs(path.to.x - path.from.x)
		-- Above the crosswalk stripes it crosses
		local line = marking(folder, "PortalPath", Vector3.new(length, 0, floor.PATH_WIDTH), (path.from.x + path.to.x) / 2, streetTop + MARKING_THICKNESS, path.from.z, look.ring, Enum.Material.Neon)
		line.Transparency = floor.GLOW_TRANSPARENCY
	end
end

local function addLabelText(parent: Instance, text: string, size: number, position: UDim2, height: number)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = UDim2.new(1, 0, height, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.Parent = label
end

local function buildPortalLabels(folder: Folder)
	for _, entry in PORTAL_LABELS do
		local anchor = Instance.new("Part")
		anchor.Name = "PortalLabel"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Position = Vector3.new(entry.spot.x, Town.PORTAL_LABEL_HEIGHT, entry.spot.z)
		anchor.Parent = folder
		local board = Instance.new("BillboardGui")
		board.Size = UDim2.fromOffset(260, 70)
		board.MaxDistance = Town.PORTAL_LABEL_DISTANCE
		board.LightInfluence = 0
		board.Parent = anchor
		addLabelText(board, entry.text, 36, UDim2.fromScale(0, 0), 0.62)
		addLabelText(board, entry.detail, 20, UDim2.fromScale(0, 0.62), 0.38)
	end
end

local function portalAt(x: number, z: number)
	for _, entry in PORTAL_LABELS do
		if math.abs(entry.spot.x - x) < PORTAL_MATCH_DISTANCE and math.abs(entry.spot.z - z) < PORTAL_MATCH_DISTANCE then
			return entry
		end
	end
	return nil
end

-- Glowing (Neon) parts of a portal frame take the portal's ring colour; its see-through panels get clearer
local function tintGlow(model: Instance, color: Color3)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Material == Enum.Material.Neon then
			descendant.Color = color
			if descendant.Transparency > 0 then
				descendant.Transparency = math.max(descendant.Transparency, Town.PORTAL_PANEL_TRANSPARENCY)
			end
		end
	end
end

local function buildDecor(folder: Folder)
	for _, placement in TownLayout.build(getWorld(), Town) do
		local at = CFrame.new(placement.x, 0, placement.z) * CFrame.Angles(0, math.rad(placement.yaw), 0)
		local model = Props.place(placement.slot, at, folder, placement.variant)
		local portal = if placement.slot == "Portal" then portalAt(placement.x, placement.z) else nil
		if portal then
			tintGlow(model, Props.color(Town.PORTAL_EFFECTS[portal.effect].ring))
		end
	end
end

local function colorSequence(colors: { { number } }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(Props.color(colors[1]))
	end
	local keys = {}
	for index, rgb in colors do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), Props.color(rgb)))
	end
	return ColorSequence.new(keys)
end

local function findRing(name: string, spot: { x: number, z: number }): BasePart?
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == name then
			local offset = descendant.Position - Vector3.new(spot.x, descendant.Position.Y, spot.z)
			if offset.Magnitude < PORTAL_MATCH_DISTANCE + 1 then
				return descendant
			end
		end
	end
	return nil
end

-- Each plaza portal: its ring tinted, a soft light, and particles rising (or drifting) out of the ring
local function buildPortalEffects(folder: Folder)
	for _, entry in PORTAL_LABELS do
		local look = Town.PORTAL_EFFECTS[entry.effect]
		local ringColor = Props.color(look.ring)
		local ring = findRing(entry.ring, entry.spot)
		local anchor = Instance.new("Part")
		anchor.Name = "PortalEffect"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = if ring then Vector3.new(1, ring.Size.Y * 0.8, ring.Size.Z * 0.8) else Vector3.new(1, 8, 8)
		anchor.CFrame = if ring
			then ring.CFrame -- the ring lies on its side: its thin X axis points the way it faces, Y is up
			else CFrame.new(entry.spot.x, Town.PORTAL_RING_CENTRE, entry.spot.z)
		anchor.Parent = folder
		if ring then
			ring.Color = ringColor
		end
		local light = Instance.new("PointLight")
		light.Color = ringColor
		light.Brightness = Town.PORTAL_GLOW.BRIGHTNESS
		light.Range = Town.PORTAL_GLOW.RANGE
		light.Parent = anchor
		for _, spec in look.emitters do
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = spec.texture
			emitter.Rate = spec.rate
			emitter.Lifetime = NumberRange.new(spec.lifetime[1], spec.lifetime[2])
			emitter.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
			emitter.Size = NumberSequence.new(spec.size[1], spec.size[2])
			emitter.Transparency = if spec.transparency then NumberSequence.new(spec.transparency[1], spec.transparency[2]) else NumberSequence.new(0, 1)
			emitter.Color = colorSequence(spec.colors or look.colors)
			emitter.Acceleration = Vector3.new(0, spec.rise, 0)
			emitter.RotSpeed = NumberRange.new(-spec.spin, spec.spin)
			emitter.Rotation = NumberRange.new(0, 360)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Shape = Enum.ParticleEmitterShape.Box
			emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			emitter.LightEmission = 1
			emitter.Parent = anchor
		end
	end
end

local function effect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

local function setLighting()
	local settings = Town.LIGHTING
	Lighting.ClockTime = settings.CLOCK_TIME
	Lighting.Brightness = settings.BRIGHTNESS
	Lighting.ExposureCompensation = settings.EXPOSURE
	Lighting.Ambient = Props.color(settings.AMBIENT)
	Lighting.OutdoorAmbient = Props.color(settings.OUTDOOR_AMBIENT)
	Lighting.EnvironmentSpecularScale = settings.SPECULAR

	local atmosphere = effect("Atmosphere", "TownAtmosphere") :: Atmosphere
	atmosphere.Density = settings.ATMOSPHERE.density
	atmosphere.Offset = settings.ATMOSPHERE.offset
	atmosphere.Haze = settings.ATMOSPHERE.haze
	atmosphere.Glare = settings.ATMOSPHERE.glare
	atmosphere.Color = Props.color(settings.ATMOSPHERE.color)
	atmosphere.Decay = Props.color(settings.ATMOSPHERE.decay)

	local bloom = effect("BloomEffect", "TownBloom") :: BloomEffect
	bloom.Intensity = settings.BLOOM.intensity
	bloom.Size = settings.BLOOM.size
	bloom.Threshold = settings.BLOOM.threshold

	local grading = effect("ColorCorrectionEffect", "TownColor") :: ColorCorrectionEffect
	grading.Saturation = settings.SATURATION
end

function TownService.Start()
	if Place.isFrontier() then
		return
	end
	-- Hand-placed decor (assets/town): the Lune test keeps scripts out; this is the second layer
	local decor = workspace:FindFirstChild("TownDecor")
	if decor then
		Props.strip(decor)
	end
	local folder = Instance.new("Folder")
	folder.Name = "Town"
	buildGround(folder)
	buildDecor(folder)
	buildPortalLabels(folder)
	buildPortalEffects(folder)
	folder.Parent = workspace
	setLighting()
end

return TownService
