--!strict
-- The scenery round the town and in the portal areas (Portal Worlds spec), from Config/Scenery: the terrain
-- (Util/TownTerrain), giant trees and snowy pines (scaled copies of the town's prop models), the caldera's glowing cracks
-- and torches, Forest Falls' water sheets, Frostpeak's ice crystals, snow, embers and the aurora, and ambient sounds.
-- Built once at server start. Main game only; the Frontier and the Dungeon keep their own.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Scenery = require(Config:WaitForChild("Scenery"))
local Town = require(Config:WaitForChild("Town"))
local WildValleyConfig = require(Config:WaitForChild("WildValley"))
local Wild = require(Config:WaitForChild("Wild"))
local SharedUtil = Shared:WaitForChild("Util")
local Place = require(SharedUtil:WaitForChild("Place"))
local Props = require(SharedUtil:WaitForChild("Props"))
local TownLayout = require(SharedUtil:WaitForChild("TownLayout"))
local TownTerrain = require(SharedUtil:WaitForChild("TownTerrain"))
local LavaCracks = require(SharedUtil:WaitForChild("LavaCracks"))
local WildValley = require(SharedUtil:WaitForChild("WildValley"))
local TownService = require(script.Parent:WaitForChild("TownService"))
local ServerUtil = (script.Parent :: Instance).Parent:WaitForChild("Util")
local ScenePieces = require(ServerUtil:WaitForChild("ScenePieces"))
local PlazaBuild = require(ServerUtil:WaitForChild("PlazaBuild"))

local SceneryService = {}

local terrainOps: { TownTerrain.Op } = {} -- the fills, also used to stand props on the drawn ground
local volcanoSmoke: Vector3? = nil -- the volcano's crater (its Fx_Smoke), where the canyon's smoke effect rises

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
	for index, op in terrainOps do
		fill(terrain, op)
		if index % OPS_PER_YIELD == 0 then
			task.wait()
		end
	end
end

local anchorPart = ScenePieces.anchor
local piece = ScenePieces.piece

-- A scaled copy of a town prop model, standing on the drawn terrain unless the spot gives its own ground height
local function placeModel(parent: Instance, spot: any, label: string): Model?
	return ScenePieces.placeModel(parent, spot, label, spot.y or TownTerrain.groundAt(terrainOps, spot.x, spot.z) or 0)
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

-- The terrain under a point, by a ray (terrain only): where a crack's end sits and which way the surface faces
local function snap(origin: Vector3, direction: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(origin, direction, params)
	return if hit and hit.Instance == workspace.Terrain then hit else nil
end

-- One glowing strip between two snapped points, lifted off the surface along its normal so it never sinks in
local function strip(folder: Instance, a: RaycastResult, b: RaycastResult, width: number, color: Color3)
	local lift = (a.Normal + b.Normal).Unit * 0.1
	local from, to = a.Position + lift, b.Position + lift
	local length = (to - from).Magnitude
	if length < 0.2 then
		return
	end
	local normal = (a.Normal + b.Normal).Unit
	local along = (to - from).Unit
	local across = along:Cross(normal).Unit
	local part = piece(folder, "Crack", Vector3.new(width, 0.2, length + width * 0.5), CFrame.fromMatrix((from + to) / 2, across, normal), color, Enum.Material.Neon)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- The caldera's glowing cracks (Util/LavaCracks): down the cliff faces (a ray from the canyon's middle line toward
-- each wall) and across the floor (a ray down); a segment whose ray finds no terrain is left out
local function buildCracks(folder: Folder)
	local cracks = Scenery.CRACKS
	local holder = Instance.new("Folder")
	holder.Name = "LavaCracks"
	holder.Parent = folder
	local color = Props.color(cracks.COLOR)
	local random = Random.new(cracks.SEED)
	local walls, floor = LavaCracks.all(cracks, Town, function(): number
		return random:NextNumber()
	end)
	local centre = Vector3.new(cracks.FLOOR.centre.x, 0, cracks.FLOOR.centre.z)
	for _, wall in cracks.WALLS do
		local from = Vector3.new(wall.from.x, 0, wall.from.z)
		local to = Vector3.new(wall.to.x, 0, wall.to.z)
		local function onWall(point: LavaCracks.WallPoint): RaycastResult?
			local spot = from:Lerp(to, point.along) + Vector3.new(0, point.y, 0)
			-- start inside the canyon, level with the point, and look out toward the wall
			local inside = Vector3.new(centre.X, point.y, centre.Z)
			local out = spot - inside
			if wall.from.x == wall.to.x then
				inside = Vector3.new(centre.X, point.y, spot.Z)
				out = Vector3.new(spot.X - centre.X, 0, 0)
			else
				inside = Vector3.new(spot.X, point.y, centre.Z)
				out = Vector3.new(0, 0, spot.Z - centre.Z)
			end
			return snap(inside, out.Unit * (out.Magnitude + 16))
		end
		for _, segment in walls[wall.name] do
			-- in two halves, each snapped at its own ends, so a crack follows the wall's steps instead of bridging them
			local middle = { along = (segment.a.along + segment.b.along) / 2, y = (segment.a.y + segment.b.y) / 2 }
			local a, m, b = onWall(segment.a), onWall(middle), onWall(segment.b)
			if a and m and b then
				strip(holder, a, m, segment.width, color)
				strip(holder, m, b, segment.width, color)
			end
		end
	end
	for _, segment in floor do
		local a = snap(Vector3.new(segment.a.x, 20, segment.a.z), Vector3.new(0, -40, 0))
		local b = snap(Vector3.new(segment.b.x, 20, segment.b.z), Vector3.new(0, -40, 0))
		if a and b then
			strip(holder, a, b, segment.width, color)
		end
	end
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

-- A caldera prop as placed: anchored, out of the way of players, its Lava glowing and its Fx_ markers hidden
local function dressCalderaProp(model: Model)
	local glow = Props.color(Scenery.LAVA.COLOR)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			if part.Name == "Lava" then
				for _, child in part:GetChildren() do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
				if part:IsA("MeshPart") then
					part.TextureID = ""
				end
				part.Material = Enum.Material.Neon
				part.Color = glow
				part.CastShadow = false
			elseif string.sub(part.Name, 1, 3) == "Fx_" then
				part.Transparency = 1
				part.CastShadow = false
			end
		end
	end
end

-- An invisible upright cylinder that stops players at a tree's trunk or a shard cluster's base (Scenery.CALDERA_COLLIDERS)
local function calderaCollider(model: Model, spot: any)
	local share = Scenery.CALDERA_COLLIDERS[spot.model]
	if not share then
		return
	end
	local radius, height = share.radius * spot.height, share.height * spot.height
	local box, size = model:GetBoundingBox()
	local foot = box.Position.Y - size.Y / 2
	local collider = Instance.new("Part")
	collider.Name = "Collider"
	collider.Shape = Enum.PartType.Cylinder
	collider.Size = Vector3.new(height, radius * 2, radius * 2)
	collider.CFrame = CFrame.new(spot.x, foot + height / 2, spot.z) * CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X: stand it up
	collider.Anchored = true
	collider.Transparency = 1
	collider.CanCollide = true
	collider.CanQuery = false
	collider.CanTouch = false
	collider.CastShadow = false
	collider.Parent = model
end

-- The caldera's Blender props (Config/Scenery CHARRED_TREES, SHARDS, VOLCANO); one not saved yet is left out (placeModel
-- warns), and the smoke then rises from the volcano's spot in the config
local function buildCalderaProps(folder: Folder)
	for _, list in { Scenery.CHARRED_TREES, Scenery.SHARDS } do
		for _, spot in list do
			local model = placeModel(folder, spot, spot.model)
			if model then
				dressCalderaProp(model)
				calderaCollider(model, spot)
			end
		end
	end
	local volcano = placeModel(folder, Scenery.VOLCANO, "Volcano")
	if volcano then
		dressCalderaProp(volcano)
		local smoke = volcano:FindFirstChild("Fx_Smoke", true)
		if smoke and smoke:IsA("BasePart") then
			volcanoSmoke = smoke.Position
		end
	end
