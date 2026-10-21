--!strict
-- The main town around the plots (main town spec): grass, the cobblestone street, the plaza pad round the
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

local Props = require((script.Parent :: Instance).Parent:WaitForChild("Util"):WaitForChild("Props"))

local TownService = {}

local GROUND_THICKNESS = 0.2 -- street and plaza sink half into the baseplate: no z-fighting on top

-- Floating names over the plaza portals
local PORTAL_LABELS = {
	{ spot = Wild.PLAZA_PORTAL, text = "🌿 The Wild", detail = "Lv 1-15 monsters" },
	{ spot = Places.FRONTIER_PORTAL, text = "❄️ The Frontier", detail = "Lv 15+ · rare cards" },
	{ spot = Pvp.ARENA_PORTAL, text = "⚔️ PvP Arena", detail = "Watch battles" },
}

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

local function buildGround(folder: Folder)
	buildBounds(folder)

	local layout = Town.LAYOUT
	ground(folder, "Street", Vector3.new(layout.STREET_HALF_LENGTH * 2, GROUND_THICKNESS, PlotConfig.STREET_WIDTH), CFrame.new(), Town.STREET_COLOR, Enum.Material.Cobblestone)

	local spring = Wild.SPRING
	-- Cylinders run along X: lay the disc flat
	local plaza = ground(folder, "Plaza", Vector3.new(GROUND_THICKNESS * 1.5, layout.PLAZA_RADIUS * 2, layout.PLAZA_RADIUS * 2), CFrame.new(spring.x, 0, spring.z) * CFrame.Angles(0, 0, math.rad(90)), Town.PLAZA_COLOR, Enum.Material.Slate)
	plaza.Shape = Enum.PartType.Cylinder
	plaza.CanCollide = false
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

local function buildDecor(folder: Folder)
	for _, placement in TownLayout.build(getWorld(), Town) do
		local at = CFrame.new(placement.x, 0, placement.z) * CFrame.Angles(0, math.rad(placement.yaw), 0)
		Props.place(placement.slot, at, folder, placement.variant)
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
	Lighting.Ambient = Props.color(settings.AMBIENT)
	Lighting.OutdoorAmbient = Props.color(settings.OUTDOOR_AMBIENT)

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
	local folder = Instance.new("Folder")
	folder.Name = "Town"
	buildGround(folder)
	buildDecor(folder)
	buildPortalLabels(folder)
	folder.Parent = workspace
	setLighting()
end

return TownService
