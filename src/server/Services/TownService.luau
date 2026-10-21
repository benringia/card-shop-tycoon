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

local GROUND_THICKNESS = 0.2 -- street, paths and plaza sink half into the baseplate: no z-fighting on top
local FRONTIER_PATH_WIDTH = 8

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

local function buildGround(folder: Folder)
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = Props.color(Town.GRASS_COLOR)
		baseplate.Material = Enum.Material.Grass
		baseplate.Transparency = 0
		local texture = baseplate:FindFirstChildOfClass("Texture")
		if texture then
			texture:Destroy() -- the default grid
		end
	end

	local layout = Town.LAYOUT
	ground(folder, "Street", Vector3.new(layout.STREET_HALF_LENGTH * 2, GROUND_THICKNESS, PlotConfig.STREET_WIDTH), CFrame.new(), Town.STREET_COLOR, Enum.Material.Cobblestone)

	local spring = Wild.SPRING
	-- Cylinders run along X: lay the disc flat
	local plaza = ground(folder, "Plaza", Vector3.new(GROUND_THICKNESS * 1.5, layout.PLAZA_RADIUS * 2, layout.PLAZA_RADIUS * 2), CFrame.new(spring.x, 0, spring.z) * CFrame.Angles(0, 0, math.rad(90)), Town.PLAZA_COLOR, Enum.Material.Slate)
	plaza.Shape = Enum.PartType.Cylinder
	plaza.CanCollide = false

	-- The Frontier portal stands off the street: a path out to it
	local portal = Places.FRONTIER_PORTAL
	local streetEdge = (if portal.z < 0 then -1 else 1) * PlotConfig.STREET_WIDTH / 2
	local length = math.abs(portal.z - streetEdge) + FRONTIER_PATH_WIDTH / 2
	ground(folder, "FrontierPath", Vector3.new(FRONTIER_PATH_WIDTH, GROUND_THICKNESS, length), CFrame.new(portal.x, 0, (streetEdge + portal.z) / 2), Town.PATH_COLOR, Enum.Material.Cobblestone)
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
	folder.Parent = workspace
	setLighting()
end

return TownService