end

-- The Wild valley's footbridge over the stream (WildValley.BRIDGE): an arched deck of planks along the trail, rails on
-- posts either side; players walk over it
local function buildBridge(folder: Instance)
	local bridge = WildValleyConfig.BRIDGE
	local wood, dark = Props.color(bridge.wood), Props.color(bridge.dark)
	local steps = 8
	for index = 0, steps - 1 do
		local t0, t1 = index / steps, (index + 1) / steps
		local z0 = bridge.z - bridge.length / 2 + t0 * bridge.length
		local z1 = bridge.z - bridge.length / 2 + t1 * bridge.length
		local y0 = math.sin(t0 * math.pi) * bridge.rise
		local y1 = math.sin(t1 * math.pi) * bridge.rise
		local from, to = Vector3.new(bridge.x, y0 + 0.2, z0), Vector3.new(bridge.x, y1 + 0.2, z1)
		piece(folder, "BridgeDeck", Vector3.new(bridge.width, 0.4, (to - from).Magnitude + 0.05), CFrame.lookAt((from + to) / 2, to), if index % 2 == 0 then wood else dark, Enum.Material.WoodPlanks)
		for _, side in { -1, 1 } do
			local x = bridge.x + side * (bridge.width / 2 - 0.3)
			local rail = piece(folder, "BridgeRail", Vector3.new(0.35, 0.35, (to - from).Magnitude + 0.05), CFrame.lookAt((from + to) / 2 + Vector3.new(x - bridge.x, 2.4, 0), to + Vector3.new(x - bridge.x, 2.4, 0)), dark, Enum.Material.Wood)
			rail.CanCollide = true
			if index % 2 == 0 then
				piece(folder, "BridgePost", Vector3.new(0.5, 2.6, 0.5), CFrame.new(x, y0 + 1.3, z0), dark, Enum.Material.Wood)
			end
		end
	end
