--!strict
-- The scenery round the town and in the portal areas (Portal Worlds spec), from Config/Scenery: the terrain
-- (Util/TownTerrain), giant trees and snowy pines (scaled copies of the town's prop models), the caldera's glowing cracks
-- and torches, Forest Falls' water sheets, Frostpeak's ice crystals, snow, embers and the aurora, and ambient sounds.
-- Built once at server start. Main game only; the Frontier and the Dungeon keep their own.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Scenery = require(Config:WaitForChild("Scenery"))
local Town = require(Config:WaitForChild("Town"))
local Bosses = require(Config:WaitForChild("Bosses"))
local SharedUtil = Shared:WaitForChild("Util")
local Place = require(SharedUtil:WaitForChild("Place"))
local ValleyConfig = Place.getValley() -- the place's valley (Util/Place)
local Props = require(SharedUtil:WaitForChild("Props"))
local AttackFx = require(Config:WaitForChild("AttackFx")) -- the rain rings' texture
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
local settling: { Model } = {} -- valley and backdrop pieces to settle onto the terrain once it's filled (settlePieces)
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

-- Invisible upright cylinders that stop players at a piece (`share`: radius and height as shares of the spot's height,
-- one in the middle or one at each `spread` offset along the piece's own X)
local function uprightColliders(model: Model, spot: any, share: any)
	local radius, height = share.radius * spot.height, share.height * spot.height
	local box, size = model:GetBoundingBox()
	local foot = box.Position.Y - size.Y / 2
	local base = CFrame.new(spot.x, foot + height / 2, spot.z) * CFrame.Angles(0, math.rad(spot.yaw or 0), 0)
	for _, offset in share.spread or { 0 } do
		local collider = Instance.new("Part")
		collider.Name = "Collider"
		collider.Shape = Enum.PartType.Cylinder
		collider.Size = Vector3.new(height, radius * 2, radius * 2)
		collider.CFrame = base * CFrame.new(offset * spot.height, 0, 0) * CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X: stand it up
		collider.Anchored = true
		collider.Transparency = 1
		collider.CanCollide = true
		collider.CanQuery = false
		collider.CanTouch = false
		collider.CastShadow = false
		collider.Parent = model
	end
end

-- An invisible upright cylinder that stops players at a tree's trunk or a shard cluster's base (Scenery.CALDERA_COLLIDERS)
local function calderaCollider(model: Model, spot: any)
	local share = Scenery.CALDERA_COLLIDERS[spot.model]
	if share then
		uprightColliders(model, spot, share)
	end
end

-- A valley scenery piece as placed (spec 2026-11-04-valley-scenery-design): anchored and out of the camera's and
-- players' way (big pieces get colliders, WildValley COLLIDERS, unless `solid` is false: round 2's backdrop pieces
-- nobody can reach), its `Glow` parts glowing in the spot's colour, no shadow from a small one
local function dressValleyProp(model: Model, spot: any, solid: boolean?)
	local glow = Props.color(ValleyConfig.GLOW[spot.glow or "teal"])
	local _, size = model:GetBoundingBox()
	local small = size.Y < Scenery.SMALL_DECOR_SIZE
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			if small then
				part.CastShadow = false
			end
			if part.Name == "Glow" then
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
			end
		end
	end
	local share = ValleyConfig.COLLIDERS[spot.model]
	if share and solid ~= false then
		uprightColliders(model, spot, share)
	end
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
-- Where the terrain draws its ground over (x, z) (Config/Scenery and Config/WildValley's fills)
local function groundAt(x: number, z: number): number
	return TownTerrain.groundAt(terrainOps, x, z) or 0
end

local function buildBridge(folder: Instance)
	local bridge = ValleyConfig.BRIDGE
	if not bridge then
		return -- the Frontier has no stream to cross
	end
	local wood, dark = Props.color(bridge.wood), Props.color(bridge.dark)
	local base = groundAt(bridge.x, bridge.z - bridge.length / 2) -- the bank it starts from
	local steps = 8
	for index = 0, steps - 1 do
		local t0, t1 = index / steps, (index + 1) / steps
		local z0 = bridge.z - bridge.length / 2 + t0 * bridge.length
		local z1 = bridge.z - bridge.length / 2 + t1 * bridge.length
		local y0 = base + math.sin(t0 * math.pi) * bridge.rise
		local y1 = base + math.sin(t1 * math.pi) * bridge.rise
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
-- and not solid, so monsters and players pass over them. The Wild's sit east and west of the trail's line; a valley
-- whose MARKER says `across` puts them square to the trail (the Frontier's runs east-west too)
local function buildTrailMarkers(folder: Instance)
	local look, bridge = ValleyConfig.MARKER, ValleyConfig.BRIDGE
	local color = Props.color(look.color)
	local points = WildValley.markers(WildValley.trail(ValleyConfig), ValleyConfig.MARKER_SPACING)
	for index, point in points do
		if not bridge or math.abs(point.z - bridge.z) > bridge.length / 2 + 1 then
			local side = if index % 2 == 0 then 1 else -1
			local offset = ValleyConfig.TRAIL_WIDTH / 2 - 0.6
			local x, z = point.x + side * offset, point.z
			local nextPoint, lastPoint = points[index + 1] or point, points[index - 1] or point
			local dx, dz = nextPoint.x - lastPoint.x, nextPoint.z - lastPoint.z
			local length = math.sqrt(dx * dx + dz * dz)
			if look.across and length > 0 then
				x, z = point.x - dz / length * side * offset, point.z + dx / length * side * offset
			end
			local stone = piece(folder, "TrailMarker", Vector3.new(0.35, look.size, look.size), CFrame.new(x, groundAt(x, z) + 0.12, z) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon, Enum.PartType.Cylinder)
			stone.CanCollide = false
			stone.CanQuery = false
			stone.CanTouch = false
			stone.CastShadow = false
		end
	end
end

-- A cluster of glowing crystals: a tall one and two smaller leaning out of its foot (the gorge's blue CRYSTAL_LOOK
-- unless another look is given, e.g. the ridge's EMBER_CRYSTAL_LOOK)
-- The Y turn that puts a CornerWedgePart's high corner (its +X, -Z top corner) toward (-qx, -qz): four of them, one in
-- each quarter round an axis, make a pyramid
local function cornerTurn(qx: number, qz: number): number
	for quarter = 0, 3 do
		local turned = CFrame.Angles(0, math.rad(90 * quarter), 0) * Vector3.new(1, 0, -1)
		if math.abs(turned.X + qx) < 0.01 and math.abs(turned.Z + qz) < 0.01 then
			return math.rad(90 * quarter)
		end
	end
	return 0
end

-- A pointed crystal cluster (the Frontier's CRYSTAL_LOOK.pointed; the owner 2026-11-10: "add oversized crystals, these
-- crystals are too small"): each crystal of WildValley.crystalShards a glassy diamond prism with a pyramid tip and a
-- glowing core, the cluster's foot sunk a little; the main crystal stops players, and a big cluster lights the ground
local function buildPointedCrystals(folder: Instance, spot: any, look: any)
	local shell, glow = Props.color(look.color), Props.color(look.tip)
	local shards = WildValley.crystalShards(spot, look.point)
	local base = CFrame.new(spot.x, groundAt(spot.x, spot.z) - shards[1].width * 0.3, spot.z) * CFrame.Angles(0, math.rad(spot.yaw), 0)
	for index, shard in shards do
		local axis = base * CFrame.Angles(0, math.rad(shard.turn), 0) * CFrame.new(0, 0, -shard.out) * CFrame.Angles(math.rad(-shard.tilt), 0, 0) * CFrame.Angles(0, math.rad(45), 0)
		local w, h, tip = shard.width, shard.height, shard.width * look.point
		local parts: { BasePart } = { piece(folder, "RiftCrystal", Vector3.new(w, h, w), axis * CFrame.new(0, h / 2, 0), shell, Enum.Material.Glass) }
		for _, quarter in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			local wedge = Instance.new("CornerWedgePart")
			wedge.Name = "RiftCrystalTip"
			wedge.Anchored = true
			wedge.Size = Vector3.new(w / 2, tip, w / 2)
			wedge.CFrame = axis * CFrame.new(quarter[1] * w / 4, h + tip / 2, quarter[2] * w / 4) * CFrame.Angles(0, cornerTurn(quarter[1], quarter[2]), 0)
			wedge.Color = shell
			wedge.Material = Enum.Material.Glass
			wedge.Parent = folder
			table.insert(parts, wedge)
		end
		local core = piece(folder, "RiftCrystalCore", Vector3.new(w * 0.45, h * 0.92, w * 0.45), axis * CFrame.new(0, h * 0.48, 0), glow, Enum.Material.Neon)
		core.Transparency = look.core
		table.insert(parts, core)
		for _, part in parts do
			if part ~= core then
				part.Transparency = look.transparency
			end
			local solid = index == 1 and part == parts[1]
			part.CanCollide = solid
			part.CanQuery = solid
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	if spot.height >= look.lightFrom then
		local light = Instance.new("PointLight")
		light.Color = shell
		light.Brightness = look.light
		light.Range = math.min(spot.height * 0.9, 60)
		light.Shadows = false
		light.Parent = anchorPart(folder, "RiftCrystalLight", base.Position + Vector3.new(0, spot.height * 0.3, 0))
	end
end

local function buildCrystalCluster(folder: Instance, spot: any, given: any?)
	local look = given or ValleyConfig.CRYSTAL_LOOK
	if look.pointed then
		buildPointedCrystals(folder, spot, look)
		return
	end
	local color, tip = Props.color(look.color), Props.color(look.tip)
	local base = CFrame.new(spot.x, groundAt(spot.x, spot.z), spot.z) * CFrame.Angles(0, math.rad(spot.yaw), 0)
	for index, shape in { { 1, 0, 0, 0 }, { 0.6, 0.9, 25, 40 }, { 0.5, -0.8, -20, 200 } } do
		local height = spot.height * shape[1]
		local lean = CFrame.Angles(math.rad(shape[3]), math.rad(shape[4]), 0)
		local crystal = piece(folder, "GorgeCrystal", Vector3.new(height * 0.4, height, height * 0.4), base * CFrame.new(shape[2], 0, 0) * lean * CFrame.new(0, height * 0.42, 0) * CFrame.Angles(0, math.rad(45), 0), if index == 1 then color else tip, Enum.Material.Neon)
		crystal.Transparency = look.transparency
		local solid = look.solid ~= false -- a look that isn't solid neither blocks players nor catches the camera
		crystal.CanCollide = solid and index == 1
		crystal.CanQuery = solid
		crystal.CanTouch = solid
		crystal.CastShadow = false
	end
end

-- The crystal cave's mouth (WildValley.CAVE): the opening is carved into the rock (an Air op); a dark wall closes its
-- back, set on the carved face a ray finds (so it runs once the terrain is filled), and a cold blue light glows inside
local function buildCave(folder: Instance)
	local cave = ValleyConfig.CAVE
	local hit = snap(Vector3.new(cave.x, cave.y + cave.height / 2, cave.z), Vector3.new(-40, 0, 0))
	if not hit then
		return
	end
	local face = hit.Position.X + 0.4
	local back = piece(folder, "CaveDark", Vector3.new(0.4, cave.height, cave.width), CFrame.new(face, cave.y + cave.height / 2, cave.z), Props.color(cave.inside), Enum.Material.SmoothPlastic)
	back.CastShadow = false
	back.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Props.color(cave.light)
	light.Brightness = 1.6
	light.Range = 18
	light.Shadows = false
	light.Parent = anchorPart(folder, "CaveGlow", Vector3.new(face + 5, cave.y + 4, cave.z))
end

-- A smoking vent on the ridge: a low basalt cone, a glowing core (its smoke is an area effect, Scenery.EMITTERS)
local function buildVent(folder: Instance, spot: any)
	local look = ValleyConfig.VENT_LOOK
	local rock, glow = Props.color(look.rock), Props.color(look.glow)
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local ground = groundAt(spot.x, spot.z)
	piece(folder, "VentBase", Vector3.new(spot.height * 0.6, look.radius * 2.4, look.radius * 2.4), CFrame.new(spot.x, ground + spot.height * 0.3, spot.z) * upright, rock, Enum.Material.Basalt, Enum.PartType.Cylinder)
	piece(folder, "VentRim", Vector3.new(spot.height * 0.5, look.radius * 1.5, look.radius * 1.5), CFrame.new(spot.x, ground + spot.height * 0.75, spot.z) * upright, rock, Enum.Material.Basalt, Enum.PartType.Cylinder)
	local core = piece(folder, "VentCore", Vector3.new(0.2, look.radius, look.radius), CFrame.new(spot.x, ground + spot.height + 0.02, spot.z) * upright, glow, Enum.Material.Neon, Enum.PartType.Cylinder)
	core.CanCollide = false
	core.CastShadow = false
end

-- The ridge's glowing floor cracks (Util/LavaCracks.floor, clear of the trail), snapped onto the terrain once it's filled
local function buildRidgeCracks(folder: Instance)
	local ridge = ValleyConfig.RIDGE_CRACKS
	local holder = Instance.new("Folder")
	holder.Name = "RidgeCracks"
	holder.Parent = folder
	local random = Random.new(ridge.SEED)
	local trail = WildValley.trail(ValleyConfig)
	local color = Props.color(Scenery.CRACKS.COLOR)
	local floor = LavaCracks.floor(ridge.FLOOR, Scenery.CRACKS.WIDTH, trail, trail[1], ValleyConfig.TRAIL_WIDTH / 2 + 2, 0, function(): number
		return random:NextNumber()
	end)
	for _, segment in floor do
		local a = snap(Vector3.new(segment.a.x, groundAt(segment.a.x, segment.a.z) + 20, segment.a.z), Vector3.new(0, -40, 0))
		local b = snap(Vector3.new(segment.b.x, groundAt(segment.b.x, segment.b.z) + 20, segment.b.z), Vector3.new(0, -40, 0))
		if a and b then
			strip(holder, a, b, segment.width, color)
		end
	end
end

-- Rain landing on still water: rings spreading on a flat box `width` across over `at`, `rate` a second
local function rainRings(folder: Instance, at: Vector3, width: number, depth: number, rate: number)
	local holder = anchorPart(folder, "RainRings", at, Vector3.new(width, 0.1, depth))
	local rings = Instance.new("ParticleEmitter")
	rings.Texture = AttackFx.TEXTURES.ring
	rings.Shape = Enum.ParticleEmitterShape.Box
	rings.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	rings.Orientation = Enum.ParticleOrientation.VelocityPerpendicular -- flat on the water
	rings.EmissionDirection = Enum.NormalId.Top
	rings.Speed = NumberRange.new(0.01)
	rings.Lifetime = NumberRange.new(0.6, 0.9)
	rings.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1.4) })
	rings.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	rings.Color = ColorSequence.new(Color3.fromRGB(200, 215, 230))
	rings.LightEmission = 0.2
	rings.Rate = rate
	rings.Parent = holder
end

-- Still water lying on the drawn ground: a thin glassy disc `width` by `depth`, turned `yaw` degrees
local function stillWater(folder: Instance, name: string, x: number, z: number, width: number, depth: number, yaw: number, look: any): BasePart
	local water = piece(folder, name, Vector3.new(0.1, width, depth), CFrame.new(x, groundAt(x, z) + 0.15, z) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(0, 0, math.rad(90)), Props.color(look.water), Enum.Material.Glass, Enum.PartType.Cylinder)
	water.Transparency = look.transparency
	water.Reflectance = look.reflectance
	water.CanCollide = false
	water.CanQuery = false
	water.CanTouch = false
	water.CastShadow = false
	return water
end

-- A swamp (Config/FrontierValley SWAMPS, SWAMP_LOOK): its mud is in the terrain (WildValley.swampOps); here its dark
-- pool with rain rings and clumps of reeds round the pool's edge (its bones and dead trees are in the scenery lists)
local function buildSwamp(folder: Instance, swamp: any, look: any)
	local radius = swamp.radius * look.pool
	local pool = stillWater(folder, "SwampPool", swamp.x, swamp.z, radius * 2, radius * 1.7, swamp.yaw or 0, look)
	rainRings(folder, pool.Position + Vector3.new(0, 0.1, 0), radius * 1.3, radius * 1.1, look.rings)
	local random = Random.new(swamp.seed)
	local reed = Props.color(look.reed)
	for _ = 1, look.reeds do
		local angle = random:NextNumber(0, math.pi * 2)
		local out = radius * random:NextNumber(0.8, 1.15)
		local cx, cz = swamp.x + math.cos(angle) * out, swamp.z + math.sin(angle) * out * 0.85
		for _ = 1, 3 do
			local x, z = cx + random:NextNumber(-0.8, 0.8), cz + random:NextNumber(-0.8, 0.8)
			local height = random:NextNumber(look.reedHeight[1], look.reedHeight[2])
			local lean = CFrame.Angles(math.rad(random:NextNumber(-12, 12)), 0, math.rad(random:NextNumber(-12, 12)))
			local stalk = piece(folder, "Reed", Vector3.new(height, 0.22, 0.22), CFrame.new(x, groundAt(x, z) - 0.3, z) * lean * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), reed, Enum.Material.Grass, Enum.PartType.Cylinder)
			stalk.CanCollide = false
			stalk.CanQuery = false
			stalk.CanTouch = false
			stalk.CastShadow = false
		end
	end
end

-- A puddle (Config/FrontierValley PUDDLES, PUDDLE_LOOK): a little oval of still water with rain rings on it
local function buildPuddle(folder: Instance, puddle: any, look: any)
	local yaw = (puddle.x * 7 + puddle.z * 13) % 180 -- a fixed turn of its own
	local water = stillWater(folder, "Puddle", puddle.x, puddle.z, puddle.radius * 2, puddle.radius * 1.4, yaw, look)
	rainRings(folder, water.Position + Vector3.new(0, 0.1, 0), puddle.radius * 1.2, puddle.radius * 0.8, look.rings * puddle.radius)
end

-- The Wild valley's dressing (Config/WildValley), each piece on the drawn ground: props, the bridge, the trail's markers,
-- the gorge's crystals, the ridge's charred trees, obsidian shards (with the caldera's colliders) and vents, and the
-- volcano past the ridge (the cave and the ridge's cracks wait for the terrain: Start)
local function buildWildValley(folder: Folder)
	local holder = Instance.new("Folder")
	holder.Name = "WildValley"
	holder.Parent = folder
	for _, spot in ValleyConfig.PROPS do
		placeModel(holder, spot, spot.model)
	end
	buildBridge(holder)
	buildTrailMarkers(holder)
	for _, spot in ValleyConfig.CRYSTALS or {} do
		buildCrystalCluster(holder, spot)
	end
	for _, list in { ValleyConfig.CHARRED or {}, ValleyConfig.SHARDS or {} } do
		for _, spot in list do
			local model = placeModel(holder, spot, spot.model)
			if model then
				dressCalderaProp(model)
				calderaCollider(model, spot)
			end
		end
	end
	for _, spot in ValleyConfig.VENTS or {} do
		buildVent(holder, spot)
	end
	-- The scenery round (spec 2026-11-04-valley-scenery-design): the new pieces, the Meadow's stone circle and mushroom
	-- rings, each dressed (freshly imported models arrive unanchored and colliding); the ridge's crystals code-built
	local circle = ValleyConfig.STONE_CIRCLE
	local pieces = if circle then WildValley.ring(circle, circle.radius, circle.count, circle) else {}
	for _, ring in ValleyConfig.MUSHROOM_RINGS or {} do
		for _, spot in WildValley.ring(ring, ring.radius, ring.count, ring) do
			table.insert(pieces, spot)
		end
	end
	for _, name in ValleyConfig.DRESSED_LISTS do
		for _, spot in ValleyConfig[name] do
			table.insert(pieces, spot)
		end
	end
	for _, spot in WildValley.passProps(ValleyConfig) do -- trees and rocks on the passes' banks
		table.insert(pieces, spot)
	end
	for _, spot in pieces do
		local model = placeModel(holder, spot, spot.model)
		if model then
			dressValleyProp(model, spot)
			table.insert(settling, model)
		end
	end
	-- The Frontier's landmarks (Config/FrontierValley LANDMARKS: the ribcage over the trail, the Dungeon gate's arch,
	-- the camp, the floating rocks): dressed the same way; a piece hung at its own `y` is never settled onto the ground
	for _, spot in ValleyConfig.LANDMARKS or {} do
		local model = placeModel(holder, spot, spot.model)
		if model then
			dressValleyProp(model, spot)
			if not spot.y then
				table.insert(settling, model)
			else
				model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- a hung piece the client bobs arrives whole
			end
		end
	end
	-- Stormpeak's storm crystals, swamps and puddles (the owner 2026-11-10: "add some storm related elements in various
	-- sizes... some puddles, some ponds with bones or something a swamp")
	for _, spot in ValleyConfig.STORM_CRYSTALS or {} do
		buildCrystalCluster(holder, spot, ValleyConfig.STORM_CRYSTAL_LOOK)
	end
	for _, swamp in ValleyConfig.SWAMPS or {} do
		buildSwamp(holder, swamp, ValleyConfig.SWAMP_LOOK)
	end
	for _, puddle in ValleyConfig.PUDDLES or {} do
		buildPuddle(holder, puddle, ValleyConfig.PUDDLE_LOOK)
	end
	for _, spot in ValleyConfig.EMBER_CRYSTALS or {} do
		buildCrystalCluster(holder, spot, ValleyConfig.EMBER_CRYSTAL_LOOK)
	end
	local volcano = if ValleyConfig.VOLCANO then placeModel(holder, ValleyConfig.VOLCANO, "Volcano") else nil
	if volcano then
		dressCalderaProp(volcano)
	end
end

-- The valley volcano's lava streams (Config/WildValley VOLCANO_LAVA, WildValley.lavaRays): each stream's rays cast onto
-- the volcano's surface and the hits joined by glowing strips. Runs once the Scenery folder is in the world (rays need
-- it there); the volcano's parts take rays only for the moment (dressCalderaProp turned them off)
local function buildVolcanoLava(scenery: Instance)
	local holder = scenery:FindFirstChild("WildValley")
	local volcano = holder and holder:FindFirstChild("Volcano")
	if not volcano then
		return
	end
	local parts = {}
	for _, part in volcano:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = true
			table.insert(parts, part)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { volcano }
	local lava = ValleyConfig.VOLCANO_LAVA
	local color = Props.color(Scenery.LAVA.COLOR)
	local streams = Instance.new("Folder")
	streams.Name = "VolcanoLava"
	streams.Parent = holder
	for _, stream in lava.streams do
		local last: RaycastResult? = nil
		for _, ray in WildValley.lavaRays(ValleyConfig.VOLCANO, stream, lava.steps, lava.reach) do
			local hit = workspace:Raycast(Vector3.new(ray.origin.x, ray.origin.y, ray.origin.z), Vector3.new(ray.direction.x, ray.direction.y, ray.direction.z), params)
			if hit and last then
				strip(streams, last, hit, lava.width, color)
			end
			last = hit
		end
	end
	for _, part in parts do
		part.CanQuery = false
	end
end

-- Drops a placed piece onto the terrain under its foot (Config/WildValley SETTLE, WildValley.settleDrop; the owner
-- 2026-11-05: roots in the air over a rounded wall top): rays up from under its box find its lowest surfaces on a grid
-- turned with it, rays down find the terrain under each, and it drops by the widest gap. Its parts take rays only for
-- the moment (dressValleyProp turned them off); its colliders move with it.
local function settle(model: Model)
	local look = ValleyConfig.SETTLE
	local box, size = model:GetBoundingBox()
	local queried = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			queried[part] = part.CanQuery
			part.CanQuery = part.Name ~= "Collider"
		end
	end
	local own = RaycastParams.new()
	own.FilterType = Enum.RaycastFilterType.Include
	own.FilterDescendantsInstances = { model }
	local reach = size.Y * look.band + 1
	local gaps = {}
	for i = 0, look.grid - 1 do
		for j = 0, look.grid - 1 do
			local column = box:PointToWorldSpace(Vector3.new(size.X * ((i + 0.5) / look.grid - 0.5), -size.Y / 2, size.Z * ((j + 0.5) / look.grid - 0.5)))
			local surface = workspace:Raycast(column - Vector3.new(0, 1, 0), Vector3.new(0, reach, 0), own)
			local ground = surface and snap(column + Vector3.new(0, size.Y, 0), Vector3.new(0, -2 * size.Y, 0))
			if surface and ground then
				table.insert(gaps, surface.Position.Y - ground.Position.Y)
			end
		end
	end
	for part, was in queried do
		part.CanQuery = was
	end
	local drop = WildValley.settleDrop(gaps, size.Y, look)
	if drop > 0 then
		model:PivotTo(model:GetPivot() - Vector3.new(0, drop, 0))
	end
end

-- Settles every valley and backdrop piece once the terrain is filled and the dressing is in the world (Start)
local function settlePieces()
	for index, model in settling do
		settle(model)
		if index % ValleyConfig.SETTLE.perYield == 0 then
			task.wait()
		end
	end
	table.clear(settling)
end

-- What stands past the valley's walls (round 2, Config/WildValley BACKDROP and MOUNTAINS): backdrop pieces on the
-- drawn ground, streamed as whole models; the far mountains at their own heights, no shadows, always loaded so they
-- never pop in as you walk
local function buildBackdrop(folder: Instance)
	local holder = Instance.new("Folder")
	holder.Name = "WildBackdrop"
	holder.Parent = folder
	for _, spot in ValleyConfig.BACKDROP do
		local model = placeModel(holder, spot, spot.model)
		if model then
			dressValleyProp(model, spot, false)
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			table.insert(settling, model)
		end
	end
	for _, spot in ValleyConfig.MOUNTAINS do
		local model = placeModel(holder, spot, spot.model)
		if model then
			dressValleyProp(model, spot, false)
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.CastShadow = false
				end
			end
			model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end
	end
end

-- Roblox's clouds over the whole place (Config/Scenery CLOUDS; round 2)
local function buildClouds()
	local look = Scenery.CLOUDS
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = look.cover
	clouds.Density = look.density
	clouds.Color = Props.color(look.color)
	clouds.Parent = workspace.Terrain
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
	groundmist = function(emitter) -- soft pale-blue puffs drifting low over the Caves' floor
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(170, 200, 235))
		emitter.LightEmission = 0.2
		emitter.Lifetime = NumberRange.new(6, 9)
		emitter.Speed = NumberRange.new(0.2, 0.6)
		emitter.SpreadAngle = Vector2.new(80, 80)
		emitter.RotSpeed = NumberRange.new(-8, 8)
		emitter.Size = NumberSequence.new(4, 7)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.85),
			NumberSequenceKeypoint.new(1, 1),
		})
	end,
	ash = function(emitter) -- grey flakes drifting down over the Ember Colossus's lava field
		emitter.Color = ColorSequence.new(Color3.fromRGB(120, 112, 108), Color3.fromRGB(70, 66, 64))
		emitter.LightEmission = 0
		emitter.Lifetime = NumberRange.new(9, 14)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.Acceleration = Vector3.new(0.6, -1.6, 0.3)
		emitter.Size = NumberSequence.new(0.3)
		emitter.EmissionDirection = Enum.NormalId.Bottom
	end,
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

