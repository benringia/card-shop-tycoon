--!strict
-- The server wild map (battles part 1): a placeholder map far from the plots, the plaza portal and the
-- healing spring, and the wild monsters. The server only moves an invisible marker per monster in
-- workspace.Monsters; clients draw them (MonsterController). Monsters sleep with no player near, wander near
-- their spawn, and elites (and every monster in an aggro zone) chase players and report contact, which
-- BattleService turns into a fight. Fights themselves live in BattleService. Boss arenas (Config/Bosses) sit beside
-- their zones; a boss is a monster with a `boss` id that stands still until its fight ends (BossService spawns it).
-- The Dungeon place has no wild map: the cavern (Util/DungeonBuilder) instead, and monsters only while a room is fought.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
-- The server wild map in the main game, the Frontier's map in the Frontier place (same shape)
local Wild = Place.getWorld()
local WildValleyConfig = require(Config:WaitForChild("WildValley"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Bosses = require(Config:WaitForChild("Bosses"))
local Combat = require(Config:WaitForChild("Combat"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local Places = require(Config:WaitForChild("Places"))
local Town = require(Config:WaitForChild("Town"))
local PortalTrails = require(Shared:WaitForChild("Util"):WaitForChild("PortalTrails"))
local Props = require(Shared:WaitForChild("Util"):WaitForChild("Props"))
local WildValley = require(Shared:WaitForChild("Util"):WaitForChild("WildValley"))
local TownTerrain = require(Shared:WaitForChild("Util"):WaitForChild("TownTerrain"))
local WildPopulation = require(Shared:WaitForChild("Util"):WaitForChild("WildPopulation"))
local LavaCracks = require(Shared:WaitForChild("Util"):WaitForChild("LavaCracks"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local PlotService = require(Services:WaitForChild("PlotService"))
local BloomFountain = require(Util:WaitForChild("BloomFountain"))
local PortalBuild = require(Util:WaitForChild("PortalBuild"))
local TrailProps = require(Util:WaitForChild("TrailProps"))
local ScenePieces = require(Util:WaitForChild("ScenePieces"))
local DungeonBuilder = require(Util:WaitForChild("DungeonBuilder"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

export type Monster = {
	id: string,
	species: string,
	level: number,
	elite: boolean,
	element: string,
	zone: number,
	home: Vector3,
	marker: Part,
	fightingPlayer: Player?,
	alive: boolean,
	spawnPoint: BasePart?, -- nil for dev-spawned monsters and bosses (no respawn)
	boss: string?, -- a Config/Bosses id: no wandering or chasing, gone when its fight ends
	wanderTarget: Vector3?,
	waitUntil: number,
	chaseCooldownUntil: number,
}

local WildService = {}

local buildSpring: (folder: Instance) -> ()

local SPAWN_TAG = "WildSpawn"
local TRAVEL_COOLDOWN = 1
local ARRIVAL_LIFT = 3 -- studs above the pad, so characters drop onto it
local PORTAL_COLOR = Color3.fromRGB(120, 90, 255)
local SPRING_COLOR = Color3.fromRGB(80, 190, 255)

local monsters: { [string]: Monster } = {}
local monstersFolder: Folder
local mapFolder: Folder
local inWild: { [Player]: boolean } = {}
local contactCallbacks: { (player: Player, monster: Monster) -> () } = {}
local travelBlockers: { (player: Player) -> string? } = {}
local homeHandler: ((player: Player) -> ())? = nil
local dungeonHandler: ((player: Player) -> ())? = nil -- the Frontier's Dungeon portal (DungeonGateService)
local frontierSpawn: SpawnLocation? = nil -- Frontier and Dungeon: everyone spawns here (not on a template spawn pad)
local dungeonLayout: DungeonBuilder.DungeonLayout? = nil -- the Dungeon place's cavern
local allowTravel = RateLimiter.new(TRAVEL_COOLDOWN)
local rng = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function vec(point: { x: number, y: number, z: number }): Vector3
	return Vector3.new(point.x, point.y, point.z)
end

local ORIGIN = vec(Wild.ORIGIN)

local function zoneCenter(index: number): Vector3
	return ORIGIN + Vector3.new(0, 0, (index - 1) * (Wild.ZONE_SIZE + Wild.ZONE_GAP))
end

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

-- Map building -------------------------------------------------------------------------------------------

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- The healing spring: the Elemental Bloom fountain (Util/BloomFountain), its water glowing and sparkling, its card
-- crystal turning and bobbing, a faint ring on the ground for the healing area (Combat.SPRING_RADIUS) and its name.
-- Effects go on parts named Water and Crystal.
function buildSpring(folder: Instance)
	local spot = vec(Wild.SPRING)
	local model = BloomFountain.build(spot, folder)
	local waters, crystal = {}, model:FindFirstChild("Crystal") :: BasePart?
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "Water" then
			table.insert(waters, part)
		end
	end
	-- The highest water gets the sparkles and the light
	table.sort(waters, function(a, b)
		return a.Position.Y > b.Position.Y
	end)
	local top = waters[1] or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	for _, water in waters do
		-- The water slowly breathes between brighter and softer
		TweenService:Create(water, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = math.min(water.Transparency + 0.25, 0.8) }):Play()
	end
	if top then
		local rising = Instance.new("ParticleEmitter")
		rising.Name = "Sparkles"
		rising.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		rising.Rate = 10
		rising.Lifetime = NumberRange.new(1.6, 2.6)
		rising.Speed = NumberRange.new(1.2, 2.4)
		rising.SpreadAngle = Vector2.new(25, 25)
		rising.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		rising.EmissionDirection = if (top :: BasePart).Size.Y < (top :: BasePart).Size.X then Enum.NormalId.Top else Enum.NormalId.Right -- flat discs emit up; cylinders lie on their side
		rising.Color = ColorSequence.new(SPRING_COLOR, Color3.new(1, 1, 1))
		rising.LightEmission = 1
		rising.Parent = top
		local light = Instance.new("PointLight")
		light.Color = SPRING_COLOR
		light.Range = 24
		light.Brightness = 1.5
		light.Parent = top
	end
	if crystal then
		local home = crystal.CFrame
		-- Turning slowly and bobbing (two loops on a holder value, applied each step)
		local bob = Instance.new("NumberValue")
		bob.Parent = crystal
		TweenService:Create(bob, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Value = 0.5 }):Play()
		local spin = 0
		RunService.Heartbeat:Connect(function(dt)
			spin = (spin + dt * 45) % 360
			-- Turn about the world's up axis, keeping the gem's tilt
			crystal.CFrame = CFrame.new(home.Position + Vector3.new(0, bob.Value, 0)) * CFrame.Angles(0, math.rad(spin), 0) * home.Rotation
		end)
		local glow = Instance.new("PointLight")
		glow.Color = crystal.Color:Lerp(Color3.new(1, 1, 1), 0.3)
		glow.Range = 10
		glow.Brightness = 1.5
		glow.Parent = crystal
		local drift = Instance.new("ParticleEmitter")
		drift.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		drift.Rate = 4
		drift.Lifetime = NumberRange.new(0.8, 1.4)
		drift.Speed = NumberRange.new(0.3, 0.8)
		drift.SpreadAngle = Vector2.new(180, 180)
		drift.Size = NumberSequence.new(0.35, 0)
		drift.Color = ColorSequence.new(crystal.Color:Lerp(Color3.new(1, 1, 1), 0.5))
		drift.LightEmission = 1
		drift.Parent = crystal
	end
	-- The healing area: a faint glowing disc on the ground
	local area = block(folder, "HealingArea", Vector3.new(0.1, Combat.SPRING_RADIUS * 2, Combat.SPRING_RADIUS * 2), CFrame.new(spot + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)), SPRING_COLOR, Enum.Material.Neon)
	area.Shape = Enum.PartType.Cylinder
	area.Transparency = 0.88
	area.CanCollide = false
	area.CanQuery = false
	area.CastShadow = false

	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(200, 40)
	-- Over the gem; a screen-up offset, since the gem itself is tilted and turning
	board.StudsOffset = Vector3.new(0, 2.5, 0)
	board.MaxDistance = Wild.SPRING_LABEL_DISTANCE
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "💧 Healing Spring"
	label.Parent = board
	board.Adornee = crystal
	board.Parent = area
end

local function sign(parent: Instance, text: string, cframe: CFrame)
	local board = block(parent, "Sign", Vector3.new(WildValleyConfig.SIGN_WIDTH, 5, 0.6), cframe, Color3.fromRGB(40, 40, 50))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(560, 200)
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
end

local function portal(parent: Instance, name: string, position: Vector3, facing: Vector3, actionText: string, onTriggered: (Player) -> ()): BasePart
	local ring = block(parent, name, Vector3.new(1, 10, 10), CFrame.lookAt(position + Vector3.new(0, 5, 0), position + Vector3.new(0, 5, 0) + facing) * CFrame.Angles(0, math.rad(90), 0), PORTAL_COLOR, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.CanCollide = false
	ring.Transparency = 0.25
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = ring
	prompt.Triggered:Connect(onTriggered)
	return ring
end

local function decorate(parent: Instance, center: Vector3, seed: number)
	local decor = Random.new(seed)
	local half = Wild.ZONE_SIZE / 2 - 6
	for _ = 1, 10 do
		local x = decor:NextNumber(-half, half)
		local z = decor:NextNumber(-half, half)
		local spot = center + Vector3.new(x, 0, z)
		if decor:NextNumber() < 0.6 then
			-- Cylinders run along X: stand the trunk up
			local trunk = block(parent, "Trunk", Vector3.new(6, 1.4, 1.4), CFrame.new(spot + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(100, 70, 45), Enum.Material.Wood)
			trunk.Shape = Enum.PartType.Cylinder
			local leaves = block(parent, "Leaves", Vector3.new(6, 6, 6), CFrame.new(spot + Vector3.new(0, 7.5, 0)), Color3.fromRGB(60, 140, 60), Enum.Material.Grass)
			leaves.Shape = Enum.PartType.Ball
		else
			local rock = block(parent, "Rock", Vector3.new(decor:NextNumber(2, 4), decor:NextNumber(1.5, 3), decor:NextNumber(2, 4)), CFrame.new(spot + Vector3.new(0, 1, 0)) * CFrame.Angles(0, decor:NextNumber(0, math.pi), 0), Color3.fromRGB(120, 120, 125), Enum.Material.Slate)
			rock.CanCollide = true
		end
	end
end

-- The main game's Wild is the dressed valley (Config/WildValley; its terrain and scenery come from SceneryService): the
-- zone floors, paths and arrival pad stay as invisible floors monsters snap to (groundAt), players walk on the terrain,
-- and walls along its edge keep them in. The Frontier keeps the plain map.
local VALLEY = not Place.isFrontier() and not Place.isDungeon()
local EDGE_HEIGHT = 40
local valleySpots: { [number]: { BasePart } } = {} -- each biome's spawn spots (WildValley.zoneSpots)
local pending: { [number]: number } = {} -- each biome's monsters waiting to respawn
local phantomPlayers = 0 -- Studio only (/crowd): counted in every biome on top of the real players
-- The valley's terrain as SceneryService fills it: where its ground draws, for things placed before it's filled
local valleyOps = if VALLEY then WildValley.terrainOps(WildValleyConfig, TownTerrain.trailSegment) else {}

local function valleyGround(x: number, z: number): number
	return TownTerrain.groundAt(valleyOps, x, z) or 0
end

-- The valley's wooden signs (Server/Util/TrailProps, like the town's), each on the drawn ground facing back down the
-- trail the way players come:
-- "The Wild" by the arrival, each biome's trailhead board (its name and monster levels) and an arrow post at each bend
local function buildValleySigns(folder: Instance)
	local function facingTrail(spot: { x: number, z: number }): CFrame
		local toward = WildValley.backAlongTrail(WildValleyConfig, spot, WildValleyConfig.BOARD_FACE_BACK)
		return CFrame.new(spot.x, valleyGround(spot.x, spot.z), spot.z) * CFrame.Angles(0, math.rad(PortalTrails.armYaw(spot, toward)), 0)
	end
	TrailProps.trailhead(folder, facingTrail(WildValleyConfig.RETURN_SIGN), "THE WILD", nil)
	for index, zone in Wild.ZONES do
		TrailProps.trailhead(folder, facingTrail(WildValleyConfig.BIOMES[index].board), string.upper(zone.name), `Lv {zone.minLevel}-{zone.maxLevel}`)
	end
	local homeColor = Props.color(Town.PORTAL_EFFECTS.Wild.ring)
	for _, post in WildValleyConfig.ARROWS do
		local arms: { TrailProps.Arm } = {}
		for _, arm in post.arms do
			local zone = if arm.zone then Wild.ZONES[arm.zone] else nil
			table.insert(arms, {
				text = if zone then string.upper(zone.name) else arm.text,
				sub = Town.SIGN_SUBTEXT,
				color = if zone then rgb(zone.color) else homeColor,
				yaw = PortalTrails.armYaw(post, arm.toward),
			})
		end
		TrailProps.signpost(folder, CFrame.new(post.x, valleyGround(post.x, post.z), post.z), arms)
	end
end

-- A monster spawn spot (an invisible tagged part)
local function addSpawnPoint(folder: Instance, zoneIndex: number, position: Vector3): BasePart
	local point = block(folder, "WildSpawn", Vector3.new(1, 1, 1), CFrame.new(position), Color3.new(1, 1, 1))
	point.Transparency = 1
	point.CanCollide = false
	point.CanQuery = false
	point.CanTouch = false
	point:SetAttribute("Zone", zoneIndex)
	CollectionService:AddTag(point, SPAWN_TAG)
	return point
end

-- A floor monsters stand on: plain in the Frontier, invisible over the valley's terrain in the main game
local function floorPart(part: BasePart): BasePart
	if VALLEY then
		part.Transparency = 1
		part.CanCollide = false
		part.CastShadow = false
	end
	return part
end

-- Invisible walls along the valley's edge (not hit by the monsters' ground ray)
local function buildEdge(folder: Instance)
	local edge = WildValleyConfig.EDGE
	for index, a in edge do
		local b = edge[index % #edge + 1]
		local from, to = Vector3.new(a.x, EDGE_HEIGHT / 2, a.z), Vector3.new(b.x, EDGE_HEIGHT / 2, b.z)
		local wall = block(folder, "EdgeWall", Vector3.new(2, EDGE_HEIGHT, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), Color3.new(1, 1, 1))
		wall.Transparency = 1
		wall.CanQuery = false
		wall.CanTouch = false
		wall.CastShadow = false
	end
end

local function buildMap(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Wild"

	local entrance = ORIGIN + vec(Wild.ENTRANCE_OFFSET)
	floorPart(block(folder, "Entrance", Vector3.new(30, 2, 24), CFrame.new(entrance - Vector3.new(0, 1, 0)), Color3.fromRGB(150, 140, 120), Enum.Material.Cobblestone))
	local returnSpot = entrance + Vector3.new(0, 0, -9)
	local returnRing = portal(folder, "Return to shop", returnSpot, Vector3.new(0, 0, 1), "Return", function(player)
		WildService.TravelHome(player)
	end)
	if VALLEY then
		-- The valley's way home is the Forest Falls root arch it came through (its prompt stays on the hidden ring)
		returnRing.Transparency = 1
		local arch = Props.place("PortalWild", CFrame.lookAt(returnSpot, returnSpot + Vector3.new(0, 0, 1)), folder)
		if arch.Name == "PortalWild" and Props.hasModel("PortalWild") then
			PortalBuild.dress(arch, Town.PORTAL_LOOKS.Wild)
		end
	end
	if VALLEY then
		buildValleySigns(folder)
	else
		sign(folder, if Place.isFrontier() then "The Frontier" else "The Wild", CFrame.new(entrance + Vector3.new(10, 4, -9)) * CFrame.Angles(0, math.pi, 0))
	end

	for index, zone in Wild.ZONES do
		if VALLEY then
			-- The valley's biomes are terrain (Config/WildValley): no floor parts; enough spawn spots for a crowd, on the
			-- modelled ground (the population check fills them, WildPopulation)
			valleySpots[index] = {}
			for _, spot in WildValley.zoneSpots(WildValleyConfig, index) do
				table.insert(valleySpots[index], addSpawnPoint(folder, index, Vector3.new(spot.x, valleyGround(spot.x, spot.z), spot.z)))
			end
			continue
		end
		local center = zoneCenter(index)
		local floor = floorPart(block(folder, zone.name, Vector3.new(Wild.ZONE_SIZE, 2, Wild.ZONE_SIZE), CFrame.new(center - Vector3.new(0, 1, 0)), rgb(zone.color), Enum.Material.Grass))
		floor:SetAttribute("Zone", index)
		if index > 1 then
			-- Path from the previous zone
			local back = center - Vector3.new(0, 1, Wild.ZONE_SIZE / 2 + Wild.ZONE_GAP / 2)
			floorPart(block(folder, "Path", Vector3.new(14, 2, Wild.ZONE_GAP + 2), CFrame.new(back), Color3.fromRGB(150, 140, 120), Enum.Material.Cobblestone))
		end
		local edge = center - Vector3.new(0, 0, Wild.ZONE_SIZE / 2 - 4)
		-- (the plain map's boards are turned so arriving players see their backs)
		sign(folder, `{zone.name}\nRecommended Lv {zone.recommended}+`, CFrame.new(edge + Vector3.new(12, 4, 0)) * CFrame.Angles(0, math.pi, 0))
		decorate(folder, center, index * 97)
		for _, spot in WildValley.spawnSpots(Wild, index) do
			addSpawnPoint(folder, index, Vector3.new(spot.x, center.Y + 0.5, spot.z))
		end
	end
	if VALLEY then
		buildEdge(folder)
	end
	return folder
end

-- Main game: the wild portal at the end of the street. Frontier: a spawn on the entrance and the Dungeon portal.
local function buildPlaza()
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	if Place.isFrontier() then
		local entrance = ORIGIN + vec(Wild.ENTRANCE_OFFSET)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "FrontierSpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = CFrame.lookAt(entrance + Vector3.new(0, 0.5, 4), entrance + Vector3.new(0, 0.5, 20))
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Duration = 0
		spawn.Parent = folder
		frontierSpawn = spawn
		local dungeonSpot = vec((Wild :: any).DUNGEON_PORTAL)
		portal(folder, "Dungeon", dungeonSpot, Vector3.new(1, 0, 0), "Enter", function(player)
			if dungeonHandler then
				dungeonHandler(player)
			else
				notify(player, "The Dungeon is coming soon!", false)
			end
		end)
		sign(folder, if Places.DUNGEON_PLACE_ID ~= 0 then "The Dungeon" else "The Dungeon · coming soon", CFrame.new(dungeonSpot + Vector3.new(0, Wild.PORTAL_SIGN_HEIGHT, 0)) * CFrame.Angles(0, math.rad(90), 0))
	else
		local portalSpot = vec(Wild.PLAZA_PORTAL)
		-- Its floating name label comes from TownService, like the other plaza portals
		local facing = PortalTrails.areaFacing(Town.PORTAL_AREAS, "Wild")
		portal(folder, "The Wild", portalSpot, Vector3.new(facing.x, 0, facing.z), "Travel", function(player)
			WildService.TravelToWild(player)
		end)
	end

	buildSpring(folder)
	folder.Parent = workspace
end

-- Monsters -----------------------------------------------------------------------------------------------

local function setMarker(monster: Monster)
	local marker = monster.marker
	marker:SetAttribute("MonsterId", monster.id)
	marker:SetAttribute("Species", monster.species)
	marker:SetAttribute("Level", monster.level)
	marker:SetAttribute("Elite", monster.elite)
	marker:SetAttribute("Element", monster.element)
	marker:SetAttribute("Zone", monster.zone)
	marker:SetAttribute("Fighting", monster.fightingPlayer ~= nil)
	marker:SetAttribute("Boss", monster.boss)
end

local function groundAt(position: Vector3): Vector3
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), rayParams)
	return if hit then hit.Position else position
end

local function createMonster(species: string, level: number, elite: boolean, zone: number, home: Vector3, spawnPoint: BasePart?, boss: string?): Monster?
	local info: { element: string }? = if boss then Bosses.BOSSES[boss] else Wild.SPECIES[species]
	if not info then
		return nil
	end
	local marker = Instance.new("Part")
	marker.Size = Vector3.new(1, 1, 1)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	local ground = groundAt(home)
	marker.CFrame = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local monster: Monster = {
		id = HttpService:GenerateGUID(false),
		species = species,
		level = level,
		elite = elite,
		element = info.element,
		zone = zone,
		home = ground,
		marker = marker,
		fightingPlayer = nil,
		alive = true,
		spawnPoint = spawnPoint,
		boss = boss,
		wanderTarget = nil,
		waitUntil = 0,
		chaseCooldownUntil = 0,
	}
	marker.Name = `Monster_{monster.id}`
	setMarker(monster)
	marker.Parent = monstersFolder
	monsters[monster.id] = monster
	return monster
end

local function spawnAt(point: BasePart)
	local zoneIndex = point:GetAttribute("Zone")
	local zone = if typeof(zoneIndex) == "number" then Wild.ZONES[zoneIndex] else nil
	if not zone then
		return
	end
	local species = zone.species[rng:NextInteger(1, #zone.species)]
	local level = rng:NextInteger(zone.minLevel, zone.maxLevel)
	createMonster(species, level, rng:NextNumber() < Wild.ELITE_CHANCE, zoneIndex :: number, point.Position, point)
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- Moves a monster marker toward a point on the ground, facing the way it goes. True when it got there.
local function moveToward(monster: Monster, target: Vector3, speed: number, dt: number): boolean
	local position = monster.marker.Position
	local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
	local distance = flat.Magnitude
	if distance < 0.5 then
		return true
	end
	local stepLength = math.min(distance, speed * dt)
	local nextPosition = groundAt(position + flat.Unit * stepLength)
	if VALLEY and not WildValley.canStep(position.Y, nextPosition.Y, WildValleyConfig.MAX_STEP) then
		monster.wanderTarget = nil -- a cliff, a shelf or the stream: pick somewhere else
		return true
	end
	monster.marker.CFrame = CFrame.lookAt(nextPosition, nextPosition + flat.Unit)
	return stepLength >= distance
end

local isFighting: (player: Player) -> boolean = function()
	return false
end

-- Nearest player in the wild; with skipBusy, ignoring players already in a fight (nobody chases into a ring)
local function nearestPlayer(position: Vector3, skipBusy: boolean?): (Player?, number)
	local best, bestDistance = nil, math.huge
	for player in inWild do
		local root = getRoot(player)
		if root and not (skipBusy and isFighting(player)) then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best, bestDistance
end

local function updateMonster(monster: Monster, dt: number, now: number)
	if not monster.alive or monster.fightingPlayer or monster.boss then
		return
	end
	local player, distance = nearestPlayer(monster.marker.Position)
	if not player or distance > Wild.WAKE_RADIUS then
		return -- asleep: nobody near
	end
	local zone = Wild.ZONES[monster.zone]
	local aggressive = monster.elite or (zone ~= nil and zone.aggro)
	local fromHome = (monster.marker.Position - monster.home).Magnitude
	local prey, preyDistance = nearestPlayer(monster.marker.Position, true)
	if aggressive and prey and now >= monster.chaseCooldownUntil and preyDistance <= Wild.AGGRO_RADIUS and fromHome <= Wild.CHASE_GIVE_UP then
		player, distance = prey, preyDistance
		local root = getRoot(player) :: BasePart
		if distance <= Wild.CONTACT_DISTANCE then
			monster.chaseCooldownUntil = now + Wild.CHASE_REST_SECONDS
			monster.wanderTarget = monster.home
			for _, callback in contactCallbacks do
				task.spawn(callback, player, monster)
			end
		else
			moveToward(monster, root.Position, Wild.CHASE_SPEED, dt)
		end
		return
	end
	if fromHome > Wild.CHASE_GIVE_UP then
		monster.chaseCooldownUntil = now + Wild.CHASE_REST_SECONDS
		monster.wanderTarget = monster.home -- too far from home: walk back
	end
	if now < monster.waitUntil then
		return
	end
	if not monster.wanderTarget then
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(2, Wild.WANDER_RADIUS)
		monster.wanderTarget = monster.home + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	end
	if moveToward(monster, monster.wanderTarget :: Vector3, Wild.WANDER_SPEED, dt) then
		monster.wanderTarget = nil
		monster.waitUntil = now + rng:NextNumber(1, 4)
	end
end

-- The valley's crowd-sized monsters (Util/WildPopulation): each biome wants more monsters the more players are in it;
-- the missing ones come back after a respawn wait on a free spot, and a crowd leaving removes nothing

-- The spots of a biome a living monster holds
local function takenSpots(zone: number): { [number]: boolean }
	local taken = {}
	local spots = valleySpots[zone] or {}
	for _, monster in monsters do
		local at = if monster.alive and monster.zone == zone and monster.spawnPoint then table.find(spots, monster.spawnPoint) else nil
		if at then
			taken[at] = true
		end
	end
	return taken
end

local function spawnOnFreeSpot(zone: number)
	local spots = valleySpots[zone] or {}
	local free = WildPopulation.freeSpots(#spots, takenSpots(zone))
	if #free > 0 then
		spawnAt(spots[free[rng:NextInteger(1, #free)]])
	end
end

local function updatePopulation()
	local cfg = WildValleyConfig.POPULATION
	local players: { [number]: number } = {}
	for player in inWild do
		local root = getRoot(player)
		local zone = if root then WildValley.zoneAt(WildValleyConfig, { x = root.Position.X, z = root.Position.Z }) else nil
		if zone then
			players[zone] = (players[zone] or 0) + 1
		end
	end
	for zone in Wild.ZONES do
		local target = WildPopulation.target(cfg, (players[zone] or 0) + phantomPlayers)
		local alive = 0
		for _ in takenSpots(zone) do
			alive += 1
		end
		local range = WildPopulation.respawnRange(cfg, target)
		for _ = 1, WildPopulation.deficit(target, alive, pending[zone] or 0) do
			pending[zone] = (pending[zone] or 0) + 1
			task.delay(rng:NextNumber(range[1], range[2]), function()
				pending[zone] -= 1
				spawnOnFreeSpot(zone)
			end)
		end
	end
end

-- API ----------------------------------------------------------------------------------------------------

function WildService.GetMonster(id: string): Monster?
	local monster = monsters[id]
	return if monster and monster.alive then monster else nil
end

function WildService.Lock(monster: Monster, player: Player)
	monster.fightingPlayer = player
	setMarker(monster)
end

-- Fight over without a win: it heals (stats come fresh each fight) and walks home
function WildService.Unlock(monster: Monster)
	monster.fightingPlayer = nil
	monster.wanderTarget = monster.home
	monster.chaseCooldownUntil = os.clock() + Wild.CHASE_REST_SECONDS
	setMarker(monster)
end

function WildService.Defeat(monster: Monster)
	if not monster.alive then
		return
	end
	monster.alive = false
	monster.fightingPlayer = nil
	monsters[monster.id] = nil
	monster.marker:Destroy()
	local point = monster.spawnPoint
	if point and not VALLEY then -- the valley's come back through the population check
		task.delay(rng:NextNumber(Wild.RESPAWN_MIN, Wild.RESPAWN_MAX), spawnAt, point)
	end
end

-- Holds a monster at its spot in a fight ring (nil: free again)
function WildService.SetFightPose(monster: Monster, cframe: CFrame?)
	if cframe and monster.alive then
		monster.marker.CFrame = cframe
	end
end

function WildService.OnContact(callback: (player: Player, monster: Monster) -> ())
	table.insert(contactCallbacks, callback)
end

-- BattleService and ArenaService refuse travel mid-fight (they can't be required from here: they require this)
function WildService.AddTravelBlocker(blocker: (player: Player) -> string?)
	table.insert(travelBlockers, blocker)
end

-- A glowing ring with a prompt (FrontierService uses it for the Frontier portal)
function WildService.BuildPortal(parent: Instance, name: string, position: Vector3, facing: Vector3, actionText: string, onTriggered: (Player) -> ())
	portal(parent, name, position, facing, actionText, onTriggered)
end

-- Studio only (/crowd): players counted in every valley biome on top of the real ones, to test a crowd alone
function WildService.SetPhantomPlayers(count: number)
	if RunService:IsStudio() then
		phantomPlayers = math.max(0, math.floor(count))
	end
end

function WildService.IsInWild(player: Player): boolean
	return inWild[player] == true
end

function WildService.GetSpringPosition(): Vector3
	return vec(Wild.SPRING)
end

-- A monster at a spot, never respawned: /elite, and bosses (with their Config/Bosses id and the zone they belong to)
function WildService.SpawnAt(position: Vector3, species: string, level: number, elite: boolean, boss: string?, zoneIndex: number?): Monster?
	local zone = zoneIndex or 1
	local inBiome = if VALLEY and not zoneIndex then WildValley.zoneAt(WildValleyConfig, { x = position.X, z = position.Z }) else nil
	if inBiome then
		zone = inBiome
	elseif not zoneIndex then
		-- the nearest zone's middle (the valley's biomes, or the Frontier's grid)
		local function middle(index: number): Vector3
			local biome = if VALLEY then WildValleyConfig.BIOMES[index] else nil
			return if biome then Vector3.new(biome.centre.x, position.Y, biome.centre.z) else zoneCenter(index)
		end
		for index in Wild.ZONES do
			if (position - middle(index)).Magnitude < (position - middle(zone)).Magnitude then
				zone = index
			end
		end
	end
	return createMonster(species, level, elite, zone, position, nil, boss)
end

-- Where a boss fight happens: its ring's spots, and where players go when they leave it (remote: a copy far from the
-- valley, reached and left by moving the player, streamed in first)
export type ArenaCopy = { spawn: CFrame, barrier: { BasePart }, inside: CFrame, center: Vector3, exit: CFrame, remote: boolean }
export type BossArena = { gate: CFrame, gatePosition: Vector3, groupPrompt: ProximityPrompt, copies: { ArenaCopy } }

-- One fenced ring at `center`: its floor and path (dressed in `look`, lifted `lift` off the ground; nil: the plain slate
-- ring), the ridge look's lava cracks, fence posts open toward -X, and the barrier (down until BossService seals it).
-- Returns where the boss stands, the barrier, where members stand when it seals, and the gate's spot.
local function buildRing(folder: Instance, boss: any, center: Vector3, look: any?, lift: number): (CFrame, { BasePart }, CFrame, Vector3)
	local radius = Bosses.ARENA_RADIUS
	-- Cylinders run along X: lay the disc flat
	local floor = block(folder, boss.name, Vector3.new(2, radius * 2, radius * 2), CFrame.new(center - Vector3.new(0, 1 - lift, 0)) * CFrame.Angles(0, 0, math.rad(90)), if look then rgb(look.floor) else Color3.fromRGB(70, 66, 80), if look then (Enum.Material :: any)[look.floorMaterial] else Enum.Material.Slate)
	floor.Shape = Enum.PartType.Cylinder
	block(folder, "Path", Vector3.new(Bosses.ARENA_GAP + 4, 2, 14), CFrame.new(center - Vector3.new(radius + Bosses.ARENA_GAP / 2, 1 - lift, 0)), if look then rgb(look.path) else Color3.fromRGB(150, 140, 120), if look then (Enum.Material :: any)[look.pathMaterial] else Enum.Material.Cobblestone)
	if look and look.cracks then
		-- glowing cracks across the ridge arena's floor, none in front of the gate
		local cracks = look.cracks
		local random = Random.new(cracks.seed)
		local gate = { { x = center.X - radius, z = center.Z }, { x = center.X - radius + 10, z = center.Z } }
		local box = { centre = { x = center.X, z = center.Z }, size = { x = cracks.size, z = cracks.size }, count = cracks.count }
		local top = center.Y + lift + 0.03
		for _, segment in LavaCracks.floor(box, cracks.width, gate, gate[1], 5, 0, function(): number
			return random:NextNumber()
		end) do
			local a, b = Vector3.new(segment.a.x, top, segment.a.z), Vector3.new(segment.b.x, top, segment.b.z)
			local crack = block(folder, "Crack", Vector3.new(segment.width, 0.05, (b - a).Magnitude + segment.width * 0.5), CFrame.lookAt((a + b) / 2, b), rgb(look.tip), Enum.Material.Neon)
			crack.CanCollide = false
			crack.CanQuery = false
			crack.CastShadow = false
		end
	end
	-- Fence posts all round, open toward the gate (-X)
	for step = 0, 23 do
		local angle = step / 24 * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		if direction.X > -0.95 then
			local postSize, postHeight = if look then look.postSize else 1.2, if look then look.postHeight else 5
			local post = center + direction * (radius - 0.6)
			block(folder, "Fence", Vector3.new(postSize, postHeight, postSize), CFrame.new(post + Vector3.new(0, postHeight / 2, 0)), if look then rgb(look.post) else Color3.fromRGB(90, 70, 50), if look then (Enum.Material :: any)[look.postMaterial] else Enum.Material.Wood)
			if look and look.tip and step % 2 == 0 then
				local tip = block(folder, "FenceTip", Vector3.new(postSize * 0.6, postSize * 1.1, postSize * 0.6), CFrame.new(post + Vector3.new(0, postHeight + postSize * 0.45, 0)) * CFrame.Angles(0, math.rad(45), 0), rgb(look.tip), Enum.Material.Neon)
				tip.CanCollide = false
				tip.CanQuery = false
				tip.CastShadow = false
			end
		end
	end
	-- The barrier: down (invisible, no collision) until BossService seals the ring for a fight
	local barrier: { BasePart } = {}
	for _, angle in BossRules.ringSegments(radius + 0.5, Bosses.BARRIER_SEGMENT) do
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local spot = center + direction * (radius + 0.5) + Vector3.new(0, Bosses.BARRIER_HEIGHT / 2, 0)
		local wall = block(folder, "Barrier", Vector3.new(Bosses.BARRIER_SEGMENT + 0.5, Bosses.BARRIER_HEIGHT, 1), CFrame.lookAt(spot, spot + direction), Color3.fromRGB(170, 120, 255), Enum.Material.ForceField)
		wall.Transparency = 1
		wall.CanCollide = false
		wall.CanQuery = false
		table.insert(barrier, wall)
	end
	local gateSpot = center - Vector3.new(radius - 2, 0, 0)
	local bossSpot = center + Vector3.new(Bosses.BOSS_SPOT, lift, 0) -- on the floor's top (BossService puts the boss here)
	return CFrame.lookAt(bossSpot, gateSpot), barrier, CFrame.lookAt(gateSpot + Vector3.new(Bosses.INSIDE_STEP, 3, 0), bossSpot + Vector3.new(0, 3, 0)), gateSpot
end

-- The Fight and Start group prompts on a gate's part (server prompts: onGate, onGroup; BossService changes the group
-- prompt's text). Returns the group prompt.
local function gatePrompts(part: BasePart, boss: any, bossId: string, onGate: (player: Player, bossId: string) -> (), onGroup: (player: Player, bossId: string) -> ()): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Fight boss"
	prompt.ObjectText = `{boss.name} · Power {boss.recommended}`
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Bosses.GATE_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		onGate(player, bossId)
	end)
	local groupPrompt = Instance.new("ProximityPrompt")
	groupPrompt.Name = "GroupPrompt"
	groupPrompt.ActionText = "Start group"
	groupPrompt.ObjectText = `{boss.name} · 2-{Bosses.GROUP_MAX} players`
	groupPrompt.HoldDuration = 0
	groupPrompt.MaxActivationDistance = Bosses.GATE_PROMPT_DISTANCE
	groupPrompt.RequiresLineOfSight = false
	groupPrompt.KeyboardKeyCode = Enum.KeyCode.F
	groupPrompt.UIOffset = Vector2.new(0, Bosses.GROUP_PROMPT_OFFSET)
	groupPrompt.Parent = part
	CollectionService:AddTag(groupPrompt, "BossGroupPrompt")
	groupPrompt.Triggered:Connect(function(player)
		onGroup(player, bossId)
	end)
	return groupPrompt
end

-- A valley arena copy's surroundings: its zone's props round the clearing, the gate's side (-X) left open for the path
-- and the way home
local function ringProps(folder: Instance, zone: number, center: Vector3, seed: number)
	local clearing = WildValleyConfig.ARENA_CLEARING
	local names = clearing.props[zone]
	local random = Random.new(seed)
	for step = 0, clearing.count - 1 do
		local angle = (step + 0.5) / clearing.count * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		if direction.X > -0.9 then
			local spot = center + direction * clearing.ring
			local model = ScenePieces.placeModel(folder, {
				model = names[random:NextInteger(1, #names)],
				x = spot.X,
				z = spot.Z,
				height = random:NextNumber(clearing.height[1], clearing.height[2]),
				yaw = random:NextNumber(0, 360),
			}, "ArenaProp", center.Y)
			for _, part in if model then model:GetDescendants() else {} do
				if part:IsA("BasePart") then
					part.Anchored = true -- the caldera's Blender props aren't saved anchored
				end
			end
		end
	end
end

-- The valley's boss (round 2 spec): a portal at its biome's `portal` spot (the obsidian arch with the Boss look) with the
-- gate prompts and a trailhead board, and ARENA_COPIES copies of its ring far away (WildValley.arenaCopyCenter), each
-- with a root-arch portal home outside its gate (its Return prompt: onReturn)
local function buildBossPortal(folder: Instance, boss: any, bossId: string, onGate: (player: Player, bossId: string) -> (), onGroup: (player: Player, bossId: string) -> (), onReturn: (player: Player, bossId: string, copy: number) -> ()): BossArena
	local spot = WildValleyConfig.BIOMES[boss.zone].portal
	local ground = valleyGround(spot.x, spot.z)
	local base = Vector3.new(spot.x, ground, spot.z)
	local facing = Vector3.new(spot.faces.x - spot.x, 0, spot.faces.z - spot.z).Unit
	local look = WildValleyConfig.BOSS_PORTAL
	local model = Props.place(look.model, CFrame.lookAt(base, base + facing), folder)
	if model.Name == look.model and Props.hasModel(look.model) then
		model:ScaleTo(model:GetScale() * look.height / Town.SLOTS[look.model].height)
		local box, size = model:GetBoundingBox()
		model:PivotTo(model:GetPivot() + Vector3.new(0, ground - (box.Position.Y - size.Y / 2), 0)) -- back on the ground
		PortalBuild.dress(model, Town.PORTAL_LOOKS.Boss)
	end
	model.Name = `BossPortal {boss.name}`
	-- The gate: an invisible part in the opening carrying the prompts (what the server measures a start from)
	local gatePart = block(folder, "BossGate", Vector3.new(10, 8, 2), CFrame.lookAt(base + Vector3.new(0, 4, 0), base + Vector3.new(0, 4, 0) + facing), PORTAL_COLOR)
	gatePart.Transparency = 1
	gatePart.CanCollide = false
	gatePart.CanQuery = false
	local groupPrompt = gatePrompts(gatePart, boss, bossId, onGate, onGroup)
	local right = facing:Cross(Vector3.yAxis)
	local boardSpot = base + right * (look.height * 0.6)
	local boardAt = Vector3.new(boardSpot.X, valleyGround(boardSpot.X, boardSpot.Z), boardSpot.Z)
	TrailProps.trailhead(folder, CFrame.lookAt(boardAt, boardAt + facing), string.upper(boss.name), `Power {boss.recommended}`)
	local gateSpot = base + facing * 8
	local gate = CFrame.lookAt(Vector3.new(gateSpot.X, valleyGround(gateSpot.X, gateSpot.Z), gateSpot.Z), Vector3.new(base.X, valleyGround(gateSpot.X, gateSpot.Z), base.Z))
	local copies: { ArenaCopy } = {}
	for copy = 1, Bosses.ARENA_COPIES do
		local point = WildValley.arenaCopyCenter(WildValleyConfig, boss.zone, copy)
		local center = Vector3.new(point.x, WildValleyConfig.ARENA_FIELD.y, point.z)
		local holder = Instance.new("Folder")
		holder.Name = `{boss.name} {copy}`
		holder.Parent = folder
		local bossAt, barrier, inside = buildRing(holder, boss, center, WildValleyConfig.ARENA_LOOKS[boss.zone], WildValleyConfig.ARENA_LIFT)
		local homeSpot = center - Vector3.new(Bosses.ARENA_RADIUS + Bosses.ARENA_GAP + 6, 0, 0)
		local ring = portal(holder, "Return to the Wild", homeSpot, Vector3.new(1, 0, 0), "Return", function(player)
			onReturn(player, bossId, copy)
		end)
		ring.Transparency = 1 -- the root arch stands round it (its prompt stays on the ring)
		local arch = Props.place("PortalWild", CFrame.lookAt(homeSpot, homeSpot + Vector3.new(1, 0, 0)), holder)
		if arch.Name == "PortalWild" and Props.hasModel("PortalWild") then
			PortalBuild.dress(arch, Town.PORTAL_LOOKS.Wild)
		end
		ringProps(holder, boss.zone, center, copy * 31 + boss.zone)
		table.insert(copies, { spawn = bossAt, barrier = barrier, inside = inside, center = center, exit = gate, remote = true })
	end
	return { gate = gate, gatePosition = gatePart.Position, groupPrompt = groupPrompt, copies = copies }
end

-- Every boss of this place: the valley's behind portals (buildBossPortal); elsewhere a fenced ring beside its zone (the
-- Dungeon's in its chamber) with a gate and a sign. Returns each boss's gate and arena copies, by boss id.
function WildService.BuildBossArenas(onGate: (player: Player, bossId: string) -> (), onGroup: (player: Player, bossId: string) -> (), onReturn: (player: Player, bossId: string, copy: number) -> ()): { [string]: BossArena }
	local arenas: { [string]: BossArena } = {}
	local folder = Instance.new("Folder")
	folder.Name = "BossArenas"
	folder.Parent = mapFolder -- part of the map, so bosses stand on its floor
	local here = if Place.isDungeon() then "Dungeon" elseif Place.isFrontier() then "Frontier" else "Wild"
	for _, bossId in Bosses.LADDER do
		local boss = Bosses.BOSSES[bossId]
		if boss.place ~= here then
			continue -- its arena is in another place
		end
		if here == "Wild" and VALLEY then
			arenas[bossId] = buildBossPortal(folder, boss, bossId, onGate, onGroup, onReturn)
			continue
		end
		local center = if here == "Dungeon" then vec(Dungeon.CHAMBER)
			else zoneCenter(boss.zone) + Vector3.new(Wild.ZONE_SIZE / 2 + Bosses.ARENA_GAP + Bosses.ARENA_RADIUS, 0, 0)
		local bossAt, barrier, inside, gateSpot = buildRing(folder, boss, center, nil, 0)
		local gatePart = block(folder, "BossGate", Vector3.new(1, 9, 12), CFrame.new(gateSpot + Vector3.new(0, 4.5, 0)), PORTAL_COLOR, Enum.Material.Neon)
		gatePart.CanCollide = false
		gatePart.Transparency = 0.6
		local groupPrompt = gatePrompts(gatePart, boss, bossId, onGate, onGroup)
		-- (these boards face the ring, so players walking up from the zone see their backs)
		sign(folder, `BOSS: {boss.name}\nRecommended Power {boss.recommended}`, CFrame.new(gateSpot + Vector3.new(-1, 11, 0)) * CFrame.Angles(0, -math.rad(90), 0))
		local gate = CFrame.lookAt(gateSpot - Vector3.new(4, 0, 0), center) -- where /boss puts you, outside the gate
		arenas[bossId] = {
			gate = gate,
			gatePosition = gatePart.Position,
			groupPrompt = groupPrompt,
			copies = { { spawn = bossAt, barrier = barrier, inside = inside, center = center, exit = gate, remote = false } },
		}
	end
	return arenas
end

local function canTravel(player: Player): boolean
	if not allowTravel(player) then
		return false
	end
	for _, blocker in travelBlockers do
		local reason = blocker(player)
		if reason then
			notify(player, reason, true)
			return false
		end
	end
	return true
end

-- StreamingEnabled: the client only has parts near it. Loads the area round a spot on their device (waits up to
-- Wild.STREAM_TIMEOUT), or a character moved there lands before the floor exists and falls through the world.
local function prestream(player: Player, position: Vector3)
	local ok, err = pcall(function()
		player:RequestStreamAroundAsync(position, Wild.STREAM_TIMEOUT)
	end)
	if not ok then
		warn(`[WildService] streaming around the destination failed: {err}`)
	end
end

local function moveCharacter(player: Player, cframe: CFrame): boolean
	if not player.Character or not getRoot(player) then
		return false
	end
	prestream(player, cframe.Position)
	local character = player.Character
	if not character or not getRoot(player) then
		return false -- left or died while it loaded
	end
	character:PivotTo(cframe + Vector3.new(0, ARRIVAL_LIFT, 0))
	return true
end

-- Safety net: anyone in the wild who falls well below its floor goes back to the entrance
local function rescueFallen()
	local entrance = ORIGIN + vec(Wild.ENTRANCE_OFFSET)
	local target = if dungeonLayout then dungeonLayout.entrance else CFrame.lookAt(entrance, entrance + Vector3.new(0, 0, 1))
	for player in inWild do
		local root = getRoot(player)
		if root and root.Position.Y < ORIGIN.Y - Wild.FALL_RESCUE_DEPTH and not root.Anchored then
			root.AssemblyLinearVelocity = Vector3.zero
			local character = player.Character :: Model
			character:PivotTo(target + Vector3.new(0, ARRIVAL_LIFT, 0))
		end
	end
end

-- Moves a player somewhere outside the wild (the arena, their shop), streaming the spot in first.
-- Not blocked by fights: the caller decides. False if they have no character.
function WildService.MoveTo(player: Player, cframe: CFrame): boolean
	if not moveCharacter(player, cframe) then
		return false
	end
	if inWild[player] then
		inWild[player] = nil
		Remotes.WildTravel:FireClient(player, "home")
	end
	return true
end

-- Loads a spot round a player before they're moved there (an arena copy, while their fight is set up); yields
function WildService.Prestream(player: Player, position: Vector3)
	prestream(player, position)
end

-- Moves a player somewhere else in the wild (into or out of an arena copy), streaming the spot in first; they stay in
-- the wild. False if they have no character.
function WildService.MoveInWild(player: Player, cframe: CFrame): boolean
	if not moveCharacter(player, cframe) then
		return false
	end
	inWild[player] = true
	return true
end

-- To the entrance, or to `at` in the wild (/boss)
function WildService.TravelToWild(player: Player, at: CFrame?)
	if not canTravel(player) then
		return
	end
	-- The valley's terrain fills in the background at start: wait for its ground (SceneryService sets the attribute)
	local ready = WildValleyConfig.TERRAIN_READY_ATTRIBUTE
	if VALLEY and not workspace:GetAttribute(ready) then
		local deadline = os.clock() + WildValleyConfig.TERRAIN_WAIT
		while not workspace:GetAttribute(ready) and os.clock() < deadline do
			task.wait(0.25)
		end
		if not workspace:GetAttribute(ready) then
			notify(player, "The Wild is still loading. Try again in a moment.", true)
			return
		end
	end
	local entrance = ORIGIN + vec(Wild.ENTRANCE_OFFSET)
	if moveCharacter(player, at or CFrame.lookAt(entrance, entrance + Vector3.new(0, 0, 1))) then
		inWild[player] = true
		Remotes.WildTravel:FireClient(player, "wild")
	end
end

-- Frontier only: what "home" means there (FrontierService teleports back to the main game)
-- BattleService tells monsters who is in a fight (nobody chases into a ring)
function WildService.SetFightCheck(check: (player: Player) -> boolean)
	isFighting = check
end

-- The Frontier: what its Dungeon portal's Enter does (DungeonGateService)
function WildService.SetDungeonHandler(handler: (player: Player) -> ())
	dungeonHandler = handler
end

-- The Dungeon place's cavern (nil elsewhere): its rooms, doors and spawn for DungeonService
function WildService.GetDungeonLayout(): DungeonBuilder.DungeonLayout?
	return dungeonLayout
end

function WildService.SetHomeHandler(handler: (player: Player) -> ())
	homeHandler = handler
end

function WildService.TravelHome(player: Player)
	if not canTravel(player) then
		return
	end
	if Place.isFrontier() or Place.isDungeon() then
		if homeHandler then
			homeHandler(player)
		end
		return
	end
	local plot = PlotService.GetPlot(player)
	local target = if plot then plot.spawn.CFrame else CFrame.new(vec(Wild.SPRING) + Vector3.new(8, 0, 0))
	if moveCharacter(player, target) then
		inWild[player] = nil
		Remotes.WildTravel:FireClient(player, "home")
	end
end

function WildService.Start()
	-- Free models can carry scripts: none may ever run. Clients also strip their own copies.
	local models = ReplicatedStorage:FindFirstChild("MonsterModels")
	if models then
		for _, descendant in models:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
	end

	monstersFolder = Instance.new("Folder")
	monstersFolder.Name = "Monsters"
	monstersFolder.Parent = workspace

	if Place.isDungeon() then
		-- No wild map or spawns: the cavern, and monsters only while a room is fought
		mapFolder = Instance.new("Folder")
		mapFolder.Name = "Dungeon"
		local layout = DungeonBuilder.build(mapFolder)
		mapFolder.Parent = workspace
		dungeonLayout = layout
		frontierSpawn = layout.spawn
	else
		mapFolder = buildMap()
		mapFolder.Parent = workspace
		buildPlaza()
		if VALLEY then
			-- each biome starts quiet; the population check adds more as players come
			for zone in Wild.ZONES do
				for _ = 1, WildValleyConfig.POPULATION.QUIET do
					spawnOnFreeSpot(zone)
				end
			end
			task.spawn(function()
				while true do
					task.wait(WildValleyConfig.POPULATION.CHECK_SECONDS)
					updatePopulation()
				end
			end)
		else
			for _, point in CollectionService:GetTagged(SPAWN_TAG) do
				if point:IsA("BasePart") then
					spawnAt(point)
				end
			end
		end
	end
	-- The valley's monsters stand on its terrain (not on its water); elsewhere on the map's floor parts
	rayParams.FilterDescendantsInstances = if VALLEY then { mapFolder, workspace.Terrain } else { mapFolder }
	rayParams.IgnoreWater = VALLEY

	-- Clients only ask to go home; going to the Wild takes walking to its portal (the prompt)
	Remotes.WildTravel.OnServerEvent:Connect(function(player, where)
		if where == "home" then
			WildService.TravelHome(player)
		end
	end)
	local function watch(player: Player)
		if Place.isFrontier() or Place.isDungeon() then
			-- The whole Frontier (and the Dungeon) is wild: monsters wake for everyone here
			inWild[player] = true
			player.RespawnLocation = frontierSpawn
			player.CharacterAdded:Connect(function()
				inWild[player] = true
			end)
			return
		end
		-- Respawning puts you back at your shop
		player.CharacterAdded:Connect(function()
			if inWild[player] then
				inWild[player] = nil
				Remotes.WildTravel:FireClient(player, "home")
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		inWild[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / Wild.MARKER_RATE then
			return
		end
		local step = elapsed
		elapsed = 0
		local now = os.clock()
		rescueFallen()
		for _, monster in monsters do
			updateMonster(monster, step, now)
		end
	end)
end

return WildService