end

-- The trail's markers (Util/WildValley.markers): small glowing stones along its edges, none under the bridge; flat
-- and not solid, so monsters and players pass over them
local function buildTrailMarkers(folder: Instance)
	local look, bridge = WildValleyConfig.MARKER, WildValleyConfig.BRIDGE
	local color = Props.color(look.color)
	for index, point in WildValley.markers(WildValley.trail(Wild), WildValleyConfig.MARKER_SPACING) do
		if math.abs(point.z - bridge.z) > bridge.length / 2 + 1 then
			local side = if index % 2 == 0 then 1 else -1
			local x = point.x + side * (WildValleyConfig.TRAIL_WIDTH / 2 - 0.6)
			local stone = piece(folder, "TrailMarker", Vector3.new(0.35, look.size, look.size), CFrame.new(x, 0.12, point.z) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon, Enum.PartType.Cylinder)
			stone.CanCollide = false
			stone.CanQuery = false
			stone.CanTouch = false
			stone.CastShadow = false
		end
	end
end

-- A cluster of glowing blue crystals in the gorge: a tall one and two smaller leaning out of its foot
local function buildCrystalCluster(folder: Instance, spot: any)
	local look = WildValleyConfig.CRYSTAL_LOOK
	local color, tip = Props.color(look.color), Props.color(look.tip)
	local base = CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad(spot.yaw), 0)
	for index, shape in { { 1, 0, 0, 0 }, { 0.6, 0.9, 25, 40 }, { 0.5, -0.8, -20, 200 } } do
		local height = spot.height * shape[1]
		local lean = CFrame.Angles(math.rad(shape[3]), math.rad(shape[4]), 0)
		local crystal = piece(folder, "GorgeCrystal", Vector3.new(height * 0.4, height, height * 0.4), base * CFrame.new(shape[2], 0, 0) * lean * CFrame.new(0, height * 0.42, 0) * CFrame.Angles(0, math.rad(45), 0), if index == 1 then color else tip, Enum.Material.Neon)
		crystal.Transparency = look.transparency
		crystal.CanCollide = index == 1
		crystal.CastShadow = false
	end
end