-- A box of particles over an area (Scenery's effect kinds: EFFECT_LOOKS), `size` wide
local function areaEffect(folder: Instance, kind: string, rate: number, at: Vector3, size: Vector3)
	local box = anchorPart(folder, "AreaEffect", at, size)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = rate
	emitter.LightEmission = 1
	local look = EFFECT_LOOKS[kind]
	if look then
		look(emitter)
	end
	emitter.Parent = box
end

-- The aurora (Config/Scenery AURORA): the store pack's beams between two upside-down attachments, `strength` times as
-- solid as the pack's own, shown day and night. A persistent model, so it never streams out of the sky.
local function buildAurora()
	local aurora = Scenery.AURORA
	local model = Instance.new("Model")
	model.Name = "Aurora"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local anchor = anchorPart(model, "AuroraAnchor", Vector3.new(aurora.at.x, aurora.at.y, aurora.at.z), Vector3.new(2, 2, 2))
	anchor.CFrame = CFrame.new(anchor.Position) * CFrame.Angles(0, math.rad(aurora.yaw), 0)
	local function hook(name: string, along: number, roll: number): Attachment
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.CFrame = CFrame.new(0, aurora.lift, along) * CFrame.Angles(0, 0, math.rad(roll))
		attachment.Parent = anchor
		return attachment
	end
	local first = hook("One", aurora.span, -180)
	local second = hook("Two", -aurora.span, 180)
	for index, spec in aurora.BEAMS do
		local colors = {}
		for _, key in spec.colors do
			table.insert(colors, ColorSequenceKeypoint.new(key[1], Props.color(key[2])))
		end
		local fade = {}
		for _, key in spec.transparency do
			table.insert(fade, NumberSequenceKeypoint.new(key[1], 1 - math.clamp((1 - key[2]) * aurora.strength, 0, 1)))
		end
		local beam = Instance.new("Beam")
		beam.Name = `AuroraBeam{index}`
		beam.Attachment0 = first
		beam.Attachment1 = second
		beam.FaceCamera = false
		beam.Width0 = spec.width
		beam.Width1 = spec.width
		beam.CurveSize0 = aurora.curve[1]
		beam.CurveSize1 = aurora.curve[2]
		beam.Segments = aurora.segments
		beam.Texture = spec.texture
		beam.TextureMode = Enum.TextureMode.Static
		beam.TextureLength = spec.length
		beam.TextureSpeed = spec.speed
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(colors)
		beam.Transparency = NumberSequence.new(fade)
		beam.Parent = anchor
	end
	model.Parent = workspace
end

local function buildEffects(folder: Folder)
	for _, spec in Scenery.EMITTERS do
		if spec.kind == "aurora" then
			buildAurora()
		elseif spec.kind == "plume" then
			buildPlume(folder, volcanoSmoke or Vector3.new(spec.x, spec.y, spec.z))
		else
			areaEffect(folder, spec.kind, spec.rate, Vector3.new(spec.x, spec.y, spec.z), Vector3.new(spec.size.x, 1, spec.size.z))
		end
	end
end

-- Each Wild boss arena copy's area effects and crystals (Config/WildValley ARENA_DRESSING; WildService builds the rest of
-- the copy, spec 2026-11-01-wild-bosses-arenas-design)
local function buildArenaEffects(folder: Folder)
	for _, boss in Bosses.BOSSES do
		local dressing = if boss.place == (if Place.isFrontier() then "Frontier" else "Wild") then ValleyConfig.ARENA_DRESSING[boss.zone] else nil
		if dressing then
			for copy = 1, Bosses.ARENA_COPIES do
				local centre = WildValley.arenaCopyCenter(ValleyConfig, boss.zone, copy)
				local y = ValleyConfig.ARENA_FIELD.y
				for _, effect in dressing.effects do
					areaEffect(folder, effect.kind, effect.rate, Vector3.new(centre.x, y + effect.y, centre.z), Vector3.new(effect.size, 1, effect.size))
				end
				local crystals = dressing.crystals
				if crystals then
					local random = Random.new(copy * 17 + boss.zone)
					local rng = function(): number
						return random:NextNumber()
					end
					for _, spot in WildValley.arenaSpots(ValleyConfig, boss.ringRadius or Bosses.RING_RADIUS, crystals.count, crystals.radius, rng) do
						buildCrystalCluster(folder, {
							x = centre.x + spot.x,
							z = centre.z + spot.z,
							height = crystals.height[1] + (crystals.height[2] - crystals.height[1]) * rng(),
							yaw = spot.yaw,
						})
					end
				end
			end
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
	buildBackdrop(folder)
	buildEffects(folder)
	buildArenaEffects(folder)
	buildSounds(folder)
	PlazaBuild.build(folder)
	folder.Parent = workspace
	quietSmallShadows()
