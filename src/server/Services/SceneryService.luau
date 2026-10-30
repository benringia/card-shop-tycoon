--!strict
-- The scenery round the town and in the portal areas (Portal Worlds spec): the terrain from Config/Scenery
-- (Util/TownTerrain), filled once at server start. Main game only; the Frontier and the Dungeon keep their own.
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

function SceneryService.Start()
	if Place.isFrontier() or Place.isDungeon() then
		return
	end
	task.spawn(buildTerrain)
end

return SceneryService