-- The crystal cave's mouth (WildValley.CAVE): the opening is carved into the rock (an Air op); a dark wall closes its
-- back, set on the carved face a ray finds (so it runs once the terrain is filled), and a cold blue light glows inside
local function buildCave(folder: Instance)
	local cave = WildValleyConfig.CAVE
	local hit = snap(Vector3.new(cave.x, cave.height / 2, cave.z), Vector3.new(-40, 0, 0))
	if not hit then
		return
	end
	local face = hit.Position.X + 0.4
	local back = piece(folder, "CaveDark", Vector3.new(0.4, cave.height, cave.width), CFrame.new(face, cave.height / 2, cave.z), Props.color(cave.inside), Enum.Material.SmoothPlastic)
	back.CastShadow = false
	back.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Props.color(cave.light)
	light.Brightness = 1.6
	light.Range = 18
	light.Shadows = false
	light.Parent = anchorPart(folder, "CaveGlow", Vector3.new(face + 5, 4, cave.z))
end

-- A smoking vent on the ridge: a low basalt cone, a glowing core (its smoke is an area effect, Scenery.EMITTERS)
local function buildVent(folder: Instance, spot: any)
	local look = WildValleyConfig.VENT_LOOK
	local rock, glow = Props.color(look.rock), Props.color(look.glow)
	local upright = CFrame.Angles(0, 0, math.rad(90))
	piece(folder, "VentBase", Vector3.new(spot.height * 0.6, look.radius * 2.4, look.radius * 2.4), CFrame.new(spot.x, spot.height * 0.3, spot.z) * upright, rock, Enum.Material.Basalt, Enum.PartType.Cylinder)
	piece(folder, "VentRim", Vector3.new(spot.height * 0.5, look.radius * 1.5, look.radius * 1.5), CFrame.new(spot.x, spot.height * 0.75, spot.z) * upright, rock, Enum.Material.Basalt, Enum.PartType.Cylinder)
	local core = piece(folder, "VentCore", Vector3.new(0.2, look.radius, look.radius), CFrame.new(spot.x, spot.height + 0.02, spot.z) * upright, glow, Enum.Material.Neon, Enum.PartType.Cylinder)
	core.CanCollide = false
	core.CastShadow = false
end

-- The ridge's glowing floor cracks (Util/LavaCracks.floor, clear of the trail), snapped onto the terrain once it's filled
local function buildRidgeCracks(folder: Instance)
	local ridge = WildValleyConfig.RIDGE_CRACKS
	local holder = Instance.new("Folder")
	holder.Name = "RidgeCracks"
	holder.Parent = folder
	local random = Random.new(ridge.SEED)
	local trail = WildValley.trail(Wild)
	local color = Props.color(Scenery.CRACKS.COLOR)
	local floor = LavaCracks.floor(ridge.FLOOR, Scenery.CRACKS.WIDTH, trail, trail[1], WildValleyConfig.TRAIL_WIDTH / 2 + 2, 0, function(): number
		return random:NextNumber()
	end)
	for _, segment in floor do
		local a = snap(Vector3.new(segment.a.x, 20, segment.a.z), Vector3.new(0, -40, 0))
		local b = snap(Vector3.new(segment.b.x, 20, segment.b.z), Vector3.new(0, -40, 0))
		if a and b then
			strip(holder, a, b, segment.width, color)
		end
	end
end

-- The Wild valley's dressing (Config/WildValley): props, the bridge, the trail's markers, the gorge's crystals and
-- cave, the ridge's charred trees, obsidian shards (with the caldera's colliders) and vents
local function buildWildValley(folder: Folder)
	local holder = Instance.new("Folder")
	holder.Name = "WildValley"
	holder.Parent = folder
	for _, spot in WildValleyConfig.PROPS do
		placeModel(holder, spot, spot.model)
	end
	buildBridge(holder)
	buildTrailMarkers(holder)
	for _, spot in WildValleyConfig.CRYSTALS do
		buildCrystalCluster(holder, spot)
	end
	for _, list in { WildValleyConfig.CHARRED, WildValleyConfig.SHARDS } do
		for _, spot in list do
			local model = placeModel(holder, spot, spot.model)
			if model then
				dressCalderaProp(model)
				calderaCollider(model, spot)
			end
		end
	end
	for _, spot in WildValleyConfig.VENTS do
		buildVent(holder, spot)
	end
end