end

-- The Frontier place: its valley alone (Config/FrontierValley via Util/Place.getValley; no town): the terrain in its own
-- colours, then the flag WildService waits for, and its dressing, backdrop and arena effects
function SceneryService.StartValley()
	if not Place.isFrontier() then
		return
	end
	terrainOps = WildValley.terrainOps(ValleyConfig, TownTerrain.trailSegment)
	-- the lighting effects the Frontier's sky looks drive (Config/DayCycle FRONTIER, Util/SkyLook), made here as
	-- TownService makes the main game's, so the place file needn't have them (final review)
	for className, name in { Atmosphere = "FrontierAtmosphere", BloomEffect = "FrontierBloom", ColorCorrectionEffect = "FrontierColor", SunRaysEffect = "FrontierSunRays" } do
		if not Lighting:FindFirstChildOfClass(className) then
			local created = Instance.new(className)
			created.Name = name
			created.Parent = Lighting
		end
	end
	local look = ValleyConfig.CLOUDS -- heavy grey clouds over the whole place
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = look.cover
	clouds.Density = look.density
	clouds.Color = Props.color(look.color)
	clouds.Parent = workspace.Terrain
	task.spawn(function()
		local terrain = workspace.Terrain
		for name, rgb in ValleyConfig.MATERIAL_COLORS do
			terrain:SetMaterialColor(material(name), Props.color(rgb))
		end
		for index, op in terrainOps do
			fill(terrain, op)
			if index % OPS_PER_YIELD == 0 then
				task.wait()
			end
		end
		workspace:SetAttribute(ValleyConfig.TERRAIN_READY_ATTRIBUTE, true)
		workspace:WaitForChild("Scenery")
		settlePieces()
	end)
	task.spawn(function()
		local folder = Instance.new("Folder")
		folder.Name = "Scenery"
		buildWildValley(folder)
		buildBackdrop(folder)
		buildArenaEffects(folder)
		folder.Parent = workspace
	end)
end

function SceneryService.Start()
	if Place.isFrontier() or Place.isDungeon() then
		return
	end
	terrainOps = TownTerrain.ops(Scenery, Town, TownLayout.plotRects(TownService.GetWorld()))
	-- The Wild valley (Config/WildValley), far up the map in this same place: its terrain fills with the town's
	for _, op in WildValley.terrainOps(ValleyConfig, TownTerrain.trailSegment) do
		table.insert(terrainOps, op)
	end
	buildClouds()
	-- Neither holds up the server's start (the players' data loads after the services start). The caldera's cracks
	-- snap onto the terrain by raycast, so they wait for it to be filled.
	task.spawn(function()
		buildTerrain()
		-- the Wild valley has ground now: WildService lets players travel there
		workspace:SetAttribute(ValleyConfig.TERRAIN_READY_ATTRIBUTE, true)
		local scenery = workspace:WaitForChild("Scenery")
		settlePieces()
		buildCracks(scenery :: Folder)
		buildRidgeCracks(scenery)
		buildCave(scenery)
		buildVolcanoLava(scenery)
	end)
	task.spawn(buildDressing)
end

return SceneryService