local function buildCanyon(folder: Folder)
	buildLava(folder)
	buildCalderaProps(folder)
	local fire = Scenery.TORCH_FIRE
	for _, spot in Scenery.TORCHES do
		local base = CFrame.new(spot.x, 0, spot.z)
		piece(folder, "TorchPillar", Vector3.new(1.6, spot.height, 1.6), base * CFrame.new(0, spot.height / 2, 0), Props.color(Scenery.TORCH_STONE), Enum.Material.Slate)
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

-- One falls effect (Config/Scenery FALLS EMITTERS): mist, the splash, foam on the pool, spray at the lip
local FALLS_EFFECTS: { [string]: (ParticleEmitter, Color3) -> Vector3 } = {
	mist = function(emitter)
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Lifetime = NumberRange.new(2, 3)
		emitter.Speed = NumberRange.new(2, 5)
		emitter.SpreadAngle = Vector2.new(70, 70)
		emitter.Size = NumberSequence.new(5, 11)
		emitter.Transparency = NumberSequence.new(0.7, 1)
		return Vector3.one
	end,
	splash = function(emitter, water)
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(water)
		emitter.LightEmission = 0.6
		emitter.Lifetime = NumberRange.new(0.8, 1.3)
		emitter.Speed = NumberRange.new(10, 16)
		emitter.SpreadAngle = Vector2.new(50, 50)
		emitter.Acceleration = Vector3.new(0, -40, 0)
		emitter.Size = NumberSequence.new(1, 0)
		return Vector3.new(10, 0.5, 2)
	end,
	foam = function(emitter)
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
		emitter.Lifetime = NumberRange.new(1.5, 2.5)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(80, 80)
		emitter.Size = NumberSequence.new(3, 6.5)
		emitter.Transparency = NumberSequence.new(0.15, 1)
		return Vector3.new(14, 0.2, 8)
	end,
	lip = function(emitter)
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
		emitter.Lifetime = NumberRange.new(0.8, 1.2)
		emitter.Speed = NumberRange.new(2, 4)
		emitter.SpreadAngle = Vector2.new(30, 30)
		emitter.Acceleration = Vector3.new(0, -6, 0)
		emitter.Size = NumberSequence.new(1.5, 3)
		emitter.Transparency = NumberSequence.new(0.5, 1)
		emitter.EmissionDirection = Enum.NormalId.Back -- out from the cliff (+Z)
		return Vector3.new(14, 0.5, 1)
	end,
}

local function buildFalls(folder: Folder)
	local falls = Scenery.FALLS
	local water = Props.color(falls.COLOR)
	local anchor = anchorPart(folder, "Falls", Vector3.new(falls.TOP.x, falls.BOTTOM.y, falls.TOP.z))
	-- Parent first: an attachment's WorldPosition only means world space once it has a part. Turned so its X axis (the
	-- way CurveSize bends a beam) points out from the cliff (+Z), so each stream bulges over the lip
	local function hook(x: number, y: number, z: number): Attachment
		local attachment = Instance.new("Attachment")
		attachment.Parent = anchor
		attachment.WorldCFrame = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(-90), 0)
		return attachment
	end
	for _, stream in falls.STREAMS do
		local beam = Instance.new("Beam")
		beam.Attachment0 = hook(falls.TOP.x + stream.offset, falls.TOP.y, falls.TOP.z)
		beam.Attachment1 = hook(falls.BOTTOM.x + stream.offset * 1.15, falls.BOTTOM.y, falls.BOTTOM.z)
		beam.Width0 = stream.width0
		beam.Width1 = stream.width1
		beam.CurveSize0 = stream.curve
		beam.Texture = falls.TEXTURE
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = stream.length
		beam.TextureSpeed = stream.speed
		beam.Color = ColorSequence.new(water)
		beam.LightEmission = 1 -- additive: the texture's black reads as see-through
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new(stream.transparency)
		beam.FaceCamera = true
		beam.Segments = 12
		beam.Parent = anchor
	end
	for _, spec in falls.EMITTERS do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = spec.rate
		emitter.EmissionDirection = Enum.NormalId.Top
		local size = FALLS_EFFECTS[spec.kind](emitter, water)
		local at = anchorPart(folder, "FallsEffect", Vector3.new(spec.x, spec.y, spec.z), size)
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.Parent = at
	end
end

-- Frostpeak's frozen falls: ice columns from the cliff's lip down to a bulging frozen mound, some stopping short like
-- giant icicles; an icicle fringe along the lip; a frozen pond at the foot with a snowy rim and a few cracks
local function buildFrozenFalls(folder: Folder)
	local f = Scenery.FROZEN_FALLS
	local model = Instance.new("Model")
	model.Name = "FrozenFalls"
	local random = Random.new(f.SEED)
	local ice, deep, frost = Props.color(f.ICE), Props.color(f.DEEP), Props.color(f.FROST)
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X: stand them up
	local left = f.x - f.WIDTH / 2
	for index = 1, f.COLUMNS do
		local radius = random:NextNumber(f.RADIUS[1], f.RADIUS[2])
		local x = left + (index - 0.5) * f.WIDTH / f.COLUMNS + random:NextNumber(-0.4, 0.4)
		local short = random:NextNumber() < f.SHORT_SHARE
		local bottom = if short then random:NextNumber(f.BOTTOM + 8, f.TOP - 7) else f.BOTTOM + random:NextNumber(0.5, 2)
		local top = f.TOP - random:NextNumber(0, 1.5)
		local z = f.FACE_Z - radius * 0.6
		local color = if index % 3 == 0 then deep else ice
		local column = piece(model, "IceColumn", Vector3.new(top - bottom, radius * 2, radius * 2), CFrame.new(x, (top + bottom) / 2, z) * upright, color, Enum.Material.Ice, Enum.PartType.Cylinder)
		column.Transparency = 0.12
		local tip = piece(model, "IceTip", Vector3.new(radius * 2, radius * 2, radius * 2), CFrame.new(x, bottom, z), color, Enum.Material.Ice, Enum.PartType.Ball)
		tip.Transparency = 0.12
	end
	for _ = 1, f.MOUND do
		local radius = random:NextNumber(2.2, 3.4)
		local ball = piece(model, "IceMound", Vector3.new(radius * 2, radius * 2, radius * 2), CFrame.new(left + random:NextNumber(0, f.WIDTH), f.BOTTOM + radius * 0.45, f.FACE_Z - random:NextNumber(2, 4)), if random:NextNumber() < 0.5 then ice else frost, Enum.Material.Ice, Enum.PartType.Ball)
		ball.Transparency = 0.1
	end
	for index = 1, f.FRINGE do
		local length = random:NextNumber(1.2, 3.5)
		local x = left - 2 + (index - 0.5) * (f.WIDTH + 4) / f.FRINGE
		local icicle = piece(model, "Icicle", Vector3.new(0.45, length, 0.45), CFrame.new(x, f.TOP - length / 2, f.FACE_Z - 0.6) * CFrame.Angles(0, math.rad(45), 0), frost, Enum.Material.Ice)
		icicle.CanCollide = false
	end
	local pond = f.POND
	local surface = piece(model, "FrozenPond", Vector3.new(0.25, pond.radius * 2, pond.radius * 2), CFrame.new(pond.x, f.BOTTOM + 0.12, pond.z) * upright, Props.color(pond.color), Enum.Material.Ice, Enum.PartType.Cylinder)
	surface.Reflectance = 0.15
	for index = 1, pond.RIM do
		local angle = (index / pond.RIM) * math.pi * 2 + random:NextNumber(-0.15, 0.15)
		local radius = random:NextNumber(1.1, 1.6)
		piece(model, "PondRim", Vector3.new(radius * 2, radius * 1.2, radius * 2), CFrame.new(pond.x + math.cos(angle) * pond.radius, f.BOTTOM + radius * 0.3, pond.z + math.sin(angle) * pond.radius), frost, Enum.Material.Snow, Enum.PartType.Ball)
	end
	for _ = 1, pond.CRACKS do
		local angle = random:NextNumber(0, 360)
		local at = random:NextNumber(0, pond.radius * 0.55)
		local crack = piece(model, "Crack", Vector3.new(0.12, 0.04, random:NextNumber(3, 5)), CFrame.new(pond.x + math.cos(math.rad(angle)) * at, f.BOTTOM + 0.27, pond.z + math.sin(math.rad(angle)) * at) * CFrame.Angles(0, math.rad(random:NextNumber(0, 180)), 0), frost, Enum.Material.SmoothPlastic)
		crack.CanCollide = false
	end
	model.Parent = folder
end

local function buildFrost(folder: Folder)
	local ice = Props.color(Scenery.CRYSTAL_COLOR)
	for _, spot in Scenery.ICICLES do
		local icicle = piece(folder, "Icicle", Vector3.new(0.7, spot.length, 0.7), CFrame.new(spot.x, spot.y - spot.length / 2, spot.z) * CFrame.Angles(0, math.rad(45), 0), ice, Enum.Material.Ice)
		icicle.CanCollide = false
		icicle.Transparency = 0.1
	end
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
	-- a ridge vent's slow grey smoke, rising and spreading
	ventsmoke = function(emitter)
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(110, 100, 104), Color3.fromRGB(70, 64, 68))
		emitter.LightEmission = 0
		emitter.Lifetime = NumberRange.new(4, 6)
		emitter.Speed = NumberRange.new(2, 3.5)
		emitter.Acceleration = Vector3.new(0.6, 1, 0)
		emitter.Size = NumberSequence.new(2, 7)
		emitter.Transparency = NumberSequence.new(0.35, 1)
		emitter.RotSpeed = NumberRange.new(-20, 20)
		emitter.Rotation = NumberRange.new(0, 360)
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

-- The volcano's smoke plume (Config/Scenery PLUME): one camera-facing beam from the crater, bending with the wind
local function buildPlume(folder: Folder, crater: Vector3)
	local plume = Scenery.PLUME
	local anchor = anchorPart(folder, "VolcanoPlume", crater)
	local base = Instance.new("Attachment")
	base.Parent = anchor
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, plume.rise, plume.drift)
	top.Parent = anchor
	local colors = {}
	for index, rgb in plume.colors do
		table.insert(colors, ColorSequenceKeypoint.new((index - 1) / (#plume.colors - 1), Props.color(rgb)))
	end
	local fades = {}
	for index, value in plume.transparency do
		table.insert(fades, NumberSequenceKeypoint.new((index - 1) / (#plume.transparency - 1), value))
	end
	local beam = Instance.new("Beam")
	beam.Attachment0 = base
	beam.Attachment1 = top
	beam.FaceCamera = true
	beam.Width0 = plume.width[1]
	beam.Width1 = plume.width[2]
	beam.Segments = 12
	beam.CurveSize0 = plume.rise * 0.15
	beam.CurveSize1 = -plume.rise * 0.1
	beam.Texture = plume.texture
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = plume.length
	beam.TextureSpeed = -plume.speed
	beam.LightEmission = 0
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(colors)
	beam.Transparency = NumberSequence.new(fades)
	beam.Parent = anchor
end

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
		elseif spec.kind == "plume" then
			buildPlume(folder, volcanoSmoke or Vector3.new(spec.x, spec.y, spec.z))
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
	for _, name in { "TownDecor" } do
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
	buildFrozenFalls(folder)
	buildSmallLife(folder)
	buildWildValley(folder)
	buildEffects(folder)
	buildSounds(folder)
	PlazaBuild.build(folder)
	folder.Parent = workspace
	quietSmallShadows()
end

function SceneryService.Start()
	if Place.isFrontier() or Place.isDungeon() then
		return
	end
	terrainOps = TownTerrain.ops(Scenery, Town, TownLayout.plotRects(TownService.GetWorld()))
	-- The Wild valley (Config/WildValley), far up the map in this same place: its terrain fills with the town's
	for _, op in WildValleyConfig.TERRAIN do
		table.insert(terrainOps, op)
	end
	-- Neither holds up the server's start (the players' data loads after the services start). The caldera's cracks
	-- snap onto the terrain by raycast, so they wait for it to be filled.
	task.spawn(function()
		buildTerrain()
		-- the Wild valley has ground now: WildService lets players travel there
		workspace:SetAttribute(WildValleyConfig.TERRAIN_READY_ATTRIBUTE, true)
		local scenery = workspace:WaitForChild("Scenery")
		buildCracks(scenery :: Folder)
		buildRidgeCracks(scenery)
		buildCave(scenery)
	end)
	task.spawn(buildDressing)
end

return SceneryService
